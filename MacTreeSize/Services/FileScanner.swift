import Foundation

protocol ScannerServiceProtocol {
    func scan(url: URL, onRootCreated: @escaping (FileNode) -> Void) async throws
    func stop()
}

actor FileScanner: ScannerServiceProtocol {
    private var isTaskCancelled = false
    
    func stop() {
        isTaskCancelled = true
    }
    
    func scan(url: URL, onRootCreated: @escaping (FileNode) -> Void) async throws {
        isTaskCancelled = false
        
        // 1. Create Root
        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        let isDirectory = resourceValues.isDirectory ?? false
        let root = FileNode(url: url, isDirectory: isDirectory)
        root.modificationDate = resourceValues.contentModificationDate
        
        // 2. Notify
        await MainActor.run {
            onRootCreated(root)
        }
        
        // 3. Start Recursive Scan
        if isDirectory {
            root.size = await processDirectory(node: root)
        } else {
            let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            let size = Int64(fileSize ?? 0)
            await MainActor.run { root.size = size }
        }
    }
    
    // Returns total size of the directory
    private func processDirectory(node: FileNode) async -> Int64 {
        if isTaskCancelled { return 0 }
        
        await MainActor.run { node.isLoading = true }
        
        let fileManager = FileManager.default
        let url = node.url
        
        var totalSize: Int64 = 0
        
        do {
            // Get contents (shallow)
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isPackageKey]
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
            
            var children: [FileNode] = []
            var fileSizes: Int64 = 0
            
            for fileURL in contents {
                if isTaskCancelled { break }
                
                let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isPackage = resourceValues?.isPackage ?? false
                let size = Int64(resourceValues?.fileSize ?? 0)
                let date = resourceValues?.contentModificationDate
                
                let child = FileNode(url: fileURL, isDirectory: isDir, parent: node)
                child.modificationDate = date
                
                if !isDir {
                    child.size = size
                    fileSizes += size
                }
                // If it's a directory, size is 0 initially (or whatever we want)
                
                children.append(child)
            }
            
            // Publish initial children
            await MainActor.run {
                node.children = children
                // node.sortChildren(by: .size) // Sort later?
            }
            
            // Recurse for directories
            // We use a TaskGroup to scan subdirectories in parallel
            totalSize = try await withThrowingTaskGroup(of: Int64.self) { group in
                for child in children where child.isDirectory {
                    group.addTask {
                        return await self.processDirectory(node: child)
                    }
                }
                
                var accumulatedSize = fileSizes
                
                // Collect results
                for try await childSize in group {
                    accumulatedSize += childSize
                    if self.isTaskCancelled { throw CancellationError() }
                }
                
                return accumulatedSize
            }
            
        } catch {
             print("Error scanning \(url.path): \(error)")
        }
        
        // Final update for this node
        await MainActor.run {
            node.size = totalSize
            node.isLoading = false
            node.sortChildren(by: .size)
        }
        
        return totalSize
    }
}

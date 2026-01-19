import Foundation

protocol ScannerServiceProtocol: Actor {
    func scan(url: URL, onRootCreated: @escaping @MainActor (FileNode) -> Void) async throws
    func stop()
}

actor FileScanner: ScannerServiceProtocol {
    private var isTaskCancelled = false
    
    func stop() {
        isTaskCancelled = true
    }
    
    func scan(url: URL, onRootCreated: @escaping @MainActor (FileNode) -> Void) async throws {
        isTaskCancelled = false
        
        // Handle Security Scoped Bookmark Access for the duration of the scan
        // If the URL is a security scoped resource, we need to access it.
        // Since we are not resolving bookmarks here, we assume the URL is already resolved or accessible.
        // However, if we were passed a URL that needs startAccessingSecurityScopedResource, we should do it.
        // But FileScanner shouldn't necessarily manage that unless passed a wrapper.
        // For now, assume the caller (ContentViewModel) handles the primary access, 
        // OR we can try to access it here just in case.
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // 1. Create Root
        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        let isDirectory = resourceValues.isDirectory ?? false
        let modificationDate = resourceValues.contentModificationDate
        
        // Create root on MainActor
        let root: FileNode = await MainActor.run {
            let node = FileNode(url: url, isDirectory: isDirectory)
            node.modificationDate = modificationDate
            onRootCreated(node)
            return node
        }
        
        // 3. Start Recursive Scan
        if isDirectory {
            let totalSize = await processDirectory(node: root)
            await MainActor.run { root.size = totalSize }
        } else {
            let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            let size = Int64(fileSize ?? 0)
            await MainActor.run { root.size = size }
        }
    }
    
    // Returns total size of the directory
    private struct ChildData: Sendable {
        let url: URL
        let isDir: Bool
        let isPackage: Bool
        let size: Int64
        let date: Date?
    }
    
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
            
            var childrenData: [ChildData] = []
            
            for fileURL in contents {
                if isTaskCancelled { break }
                
                let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys))
                let isDir = resourceValues?.isDirectory ?? false
                let isPackage = resourceValues?.isPackage ?? false
                let size = Int64(resourceValues?.fileSize ?? 0)
                let date = resourceValues?.contentModificationDate
                
                childrenData.append(ChildData(url: fileURL, isDir: isDir, isPackage: isPackage, size: size, date: date))
                
                if !isDir {
                    fileSizes += size
                }
            }
            
            // Create FileNode objects on MainActor to ensure thread safety for the parent relationship and @Published properties
            children = await MainActor.run { [childrenData] in
                var nodes: [FileNode] = []
                for data in childrenData {
                    let child = FileNode(url: data.url, isDirectory: data.isDir, parent: node)
                    child.modificationDate = data.date
                    if !data.isDir {
                        child.size = data.size
                    }
                    nodes.append(child)
                }
                
                node.children = nodes
                return nodes
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
        await MainActor.run { [totalSize] in
            node.size = totalSize
            node.isLoading = false
            // node.sortChildren(by: .size) // Avoid sorting during scan to improve performance, do it on demand or at end
        }
        
        return totalSize
    }
}

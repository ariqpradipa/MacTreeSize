import Foundation
import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
class ContentViewModel: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFolder: URL?
    @Published var currentPreset: ScanPreset?
    @Published var statistics = ScanStatistics()
    
    private let scanner: ScannerServiceProtocol
    private var favoritesManager: FavoritesManager?
    
    init(scanner: ScannerServiceProtocol = FileScanner()) {
        self.scanner = scanner
    }
    
    func setFavoritesManager(_ manager: FavoritesManager) {
        self.favoritesManager = manager
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            self.selectedFolder = panel.url
            startScan()
        }
    }
    
    func startScan() {
        guard let url = selectedFolder else { return }
        performScan(url: url)
    }
    
    func scanVolume(_ volume: VolumeInfo) {
        selectedFolder = volume.url
        performScan(url: volume.url)
    }
    
    func scanLocation(_ url: URL, bookmarkData: Data? = nil) {
        // Resolve bookmark if available to ensure access to the security-scoped resource
        var targetURL = url
        var isStale = false
        
        if let data = bookmarkData {
            do {
                // Resolving the bookmark allows the system to refresh the security scope access
                targetURL = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                   print("Bookmark is stale for \(targetURL.path)")
                   // In a real app, we might want to regenerate and save the bookmark here
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
                // Fallback to original URL if resolution fails, though it might lack permissions
            }
        }
        
        selectedFolder = targetURL
        performScan(url: targetURL)
    }
    
    func scanWithPreset(_ preset: ScanPreset) {
        currentPreset = preset
        selectFolder()
    }
    
    private func performScan(url: URL) {
        stopScan() // Stop any previous scan
        
        isScanning = true
        errorMessage = nil
        rootNode = nil
        statistics.startScan()
        
        // Add to recent scans
        favoritesManager?.addRecentScan(url: url)
        
        Task {
            do {
                try await scanner.scan(url: url) { root in
                    self.rootNode = root
                    self.statistics.calculateStatistics(from: root)
                }
                self.statistics.endScan()
                self.isScanning = false
            } catch is CancellationError {
                self.statistics.endScan()
                // Ignore
            } catch {
                self.errorMessage = error.localizedDescription
                self.statistics.endScan()
                self.isScanning = false
            }
        }
    }
    
    func stopScan() {
        Task {
            await scanner.stop()
        }
        isScanning = false
    }
    
    func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }
    
    func moveToTrash(_ node: FileNode) {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            // Remove node from parent
            if let parent = node.parent {
                parent.children?.removeAll { $0.id == node.id }
                updateSizeUpwards(from: parent, by: -node.size)
            } else {
                self.rootNode = nil
            }
        } catch {
            self.errorMessage = "Failed to move to trash: \(error.localizedDescription)"
        }
    }
    
    private func updateSizeUpwards(from node: FileNode, by delta: Int64) {
        node.size += delta
        if let parent = node.parent {
            updateSizeUpwards(from: parent, by: delta)
        }
    }
    
    // MARK: - Quick Actions
    
    func exportReport() {
        guard let root = rootNode else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "disk_analysis_report.csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            let report = generateCSVReport(from: root)
            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.errorMessage = "Failed to export report: \(error.localizedDescription)"
            }
        }
    }
    
    private func generateCSVReport(from root: FileNode) -> String {
        var csv = "Path,Name,Type,Size (Bytes),Size (Formatted),Modified Date\n"
        
        func traverse(_ node: FileNode, depth: Int = 0) {
            let type = node.isDirectory ? "Folder" : "File"
            let modDate = node.modificationDate?.formatted(date: .numeric, time: .shortened) ?? "N/A"
            let escapedPath = node.url.path.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedName = node.name.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(escapedPath)\",\"\(escapedName)\",\(type),\(node.size),\(node.formattedSize),\(modDate)\n"
            
            if let children = node.children {
                for child in children {
                    traverse(child, depth: depth + 1)
                }
            }
        }
        
        traverse(root)
        return csv
    }
    
    func emptyTrash() {
        let alert = NSAlert()
        alert.messageText = "Empty Trash?"
        alert.informativeText = "This will permanently delete all items in the Trash. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                let script = """
                tell application "Finder"
                    empty trash
                end tell
                """
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                    if let error = error {
                        self.errorMessage = "Failed to empty trash: \(error)"
                    }
                }
            }
        }
    }
}

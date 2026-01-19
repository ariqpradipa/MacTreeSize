import Foundation
import SwiftUI
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    @Published var rootNode: FileNode?
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFolder: URL?
    
    private let scanner: ScannerServiceProtocol
    
    init(scanner: ScannerServiceProtocol = FileScanner()) {
        self.scanner = scanner
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
        
        stopScan() // Stop any previous scan
        
        isScanning = true
        errorMessage = nil
        rootNode = nil
        
        Task {
            do {
                try await scanner.scan(url: url) { root in
                    self.rootNode = root
                }
                self.isScanning = false
            } catch is CancellationError {
                // Ignore
            } catch {
                self.errorMessage = error.localizedDescription
                self.isScanning = false
            }
        }
    }
    
    func stopScan() {
        scanner.stop()
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
}

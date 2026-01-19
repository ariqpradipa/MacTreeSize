import Foundation
import Combine

class FileNode: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    
    @Published var size: Int64 = 0
    @Published var children: [FileNode]? = nil
    @Published var isLoading: Bool = false
    
    weak var parent: FileNode?
    
    var modificationDate: Date?
    
    // Formatting helpers
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    init(url: URL, isDirectory: Bool, parent: FileNode? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.parent = parent
    }
    
    func sortChildren(by sortOption: SortOption) {
        guard let children = children else { return }
        
        switch sortOption {
        case .size:
            self.children = children.sorted { $0.size > $1.size }
        case .name:
            self.children = children.sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
        }
    }
    
    func sortRecursive(using comparators: [KeyPathComparator<FileNode>]) {
        guard let children = children else { return }
        self.children = children.sorted(using: comparators)
        // Recursively sort children? 
        // For a large tree, this freezes the UI.
        // Ideally we only sort what is visible. 
        // But let's do a Task to sort in background? 
        // Updating the model must be on MainActor. 
        // Let's just sort the immediate children for now, or just the top level?
        // Users expect recursive sort usually.
        // Let's just do immediate children for now to see performance.
        self.children?.forEach { $0.sortRecursive(using: comparators) }
    }
}

enum SortOption {
    case size
    case name
}

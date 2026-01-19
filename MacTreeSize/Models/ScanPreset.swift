import Foundation

enum ScanPreset: String, CaseIterable, Identifiable {
    case standard = "Standard Scan"
    case largeFiles = "Find Large Files"
    case oldFiles = "Find Old Files"
    case cacheFiles = "Cache & Temp Files"
    case developerWaste = "Developer Waste"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .standard: return "scope"
        case .largeFiles: return "doc.badge.ellipsis"
        case .oldFiles: return "calendar.badge.clock"
        case .cacheFiles: return "trash.circle"
        case .developerWaste: return "terminal.fill"
        }
    }
    
    var description: String {
        switch self {
        case .standard:
            return "Complete directory scan"
        case .largeFiles:
            return "Files larger than 100 MB"
        case .oldFiles:
            return "Files not modified in 6+ months"
        case .cacheFiles:
            return "Caches, logs, and temporary files"
        case .developerWaste:
            return "node_modules, build folders, .git"
        }
    }
    
    var targetPaths: [String] {
        switch self {
        case .standard:
            return []
        case .largeFiles:
            return []
        case .oldFiles:
            return []
        case .cacheFiles:
            return ["Library/Caches", "tmp", "var/tmp"]
        case .developerWaste:
            return []
        }
    }
    
    var targetFolderNames: Set<String> {
        switch self {
        case .developerWaste:
            return ["node_modules", ".git", "build", "dist", "target", ".gradle", "bin", "obj", "DerivedData", "Pods"]
        case .cacheFiles:
            return ["Caches", "Cache", "tmp", "temp", "logs"]
        default:
            return []
        }
    }
    
    var minimumSize: Int64? {
        switch self {
        case .largeFiles:
            return 100_000_000 // 100 MB
        default:
            return nil
        }
    }
    
    var maximumAge: TimeInterval? {
        switch self {
        case .oldFiles:
            return -6 * 30 * 24 * 3600 // 6 months
        default:
            return nil
        }
    }
    
    func shouldInclude(_ node: FileNode) -> Bool {
        // Check minimum size
        if let minSize = minimumSize, node.size < minSize {
            return false
        }
        
        // Check age
        if let maxAge = maximumAge, let modDate = node.modificationDate {
            let cutoffDate = Date().addingTimeInterval(maxAge)
            if modDate > cutoffDate {
                return false
            }
        }
        
        // Check folder names
        if !targetFolderNames.isEmpty {
            let folderName = node.url.lastPathComponent
            if node.isDirectory && targetFolderNames.contains(folderName) {
                return true
            }
            // Check if parent folder matches
            let parentFolderName = node.url.deletingLastPathComponent().lastPathComponent
            if targetFolderNames.contains(parentFolderName) {
                return true
            }
        }
        
        return self == .standard || targetFolderNames.isEmpty
    }
}

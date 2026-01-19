import Foundation
import Combine

@MainActor
class ScanStatistics: ObservableObject {
    @Published var totalFiles: Int = 0
    @Published var totalFolders: Int = 0
    @Published var totalSize: Int64 = 0
    @Published var scanDuration: TimeInterval = 0
    @Published var categoryStats: [FileCategoryStats] = []
    @Published var largestFile: FileNode?
    @Published var scanStartTime: Date?
    @Published var isScanning: Bool = false
    
    var totalItems: Int {
        totalFiles + totalFolders
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var formattedDuration: String {
        if scanDuration < 60 {
            return String(format: "%.1f sec", scanDuration)
        } else {
            let minutes = Int(scanDuration / 60)
            let seconds = Int(scanDuration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var averageFileSize: Int64 {
        guard totalFiles > 0 else { return 0 }
        return totalSize / Int64(totalFiles)
    }
    
    func startScan() {
        reset()
        scanStartTime = Date()
        isScanning = true
    }
    
    func endScan() {
        if let startTime = scanStartTime {
            scanDuration = Date().timeIntervalSince(startTime)
        }
        isScanning = false
    }
    
    func reset() {
        totalFiles = 0
        totalFolders = 0
        totalSize = 0
        scanDuration = 0
        categoryStats = []
        largestFile = nil
        scanStartTime = nil
        isScanning = false
    }
    
    func calculateStatistics(from rootNode: FileNode) {
        reset()
        var stats: [FileCategory: FileCategoryStats] = [:]
        
        // Initialize all categories
        for category in FileCategory.allCases {
            stats[category] = FileCategoryStats(category: category)
        }
        
        var largestFileFound: FileNode?
        var maxSize: Int64 = 0
        
        func traverse(_ node: FileNode) {
            if node.isDirectory {
                totalFolders += 1
                if let children = node.children {
                    for child in children {
                        traverse(child)
                    }
                }
            } else {
                totalFiles += 1
                totalSize += node.size
                
                // Track largest file
                if node.size > maxSize {
                    maxSize = node.size
                    largestFileFound = node
                }
                
                // Categorize
                let ext = node.url.pathExtension
                let category = FileCategory.category(for: ext)
                stats[category]?.totalSize += node.size
                stats[category]?.fileCount += 1
            }
        }
        
        traverse(rootNode)
        
        // Convert to array and calculate percentages
        var categoryArray = Array(stats.values)
        for i in 0..<categoryArray.count {
            _ = totalSize > 0 ? Double(categoryArray[i].totalSize) / Double(totalSize) : 0
            categoryArray[i] = FileCategoryStats(
                category: categoryArray[i].category,
                totalSize: categoryArray[i].totalSize,
                fileCount: categoryArray[i].fileCount
            )
        }
        
        // Sort by size and keep only non-zero
        self.categoryStats = categoryArray
            .filter { $0.totalSize > 0 }
            .sorted { $0.totalSize > $1.totalSize }
        
        self.largestFile = largestFileFound
    }
    
    func updateDuringScans() {
        guard isScanning, let startTime = scanStartTime else { return }
        scanDuration = Date().timeIntervalSince(startTime)
    }
}

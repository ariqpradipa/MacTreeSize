import Foundation
import Combine

enum FileCategory: String, CaseIterable, Identifiable {
    case videos = "Videos"
    case images = "Images"
    case audio = "Audio"
    case documents = "Documents"
    case archives = "Archives"
    case code = "Code"
    case applications = "Applications"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .videos: return "film.fill"
        case .images: return "photo.fill"
        case .audio: return "music.note"
        case .documents: return "doc.text.fill"
        case .archives: return "archivebox.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .applications: return "app.fill"
        case .other: return "doc.fill"
        }
    }
    
    var extensions: Set<String> {
        switch self {
        case .videos:
            return ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v", "webm", "mpeg", "mpg"]
        case .images:
            return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "svg", "heic", "webp", "ico", "raw"]
        case .audio:
            return ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
        case .documents:
            return ["pdf", "doc", "docx", "txt", "rtf", "pages", "xls", "xlsx", "numbers", "ppt", "pptx", "keynote", "odt", "ods", "odp"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg"]
        case .code:
            return ["swift", "py", "java", "cpp", "c", "h", "js", "ts", "html", "css", "json", "xml", "yaml", "yml", "sh", "rb", "go", "rs", "php"]
        case .applications:
            return ["app"]
        case .other:
            return []
        }
    }
    
    static func category(for fileExtension: String) -> FileCategory {
        let ext = fileExtension.lowercased()
        for category in FileCategory.allCases where category != .other {
            if category.extensions.contains(ext) {
                return category
            }
        }
        return .other
    }
}

struct FileCategoryStats: Identifiable {
    let category: FileCategory
    var totalSize: Int64 = 0
    var fileCount: Int = 0
    
    var id: String { category.id }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var percentage: Double {
        0 // Will be calculated relative to total
    }
}

enum SmartFilter: Identifiable, CaseIterable {
    case largeFiles1GB
    case largeFiles100MB
    case largeFiles10MB
    case oldFilesYear
    case oldFiles6Months
    case recentWeek
    case recentMonth
    case showHidden
    
    var id: String {
        switch self {
        case .largeFiles1GB: return "large_1gb"
        case .largeFiles100MB: return "large_100mb"
        case .largeFiles10MB: return "large_10mb"
        case .oldFilesYear: return "old_year"
        case .oldFiles6Months: return "old_6months"
        case .recentWeek: return "recent_week"
        case .recentMonth: return "recent_month"
        case .showHidden: return "show_hidden"
        }
    }
    
    var title: String {
        switch self {
        case .largeFiles1GB: return "Files > 1 GB"
        case .largeFiles100MB: return "Files > 100 MB"
        case .largeFiles10MB: return "Files > 10 MB"
        case .oldFilesYear: return "Older than 1 Year"
        case .oldFiles6Months: return "Older than 6 Months"
        case .recentWeek: return "Modified This Week"
        case .recentMonth: return "Modified This Month"
        case .showHidden: return "Show Hidden Files"
        }
    }
    
    var icon: String {
        switch self {
        case .largeFiles1GB, .largeFiles100MB, .largeFiles10MB:
            return "doc.badge.plus"
        case .oldFilesYear, .oldFiles6Months:
            return "clock.arrow.circlepath"
        case .recentWeek, .recentMonth:
            return "clock.fill"
        case .showHidden:
            return "eye.slash.fill"
        }
    }
    
    func matches(_ node: FileNode) -> Bool {
        switch self {
        case .largeFiles1GB:
            return node.size >= 1_000_000_000
        case .largeFiles100MB:
            return node.size >= 100_000_000
        case .largeFiles10MB:
            return node.size >= 10_000_000
        case .oldFilesYear:
            guard let date = node.modificationDate else { return false }
            return date < Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case .oldFiles6Months:
            guard let date = node.modificationDate else { return false }
            return date < Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .recentWeek:
            guard let date = node.modificationDate else { return false }
            return date > Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .recentMonth:
            guard let date = node.modificationDate else { return false }
            return date > Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .showHidden:
            return true // This is handled differently (shows all files)
        }
    }
}

@MainActor
class FilterManager: ObservableObject {
    @Published var selectedCategories: Set<FileCategory> = []
    @Published var selectedFilters: Set<SmartFilter> = []
    @Published var showHiddenFiles: Bool = false
    
    var isFilterActive: Bool {
        !selectedCategories.isEmpty || !selectedFilters.isEmpty
    }
    
    func toggleCategory(_ category: FileCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    func toggleFilter(_ filter: SmartFilter) {
        if filter == .showHidden {
            showHiddenFiles.toggle()
            return
        }
        
        if selectedFilters.contains(filter) {
            selectedFilters.remove(filter)
        } else {
            selectedFilters.insert(filter)
        }
    }
    
    func clearAllFilters() {
        selectedCategories.removeAll()
        selectedFilters.removeAll()
        showHiddenFiles = false
    }
    
    func matchesFilters(_ node: FileNode) -> Bool {
        // Category filter
        if !selectedCategories.isEmpty {
            let ext = node.url.pathExtension
            let category = FileCategory.category(for: ext)
            if !selectedCategories.contains(category) {
                return false
            }
        }
        
        // Smart filters
        if !selectedFilters.isEmpty {
            let matchesAnyFilter = selectedFilters.contains { filter in
                filter.matches(node)
            }
            if !matchesAnyFilter {
                return false
            }
        }
        
        return true
    }
}

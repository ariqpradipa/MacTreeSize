import Foundation
import Combine

struct FavoriteLocation: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    let type: LocationType
    let dateAdded: Date
    var bookmarkData: Data? // Added for Security Scoped Bookmarks
    
    init(id: UUID = UUID(), url: URL, name: String, type: LocationType, dateAdded: Date = Date(), bookmarkData: Data? = nil) {
        self.id = id
        self.url = url
        self.name = name
        self.type = type
        self.dateAdded = dateAdded
        self.bookmarkData = bookmarkData
    }
    
    var icon: String {
        switch type {
        case .system:
            return systemIcon(for: name)
        case .custom:
            return "folder.fill"
        case .recent:
            return "clock.fill"
        }
    }
    
    private func systemIcon(for name: String) -> String {
        switch name.lowercased() {
        case "desktop": return "desktopcomputer"
        case "documents": return "doc.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "applications": return "app.fill"
        case "library": return "books.vertical.fill"
        case "movies": return "film.fill"
        case "music": return "music.note"
        case "pictures": return "photo.fill"
        default: return "folder.fill"
        }
    }
}

enum LocationType: String, Codable {
    case system
    case custom
    case recent
}

@MainActor
class FavoritesManager: ObservableObject {
    @Published var favorites: [FavoriteLocation] = []
    @Published var recentScans: [FavoriteLocation] = []
    
    private let favoritesKey = "favorites_locations"
    private let recentScansKey = "recent_scans"
    private let maxRecentScans = 10
    
    init() {
        loadFavorites()
        loadRecentScans()
        addDefaultSystemLocations()
    }
    
    private func addDefaultSystemLocations() {
        // Only add if favorites is empty (first launch)
        guard favorites.isEmpty else { return }
        
        // Add root directory as the only default favorite
        let rootURL = URL(fileURLWithPath: "/")
        let favorite = FavoriteLocation(url: rootURL, name: "Root", type: .system)
        favorites.append(favorite)
        
        saveFavorites()
    }
    
    func addCustomFavorite(url: URL, name: String) {
        // Create security scoped bookmark
        let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        
        let favorite = FavoriteLocation(url: url, name: name, type: .custom, bookmarkData: bookmarkData)
        favorites.append(favorite)
        saveFavorites()
    }
    
    func removeFavorite(_ favorite: FavoriteLocation) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }
    
    func addRecentScan(url: URL) {
        // Remove if already exists
        recentScans.removeAll { $0.url == url }
        
        // Create security scoped bookmark for recent scan as well
        let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        
        // Add at the beginning
        let recent = FavoriteLocation(url: url, name: url.lastPathComponent, type: .recent, bookmarkData: bookmarkData)
        recentScans.insert(recent, at: 0)
        
        // Keep only max recent scans
        if recentScans.count > maxRecentScans {
            recentScans = Array(recentScans.prefix(maxRecentScans))
        }
        
        saveRecentScans()
    }
    
    func clearRecentScans() {
        recentScans.removeAll()
        saveRecentScans()
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteLocation].self, from: data) {
            favorites = decoded
        }
    }
    
    private func saveRecentScans() {
        if let encoded = try? JSONEncoder().encode(recentScans) {
            UserDefaults.standard.set(encoded, forKey: recentScansKey)
        }
    }
    
    private func loadRecentScans() {
        if let data = UserDefaults.standard.data(forKey: recentScansKey),
           let decoded = try? JSONDecoder().decode([FavoriteLocation].self, from: data) {
            recentScans = decoded
        }
    }
}

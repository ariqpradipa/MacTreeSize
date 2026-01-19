import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var volumeScanner = VolumeScanner()
    @StateObject private var favoritesManager = FavoritesManager()
    @StateObject private var filterManager = FilterManager()
    @ObservedObject var statistics: ScanStatistics
    
    @State private var showAddFavoriteSheet = false
    
    var body: some View {
        List {
            // Volumes Section
            volumesSection
            
            // Favorites Section
            favoritesSection
            
            // Recent Scans
            recentScansSection
            
            // Scan Presets
            presetsSection
            
            // File Type Categories
            if viewModel.rootNode != nil {
                categoriesSection
            }
            
            // Smart Filters
            filtersSection
            
            // Statistics
            if viewModel.rootNode != nil {
                statisticsSection
            }
            
            // Actions
            actionsSection
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 350)
        .onAppear {
            volumeScanner.scanVolumes()
        }
        .sheet(isPresented: $showAddFavoriteSheet) {
            AddFavoriteSheet(favoritesManager: favoritesManager)
        }
    }
    
    // MARK: - Volumes Section
    private var volumesSection: some View {
        Section("Volumes") {
            ForEach(volumeScanner.volumes) { volume in
                VolumeRowView(volume: volume) {
                    viewModel.scanVolume(volume)
                }
            }
            
            Button(action: { volumeScanner.scanVolumes() }) {
                Label("Refresh Volumes", systemImage: "arrow.clockwise")
            }
            .font(.caption)
        }
    }
    
    // MARK: - Favorites Section
    private var favoritesSection: some View {
        Section("Favorites") {
            ForEach(favoritesManager.favorites) { favorite in
                FavoriteRowView(favorite: favorite) {
                    if favorite.type == .custom || favorite.type == .recent {
                         // Use background thread/Task to handle potential heavy lifting or delays? 
                         // scanLocation is synchronous but spawns a Task. 
                         // Just ensuring UI feedback is key.
                    }
                    viewModel.scanLocation(favorite.url, bookmarkData: favorite.bookmarkData)
                }
                .contextMenu {
                    if favorite.type == .custom {
                        Button("Remove", role: .destructive) {
                            favoritesManager.removeFavorite(favorite)
                        }
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([favorite.url])
                    }
                }
            }
            
            Button(action: { showAddFavoriteSheet = true }) {
                Label("Add Favorite", systemImage: "plus.circle")
            }
            .font(.caption)
        }
    }
    
    // MARK: - Recent Scans Section
    private var recentScansSection: some View {
        Section("Recent Scans") {
            if favoritesManager.recentScans.isEmpty {
                Text("No recent scans")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(favoritesManager.recentScans.prefix(5)) { recent in
                    FavoriteRowView(favorite: recent) {
                        viewModel.scanLocation(recent.url, bookmarkData: recent.bookmarkData)
                    }
                }
                
                if favoritesManager.recentScans.count > 0 {
                    Button("Clear Recent", role: .destructive) {
                        favoritesManager.clearRecentScans()
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Presets Section
    private var presetsSection: some View {
        Section("Scan Presets") {
            ForEach(ScanPreset.allCases) { preset in
                Button(action: {
                    viewModel.scanWithPreset(preset)
                }) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.rawValue)
                            Text(preset.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: preset.icon)
                    }
                }
            }
        }
    }
    
    // MARK: - Categories Section
    private var categoriesSection: some View {
        Section("File Categories") {
            ForEach(statistics.categoryStats.prefix(8)) { stat in
                Button(action: {
                    filterManager.toggleCategory(stat.category)
                }) {
                    HStack {
                        Image(systemName: stat.category.icon)
                            .foregroundColor(filterManager.selectedCategories.contains(stat.category) ? .accentColor : .secondary)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.category.rawValue)
                                .font(.subheadline)
                            Text("\(stat.fileCount) files • \(stat.formattedSize)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if filterManager.selectedCategories.contains(stat.category) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        Section("Smart Filters") {
            ForEach(SmartFilter.allCases) { filter in
                Button(action: {
                    filterManager.toggleFilter(filter)
                }) {
                    HStack {
                        Image(systemName: filter.icon)
                            .foregroundColor(isFilterActive(filter) ? .accentColor : .secondary)
                            .frame(width: 20)
                        Text(filter.title)
                            .font(.subheadline)
                        Spacer()
                        if isFilterActive(filter) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            
            if filterManager.isFilterActive || filterManager.showHiddenFiles {
                Button("Clear All Filters", role: .destructive) {
                    filterManager.clearAllFilters()
                }
                .font(.caption)
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        Section("Statistics") {
            VStack(alignment: .leading, spacing: 8) {
                StatRowView(label: "Total Items", value: "\(statistics.totalItems)")
                StatRowView(label: "Files", value: "\(statistics.totalFiles)")
                StatRowView(label: "Folders", value: "\(statistics.totalFolders)")
                StatRowView(label: "Total Size", value: statistics.formattedTotalSize)
                if statistics.scanDuration > 0 {
                    StatRowView(label: "Scan Duration", value: statistics.formattedDuration)
                }
            }
            .font(.caption)
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        Section("Actions") {
            Button(action: { viewModel.selectFolder() }) {
                Label("Scan Custom Folder", systemImage: "folder.badge.plus")
            }
            
            if viewModel.rootNode != nil {
                Button(action: { viewModel.exportReport() }) {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { viewModel.emptyTrash() }) {
                    Label("Empty Trash", systemImage: "trash")
                }
            }
        }
    }
    
    private func isFilterActive(_ filter: SmartFilter) -> Bool {
        if filter == .showHidden {
            return filterManager.showHiddenFiles
        }
        return filterManager.selectedFilters.contains(filter)
    }
}

// MARK: - Supporting Views

struct VolumeRowView: View {
    let volume: VolumeInfo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: volume.icon)
                        .foregroundColor(.accentColor)
                    Text(volume.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(volume.formattedUsed)
                        Text("of")
                            .foregroundColor(.secondary)
                        Text(volume.formattedTotal)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                            
                            Rectangle()
                                .fill(usageColor(for: volume.usedPercentage))
                                .frame(width: geometry.size.width * volume.usedPercentage)
                        }
                        .frame(height: 4)
                        .cornerRadius(2)
                    }
                    .frame(height: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func usageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<0.7:
            return .green
        case 0.7..<0.9:
            return .orange
        default:
            return .red
        }
    }
}

struct FavoriteRowView: View {
    let favorite: FavoriteLocation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(favorite.name, systemImage: favorite.icon)
        }
        .buttonStyle(.plain)
    }
}

struct StatRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct AddFavoriteSheet: View {
    @ObservedObject var favoritesManager: FavoritesManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?
    @State private var customName: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Favorite Location")
                .font(.headline)
            
            if let url = selectedURL {
                VStack(alignment: .leading) {
                    Text("Selected:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(url.path)
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            TextField("Name (optional)", text: $customName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Choose Folder") {
                    selectFolder()
                }
                
                Button("Add") {
                    if let url = selectedURL {
                        let name = customName.isEmpty ? url.lastPathComponent : customName
                        favoritesManager.addCustomFavorite(url: url, name: name)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedURL == nil)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            selectedURL = panel.url
            if customName.isEmpty {
                customName = panel.url?.lastPathComponent ?? ""
            }
        }
    }
}

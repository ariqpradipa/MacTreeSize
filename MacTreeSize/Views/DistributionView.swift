import SwiftUI
import Charts

struct DistributionView: View {
    @ObservedObject var rootNode: FileNode
    @State private var itemsToShow = 20
    
    // Configuration for visualization
    private let maxNameLength = 40
    private let minItemsToShow = 10
    private let maxItemsToShow = 50
    
    // We might want to show the top N items + "Others"
    var topItems: [FileNode] {
        guard let children = rootNode.children else { return [] }
        let sorted = children.sorted { $0.size > $1.size }
        return Array(sorted.prefix(itemsToShow))
    }
    
    var hasMoreItems: Bool {
        guard let children = rootNode.children else { return false }
        return children.count > itemsToShow
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with controls
            HStack {
                Text("Size Distribution")
                    .font(.headline)
                
                Spacer()
                
                if !topItems.isEmpty {
                    HStack(spacing: 6) {
                        Text("Show:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()
                        
                        Picker("", selection: $itemsToShow) {
                            Text("10").tag(10)
                            Text("20").tag(20)
                            Text("30").tag(30)
                            Text("50").tag(50)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            if topItems.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Chart(topItems) { item in
                            BarMark(
                                x: .value("Size", item.size),
                                y: .value("Name", truncatedName(item.name))
                            )
                            .foregroundStyle(by: .value("Type", item.isDirectory ? "Folder" : "File"))
                        }
                        .chartLegend(position: .bottom, alignment: .center)
                        .chartXAxis {
                            AxisMarks(format: ByteCountFormatStyle(style: .file))
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                if let name = value.as(String.self) {
                                    AxisValueLabel {
                                        Text(name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .help(fullName(for: name))
                                            .frame(width: 80, alignment: .trailing) // Fixed width for alignment
                                    }
                                }
                            }
                        }
                        .frame(height: CGFloat(topItems.count * 35 + 80))
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // List view with details
                        VStack(spacing: 0) {
                            ForEach(topItems) { item in
                                HStack {
                                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundColor(item.isDirectory ? .blue : .secondary)
                                        .frame(width: 16)
                                    
                                    Text(item.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .help(item.name)
                                    
                                    Spacer()
                                    
                                    Text(item.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Text(percentageString(for: item))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .trailing)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                                
                                if item.id != topItems.last?.id {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if hasMoreItems {
                            Text("Showing top \(itemsToShow) of \(rootNode.children?.count ?? 0) items")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
        }
    }
    
    // Helper functions
    private func truncatedName(_ name: String) -> String {
        if name.count > maxNameLength {
            let index = name.index(name.startIndex, offsetBy: maxNameLength)
            return String(name[..<index]) + "..."
        }
        return name
    }
    
    private func fullName(for truncated: String) -> String {
        return topItems.first { truncatedName($0.name) == truncated }?.name ?? truncated
    }
    
    private func percentageString(for item: FileNode) -> String {
        guard rootNode.size > 0 else { return "0%" }
        let percentage = Double(item.size) / Double(rootNode.size) * 100.0
        return String(format: "%.1f%%", percentage)
    }
}

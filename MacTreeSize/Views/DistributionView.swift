import SwiftUI
import Charts

struct DistributionView: View {
    @ObservedObject var rootNode: FileNode
    
    // We might want to show the top N items + "Others"
    var topItems: [FileNode] {
        guard let children = rootNode.children else { return [] }
        let sorted = children.sorted { $0.size > $1.size }
        return Array(sorted.prefix(10))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Size Distribution")
                .font(.headline)
                .padding(.horizontal)
            
            if topItems.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar")
            } else {
                Chart(topItems) { item in
                    BarMark(
                        x: .value("Size", item.size),
                        y: .value("Name", item.name)
                    )
                    .foregroundStyle(by: .value("Type", item.isDirectory ? "Folder" : "File"))
                    .annotation(position: .trailing) {
                        Text(item.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .chartLegend(position: .bottom)
                .chartXAxis {
                    AxisMarks(format: ByteCountFormatStyle(style: .file))
                }
                .padding()
            }
        }
    }
}

//
//  ContentView.swift
//  MacTreeSize
//
//  Created by encore on 19/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var favoritesManager = FavoritesManager()
    @State private var selection: Set<FileNode.ID> = []
    @State private var sortOrder: [KeyPathComparator<FileNode>] = [
        .init(\.size, order: .reverse)
    ]
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                statistics: viewModel.statistics
            )
            .environmentObject(favoritesManager)
        } detail: {
            detailView
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.selectFolder() }) {
                    Label("Scan", systemImage: "play.fill")
                }
                .disabled(viewModel.isScanning)
            }
            
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { viewModel.stopScan() }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.isScanning)
            }
            
            ToolbarItem(placement: .status) {
                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.setFavoritesManager(favoritesManager)
        }
    }

    @ViewBuilder
    var detailView: some View {
        VSplitView {
            VStack(spacing: 0) {
                if let root = viewModel.rootNode {
                    fileTable(root: root)
                } else {
                    ContentUnavailableView("No Scan Data", systemImage: "externaldrive", description: Text("Select a folder to start scanning."))
                }
            }
            .frame(minHeight: 300)
            
            if let root = viewModel.rootNode {
                DistributionView(rootNode: root)
                    .frame(minHeight: 200)
                    .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    func fileTable(root: FileNode) -> some View {
        Table([root], children: \.children, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { node in
                HStack {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                        .foregroundColor(node.isDirectory ? .blue : .secondary)
                    Text(node.name)
                    
                    if node.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .padding(.leading, 4)
                    }
                }
                .contextMenu {
                    Button("Reveal in Finder") {
                        viewModel.revealInFinder(node)
                    }
                    Button("Move to Trash", role: .destructive) {
                        viewModel.moveToTrash(node)
                    }
                }
            }
            .width(min: 200, ideal: 300)
            
            TableColumn("Size", value: \.size) { node in
                Text(node.formattedSize)
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Modified") { node in
                Text(node.modificationDate?.formatted(date: .numeric, time: .shortened) ?? "-")
            }
        }
        .onChange(of: sortOrder) { newOrder in
            root.sortRecursive(using: newOrder)
        }
    }
}

#Preview {
    ContentView()
}

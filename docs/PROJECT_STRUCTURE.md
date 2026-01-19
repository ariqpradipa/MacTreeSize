# Project Structure: MacTreeSize

This document outlines the file structure and architecture of the MacTreeSize application. It is intended to help developers and AI assistants understand the codebase organization.

## Root Directory

- **`MacTreeSize.xcodeproj`**: The Xcode project bundle.
- **`docs/`**: Documentation files.
  - `IMPLEMENTATION_PLAN.md`: The original development plan and progress checklist.
  - `PROJECT_STRUCTURE.md`: This file.

## Source Code (`MacTreeSize/`)

The main application source code is located in the `MacTreeSize` directory. The project follows a roughly MVVM (Model-View-ViewModel) architecture.

### Entry Point
- **`MacTreeSizeApp.swift`**: The main entry point of the SwiftUI application. Sets up the window group.

### Views (`Views/` & Root)
- **`ContentView.swift`**: The primary application window.
  - Implements a `NavigationSplitView` with a sidebar for actions and a detail area.
  - Uses `VSplitView` to show a hierarchical file table (`Table`) stacked above a visualization chart.
  - Handles the main toolbar.
- **`Views/DistributionView.swift`**: A visualization component using Swift Charts.
  - Displays a bar chart of the largest files/folders in the currently scanned directory.
  - Handles color coding by file type (Folder vs File).

### ViewModels (`ViewModels/`)
- **`ContentViewModel.swift`**: The main view model driving the `ContentView`.
  - `@MainActor` class conforming to `ObservableObject`.
  - **Responsibilities**:
    - Manages the state of the scan (`isScanning`, `rootNode`).
    - Handles user intents: `startScan`, `stopScan`, `selectFolder`.
    - Implements file actions: `revealInFinder`, `moveToTrash`.
    - Handles error propagation.

### Models (`Models/`)
- **`FileNode.swift`**: The core data model representing a file system node.
  - **Class**: Reference type to support recursive relationships (`parent`, `children`).
  - **Properties**: `url`, `name`, `size`, `children`, `modificationDate`, `isLoading`.
  - **Features**: 
    - Implements `Identifiable` and `ObservableObject`.
    - recursive sorting logic (`sortRecursive`).
    - `formattedSize` helper using `ByteCountFormatter`.

### Services (`Services/`)
- **`FileScanner.swift`**: The scanning engine.
  - **Actor**: Uses Swift Actors to handle concurrency safely.
  - **Protocol**: `ScannerServiceProtocol`.
  - **Logic**:
    - Performs recursive file scanning using `FileManager`.
    - Uses `TaskGroup` for concurrent scanning of subdirectories (planned/implemented).
    - Populates `FileNode` trees.
    - Supports cancellation via atomic flags.

### Resources
- **`Assets.xcassets/`**: Standard Xcode asset catalog for App Icons and Colors.

## Tests

- **`MacTreeSizeTests/`**: Unit test bundles.
- **`MacTreeSizeUITests/`**: UI test bundles.

## Architecture Notes

1.  **Concurrency**: The app uses Swift Structured Concurrency (`async`/`await`). The `FileScanner` is an `actor` that offloads I/O from the main thread. UI updates are dispatched back to the `MainActor` via the `FileNode` `@Published` properties or callbacks.
2.  **Data Flow**:
    - `ContentViewModel` triggers `FileScanner`.
    - `FileScanner` builds `FileNode` hierarchy.
    - `FileNode` updates propagate to SwiftUI Views via `ObservableObject`.
3.  **Performance**:
    - `FileNode` is a class to prevent copying large trees.
    - The `Table` view uses efficient hierarchy rendering.
    - Scanning can be stopped/cancelled.

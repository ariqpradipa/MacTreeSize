# MacTreeSize

MacTreeSize is a powerful, native macOS application designed to help you visualize and manage your disk space usage. Inspired by classic disk usage tools, it provides a clean, modern SwiftUI interface to quickly identify large files and folders that are consuming your storage.

## Features

- **🚀 Fast & Efficient Scanning**: Uses Swift's structured concurrency and actors for high-performance, non-blocking file system scanning.
- **📊 Visual Analysis**:
  - **Hierarchical List**: Drill down into folders to see exactly where space is being used.
  - **Distribution Charts**: Interactive bar charts powered by Swift Charts to visualize file distribution.
- **📂 File Management**:
  - Reveal files directly in Finder.
  - Move unwanted files/folders to the Trash directly from the app.
- **⭐ Favorites**: Bookmark frequently accessed locations for quick re-scanning.
- **🔍 Filtering**: Filtering capabilities to find specific file types or large items (Implied by code structure).
- **🖥️ Native macOS UI**: Built completely with SwiftUI, supporting Dark Mode and standard macOS behaviors.

## Requirements

- **macOS**: 14.0 (Sonoma) or later.
- **Xcode**: 15.0 or later (to build the project).

## Usage

### Running the App

1. **Launch MacTreeSize**.
2. Click the **Scan** button (Play icon) in the toolbar.
3. Select a folder or disk volume you want to analyze.
4. The scan will start immediately. You can view progress in real-time.
5. Navigate through the folder structure in the list view.
6. Use the **Visualization View** at the bottom to see a graphical representation of the selected folder.

### Common Shortcuts
- **Open in Finder**: Right-click a file/folder and select "Show in Finder".
- **Delete**: Right-click and select "Move to Trash".
- **Stop Scan**: Click the "Stop" button in the toolbar to cancel an ongoing operation.

## Installation / Build Instructions

To build and run MacTreeSize locally, follow these steps:

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/MacTreeSize.git
cd MacTreeSize
```

### 2. Open in Xcode
Open the project file using Xcode:
```bash
open MacTreeSize.xcodeproj
```

### 3. Build and Run
1.  Ensure the target **MacTreeSize** is selected in the top bar.
2.  Select your Mac ("My Mac") as the destination.
3.  Press **Cmd + R** or click the **Run** button (Play icon) in Xcode.

## Building for Release

To create a standalone application file (`.app`):

1.  In Xcode, go to **Product** > **Archive**.
2.  Once the archive is created, the Organizer window will open.
3.  Select the latest archive and click **Distribute App**.
4.  Choose **Copy App** (for personal use) or **TestFlight / App Store Connect** (for distribution).
5.  Follow the prompts to export the application.

## Architecture

MacTreeSize is built using modern Swift principles:

-   **MVVM (Model-View-ViewModel)**: Separates UI logic from business logic.
-   **SwiftUI**: Declarative user interface.
-   **Structured Concurrency**: Uses Swift Actors (`FileScanner`) to handle file I/O operations safely on background threads without freezing the UI.
-   **FileNode System**: A reference-based recursive data structure optimized for handling large file trees.

## Project Structure

-   `MacTreeSize/`: Main source code.
    -   `Views/`: SwiftUI views (`ContentView`, `SidebarView`, `DistributionView`).
    -   `ViewModels/`: Logic controllers (`ContentViewModel`).
    -   `Models/`: Data structures (`FileNode`, `ScanStatistics`).
    -   `Services/`: core engines (`FileScanner`, `VolumeScanner`).

For a more detailed deep-dive, see [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md).

## Contributing

Contributions are welcome! If you'd like to improve MacTreeSize:

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

[MIT License](LICENSE).

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedSection) {
                ForEach(LibrarySection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                SidebarFooter()
            }
        } detail: {
            ZStack {
                selectedView
                if store.isScanning {
                    ScanOverlay()
                }
            }
            .navigationTitle(store.selectedSection.title)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.presentLibraryPicker()
                    } label: {
                        Label("Choose Folder", systemImage: "folder.badge.plus")
                    }

                    Button {
                        store.presentXMLPicker()
                    } label: {
                        Label("Import XML", systemImage: "doc.badge.plus")
                    }

                    Button {
                        store.rescanSelectedLibrary()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.libraryURL == nil || store.isScanning)

                    if store.isScanning {
                        Button {
                            store.cancelScan()
                        } label: {
                            Label("Stop Scan", systemImage: "stop.circle")
                        }
                    }
                }
            }
            .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search music")
            .alert("Music Library Lens", isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )) {
                Button("OK", role: .cancel) { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
        }
    }

    @ViewBuilder
    private var selectedView: some View {
        switch store.selectedSection {
        case .dashboard:
            DashboardView()
        case .albums:
            AlbumsView()
        case .artists:
            ArtistsView()
        case .versions:
            SongVersionsView()
        case .missingArtwork:
            MissingArtworkView()
        case .folders:
            FoldersView()
        case .tracks:
            TracksView()
        }
    }
}

private struct SidebarFooter: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let libraryURL = store.libraryURL {
                Label(libraryURL.lastPathComponent, systemImage: "externaldrive")
                    .font(.callout)
                    .lineLimit(1)
                    .help(libraryURL.path)
            } else {
                Label("No folder chosen", systemImage: "externaldrive.badge.questionmark")
                    .font(.callout)
            }

            if let importedXMLURL = store.importedXMLURL {
                Label(importedXMLURL.lastPathComponent, systemImage: "doc.richtext")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(importedXMLURL.path)
            }

            if store.libraryURL != nil {
                Button("Forget Folder") {
                    store.clearRememberedLibrary()
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScanOverlay: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(spacing: 14) {
            ProgressView(value: store.scanProgress.fraction)
                .progressViewStyle(.linear)
                .frame(width: 320)

            Text("Scanning \(DisplayFormatters.integer(store.scanProgress.completedFiles)) of \(DisplayFormatters.integer(store.scanProgress.totalFiles)) files")
                .font(.headline)

            Text(store.scanProgress.currentFileName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 360)

            Button("Stop Scan") {
                store.cancelScan()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 18)
    }
}

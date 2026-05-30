import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        if store.catalogTracks.isEmpty {
            EmptyLibraryView(
                title: "Choose a music folder",
                message: "Music Library Lens will scan local audio files, read available metadata, and show albums, covers, artists, folders, and song versions.",
                actionTitle: "Choose Folder",
                action: store.presentLibraryPicker
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeader(
                        title: "Library Overview",
                        subtitle: summarySubtitle
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                        MetricCard(
                            title: "Tracks",
                            value: DisplayFormatters.integer(store.catalogTracks.count),
                            subtitle: "\(DisplayFormatters.fileSize(store.totalFileSize)) on disk",
                            symbolName: "music.note.list"
                        )
                        MetricCard(
                            title: "Albums",
                            value: DisplayFormatters.integer(store.albumSummaries.count),
                            subtitle: "\(DisplayFormatters.integer(store.missingArtworkAlbums.count)) missing covers",
                            symbolName: "square.stack"
                        )
                        MetricCard(
                            title: "Artists",
                            value: DisplayFormatters.integer(store.artistSummaries.count),
                            subtitle: "Grouped from track artists",
                            symbolName: "music.mic"
                        )
                        MetricCard(
                            title: "Song Versions",
                            value: DisplayFormatters.integer(store.songVersionGroups.count),
                            subtitle: "Same title on multiple artists or albums",
                            symbolName: "rectangle.2.swap"
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Cover Completeness")
                                .font(.headline)
                            Spacer()
                            Text(DisplayFormatters.percent(store.artworkCoverage))
                                .font(.headline)
                        }
                        ProgressView(value: store.artworkCoverage)
                            .progressViewStyle(.linear)
                        Text("\(DisplayFormatters.integer(store.catalogTracks.filter(\.hasArtwork).count)) tracks have embedded or folder artwork.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    HStack(alignment: .top, spacing: 16) {
                        DashboardList(
                            title: "Most Common Song Titles",
                            rows: store.songVersionGroups.prefix(6).map {
                                DashboardRow(
                                    title: $0.title,
                                    detail: "\(DisplayFormatters.integer($0.tracks.count)) versions across \(DisplayFormatters.integer($0.albums.count)) albums"
                                )
                            }
                        )

                        DashboardList(
                            title: "Largest Folders",
                            rows: store.folderSummaries.prefix(6).map {
                                DashboardRow(
                                    title: $0.path,
                                    detail: "\(DisplayFormatters.integer($0.trackCount)) tracks, \(DisplayFormatters.fileSize($0.totalSize))"
                                )
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
    }

    private var summarySubtitle: String {
        if let date = store.lastScanDate {
            return "Last scanned \(DisplayFormatters.shortDate(date))"
        }
        return "Imported from XML"
    }
}

private struct DashboardRow: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
}

private struct DashboardList: View {
    var title: String
    var rows: [DashboardRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if rows.isEmpty {
                Text("Nothing to show yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Divider()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var store: LibraryStore
    @AppStorage("albumTileSize") private var albumTileSize: Double = 172

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    SectionHeader(
                        title: "Albums",
                        subtitle: "\(DisplayFormatters.integer(store.albumSummaries.count)) albums from \(DisplayFormatters.integer(store.filteredTracks.count)) tracks"
                    )
                    Spacer()
                    HStack {
                        Image(systemName: "rectangle.grid.2x2")
                        Slider(value: $albumTileSize, in: 136...230)
                            .frame(width: 150)
                    }
                    .help("Album tile size")
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: albumTileSize), spacing: 18)],
                    spacing: 18
                ) {
                    ForEach(store.albumSummaries) { album in
                        AlbumTile(album: album)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct AlbumTile: View {
    var album: AlbumSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkThumbnail(track: album.artworkTrack, title: album.title)
                .aspectRatio(1, contentMode: .fit)

            Text(album.title)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(album.artist)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Label("\(album.trackCount)", systemImage: "music.note")
                if let year = album.year {
                    Text("\(year)")
                }
                Spacer()
                if !album.hasArtwork {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.orange)
                        .help("No cover art found")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            if let firstURL = album.tracks.first?.url {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([firstURL])
                }
            }
        }
    }
}

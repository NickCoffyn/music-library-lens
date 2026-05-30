import SwiftUI

struct MissingArtworkView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Missing Covers",
                    subtitle: "\(DisplayFormatters.integer(store.missingArtworkAlbums.count)) albums have no embedded or folder cover art"
                )

                ForEach(store.missingArtworkAlbums) { album in
                    MissingArtworkRow(album: album)
                }
            }
            .padding(24)
        }
    }
}

private struct MissingArtworkRow: View {
    var album: AlbumSummary

    var body: some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(track: nil, title: album.title, cornerRadius: 6)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text(album.title)
                    .font(.headline)
                Text(album.artist)
                    .foregroundStyle(.secondary)
                Text("\(DisplayFormatters.integer(album.trackCount)) tracks in \(album.tracks.first?.relativeFolderPath ?? "Unknown folder")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let firstURL = album.tracks.first?.url {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([firstURL])
                } label: {
                    Label("Finder", systemImage: "folder")
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

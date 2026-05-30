import SwiftUI

struct TracksView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Tracks",
                subtitle: "\(DisplayFormatters.integer(store.filteredTracks.count)) matching tracks"
            )
            .padding([.horizontal, .top], 24)

            Table(store.filteredTracks) {
                TableColumn("Title") { track in
                    Text(track.title)
                        .lineLimit(1)
                }
                TableColumn("Artist") { track in
                    Text(track.displayArtist)
                        .lineLimit(1)
                }
                TableColumn("Album") { track in
                    Text(track.displayAlbum)
                        .lineLimit(1)
                }
                TableColumn("Time") { track in
                    Text(track.duration.map(DisplayFormatters.duration) ?? "Unknown")
                }
                TableColumn("Format") { track in
                    Text(track.fileExtension)
                }
                TableColumn("Cover") { track in
                    Image(systemName: track.hasArtwork ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(track.hasArtwork ? .green : .secondary)
                }
                TableColumn("Folder") { track in
                    Text(track.relativeFolderPath)
                        .lineLimit(1)
                }
            }
        }
    }
}

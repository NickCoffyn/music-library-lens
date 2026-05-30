import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Artists",
                    subtitle: "\(DisplayFormatters.integer(store.artistSummaries.count)) artists grouped by track metadata"
                )

                ForEach(store.artistSummaries) { artist in
                    ArtistRow(artist: artist)
                }
            }
            .padding(24)
        }
    }
}

private struct ArtistRow: View {
    var artist: ArtistSummary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.mic.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 5) {
                Text(artist.name)
                    .font(.headline)
                Text("\(DisplayFormatters.integer(artist.trackCount)) tracks on \(DisplayFormatters.integer(artist.albumCount)) albums")
                    .foregroundStyle(.secondary)
                Text(artist.albums.prefix(5).joined(separator: " - "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(artist.formats.joined(separator: ", "))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

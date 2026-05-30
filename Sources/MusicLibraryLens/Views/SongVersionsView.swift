import SwiftUI

struct SongVersionsView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Song Versions",
                    subtitle: "\(DisplayFormatters.integer(store.songVersionGroups.count)) titles appear across multiple artists or albums"
                )

                ForEach(store.songVersionGroups) { group in
                    SongVersionCard(group: group)
                }
            }
            .padding(24)
        }
    }
}

private struct SongVersionCard: View {
    var group: SongVersionGroup
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(group.tracks) { track in
                    TrackMiniRow(track: track)
                    if track.id != group.tracks.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.2.swap")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.headline)
                    Text("\(DisplayFormatters.integer(group.tracks.count)) tracks - \(DisplayFormatters.integer(group.artists.count)) artists - \(DisplayFormatters.integer(group.albums.count)) albums")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(group.formats.joined(separator: ", "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

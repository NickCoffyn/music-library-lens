import SwiftUI

struct FoldersView: View {
    @EnvironmentObject private var store: LibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Folders",
                    subtitle: "\(DisplayFormatters.integer(store.folderSummaries.count)) folders sorted by track count"
                )

                ForEach(store.folderSummaries) { folder in
                    FolderRow(folder: folder)
                }
            }
            .padding(24)
        }
    }
}

private struct FolderRow: View {
    var folder: FolderSummary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder.fill")
                .font(.system(size: 30))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 5) {
                Text(folder.path)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(DisplayFormatters.integer(folder.trackCount)) tracks - \(DisplayFormatters.integer(folder.albumCount)) albums - \(DisplayFormatters.fileSize(folder.totalSize))")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if folder.missingArtworkCount > 0 {
                Label("\(folder.missingArtworkCount)", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .help("Tracks with no cover art")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

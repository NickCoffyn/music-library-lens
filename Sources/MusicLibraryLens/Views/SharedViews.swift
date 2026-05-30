import AppKit
import SwiftUI

struct EmptyLibraryView: View {
    var title: String
    var message: String
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.house")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var subtitle: String
    var symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Spacer()
            }
            Text(value)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ArtworkThumbnail: View {
    var track: MusicTrack?
    var title: String
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                    Text(title)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
                .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
        }
    }

    private var image: NSImage? {
        guard let track else { return nil }
        if let data = track.artworkData, let image = NSImage(data: data) {
            return image
        }
        if let url = track.artworkURL, let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrackMiniRow: View {
    var track: MusicTrack

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(track: track, title: track.title, cornerRadius: 5)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(track.displayArtist) - \(track.displayAlbum)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(track.fileExtension)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 4)
    }
}

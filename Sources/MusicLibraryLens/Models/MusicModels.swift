import Foundation

enum LibrarySection: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case albums
    case artists
    case versions
    case missingArtwork
    case folders
    case tracks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Overview"
        case .albums: return "Albums"
        case .artists: return "Artists"
        case .versions: return "Song Versions"
        case .missingArtwork: return "Missing Covers"
        case .folders: return "Folders"
        case .tracks: return "Tracks"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .albums: return "square.stack"
        case .artists: return "music.mic"
        case .versions: return "rectangle.2.swap"
        case .missingArtwork: return "photo.badge.exclamationmark"
        case .folders: return "folder"
        case .tracks: return "music.note.list"
        }
    }
}

enum TrackSource: String, Sendable {
    case fileScan = "File"
    case xml = "XML"
}

enum ArtworkKind: String, Sendable {
    case embedded = "Embedded"
    case folderFile = "Folder"
    case none = "None"
}

struct ScanProgress: Equatable, Sendable {
    var currentFileName: String = ""
    var completedFiles: Int = 0
    var totalFiles: Int = 0

    var fraction: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(completedFiles) / Double(totalFiles)
    }
}

struct MusicTrack: Identifiable, Sendable {
    var id: UUID
    var url: URL?
    var fileSystemIdentity: String?
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var genre: String
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval?
    var fileExtension: String
    var fileSize: Int64?
    var folderPath: String
    var relativeFolderPath: String
    var source: TrackSource
    var artworkData: Data?
    var artworkURL: URL?
    var artworkKind: ArtworkKind

    init(
        id: UUID = UUID(),
        url: URL?,
        fileSystemIdentity: String? = nil,
        title: String,
        artist: String,
        album: String,
        albumArtist: String,
        genre: String,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        duration: TimeInterval? = nil,
        fileExtension: String,
        fileSize: Int64? = nil,
        folderPath: String,
        relativeFolderPath: String,
        source: TrackSource,
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        artworkKind: ArtworkKind = .none
    ) {
        self.id = id
        self.url = url
        self.fileSystemIdentity = fileSystemIdentity
        self.title = title.nonEmptyOr("Untitled")
        self.artist = artist.nonEmptyOr("Unknown Artist")
        self.album = album.nonEmptyOr("Unknown Album")
        self.albumArtist = albumArtist.nonEmptyOr(self.artist.nonEmptyOr("Unknown Artist"))
        self.genre = genre.nonEmptyOr("Unknown Genre")
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.fileExtension = fileExtension.uppercased()
        self.fileSize = fileSize
        self.folderPath = folderPath
        self.relativeFolderPath = relativeFolderPath.nonEmptyOr("Library root")
        self.source = source
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.artworkKind = artworkKind
    }

    var hasArtwork: Bool {
        artworkData != nil || artworkURL != nil
    }

    var titleKey: String {
        TextNormalizer.songKey(title)
    }

    var artistKey: String {
        TextNormalizer.personKey(artist)
    }

    var albumKey: String {
        TextNormalizer.albumKey(album)
    }

    var albumIdentityKey: String {
        "\(TextNormalizer.personKey(albumArtist))|\(albumKey)"
    }

    var fileIdentityKey: String {
        if let fileSystemIdentity {
            return "fs|\(fileSystemIdentity)"
        }
        if let url {
            return "url|\(url.standardizedFileURL.path.lowercased())"
        }
        return "meta|\(titleKey)|\(artistKey)|\(albumKey)|\(fileExtension)"
    }

    var metadataIdentityKey: String {
        let durationBucket: Int
        if let duration {
            durationBucket = Int(duration.rounded())
        } else {
            durationBucket = -1
        }

        return [
            titleKey,
            artistKey,
            albumKey,
            "\(discNumber ?? -1)",
            "\(trackNumber ?? -1)",
            "\(durationBucket)",
            fileExtension
        ].joined(separator: "|")
    }

    var displayArtist: String {
        artist.nonEmptyOr("Unknown Artist")
    }

    var displayAlbum: String {
        album.nonEmptyOr("Unknown Album")
    }

    func fillingMissingMetadata(from other: MusicTrack) -> MusicTrack {
        var merged = self
        if merged.title.isPlaceholderTitle { merged.title = other.title }
        if merged.artist.isUnknownArtist { merged.artist = other.artist }
        if merged.album.isUnknownAlbum { merged.album = other.album }
        if merged.albumArtist.isUnknownArtist { merged.albumArtist = other.albumArtist }
        if merged.genre.isUnknownGenre { merged.genre = other.genre }
        if merged.year == nil { merged.year = other.year }
        if merged.trackNumber == nil { merged.trackNumber = other.trackNumber }
        if merged.discNumber == nil { merged.discNumber = other.discNumber }
        if merged.duration == nil { merged.duration = other.duration }
        if merged.fileSize == nil { merged.fileSize = other.fileSize }
        if merged.fileSystemIdentity == nil { merged.fileSystemIdentity = other.fileSystemIdentity }
        if !merged.hasArtwork, other.hasArtwork {
            merged.artworkData = other.artworkData
            merged.artworkURL = other.artworkURL
            merged.artworkKind = other.artworkKind
        }
        return merged
    }
}

struct AlbumSummary: Identifiable {
    var id: String
    var title: String
    var artist: String
    var tracks: [MusicTrack]

    var trackCount: Int { tracks.count }
    var discCount: Int { Set(tracks.compactMap(\.discNumber)).count }
    var totalDuration: TimeInterval { tracks.compactMap(\.duration).reduce(0, +) }
    var artworkTrack: MusicTrack? { tracks.first(where: \.hasArtwork) }
    var hasArtwork: Bool { artworkTrack != nil }
    var formats: [String] { Array(Set(tracks.map(\.fileExtension))).sorted() }
    var year: Int? { tracks.compactMap(\.year).min() }
}

struct ArtistSummary: Identifiable {
    var id: String
    var name: String
    var tracks: [MusicTrack]

    var trackCount: Int { tracks.count }
    var albums: [String] { Array(Set(tracks.map(\.displayAlbum))).sorted() }
    var albumCount: Int { albums.count }
    var formats: [String] { Array(Set(tracks.map(\.fileExtension))).sorted() }
}

struct SongVersionGroup: Identifiable {
    var id: String
    var title: String
    var tracks: [MusicTrack]

    var artists: [String] { Array(Set(tracks.map(\.displayArtist))).sorted() }
    var albums: [String] { Array(Set(tracks.map(\.displayAlbum))).sorted() }
    var formats: [String] { Array(Set(tracks.map(\.fileExtension))).sorted() }
    var hasMultipleArtists: Bool { artists.count > 1 }
    var hasMultipleAlbums: Bool { albums.count > 1 }
}

struct FolderSummary: Identifiable {
    var id: String
    var path: String
    var tracks: [MusicTrack]

    var trackCount: Int { tracks.count }
    var albumCount: Int { Set(tracks.map(\.albumIdentityKey)).count }
    var missingArtworkCount: Int { tracks.filter { !$0.hasArtwork }.count }
    var totalSize: Int64 { tracks.compactMap(\.fileSize).reduce(0, +) }
}

enum TextNormalizer {
    static func songKey(_ value: String) -> String {
        var normalized = base(value)
        let removableQualifiers = [
            "remastered", "remaster", "digital remaster", "single version",
            "album version", "bonus track", "original mix", "mono", "stereo"
        ]
        for qualifier in removableQualifiers {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: qualifier))\\b"
            normalized = normalized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func personKey(_ value: String) -> String {
        var normalized = base(value)
        if normalized.hasPrefix("the ") {
            normalized.removeFirst(4)
        }
        return normalized
    }

    static func albumKey(_ value: String) -> String {
        base(value)
    }

    private static func base(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[\[\]\(\)\{\}:;,'"“”‘’!?.]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[-_/]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    func nonEmptyOr(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    var isPlaceholderTitle: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self == "Untitled"
    }

    var isUnknownArtist: Bool {
        self == "Unknown Artist" || trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isUnknownAlbum: Bool {
        self == "Unknown Album" || trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isUnknownGenre: Bool {
        self == "Unknown Genre" || trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

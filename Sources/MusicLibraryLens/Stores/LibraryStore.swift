import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    private static let savedLibraryPathKey = "savedLibraryPathV2"

    @Published var selectedSection: LibrarySection = .dashboard
    @Published var searchText: String = ""
    @Published private(set) var libraryURL: URL?
    @Published private(set) var importedXMLURL: URL?
    @Published private(set) var catalogTracks: [MusicTrack] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanProgress = ScanProgress()
    @Published private(set) var lastScanDate: Date?
    @Published var lastError: String?

    private var scannedTracks: [MusicTrack] = []
    private var xmlTracks: [MusicTrack] = []
    private var scanTask: Task<Void, Never>?
    private var didAttemptSavedLibraryRestore = false
    private var activeScanID: UUID?

    deinit {
        scanTask?.cancel()
    }

    var filteredTracks: [MusicTrack] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalogTracks }
        return catalogTracks.filter { track in
            track.title.localizedCaseInsensitiveContains(query) ||
            track.artist.localizedCaseInsensitiveContains(query) ||
            track.album.localizedCaseInsensitiveContains(query) ||
            track.relativeFolderPath.localizedCaseInsensitiveContains(query) ||
            track.fileExtension.localizedCaseInsensitiveContains(query)
        }
    }

    var albumSummaries: [AlbumSummary] {
        Dictionary(grouping: filteredTracks, by: \.albumIdentityKey)
            .map { key, tracks in
                let sortedTracks = tracks.sortedForAlbum()
                let first = sortedTracks[0]
                return AlbumSummary(
                    id: key,
                    title: first.displayAlbum,
                    artist: first.albumArtist,
                    tracks: sortedTracks
                )
            }
            .sorted {
                let lhs = "\($0.artist) \($0.title)"
                let rhs = "\($1.artist) \($1.title)"
                return lhs.localizedStandardCompare(rhs) == .orderedAscending
            }
    }

    var artistSummaries: [ArtistSummary] {
        Dictionary(grouping: filteredTracks, by: \.artistKey)
            .map { key, tracks in
                ArtistSummary(id: key, name: tracks[0].displayArtist, tracks: tracks)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var songVersionGroups: [SongVersionGroup] {
        Dictionary(grouping: filteredTracks.filter { !$0.titleKey.isEmpty }, by: \.titleKey)
            .compactMap { key, tracks -> SongVersionGroup? in
                guard tracks.count > 1 else { return nil }
                let group = SongVersionGroup(
                    id: key,
                    title: tracks.sorted { $0.title.count < $1.title.count }[0].title,
                    tracks: tracks.sortedByArtistAlbumTitle()
                )
                guard group.hasMultipleArtists || group.hasMultipleAlbums else { return nil }
                return group
            }
            .sorted {
                if $0.tracks.count != $1.tracks.count {
                    return $0.tracks.count > $1.tracks.count
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    var folderSummaries: [FolderSummary] {
        Dictionary(grouping: filteredTracks, by: \.relativeFolderPath)
            .map { path, tracks in
                FolderSummary(id: path, path: path, tracks: tracks)
            }
            .sorted {
                if $0.trackCount != $1.trackCount {
                    return $0.trackCount > $1.trackCount
                }
                return $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }
    }

    var missingArtworkAlbums: [AlbumSummary] {
        albumSummaries.filter { !$0.hasArtwork }
    }

    var artworkCoverage: Double {
        guard !catalogTracks.isEmpty else { return 0 }
        let withArtwork = catalogTracks.filter(\.hasArtwork).count
        return Double(withArtwork) / Double(catalogTracks.count)
    }

    var totalFileSize: Int64 {
        var seenPaths = Set<String>()
        var total: Int64 = 0

        for track in scannedTracks {
            guard let url = track.url else { continue }
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { continue }
            total += track.fileSize ?? 0
        }

        return total
    }

    func presentLibraryPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Music Folder"
        panel.prompt = "Choose"
        panel.message = "Select the top folder that contains the music library."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.scanLibrary(at: url)
            }
        }
    }

    func presentXMLPicker() {
        let panel = NSOpenPanel()
        panel.title = "Import Music XML"
        panel.prompt = "Import"
        panel.message = "Choose an iTunes-style XML library export."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.xml, .propertyList]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.importXML(at: url)
            }
        }
    }

    func rescanSelectedLibrary() {
        guard let libraryURL else {
            presentLibraryPicker()
            return
        }
        scanLibrary(at: libraryURL)
    }

    func cancelScan() {
        scanTask?.cancel()
        activeScanID = nil
        isScanning = false
        scanProgress = ScanProgress()
    }

    func clearRememberedLibrary() {
        cancelScan()
        UserDefaults.standard.removeObject(forKey: Self.savedLibraryPathKey)
        libraryURL = nil
        importedXMLURL = nil
        scannedTracks = []
        xmlTracks = []
        catalogTracks = []
        lastScanDate = nil
        lastError = nil
        searchText = ""
    }

    func restoreSavedLibraryIfAvailable() {
        guard !didAttemptSavedLibraryRestore else { return }
        didAttemptSavedLibraryRestore = true

        guard
            let path = UserDefaults.standard.string(forKey: Self.savedLibraryPathKey),
            FileManager.default.fileExists(atPath: path)
        else {
            return
        }

        scanLibrary(at: URL(fileURLWithPath: path))
    }

    func scanLibrary(at url: URL) {
        scanTask?.cancel()
        lastError = nil
        libraryURL = url
        isScanning = true
        scanProgress = ScanProgress(currentFileName: "Preparing scan", completedFiles: 0, totalFiles: 0)
        let scanID = UUID()
        activeScanID = scanID

        scanTask = Task { [weak self] in
            guard let self else { return }
            let scanner = MusicLibraryScanner()
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let scannedTracks = try scanner.scan(folder: url) { progress in
                        Task { @MainActor [weak self] in
                            guard let self, self.activeScanID == scanID else { return }
                            self.scanProgress = progress
                        }
                    }
                    let xmlURL = LocalXMLLibraryFinder.findLibraryXML(in: url)
                    let xmlTracks = try xmlURL.map {
                        try ITunesXMLImporter().importTracks(from: $0, libraryRoot: url)
                    } ?? []

                    return LibraryScanResult(
                        scannedTracks: scannedTracks,
                        xmlURL: xmlURL,
                        xmlTracks: xmlTracks
                    )
                }.value

                guard self.activeScanID == scanID else { return }
                self.scannedTracks = result.scannedTracks
                self.xmlTracks = result.xmlTracks
                self.importedXMLURL = result.xmlURL
                self.lastScanDate = Date()
                UserDefaults.standard.set(url.path, forKey: Self.savedLibraryPathKey)
                self.rebuildCatalog()
                self.isScanning = false
                self.scanProgress = ScanProgress()
                self.activeScanID = nil
            } catch is CancellationError {
                guard self.activeScanID == scanID else { return }
                self.isScanning = false
                self.scanProgress = ScanProgress()
                self.activeScanID = nil
            } catch {
                guard self.activeScanID == scanID else { return }
                self.lastError = error.localizedDescription
                self.isScanning = false
                self.scanProgress = ScanProgress()
                self.activeScanID = nil
            }
        }
    }

    func importXML(at url: URL) {
        lastError = nil
        do {
            let importer = ITunesXMLImporter()
            xmlTracks = try importer.importTracks(from: url, libraryRoot: libraryURL)
            importedXMLURL = url
            rebuildCatalog()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func rebuildCatalog() {
        var mergedByIdentity: [String: MusicTrack] = [:]
        var identityKeyByMetadataKey: [String: String] = [:]

        func upsert(_ track: MusicTrack, preferIncoming: Bool) {
            let identityKey = track.fileIdentityKey
            if let existing = mergedByIdentity[identityKey] {
                mergedByIdentity[identityKey] = preferIncoming
                    ? track.fillingMissingMetadata(from: existing)
                    : existing.fillingMissingMetadata(from: track)
                identityKeyByMetadataKey[track.metadataIdentityKey] = identityKey
                return
            }

            if let existingIdentityKey = identityKeyByMetadataKey[track.metadataIdentityKey],
               let existing = mergedByIdentity[existingIdentityKey] {
                mergedByIdentity[existingIdentityKey] = preferIncoming
                    ? track.fillingMissingMetadata(from: existing)
                    : existing.fillingMissingMetadata(from: track)
                return
            }

            mergedByIdentity[identityKey] = track
            identityKeyByMetadataKey[track.metadataIdentityKey] = identityKey
        }

        for track in xmlTracks {
            upsert(track, preferIncoming: false)
        }

        for track in scannedTracks {
            upsert(track, preferIncoming: true)
        }

        catalogTracks = Array(mergedByIdentity.values).sortedByArtistAlbumTitle()
    }
}

private struct LibraryScanResult: Sendable {
    var scannedTracks: [MusicTrack]
    var xmlURL: URL?
    var xmlTracks: [MusicTrack]
}

private enum LocalXMLLibraryFinder {
    static func findLibraryXML(in root: URL) -> URL? {
        let candidates = xmlCandidates(in: root, maxDepth: 2)
        let importer = ITunesXMLImporter()

        for candidate in candidates {
            if (try? importer.importTracks(from: candidate, libraryRoot: root).isEmpty) == false {
                return candidate
            }
        }

        return nil
    }

    private static func xmlCandidates(in root: URL, maxDepth: Int) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let rootDepth = root.standardizedFileURL.pathComponents.count
        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            let depth = url.standardizedFileURL.pathComponents.count - rootDepth

            if values?.isDirectory == true {
                if depth >= maxDepth {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard depth <= maxDepth else { continue }
            guard url.pathExtension.lowercased() == "xml" else { continue }
            guard values?.isRegularFile == true else { continue }
            urls.append(url)
        }

        return urls.sorted { lhs, rhs in
            let lhsScore = libraryNameScore(lhs.lastPathComponent)
            let rhsScore = libraryNameScore(rhs.lastPathComponent)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private static func libraryNameScore(_ fileName: String) -> Int {
        let normalized = fileName.lowercased()
        var score = 0
        if normalized.contains("itunes") { score += 4 }
        if normalized.contains("music") { score += 3 }
        if normalized.contains("library") { score += 3 }
        if normalized.contains("plex") { score += 1 }
        return score
    }
}

private extension Array where Element == MusicTrack {
    func sortedByArtistAlbumTitle() -> [MusicTrack] {
        sorted {
            let lhs = "\($0.displayArtist) \($0.displayAlbum) \($0.trackNumber ?? 999) \($0.title)"
            let rhs = "\($1.displayArtist) \($1.displayAlbum) \($1.trackNumber ?? 999) \($1.title)"
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    func sortedForAlbum() -> [MusicTrack] {
        sorted {
            if ($0.discNumber ?? 0) != ($1.discNumber ?? 0) {
                return ($0.discNumber ?? 0) < ($1.discNumber ?? 0)
            }
            if ($0.trackNumber ?? 999) != ($1.trackNumber ?? 999) {
                return ($0.trackNumber ?? 999) < ($1.trackNumber ?? 999)
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}

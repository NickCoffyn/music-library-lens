import AVFoundation
import Foundation

struct MusicLibraryScanner {
    static let supportedAudioExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "alac", "flac", "wav", "aif", "aiff",
        "caf", "ogg", "opus", "wma"
    ]

    private enum FolderArtworkLookup {
        case found(URL)
        case missing
    }

    private let folderArtworkNames = ["cover", "folder", "front", "album", "artwork"]
    private let folderArtworkExtensions = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]

    func scan(folder root: URL, progress: @escaping (ScanProgress) -> Void) throws -> [MusicTrack] {
        let audioFiles = try collectAudioFiles(in: root)
        var tracks: [MusicTrack] = []
        tracks.reserveCapacity(audioFiles.count)
        var folderArtworkCache: [String: FolderArtworkLookup] = [:]
        var lastProgressIndex = -1
        var lastProgressTimestamp = 0.0

        for (index, url) in audioFiles.enumerated() {
            if Task.isCancelled {
                throw CancellationError()
            }

            let completedFiles = index + 1
            if shouldReportProgress(
                completedFiles: completedFiles,
                totalFiles: audioFiles.count,
                lastProgressIndex: &lastProgressIndex,
                lastProgressTimestamp: &lastProgressTimestamp
            ) {
                progress(ScanProgress(
                    currentFileName: url.lastPathComponent,
                    completedFiles: completedFiles,
                    totalFiles: audioFiles.count
                ))
            }

            autoreleasepool {
                tracks.append(makeTrack(
                    from: url,
                    root: root,
                    folderArtworkCache: &folderArtworkCache
                ))
            }
        }

        progress(ScanProgress(
            currentFileName: "",
            completedFiles: audioFiles.count,
            totalFiles: audioFiles.count
        ))

        return tracks
    }

    private func collectAudioFiles(in root: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            if Task.isCancelled {
                throw CancellationError()
            }

            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            let ext = url.pathExtension.lowercased()
            if Self.supportedAudioExtensions.contains(ext) {
                urls.append(url)
            }
        }

        return urls.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    private func makeTrack(
        from url: URL,
        root: URL,
        folderArtworkCache: inout [String: FolderArtworkLookup]
    ) -> MusicTrack {
        let asset = AVURLAsset(url: url)
        let metadata = asset.commonMetadata
        let fileNameTitle = url.deletingPathExtension().lastPathComponent.removingLeadingTrackNumber()
        let folder = url.deletingLastPathComponent()
        let folderPath = folder.standardizedFileURL.path
        let relativeFolder = relativePath(for: folder, root: root)
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSystemIdentity = fileSystemIdentity(for: url)
        let duration = asset.duration.seconds.isFinite && asset.duration.seconds > 0 ? asset.duration.seconds : nil
        let embeddedArtwork = metadata.embeddedArtworkData()
        let folderArtwork = cachedFolderArtwork(in: folder, cache: &folderArtworkCache)

        let artworkKind: ArtworkKind
        if embeddedArtwork != nil {
            artworkKind = .embedded
        } else if folderArtwork != nil {
            artworkKind = .folderFile
        } else {
            artworkKind = .none
        }

        return MusicTrack(
            url: url,
            fileSystemIdentity: fileSystemIdentity,
            title: metadata.string(forCommonKey: .commonKeyTitle) ?? metadata.string(forMetadataKey: .iTunesMetadataKeySongName) ?? fileNameTitle,
            artist: metadata.string(forCommonKey: .commonKeyArtist) ?? metadata.string(forMetadataKey: .iTunesMetadataKeyArtist) ?? "Unknown Artist",
            album: metadata.string(forCommonKey: .commonKeyAlbumName) ?? metadata.string(forMetadataKey: .iTunesMetadataKeyAlbum) ?? folder.lastPathComponent,
            albumArtist: metadata.string(forMetadataKey: .iTunesMetadataKeyAlbumArtist) ?? metadata.string(forCommonKey: .commonKeyArtist) ?? "Unknown Artist",
            genre: metadata.string(forMetadataKey: .iTunesMetadataKeyUserGenre) ?? metadata.string(forMetadataKey: .id3MetadataKeyContentType) ?? "Unknown Genre",
            year: metadata.yearValue(),
            trackNumber: metadata.trackNumberValue() ?? url.lastPathComponent.leadingTrackNumber(),
            discNumber: metadata.discNumberValue(),
            duration: duration,
            fileExtension: url.pathExtension,
            fileSize: resourceValues?.fileSize.map(Int64.init),
            folderPath: folderPath,
            relativeFolderPath: relativeFolder,
            source: .fileScan,
            artworkData: embeddedArtwork,
            artworkURL: embeddedArtwork == nil ? folderArtwork : nil,
            artworkKind: artworkKind
        )
    }

    private func relativePath(for folder: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let folderPath = folder.standardizedFileURL.path
        guard folderPath.hasPrefix(rootPath) else {
            return folder.lastPathComponent
        }
        let relative = String(folderPath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? "Library root" : relative
    }

    private func fileSystemIdentity(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.stringValue
        let systemNumber = (attributes[.systemNumber] as? NSNumber)?.stringValue
        guard let fileNumber else { return nil }
        return [systemNumber ?? "0", fileNumber].joined(separator: ":")
    }

    private func shouldReportProgress(
        completedFiles: Int,
        totalFiles: Int,
        lastProgressIndex: inout Int,
        lastProgressTimestamp: inout TimeInterval
    ) -> Bool {
        guard totalFiles > 0 else { return false }
        if completedFiles == totalFiles || completedFiles == 1 {
            lastProgressIndex = completedFiles
            lastProgressTimestamp = Date.timeIntervalSinceReferenceDate
            return true
        }

        let now = Date.timeIntervalSinceReferenceDate
        let shouldReport = completedFiles - lastProgressIndex >= 40 || (now - lastProgressTimestamp) >= 0.15
        if shouldReport {
            lastProgressIndex = completedFiles
            lastProgressTimestamp = now
        }
        return shouldReport
    }

    private func cachedFolderArtwork(
        in folder: URL,
        cache: inout [String: FolderArtworkLookup]
    ) -> URL? {
        let key = folder.standardizedFileURL.path
        if let cached = cache[key] {
            switch cached {
            case .found(let url):
                return url
            case .missing:
                return nil
            }
        }

        let discovered = findFolderArtwork(in: folder)
        cache[key] = discovered.map(FolderArtworkLookup.found) ?? .missing
        return discovered
    }

    private func findFolderArtwork(in folder: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for name in folderArtworkNames {
            for ext in folderArtworkExtensions {
                if let match = files.first(where: {
                    $0.deletingPathExtension().lastPathComponent.lowercased() == name &&
                    $0.pathExtension.lowercased() == ext
                }) {
                    return match
                }
            }
        }

        return files.first {
            folderArtworkExtensions.contains($0.pathExtension.lowercased())
        }
    }
}

private extension Array where Element == AVMetadataItem {
    func string(forCommonKey key: AVMetadataKey) -> String? {
        clean(first { $0.commonKey == key }?.stringValue)
    }

    func string(forMetadataKey key: AVMetadataKey) -> String? {
        clean(metadataItem(for: key)?.stringValue)
    }

    func embeddedArtworkData() -> Data? {
        guard let artworkItem = first(where: { $0.commonKey == .commonKeyArtwork }) ??
            metadataItem(for: .iTunesMetadataKeyCoverArt) ??
            metadataItem(for: .id3MetadataKeyAttachedPicture) else {
            return nil
        }
        if let data = artworkItem.dataValue {
            return data
        }
        return artworkItem.value as? Data
    }

    func yearValue() -> Int? {
        let candidates = [
            string(forCommonKey: .commonKeyCreationDate),
            string(forMetadataKey: .iTunesMetadataKeyReleaseDate),
            string(forMetadataKey: .id3MetadataKeyYear)
        ]
        for candidate in candidates.compactMap({ $0 }) {
            if let match = candidate.range(of: #"\d{4}"#, options: .regularExpression) {
                return Int(candidate[match])
            }
        }
        return nil
    }

    func trackNumberValue() -> Int? {
        let keys: [AVMetadataKey] = [.iTunesMetadataKeyTrackNumber, .id3MetadataKeyTrackNumber]
        for key in keys {
            if let value = string(forMetadataKey: key)?.leadingTrackNumber() {
                return value
            }
        }
        return nil
    }

    func discNumberValue() -> Int? {
        let keys: [AVMetadataKey] = [.iTunesMetadataKeyDiscNumber]
        for key in keys {
            if let value = string(forMetadataKey: key)?.leadingTrackNumber() {
                return value
            }
        }
        return nil
    }

    private func metadataItem(for key: AVMetadataKey) -> AVMetadataItem? {
        first { item in
            if let rawKey = item.key as? String, rawKey == key.rawValue {
                return true
            }
            if item.identifier?.rawValue == key.rawValue {
                return true
            }
            return item.identifier?.rawValue.hasSuffix("/\(key.rawValue)") == true
        }
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

private extension String {
    func removingLeadingTrackNumber() -> String {
        replacingOccurrences(
            of: #"^\s*\d{1,3}\s*[-._ ]+\s*"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func leadingTrackNumber() -> Int? {
        if let range = range(of: #"^\s*\d{1,3}"#, options: .regularExpression) {
            return Int(self[range].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let range = range(of: #"^\s*(\d{1,3})/\d{1,3}"#, options: .regularExpression) {
            let value = String(self[range]).split(separator: "/").first ?? ""
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

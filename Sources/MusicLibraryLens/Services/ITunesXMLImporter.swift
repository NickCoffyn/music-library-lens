import Foundation

struct ITunesXMLImporter {
    func importTracks(from xmlURL: URL, libraryRoot: URL?) throws -> [MusicTrack] {
        let data = try Data(contentsOf: xmlURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard
            let root = plist as? [String: Any],
            let tracksDictionary = root["Tracks"] as? [String: Any]
        else {
            throw XMLImportError.unsupportedFile
        }

        return tracksDictionary.values.compactMap { rawTrack in
            guard let track = rawTrack as? [String: Any] else { return nil }
            return makeTrack(from: track, libraryRoot: libraryRoot)
        }
    }

    private func makeTrack(from dictionary: [String: Any], libraryRoot: URL?) -> MusicTrack? {
        let location = dictionary["Location"] as? String
        let url = location.flatMap(Self.fileURL(from:))
        let ext = url?.pathExtension.lowercased() ?? ""
        let kind = (dictionary["Kind"] as? String ?? "").lowercased()
        let isAudio = MusicLibraryScanner.supportedAudioExtensions.contains(ext) || kind.contains("audio") || kind.contains("mpeg")
        guard isAudio else { return nil }
        if let url {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            if let libraryRoot, !Self.isWithinLibraryRoot(url: url, root: libraryRoot) {
                return nil
            }
        }

        let folder = url?.deletingLastPathComponent()
        let folderPath = folder?.standardizedFileURL.path ?? "XML library"
        let fileSystemIdentity = url.flatMap(Self.fileSystemIdentity(for:))
        let relativeFolder: String
        if let folder, let libraryRoot {
            relativeFolder = Self.relativePath(for: folder, root: libraryRoot)
        } else {
            relativeFolder = folder?.lastPathComponent ?? "XML library"
        }

        let durationMilliseconds = dictionary["Total Time"] as? Int
        let duration = durationMilliseconds.map { TimeInterval($0) / 1000.0 }
        let folderArtwork = folder.flatMap(findFolderArtwork)

        let fileSize: Int64?
        if let size = dictionary["Size"] as? Int64 {
            fileSize = size
        } else if let size = dictionary["Size"] as? Int {
            fileSize = Int64(size)
        } else {
            fileSize = nil
        }

        return MusicTrack(
            url: url,
            fileSystemIdentity: fileSystemIdentity,
            title: dictionary["Name"] as? String ?? url?.deletingPathExtension().lastPathComponent ?? "Untitled",
            artist: dictionary["Artist"] as? String ?? "Unknown Artist",
            album: dictionary["Album"] as? String ?? folder?.lastPathComponent ?? "Unknown Album",
            albumArtist: dictionary["Album Artist"] as? String ?? dictionary["Artist"] as? String ?? "Unknown Artist",
            genre: dictionary["Genre"] as? String ?? "Unknown Genre",
            year: dictionary["Year"] as? Int,
            trackNumber: dictionary["Track Number"] as? Int,
            discNumber: dictionary["Disc Number"] as? Int,
            duration: duration,
            fileExtension: ext.isEmpty ? "XML" : ext,
            fileSize: fileSize,
            folderPath: folderPath,
            relativeFolderPath: relativeFolder,
            source: .xml,
            artworkData: nil,
            artworkURL: folderArtwork,
            artworkKind: folderArtwork == nil ? .none : .folderFile
        )
    }

    private static func fileURL(from location: String) -> URL? {
        if let url = URL(string: location), url.isFileURL {
            return url
        }
        if location.hasPrefix("/") {
            return URL(fileURLWithPath: location)
        }
        return nil
    }

    private static func relativePath(for folder: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let folderPath = folder.standardizedFileURL.path
        guard folderPath.hasPrefix(rootPath) else {
            return folder.lastPathComponent
        }
        let relative = String(folderPath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? "Library root" : relative
    }

    private static func fileSystemIdentity(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.stringValue
        let systemNumber = (attributes[.systemNumber] as? NSNumber)?.stringValue
        guard let fileNumber else { return nil }
        return [systemNumber ?? "0", fileNumber].joined(separator: ":")
    }

    private static func isWithinLibraryRoot(url: URL, root: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        return filePath == rootPath || filePath.hasPrefix(rootPath + "/")
    }

    private func findFolderArtwork(in folder: URL) -> URL? {
        let names = ["cover", "folder", "front", "album", "artwork"]
        let extensions = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for name in names {
            for ext in extensions {
                if let match = files.first(where: {
                    $0.deletingPathExtension().lastPathComponent.lowercased() == name &&
                    $0.pathExtension.lowercased() == ext
                }) {
                    return match
                }
            }
        }

        return files.first { extensions.contains($0.pathExtension.lowercased()) }
    }
}

enum XMLImportError: LocalizedError {
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "That XML file did not look like an iTunes-style music library export."
        }
    }
}

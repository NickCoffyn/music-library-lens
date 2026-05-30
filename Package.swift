// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MusicLibraryLens",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MusicLibraryLens", targets: ["MusicLibraryLens"])
    ],
    targets: [
        .executableTarget(
            name: "MusicLibraryLens",
            path: "Sources/MusicLibraryLens"
        )
    ],
    swiftLanguageVersions: [.v5]
)

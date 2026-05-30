# Music Library Lens

Music Library Lens is a native macOS SwiftUI app for browsing a local music library as a visual catalog. It is read-only: it does not rename, move, edit, upload, or reorganize music files. The app scans the selected folder in place, reads common metadata and cover art with AVFoundation, picks up an iTunes-style XML library export when one is found locally, and highlights albums, artists, folders, missing covers, and song titles that appear on multiple albums or by multiple artists.

## Build and Run

```bash
./script/build_and_run.sh
```

The script builds with SwiftPM, stages a shareable app bundle at:

```text
dist/MusicLibraryLens.app
```

If this repo is opened in Codex desktop, the tracked `.codex` environment file
should expose a `Run` action that calls the same script automatically.

## Package To Send

```bash
./script/package_for_sharing.sh
```

That creates a zip in:

```text
share/
```

Use `./script/package_for_sharing.sh --universal` if the app needs to run on both Apple Silicon and Intel Macs.

Use `./script/package_for_sharing.sh --trial` for a faster debug-signed build when you just want a quick test package.

## Rebuild In Codex

1. Clone the repository into Codex on the target Mac.
2. Open the repo folder in Codex.
3. Use the `Run` action, or ask Codex to run `./script/build_and_run.sh`.
4. Choose the actual top-level music library folder when the app opens.

## Notes

- Supported scan extensions include MP3, M4A, AAC, ALAC, FLAC, WAV, AIFF, CAF, OGG, OPUS, and WMA.
- Metadata quality depends on what macOS AVFoundation can read from each file.
- Cover art is detected from embedded artwork first, then common folder files such as `cover.jpg`, `folder.png`, `front.jpg`, and similar image files.
- XML import expects an iTunes-style XML property-list export with a `Tracks` dictionary. If one is inside the selected folder, the app attempts to load it automatically.
- The selected folder path is remembered and rescanned on the next launch.

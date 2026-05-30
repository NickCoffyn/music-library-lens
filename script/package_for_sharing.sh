#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MusicLibraryLens"
DISPLAY_NAME="Music Library Lens"
BUNDLE_ID="com.nickcoffyn.MusicLibraryLens"
MIN_SYSTEM_VERSION="13.0"
VERSION="0.1"
MODE="${1:-native}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHARE_DIR="$ROOT_DIR/share"

case "$MODE" in
  native|--native)
    ARCH_LABEL="$(uname -m)"
    BUILD_ARGS=(-c release)
    BUILD_KIND="release"
    ;;
  universal|--universal)
    ARCH_LABEL="universal"
    BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
    BUILD_KIND="release"
    ;;
  trial|--trial)
    ARCH_LABEL="$(uname -m)-trial"
    BUILD_ARGS=(-c debug)
    BUILD_KIND="trial"
    ;;
  *)
    echo "usage: $0 [native|--native|universal|--universal|trial|--trial]" >&2
    exit 2
    ;;
esac

mkdir -p "$SHARE_DIR"

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/musiclibrarylens-package.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

APP_BUNDLE="$BUILD_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
README_FILE="$BUILD_DIR/READ_ME_FIRST.txt"

mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cd "$ROOT_DIR"
swift build "${BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat >"$README_FILE" <<README
Music Library Lens

This is a local-only music library viewer. It does not move, rename, edit,
upload, or reorganize music files.

How to try it:
1. Drag "Music Library Lens.app" into Applications, or open it from this folder.
2. If macOS says it cannot verify the developer, right-click the app and choose Open.
3. Choose the top folder that contains the music library.
4. The app scans the folder in place and remembers it for next time.

Minimum macOS version: $MIN_SYSTEM_VERSION
Build: $ARCH_LABEL
Kind: $BUILD_KIND
README

/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ZIP_NAME="${APP_NAME}-${VERSION}-${ARCH_LABEL}.zip"
ZIP_PATH="$SHARE_DIR/$ZIP_NAME"
rm -f "$ZIP_PATH"
(
  cd "$BUILD_DIR"
  COPYFILE_DISABLE=1 /usr/bin/zip -qry "$ZIP_PATH" "$DISPLAY_NAME.app" "READ_ME_FIRST.txt"
)

echo "$ZIP_PATH"

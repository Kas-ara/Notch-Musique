#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
APP="$PWD/build/Notch multitools.app"
"$APP/Contents/MacOS/NotchMultitools" --self-test
/usr/bin/codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Unsupported release version: %s\n' "$VERSION" >&2
    exit 1
fi
OUTPUT="$PWD/build/release"
NAME="Notch-multitools-${VERSION}-macOS-arm64.zip"
mkdir -p "$OUTPUT"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/$NAME"
CHECK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/notch-multitools-release.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT
/usr/bin/ditto -x -k "$OUTPUT/$NAME" "$CHECK_DIR"
/usr/bin/codesign --verify --deep --strict "$CHECK_DIR/Notch multitools.app"
"$CHECK_DIR/Notch multitools.app/Contents/MacOS/NotchMultitools" --self-test
(
    cd "$OUTPUT"
    /usr/bin/shasum -a 256 "$NAME" > "$NAME.sha256"
    /usr/bin/shasum -a 256 -c "$NAME.sha256"
)
printf 'Release archive: %s\n' "$OUTPUT/$NAME"

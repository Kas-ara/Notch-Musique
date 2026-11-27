#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -x /Library/Developer/CommandLineTools/usr/bin/swiftc ]; then
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
APP="$PWD/build/Notch multitools.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/build/module-cache"
SDK="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
/usr/bin/xcrun swiftc -swift-version 5 -O -sdk "$SDK" \
    -module-cache-path "$PWD/build/module-cache" \
    -target arm64-apple-macosx13.0 \
    -framework AppKit -framework SwiftUI -framework ImageIO -framework ServiceManagement -framework EventKit \
    Sources/*.swift -o "$APP/Contents/MacOS/NotchMultitools"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
for LANGUAGE in en fr; do
    /usr/bin/ditto "Resources/$LANGUAGE.lproj" "$APP/Contents/Resources/$LANGUAGE.lproj"
done
/usr/bin/codesign --force --sign - "$APP"
printf 'Application créée : %s\n' "$APP"

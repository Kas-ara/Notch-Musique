#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Package the existing branding at macOS standard and Retina icon sizes.
ICONSET="$PWD/build/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    /usr/bin/sips -z "$SIZE" "$SIZE" assets/logo.png \
        --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    RETINA_SIZE=$((SIZE * 2))
    /usr/bin/sips -z "$RETINA_SIZE" "$RETINA_SIZE" assets/logo.png \
        --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
printf 'Application icon created: Resources/AppIcon.icns\n'

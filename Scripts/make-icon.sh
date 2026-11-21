#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

SOURCE="Support/AppIcon.png"
OUT="Support/AppIcon.icns"
TMPDIR="$(mktemp -d)"
ICONSET="$TMPDIR/AppIcon.iconset"
trap 'rm -rf "$TMPDIR"' EXIT

if [ ! -f "$SOURCE" ]; then
    echo "Missing $SOURCE. Run: swift Scripts/GenerateIcon.swift" >&2
    exit 1
fi

mkdir -p "$ICONSET"

sips -z 16 16       "$SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64       "$SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128     "$SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024   "$SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"

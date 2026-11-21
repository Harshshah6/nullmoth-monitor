#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <path-to-NullMothMonitor-binary>" >&2
    exit 1
fi

BINARY="$1"
APP_NAME="NullMoth Monitor"
BUNDLE="build/$APP_NAME.app"

if [ ! -x "$BINARY" ]; then
    echo "Missing executable: $BINARY" >&2
    exit 1
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/NullMothMonitor"
cp Support/Info.plist "$BUNDLE/Contents/Info.plist"

if [ -f Support/AppIcon.icns ]; then
    cp Support/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "Built $BUNDLE"

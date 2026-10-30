#!/usr/bin/env bash
# Build G710Keys.app from source. Requires Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/G710Keys.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> compiling"
swiftc -O -swift-version 5 Sources/G710Keys.swift \
    -o "$APP/Contents/MacOS/G710Keys" \
    -framework Cocoa -framework IOKit

cp packaging/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign -v --deep --strict "$APP" && echo "==> ok: $APP"

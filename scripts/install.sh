#!/usr/bin/env bash
# Install the built app and launch it.
# Usage: ./scripts/install.sh [target-dir]   (default: /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:-/Applications}"

if [ ! -d build/G710Keys.app ]; then
  echo "build/G710Keys.app not found. Run ./scripts/build.sh first." >&2
  exit 1
fi

rm -rf "$TARGET/G710Keys.app"
cp -R build/G710Keys.app "$TARGET/"
open -a "$TARGET/G710Keys.app"
echo "Installed to $TARGET/G710Keys.app and launched."
echo "Now grant Input Monitoring + Accessibility in System Settings,"
echo "then use the \"Restart after granting\" button in the app window."

#!/usr/bin/env bash
# Remove G710Keys from /Applications (or the directory given as $1).
set -u
TARGET="${1:-/Applications}"
pkill -f "$TARGET/G710Keys.app" 2>/dev/null || true
rm -rf "$TARGET/G710Keys.app"
rm -f "$HOME/Library/LaunchAgents/local.g710keys.plist"
echo "Removed $TARGET/G710Keys.app"
echo "Config and log were left in place:"
echo "  ~/Library/Application Support/G710Keys"
echo "  ~/Library/Logs/G710Keys.log"
echo "Also remove G710Keys from System Settings > Privacy & Security."

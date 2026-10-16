#!/bin/sh
# Renders every UI surface to .notes/previews/*.png (light and dark side by side) from fixture data,
# plus the DMG window background. No running app or calendar access needed.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-.notes/previews}"
swift build 2>&1 | grep -E "error|warning: [^s]" || true
BIN=$(swift build --show-bin-path)
SPARKLE_DIR=$(dirname "$(find .build/artifacts -type d -name Sparkle.framework -path "*macos*" | head -n 1)")
mkdir -p "$OUT"
# The debug binary isn't in a bundle, so point dyld at the framework instead of @rpath.
DYLD_FRAMEWORK_PATH="$SPARKLE_DIR" "$BIN/Calenbar" --render-previews "$OUT"
swift scripts/dmg-background.swift "$OUT/dmg-background.png" 2
echo "Previews written to $OUT"

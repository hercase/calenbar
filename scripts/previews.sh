#!/bin/sh
# Renders every UI surface to .notes/previews/*.png (light and dark side by side) from fixture data,
# plus the DMG window background. No running app or calendar access needed.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-.notes/previews}"
LOG=$(mktemp)
if ! swift build > "$LOG" 2>&1; then
  grep -E "error" "$LOG" >&2
  rm -f "$LOG"
  exit 1
fi
rm -f "$LOG"
mkdir -p "$OUT"
BIN=$(swift build --show-bin-path)
SPARKLE_DIR=$(dirname "$(find .build/artifacts -type d -name Sparkle.framework -path "*macos*" | head -n 1)")
# A bare executable's "bundle" is its directory: put the translations and provider logos beside it so
# previews show real strings and icons, from the code that was just built (never a stale .app).
cp -R Resources/*.lproj Resources/ProviderIcons Resources/Brand "$BIN/"
# The debug binary isn't in a bundle, so point dyld at the framework instead of @rpath.
DYLD_FRAMEWORK_PATH="$SPARKLE_DIR" "$BIN/Calenbar" --render-previews "$OUT"
swift scripts/dmg-background.swift "$OUT/dmg-background.png" 2
echo "Previews written to $OUT"

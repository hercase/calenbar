#!/bin/sh
# Builds Calenbar.app and wraps it in dist/Calenbar-<version>.dmg with the classic
# "drag to Applications" window (background art + icon positions), via create-dmg.
set -e
cd "$(dirname "$0")/.."

scripts/build.sh --no-install

VERSION=$(cat VERSION)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/staging"
cp -R .build/Calenbar.app "$WORK/staging/"

# Background at 1x and 2x, merged into one Retina-aware TIFF.
swift scripts/dmg-background.swift "$WORK/bg.png" 1
swift scripts/dmg-background.swift "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/background.tiff" 2>/dev/null

mkdir -p dist
DMG="dist/Calenbar-$VERSION.dmg"
rm -f "$DMG"
# Positions match the arrow drawn by scripts/dmg-background.swift.
create-dmg \
  --volname "Calenbar $VERSION" \
  --volicon Resources/AppIcon.icns \
  --background "$WORK/background.tiff" \
  --window-pos 200 120 \
  --window-size 640 400 \
  --icon-size 128 \
  --text-size 13 \
  --icon "Calenbar.app" 160 190 \
  --hide-extension "Calenbar.app" \
  --app-drop-link 480 190 \
  --no-internet-enable \
  "$DMG" "$WORK/staging" >/dev/null
echo "Created $DMG"

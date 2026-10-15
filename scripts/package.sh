#!/bin/sh
# Builds Calenbar.app and wraps it in dist/Calenbar-<version>.dmg (drag-to-Applications layout).
set -e
cd "$(dirname "$0")/.."

scripts/build.sh --no-install

VERSION=$(cat VERSION)
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

cp -R .build/Calenbar.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp INSTALL.md "$STAGING/How to install.txt"

mkdir -p dist
DMG="dist/Calenbar-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Calenbar $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"
echo "Created $DMG"

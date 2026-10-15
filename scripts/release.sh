#!/bin/sh
# Publishes a new version: bumps VERSION, tags it, builds the DMG and creates a GitHub Release.
# Usage: scripts/release.sh 0.2.0 ["Short summary for the release notes"]
set -e
cd "$(dirname "$0")/.."

VERSION="$1"
SUMMARY="$2"
if ! echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "usage: scripts/release.sh X.Y.Z [summary]" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean; commit or stash first." >&2
  exit 1
fi
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "Releases are cut from main." >&2
  exit 1
fi

./scripts/test.sh >/dev/null
./scripts/lint.sh --check

if [ "$(cat VERSION)" != "$VERSION" ]; then
  echo "$VERSION" > VERSION
  git commit -qm "chore: release v$VERSION" VERSION
fi
git tag -a "v$VERSION" -m "Calenbar $VERSION"

./scripts/package.sh
DMG="dist/Calenbar-$VERSION.dmg"

git push -q origin main "v$VERSION"
NOTES=$(mktemp)
{
  [ -n "$SUMMARY" ] && printf '%s\n\n' "$SUMMARY"
  printf '### Install or update\n'
  printf '1. Download **Calenbar-%s.dmg** below and open it.\n' "$VERSION"
  printf '2. Quit Calenbar (••• › Quit), then drag the new Calenbar to Applications and replace the old one.\n'
  printf '3. Open it. The first time, macOS asks to confirm: System Settings › Privacy & Security › Open Anyway.\n'
} > "$NOTES"
gh release create "v$VERSION" "$DMG" --title "Calenbar $VERSION" --notes-file "$NOTES" --generate-notes
rm -f "$NOTES"
echo "Released v$VERSION"

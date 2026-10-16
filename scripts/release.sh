#!/bin/sh
# Publishes a new version: bumps VERSION, tags it, builds and EdDSA-signs the DMG, creates the GitHub
# Release, and updates the Sparkle appcast on GitHub Pages so every installed copy updates itself.
# Usage: scripts/release.sh 0.4.0 ["Short summary for the release notes"]
#
# One-time setup on the release machine:
#   scripts/make-signing-cert.sh        # "Calenbar Dev" code-signing identity (keeps macOS permissions)
#   $(scripts/sparkle-tools.sh)/generate_keys   # Sparkle EdDSA key pair in the login keychain;
#                                               # its public half must match SUPublicEDKey in Info.plist
set -e
cd "$(dirname "$0")/.."

VERSION="$1"
SUMMARY="$2"
REPO="hercase/calenbar"
PAGES_URL="https://hercase.github.io/calenbar"
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

TOOLS=$(scripts/sparkle-tools.sh)
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" Resources/Info.plist)
ACTUAL_KEY=$("$TOOLS/generate_keys" -p 2>/dev/null || true)
if [ "$ACTUAL_KEY" != "$EXPECTED_KEY" ]; then
  echo "error: the Sparkle private key in this keychain doesn't match SUPublicEDKey in Info.plist." >&2
  echo "       Import the backed-up key with: $TOOLS/generate_keys -i <key-file>" >&2
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
DOWNLOAD_URL="https://github.com/$REPO/releases/download/v$VERSION/Calenbar-$VERSION.dmg"

SIGNATURE=$("$TOOLS/sign_update" -p "$DMG")
"$TOOLS/sign_update" --verify "$DMG" "$SIGNATURE" >/dev/null
LENGTH=$(stat -f%z "$DMG")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" .build/Calenbar.app/Contents/Info.plist)
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" .build/Calenbar.app/Contents/Info.plist)

# A stable copy for the landing page's Download button (…/releases/latest/download/Calenbar.dmg).
cp "$DMG" dist/Calenbar.dmg

# The release (with its DMG) goes up first; only then does the appcast point at it, so installed
# copies never see an item whose download doesn't exist yet.
git push -q origin main "v$VERSION"
NOTES=$(mktemp)
{
  [ -n "$SUMMARY" ] && printf '%s\n\n' "$SUMMARY"
  printf 'Installed copies update themselves: open the panel and click **Update available**, or wait for the next automatic check.\n\n'
  printf 'New here? Follow the [install guide](%s).\n' "$PAGES_URL"
} > "$NOTES"
gh release create "v$VERSION" "$DMG" "dist/Calenbar.dmg" --title "Calenbar $VERSION" --notes-file "$NOTES" --generate-notes
rm -f "$NOTES" dist/Calenbar.dmg

python3 scripts/appcast.py docs/appcast.xml \
  --version "$VERSION" --build "$BUILD" --url "$DOWNLOAD_URL" --length "$LENGTH" \
  --signature "$SIGNATURE" --minimum-system-version "$MIN_OS" --notes "$SUMMARY"
git commit -qm "chore: appcast for v$VERSION" docs/appcast.xml
git push -q origin main
echo "Released v$VERSION; the appcast at $PAGES_URL/appcast.xml goes live when GitHub Pages redeploys (about a minute)."

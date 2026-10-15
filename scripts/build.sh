#!/bin/sh
# Builds Calenbar.app in release mode, signs it, and installs it to ~/Applications.
# Usage: scripts/build.sh [--no-install]
set -e
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP=".build/Calenbar.app"
IDENTITY="Calenbar Dev"

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchAgents"
cp "$BIN/Calenbar" "$APP/Contents/MacOS/Calenbar"
cp -R Resources/ProviderIcons "$APP/Contents/Resources/ProviderIcons"
cp Resources/LaunchAgent.plist "$APP/Contents/Library/LaunchAgents/com.hernancase.calenbar.agent.plist"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  codesign --force --options runtime --entitlements Resources/Calenbar.entitlements --sign "$IDENTITY" "$APP"
else
  echo "warning: \"$IDENTITY\" not found; signing ad-hoc. Run scripts/make-signing-cert.sh to keep permissions across builds." >&2
  codesign --force --options runtime --entitlements Resources/Calenbar.entitlements --sign - "$APP"
fi
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION build $BUILD)"

if [ "$1" != "--no-install" ]; then
  mkdir -p "$HOME/Applications"
  pkill -x Calenbar 2>/dev/null || true
  rm -rf "$HOME/Applications/Calenbar.app"
  cp -R "$APP" "$HOME/Applications/Calenbar.app"
  echo "Installed to ~/Applications/Calenbar.app"
fi

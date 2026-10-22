#!/bin/sh
# Builds Calenbar.app in release mode, signs it, and installs it to ~/Applications.
# Usage: scripts/build.sh [--no-install] [--require-identity]
#   --require-identity  fail instead of signing ad-hoc (releases: a changing signature would make
#                       macOS re-ask for Calendar access after every update)
set -e
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=${CALENBAR_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}
# Test builds can point Sparkle at a local appcast: CALENBAR_FEED_URL=http://localhost:8765/appcast.xml
FEED_URL=${CALENBAR_FEED_URL:-}
APP=".build/Calenbar.app"
IDENTITY="Calenbar Dev"
INSTALL=1
REQUIRE_IDENTITY=0
for arg in "$@"; do
  case "$arg" in
    --no-install) INSTALL=0 ;;
    --require-identity) REQUIRE_IDENTITY=1 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  SIGN="$IDENTITY"
elif [ "$REQUIRE_IDENTITY" = 1 ]; then
  echo "error: code-signing identity \"$IDENTITY\" not found. Run scripts/make-signing-cert.sh on the release machine." >&2
  exit 1
else
  echo "warning: \"$IDENTITY\" not found; signing ad-hoc. Run scripts/make-signing-cert.sh to keep permissions across builds." >&2
  SIGN="-"
fi

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
SPARKLE=$(find .build/artifacts -type d -name Sparkle.framework -path "*macos*" | head -n 1)
if [ -z "$SPARKLE" ]; then
  echo "error: Sparkle.framework not found under .build/artifacts (swift package resolve should fetch it)" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" "$APP/Contents/Library/LaunchAgents"
cp "$BIN/Calenbar" "$APP/Contents/MacOS/Calenbar"
cp -R Resources/ProviderIcons "$APP/Contents/Resources/ProviderIcons"
cp -R Resources/Brand "$APP/Contents/Resources/Brand"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp Resources/LaunchAgent.plist "$APP/Contents/Library/LaunchAgents/com.hernancase.calenbar.agent.plist"
# -R on a symlinked framework keeps Versions/Current etc. as links; the executable loads it via @rpath.
cp -R "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
if [ -n "$FEED_URL" ]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL $FEED_URL" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$APP/Contents/Info.plist"
  echo "warning: test build, Sparkle feed is $FEED_URL" >&2
fi
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

# Sign inside out, as Sparkle's docs prescribe: its helpers, then the framework, then the app.
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --options runtime --sign "$SIGN" "$FW/XPCServices/Downloader.xpc"
codesign --force --options runtime --sign "$SIGN" "$FW/XPCServices/Installer.xpc"
codesign --force --options runtime --sign "$SIGN" "$FW/Autoupdate"
codesign --force --options runtime --sign "$SIGN" "$FW/Updater.app"
codesign --force --options runtime --sign "$SIGN" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --options runtime --entitlements Resources/Calenbar.entitlements --sign "$SIGN" "$APP"
codesign --verify --strict --deep "$APP"
echo "Built $APP ($VERSION build $BUILD)"

if [ "$INSTALL" = 1 ]; then
  mkdir -p "$HOME/Applications"
  pkill -x Calenbar 2>/dev/null || true
  rm -rf "$HOME/Applications/Calenbar.app"
  cp -R "$APP" "$HOME/Applications/Calenbar.app"
  echo "Installed to ~/Applications/Calenbar.app"
  # The running copy was quit above; bring the new one back so the menu bar isn't left empty.
  open "$HOME/Applications/Calenbar.app"
fi

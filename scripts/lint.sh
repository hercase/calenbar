#!/bin/sh
# Formats with swift-format, stamps the site's CSS/JS links, then lints with SwiftLint. Pass --check to fail instead of rewriting.
set -e
cd "$(dirname "$0")/.."
if [ "$1" = "--check" ]; then
  swift format lint --strict --recursive Sources Tests
else
  swift format --in-place --recursive Sources Tests
fi
python3 scripts/check-l10n.py
python3 scripts/site-assets.py $([ "$1" = "--check" ] && echo --check)
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$(xcode-select -p)}" swiftlint lint --strict --quiet

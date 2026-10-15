#!/bin/sh
# Formats with swift-format, then lints with SwiftLint. Pass --check to fail instead of rewriting.
set -e
cd "$(dirname "$0")/.."
if [ "$1" = "--check" ]; then
  swift format lint --strict --recursive Sources Tests
else
  swift format --in-place --recursive Sources Tests
fi
TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-$(xcode-select -p)}" swiftlint lint --strict --quiet

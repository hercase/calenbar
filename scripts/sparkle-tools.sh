#!/bin/sh
# Prints the directory holding Sparkle's command line tools (sign_update, generate_keys,
# generate_appcast), downloading and checksum-verifying the release once into .build/.
# The version must match the Sparkle dependency pinned in Package.swift.
set -e
cd "$(dirname "$0")/.."

SPARKLE_VERSION="2.10.0"
SPARKLE_SHA256="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"
DIR=".build/sparkle-tools/$SPARKLE_VERSION"

if [ ! -x "$DIR/bin/sign_update" ]; then
  ARCHIVE="$DIR/Sparkle-$SPARKLE_VERSION.tar.xz"
  mkdir -p "$DIR"
  echo "Downloading Sparkle $SPARKLE_VERSION tools…" >&2
  curl -fsSL -o "$ARCHIVE" "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
  ACTUAL=$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)
  if [ "$ACTUAL" != "$SPARKLE_SHA256" ]; then
    echo "Sparkle download checksum mismatch: $ACTUAL" >&2
    rm -rf "$DIR"
    exit 1
  fi
  tar -xJf "$ARCHIVE" -C "$DIR" bin
  rm -f "$ARCHIVE"
fi
echo "$DIR/bin"

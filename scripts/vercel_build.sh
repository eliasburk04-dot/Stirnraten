#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$ROOT_DIR/.vercel/flutter}"
PUB_CACHE_DIR="${PUB_CACHE_DIR:-$ROOT_DIR/.vercel/pub-cache}"

if [ ! -d "$FLUTTER_DIR" ]; then
  mkdir -p "$(dirname "$FLUTTER_DIR")"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
export PUB_CACHE="$PUB_CACHE_DIR"

flutter --version
flutter config --enable-web >/dev/null
flutter pub get
flutter build web --release

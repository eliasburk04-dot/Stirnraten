#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEFINES_FILE="ios/Flutter/dart_defines_prod.env"
if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "Missing $DEFINES_FILE"
  echo "Create it with:"
  echo "  SUPABASE_URL=..."
  echo "  SUPABASE_ANON_KEY=..."
  echo "  AI_WORDLIST_ENDPOINT=..."
  exit 1
fi

flutter pub get
./scripts/generate_ios_xcode_dart_defines.sh

# Generates ios/Flutter/Generated.xcconfig + flutter_export_environment.sh
# with Release flags and the production dart-defines.
flutter build ios --release --dart-define-from-file="$DEFINES_FILE"

open ios/Runner.xcworkspace

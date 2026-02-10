#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEFINES_FILE="ios/Flutter/dart_defines_prod.env"
OUT_FILE="ios/Flutter/DartDefines.xcconfig"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "Missing $DEFINES_FILE"
  echo "Create it (local only) with e.g.:"
  echo "  SUPABASE_URL=..."
  echo "  SUPABASE_ANON_KEY=..."
  echo "  AI_WORDLIST_ENDPOINT=... (optional)"
  echo "  IOS_IAP_PREMIUM_LIFETIME_PRODUCT_ID=... (optional)"
  exit 1
fi

defs=()
while IFS= read -r line || [[ -n "${line:-}" ]]; do
  # Trim whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  # Only accept KEY=VALUE pairs
  if [[ "$line" != *"="* ]]; then
    continue
  fi

  b64="$(printf '%s' "$line" | base64 | tr -d '\n')"
  defs+=("$b64")
done < "$DEFINES_FILE"

if [[ ${#defs[@]} -eq 0 ]]; then
  echo "No KEY=VALUE entries found in $DEFINES_FILE"
  exit 1
fi

joined="$(IFS=, ; echo "${defs[*]}")"

cat > "$OUT_FILE" <<EOF
// Auto-generated from $DEFINES_FILE.
// Used when launching from Xcode so Supabase + IAP env works in Debug/Release.
// Do not commit this file (it's gitignored).
DART_DEFINES=$joined
EOF

echo "Wrote $OUT_FILE"


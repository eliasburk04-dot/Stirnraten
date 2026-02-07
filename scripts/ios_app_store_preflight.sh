#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PLIST="ios/Runner/Info.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

echo "==> Flutter pub get"
flutter pub get

echo "==> Static analysis"
flutter analyze

echo "==> Tests"
flutter test

if command -v xattr >/dev/null 2>&1; then
  echo "==> Cleaning extended macOS attributes"
  xattr -rc ios || true
  xattr -rc build || true
  FLUTTER_BIN="$(command -v flutter || true)"
  if [[ -n "${FLUTTER_BIN}" ]]; then
    if command -v realpath >/dev/null 2>&1; then
      FLUTTER_BIN="$(realpath "${FLUTTER_BIN}")"
    elif command -v python3 >/dev/null 2>&1; then
      FLUTTER_BIN="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "${FLUTTER_BIN}")"
    fi
    FLUTTER_ROOT="$(cd "$(dirname "${FLUTTER_BIN}")/.." && pwd)"
    if [[ -d "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios" ]]; then
      xattr -rc "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios" || true
    fi
    if [[ -d "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios-profile" ]]; then
      xattr -rc "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios-profile" || true
    fi
    if [[ -d "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios-release" ]]; then
      xattr -rc "${FLUTTER_ROOT}/bin/cache/artifacts/engine/ios-release" || true
    fi
  fi
fi

echo "==> iOS release build (no codesign)"
NEEDS_TEMP_BUILD="false"
CHECK_DIR="$ROOT_DIR"
while [[ "$CHECK_DIR" != "/" ]]; do
  if xattr -p com.apple.file-provider-domain-id "$CHECK_DIR" >/dev/null 2>&1 ||
    xattr -p com.apple.fileprovider.detached#B "$CHECK_DIR" >/dev/null 2>&1; then
    NEEDS_TEMP_BUILD="true"
    break
  fi
  CHECK_DIR="$(dirname "$CHECK_DIR")"
done

if [[ "$NEEDS_TEMP_BUILD" == "true" ]]; then
  echo "Project is in an iCloud/FileProvider path; building from temporary mirror"
  TMP_DIR="$(mktemp -d)"
  MIRROR_DIR="${TMP_DIR}/Stirnraten"
  rsync -a --delete --exclude '.git' --exclude 'build' "${ROOT_DIR}/" "${MIRROR_DIR}/"
  (
    cd "${MIRROR_DIR}"
    flutter build ios --release --no-codesign
  )
else
  flutter build ios --release --no-codesign
fi

echo "==> Validate required iOS keys in Info.plist"
"$PLIST_BUDDY" -c "Print :UIApplicationSceneManifest" "$PLIST" >/dev/null
"$PLIST_BUDDY" -c "Print :NSMotionUsageDescription" "$PLIST" >/dev/null
"$PLIST_BUDDY" -c "Print :ITSAppUsesNonExemptEncryption" "$PLIST" >/dev/null

echo "==> Validate Scene delegate class"
"$PLIST_BUDDY" -c "Print :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName" "$PLIST" | grep -q "FlutterSceneDelegate"

echo "==> Preflight passed"

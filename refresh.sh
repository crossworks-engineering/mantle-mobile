#!/usr/bin/env bash
#
# refresh.sh — re-sync the project after editing pubspec.yaml (added/updated deps,
# or a version bump). Runs the full update chain so Dart packages, generated code,
# and the iOS CocoaPods/SwiftPM/config all match pubspec. Idempotent; run anytime.
#
#   ./refresh.sh
#
# What it does, in order:
#   1. flutter pub get        — resolve Dart/Flutter packages
#   2. build_runner           — regenerate *.g.dart (riverpod / freezed / drift / json)
#   3. (macOS) iOS config     — regenerate Generated.xcconfig + run `pod install`
#   4. (macOS) arm64e strip   — App Store arch fix for the prebuilt libsodium (no-op if clean)
#
set -euo pipefail
cd "$(dirname "$0")"   # this script lives at the repo root

# CocoaPods aborts without a UTF-8 locale (Encoding::CompatibilityError).
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

echo "▸ 1  flutter pub get — resolving Dart/Flutter packages"
fvm flutter pub get

echo "▸ 2  build_runner — regenerating *.g.dart (riverpod / freezed / drift / json)"
# (newer build_runner deletes conflicting outputs by default; the old
#  --delete-conflicting-outputs flag was removed.)
fvm dart run build_runner build

if [[ "${OSTYPE:-}" == darwin* ]]; then
  echo "▸ 3  iOS — regenerating Flutter config + pod install"
  # --config-only rewrites ios/Flutter/Generated.xcconfig (app version + plugin list)
  # AND runs `pod install`, keeping CocoaPods and SwiftPM in sync with pubspec.
  fvm flutter build ios --config-only

  echo "▸ 4  iOS — stripping arm64e from libsodium (App Store arch fix; no-op if clean)"
  # The sodium_libs prebuilt libsodium.xcframework can ship an arm64e slice built
  # against an old SDK that App Store validation rejects (error 91011). Strip it from
  # any built copies so the next archive passes. Conditional + best-effort — does
  # nothing if there's no DerivedData or no arm64e slice (e.g. on native-assets builds).
  dd="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null | head -1 || true)"
  if [[ -n "$dd" ]]; then
    while IFS= read -r bin; do
      if lipo -archs "$bin" 2>/dev/null | grep -qw arm64e; then
        lipo -remove arm64e "$bin" -output "$bin" 2>/dev/null \
          && echo "     stripped arm64e: ${bin#"$dd"/}"
      fi
    done < <(find "$dd" -path '*libsodium.framework/libsodium' -type f 2>/dev/null)
  fi
else
  echo "▸ 3  (skipping iOS pods/config — not on macOS)"
fi

echo "✅ refresh complete — pub, codegen, pods, and iOS config are in sync."

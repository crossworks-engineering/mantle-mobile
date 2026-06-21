#!/usr/bin/env bash
#
# check_push_env.sh — report the effective APNs environment for this app so you
# know which Apple Push endpoint your Mantle server must target. Push fails
# SILENTLY when the build's aps-environment and the server's endpoint disagree,
# so verify before concluding "push is broken".
#
#   ./check_push_env.sh                  # read the source .entitlements files
#   ./check_push_env.sh <path-to.app>    # read what's actually embedded in a build
#   ./check_push_env.sh <path-to.xcarchive>
#
# Mapping (this is the whole point):
#   aps-environment = development  ->  sandbox     api.sandbox.push.apple.com
#   aps-environment = production   ->  production   api.push.apple.com
#
# Why the source files say 'development' but TestFlight/App Store push works:
# Xcode's DISTRIBUTION provisioning profile only carries 'production', and that
# overrides the file at archive time. So a dev-signed build (`flutter run
# --release`) registers a SANDBOX token; only an archived/TestFlight build
# registers a PRODUCTION token. Don't hand-edit the file to 'production' — a
# development profile can't carry it and the build won't push either way.
set -euo pipefail
cd "$(dirname "$0")"   # this script lives at the repo root

# Pull the <string> that follows the aps-environment <key> out of a plist/xml blob.
aps_from_blob() {
  # -A1: the value line is right after the key. Tolerant of indentation.
  grep -A1 'aps-environment' | grep '<string>' | sed -E 's/.*<string>(.*)<\/string>.*/\1/' | head -1
}

endpoint_for() {
  case "$1" in
    development) echo "sandbox     -> api.sandbox.push.apple.com" ;;
    production)  echo "PRODUCTION  -> api.push.apple.com" ;;
    "")          echo "(none found — no Push Notifications entitlement?)" ;;
    *)           echo "(unknown value: '$1')" ;;
  esac
}

report() { # label  value
  printf '  %-22s %-12s %s\n' "$1" "${2:-<missing>}" "$(endpoint_for "${2:-}")"
}

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "▸ Source entitlements (what you sign with for dev/debug builds)"
  app_env="$(aps_from_blob < ios/Runner/Runner.entitlements || true)"
  ext_env="$(aps_from_blob < ios/NotificationService/NotificationService.entitlements || true)"
  report "Runner (app):" "$app_env"
  report "NotificationService:" "$ext_env"
  echo
  echo "  These values apply to dev signing (incl. \`fvm flutter run --release\`)."
  echo "  An archive signed with a DISTRIBUTION profile is flipped to 'production'"
  echo "  regardless — re-run against the built .app/.xcarchive to confirm:"
  echo "      ./check_push_env.sh <path-to .app or .xcarchive>"
  exit 0
fi

# --- Inspect a built artifact: read the entitlements actually baked into the binary.
if [[ ! -e "$TARGET" ]]; then
  echo "✗ Not found: $TARGET" >&2
  exit 1
fi

# .xcarchive -> dive into the packaged .app
if [[ "$TARGET" == *.xcarchive ]]; then
  app="$(find "$TARGET/Products/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
  [[ -n "$app" ]] || { echo "✗ No .app inside $TARGET" >&2; exit 1; }
  TARGET="$app"
fi

echo "▸ Embedded entitlements (what the device will actually register with)"
echo "  $TARGET"
echo

# Main app binary
app_env="$(codesign -d --entitlements - --xml "$TARGET" 2>/dev/null | aps_from_blob || true)"
report "Runner (app):" "$app_env"

# NotificationService extension, if bundled
ext="$(find "$TARGET/PlugIns" -maxdepth 1 -name '*.appex' 2>/dev/null | head -1 || true)"
if [[ -n "$ext" ]]; then
  ext_env="$(codesign -d --entitlements - --xml "$ext" 2>/dev/null | aps_from_blob || true)"
  report "NotificationService:" "$ext_env"
else
  echo "  NotificationService:   <not bundled — extension missing from this build!>"
fi

echo
if [[ "$app_env" == "production" ]]; then
  echo "✅ Production push path — server must send to api.push.apple.com (TestFlight/App Store)."
elif [[ "$app_env" == "development" ]]; then
  echo "⚠️  Sandbox push path — server must send to api.sandbox.push.apple.com."
  echo "   If your APNs key/server is production-only, this build will NOT receive push."
else
  echo "✗ No aps-environment found — the Push Notifications capability may be missing."
fi

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

# Pull the <string> that follows the aps-environment <key> out of a plist/xml
# blob. Newline-agnostic on purpose: pretty-printed .entitlements files put the
# value on the next line, but `codesign` emits the whole plist on ONE line, so a
# line-based grep misses it. Slurp the whole input and match across newlines.
aps_from_blob() {
  perl -0777 -ne 'print "$1" if m{aps-environment</key>\s*<string>([^<]*)</string>}'
}

# Dump the entitlements embedded in a signed .app/.appex to stdout (single-line
# XML on current macOS). `:-` writes the plist to stdout.
entitlements_of() {
  codesign -d --entitlements :- "$1" 2>/dev/null
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
  echo "  The .xcarchive is signed for DEVELOPMENT; \`flutter build ipa\` re-signs"
  echo "  on export, flipping the IPA to 'production'. Check the real artifact:"
  echo "      ./check_push_env.sh <path-to .ipa / .xcarchive / .app>"
  exit 0
fi

# --- Inspect a built artifact: read the entitlements actually baked into the binary.
if [[ ! -e "$TARGET" ]]; then
  echo "✗ Not found: $TARGET" >&2
  exit 1
fi

# .ipa -> unzip to a temp dir and inspect Payload/*.app (cleaned up on exit). The
# IPA is the artifact uploaded to TestFlight, so this is the one that matters.
TMP=""
cleanup() { [[ -n "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT
if [[ "$TARGET" == *.ipa ]]; then
  TMP="$(mktemp -d)"
  unzip -q "$TARGET" -d "$TMP"
  app="$(find "$TMP/Payload" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
  [[ -n "$app" ]] || { echo "✗ No .app inside $TARGET" >&2; exit 1; }
  echo "▸ Embedded entitlements in IPA: $(basename "$TARGET")"
  TARGET="$app"
# .xcarchive -> dive into the packaged .app
elif [[ "$TARGET" == *.xcarchive ]]; then
  app="$(find "$TARGET/Products/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)"
  [[ -n "$app" ]] || { echo "✗ No .app inside $TARGET" >&2; exit 1; }
  echo "▸ Embedded entitlements in archive (note: re-signed on IPA export)"
  TARGET="$app"
else
  echo "▸ Embedded entitlements (what the device will actually register with)"
  echo "  $TARGET"
fi
echo

# Main app binary
app_env="$(entitlements_of "$TARGET" | aps_from_blob || true)"
report "Runner (app):" "$app_env"

# NotificationService extension, if bundled
ext="$(find "$TARGET/PlugIns" -maxdepth 1 -name '*.appex' 2>/dev/null | head -1 || true)"
if [[ -n "$ext" ]]; then
  ext_env="$(entitlements_of "$ext" | aps_from_blob || true)"
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

#!/usr/bin/env bash
# Refresh the checked-in copy of mantle's theme sources and regenerate the
# phone's theme registry from it.
#
#   tool/sync_themes.sh                # from ~/Projects/mantle
#   MANTLE_DIR=/path/to/mantle tool/sync_themes.sh
#
# What it copies (both are GENERATED in mantle from themes/seeds.mjs — never
# edit the copies here; fix the seed, `pnpm themes:build` there, sync again):
#   packages/share-ui/styles/themes.css              → tool/themes/themes.css
#   packages/share-ui/src/lib/theme-registry.gen.ts  → tool/themes/theme-registry.gen.ts
# and records the mantle commit that last touched them in tool/themes/SOURCE.
# CI regenerates from this copy and fails when lib/theme/mantle_themes.g.dart
# is stale, and separately fails when the copy no longer matches mantle main.
set -euo pipefail

cd "$(dirname "$0")/.."
MANTLE_DIR="${MANTLE_DIR:-$HOME/Projects/mantle}"
SHARE_UI="$MANTLE_DIR/packages/share-ui"
CSS="$SHARE_UI/styles/themes.css"
REG="$SHARE_UI/src/lib/theme-registry.gen.ts"

if [[ ! -f "$CSS" || ! -f "$REG" ]]; then
  echo "✗ themes.css / theme-registry.gen.ts not found under $SHARE_UI" >&2
  echo "  Set MANTLE_DIR to a mantle checkout." >&2
  exit 1
fi

mkdir -p tool/themes
cp "$CSS" tool/themes/themes.css
cp "$REG" tool/themes/theme-registry.gen.ts
git -C "$MANTLE_DIR" log -1 --format='%H %s' -- \
  packages/share-ui/styles/themes.css packages/share-ui/src/lib/theme-registry.gen.ts \
  > tool/themes/SOURCE

echo "synced from $(cat tool/themes/SOURCE)"
fvm dart run tool/generate_themes.dart

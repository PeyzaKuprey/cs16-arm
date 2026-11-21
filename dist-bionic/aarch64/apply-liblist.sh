#!/usr/bin/env bash
# apply-liblist.sh — point cstrike/liblist.gam at metamod-r as the gamedll.
# Run from your HLDS install dir after extracting this overlay.  Idempotent.
set -euo pipefail
lib="${1:-cstrike/liblist.gam}"
val="addons/metamod/dlls/metamod_aarch64.so"
if [ ! -f "$lib" ]; then
  echo "error: $lib not found.  Run from your HLDS install dir."
  exit 1
fi
if grep -q '^gamedll_linux ' "$lib"; then
  sed -i.bak "s|^gamedll_linux .*|gamedll_linux \"$val\"|" "$lib"
else
  printf 'gamedll_linux "%s"\n' "$val" >> "$lib"
fi
echo "set gamedll_linux \"$val\" in $lib"

#!/bin/bash
# fetch-sources.sh — clone every upstream project at its pinned SHA, create
# the `arm` branch and apply this repo's port patches.
#
# Usage:  bash scripts/fetch-sources.sh [dest-dir]     (default: ./src)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${1:-$ROOT/src}
PATCHES=$ROOT/patches
mkdir -p "$DEST"

# name | upstream URL | pinned SHA | patch dir
PROJECTS=(
  "rehlds|https://github.com/goldsrc-net/ReHLDS.git|12d78baf470f6c208d5652cc4e230bf82ee24748|rehlds"
  "metamod-r|https://github.com/goldsrc-net/Metamod-R.git|b2ea6fb08e5ba5c70b19f82b7cf9e8d7b7b76c13|metamod-r"
  "regamedll|https://github.com/s1lentq/ReGameDLL_CS|1f16a7f25c14225931f8df1abc51f68d18ded839|regamedll"
  "reunion|https://github.com/rehlds/ReUnion|df6ccc9747b0bf98225856380776371d559c1d93|reunion"
  "rehlmaster|https://github.com/anzz1/rehlmaster|8fe006b40d4e30f0634fc80aa8011a0d9aa6b308|rehlmaster"
  "hlmaster|https://github.com/anzz1/hlmaster|9e41a4e2c7b7c7abaf40e1477a8f8f9983e943cc|hlmaster"
)

# destination subpath for each project (mirrors the layout build/*.sh expect)
subpath() {
  case $1 in
    rehlds)    echo "buildchain/ReHLDS" ;;
    metamod-r) echo "buildchain/Metamod-R" ;;
    regamedll) echo "ReGameDLL_CS" ;;
    reunion)   echo "ReUnion" ;;
    rehlmaster) echo "rehlmaster" ;;
    hlmaster)  echo "hlmaster" ;;
  esac
}

fail=0
for entry in "${PROJECTS[@]}"; do
  IFS='|' read -r name url sha patchdir <<< "$entry"
  dest="$DEST/$(subpath $name)"
  if [ -d "$dest/.git" ]; then
    echo "== $name: already cloned, verifying SHA"
    git -C "$dest" checkout -q $sha 2>/dev/null || { echo "$name: pinned SHA missing in existing clone"; fail=1; continue; }
  else
    echo "== $name: cloning $url"
    git clone -q "$url" "$dest" || { echo "$name: clone failed"; fail=1; continue; }
    git -C "$dest" checkout -q $sha || { echo "$name: pinned SHA $sha not found upstream"; fail=1; continue; }
    git -C "$dest" submodule update -q --init --recursive 2>/dev/null || echo "$name: (no submodules or fetch failed)"
  fi
  # am creates commits; make sure an identity exists (repo-local, no global side effects)
  git -C "$dest" config user.name "cs16-arm" 2>/dev/null || true
  git -C "$dest" config user.email "cs16-arm@local" 2>/dev/null || true
  if git -C "$dest" rev-parse -q --verify refs/heads/arm > /dev/null; then
    echo "== $name: arm branch exists, resetting to patch state"
    git -C "$dest" checkout -q arm
    git -C "$dest" reset -q --hard $sha
  else
    git -C "$dest" checkout -q -b arm
  fi
  if ls "$PATCHES/$patchdir/"*.patch > /dev/null 2>&1; then
    echo "== $name: applying $patchdir"
    if ! git -C "$dest" am -q "$PATCHES/$patchdir/"*.patch 2>/dev/null; then
      git -C "$dest" am -q --abort 2>/dev/null || true
      # stateless fallback (identical tree, keeps authorship via commit below)
      git -C "$dest" apply --index "$PATCHES/$patchdir/"*.patch \
        && git -C "$dest" commit -q -m "arm: port build to armv7-a / aarch64 (patchset $patchdir)" \
        || { echo "$name: patch apply FAILED"; fail=1; continue; }
    fi
  else
    echo "== $name: no patches, upstream as-is"
  fi
  echo "   -> $(git -C "$dest" log --oneline -1)"
done

exit $fail

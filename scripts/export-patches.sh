#!/bin/bash
# export-patches.sh — regenerate patches/<project>/arm-port.mbox from the
# working trees' arm branches, relative to the pinned upstream SHAs
# (deterministic: commit count on the arm branch never shifts the range).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=${W:-$ROOT/..}   # working trees root (src/ clones); override with W=/path
SRC=$W/src

export_one() {
  local dir=$1 patchdir=$2 pinned=$3
  git -C "$SRC/$dir" format-patch "$pinned"..arm --stdout > "$ROOT/patches/$patchdir/arm-port.mbox"
  echo "$patchdir: $(grep -c '^From ' "$ROOT/patches/$patchdir/arm-port.mbox") commits"
}

export_one buildchain/ReHLDS    rehlds     12d78baf470f6c208d5652cc4e230bf82ee24748
export_one buildchain/Metamod-R metamod-r  b2ea6fb08e5ba5c70b19f82b7cf9e8d7b7b76c13
export_one ReGameDLL_CS         regamedll  1f16a7f25c14225931f8df1abc51f68d18ded839
export_one ReUnion              reunion    df6ccc9747b0bf98225856380776371d559c1d93
export_one rehlmaster           rehlmaster 8fe006b40d4e30f0634fc80aa8011a0d9aa6b308
export_one hlmaster             hlmaster   9e41a4e2c7b7c7abaf40e1477a8f8f9983e943cc

#!/bin/bash
# fetch-toolchains.sh — download the Bootlin glibc cross-toolchains used by
# build/*.cmake and unpack them into ./toolchains/.
#
# gcc 10.3 / binutils 2.36.1 / glibc 2.34 (binaries run on any host Linux;
# produced binaries need glibc >= 2.34 on the target).
#
# Usage:  bash scripts/fetch-toolchains.sh
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=$ROOT/toolchains
mkdir -p "$TC"

BASE=https://toolchains.bootlin.com/downloads/releases/toolchains
TC_ARM=$BASE/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2021.11-1.tar.bz2
TC_A64=$BASE/aarch64/tarballs/aarch64--glibc--stable-2021.11-1.tar.bz2

fetch() {
  local url=$1 name=$2 dir=$3
  if [ -d "$TC/$dir/bin" ]; then
    echo "== $name: already present"
    return
  fi
  echo "== $name: downloading $url"
  curl -fL --retry 3 -o "$TC/$name.tar.bz2" "$url"
  echo "== $name: unpacking"
  mkdir -p "$TC/$name"
  tar -xjf "$TC/$name.tar.bz2" -C "$TC/$name" --strip-components=1
  rm -f "$TC/$name.tar.bz2"
  # Bootlin SDKs ship a relocation helper; run it so absolute paths baked
  # into the toolchain point at this checkout
  if [ -x "$TC/$dir/relocate-sdk.sh" ]; then
    bash "$TC/$dir/relocate-sdk.sh" > /dev/null
  fi
  echo "   -> $TC/$dir"
}

fetch armv7 armv7-eabihf--glibc--stable-2021.11-1 armv7
fetch aarch64 aarch64--glibc--stable-2021.11-1 aarch64

echo "done"

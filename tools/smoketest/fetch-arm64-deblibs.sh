#!/bin/bash
# fetch-arm64-deblibs.sh — pull Debian bookworm arm64 shared libs needed by
# Valve's aarch64 steamclient.so into <outdir>, for qemu-user smoke tests.
# Skips libc/libm/libpthread/ld.so (the toolchain sysroot already provides
# those; letting bookworm's shadow them would break the loader pair).
set -u
OUT=${1:-/tmp/c16-smoke/deblibs}
mkdir -p "$OUT"; cd "$OUT" || exit 1

PKGS=(
  libx11-6 libxau6 libxdmcp6 libxcb1 libxext6 libxrender1 libxrandr2
  libxi6 libxtst6 libglvnd0 libglx0 libgl1 libdrm2 libbsd0 libmd0
  libglib2.0-0 libgobject-2-0 libgio-2.0-0 libffi8 libpcre2-8-0
  libmount1 libblkid1 libselinux1 libzstd1 liblzma5 libz
  libudev1 libnm0 libuuid1 libopenal1 libpulse0 libasyncns0
  libsndfile1 libdbus-1-3 libpipewire-0.3-0 libspa-0.2-modules
  libwayland-client0 libwayland-cursor0 libwayland-egl1
)

get() {
  local pkg=$1 f html url deb
  f="page_$pkg.html"
  curl -fsSL "https://packages.debian.org/bookworm/arm64/$pkg/download" -o "$f" || { echo "PAGE-FAIL $pkg"; return; }
  # first http/https pool .deb link on the page
  url=$(grep -oE 'https?://[^"]+/pool/[^"]+\.deb' "$f" | head -1)
  [ -n "$url" ] || { echo "URL-FAIL $pkg"; return; }
  deb=$(basename "$url")
  [ -f "$deb" ] || curl -fsSL "$url" -o "$deb" || { echo "DL-FAIL $pkg"; return; }
  dpkg-deb -x "$deb" . 2>/dev/null || tar -xf "$deb" 2>/dev/null || ar p "$deb" data.tar.xz 2>/dev/null | tar -xJ 2>/dev/null || { echo "EX-FAIL $pkg"; return; }
  echo "OK $pkg"
}

for p in "${PKGS[@]}"; do get "$p"; done

# Never let bookworm's libc shadow the toolchain sysroot pair
find . -name 'libc.so.6' -o -name 'libm.so.6' -o -name 'ld-linux-aarch64.so.1' -o -name 'libpthread.so.0' -o -name 'libdl.so.2' -o -name 'librt.so.1' | xargs -r rm -f
echo "done -> $OUT"

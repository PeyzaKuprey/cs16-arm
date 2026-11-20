#!/bin/bash
# smoke-test.sh — build the dlopen harness + SteamClient012 stub for each
# arch and dlopen every produced artifact under qemu-user.  Verifies ELF
# correctness, relocation and dependency resolution without any Valve
# binaries.
#
# Requires: qemu-user-static (any recent version) on PATH or in
# tools/qemu/usr/bin/.  Toolchains fetched via scripts/fetch-toolchains.sh.
# Run after build-armv7.sh / build-aarch64.sh.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SMOKE=$ROOT/tools/smoketest
QEMU_A64=${QEMU_A64:-$(command -v qemu-aarch64-static || echo $ROOT/tools/qemu/usr/bin/qemu-aarch64-static)}
QEMU_V7=${QEMU_V7:-$(command -v qemu-arm-static || echo $ROOT/tools/qemu/usr/bin/qemu-arm-static)}
SYS64=$ROOT/toolchains/aarch64/aarch64-buildroot-linux-gnu/sysroot
SYS32=$ROOT/toolchains/armv7/arm-buildroot-linux-gnueabihf/sysroot
REHLDS=$ROOT/src/buildchain/ReHLDS

# build harness + stub per arch
$ROOT/toolchains/aarch64/bin/aarch64-buildroot-linux-gnu-gcc -O0 -o "$SMOKE/dltest-aarch64" "$SMOKE/dltest.c" -ldl
$ROOT/toolchains/armv7/bin/arm-buildroot-linux-gnueabihf-gcc -O0 -o "$SMOKE/dltest-armv7" "$SMOKE/dltest.c" -ldl
INC="-I$REHLDS/rehlds/public/steam -I$REHLDS/rehlds/public/tier0 -I$REHLDS/rehlds/public -I$REHLDS/dep/libsteam_api/stub_include"
$ROOT/toolchains/aarch64/bin/aarch64-buildroot-linux-gnu-g++ -std=c++11 -w -shared -fPIC -O1 -static-libstdc++ \
  $INC "$SMOKE/steamclient_stub.cpp" -o "$SMOKE/steamclient_stub-aarch64.so"
$ROOT/toolchains/armv7/bin/arm-buildroot-linux-gnueabihf-g++ -std=c++11 -w -march=armv7-a -mfpu=neon -mfloat-abi=hard \
  -shared -fPIC -O1 -static-libstdc++ $INC "$SMOKE/steamclient_stub.cpp" -o "$SMOKE/steamclient_stub-armv7.so"

fail=0
run() {
  local qemu=$1 sysroot=$2 harness=$3 label=$4; shift 4
  echo "== $label"
  "$qemu" -L "$sysroot" "$harness" "$@" || { echo "$label: FAILED"; fail=1; }
}

run_ldpath() {
  local qemu=$1 sysroot=$2 harness=$3 label=$4 ldpath=$5; shift 5
  echo "== $label (LD_LIBRARY_PATH)"
  "$qemu" -L "$sysroot" -E "LD_LIBRARY_PATH=$ldpath" "$harness" "$@" || { echo "$label: FAILED"; fail=1; }
}

for arch in aarch64 armv7; do
  if [ $arch = aarch64 ]; then Q=$QEMU_A64; SYS=$SYS64; H=$SMOKE/dltest-aarch64; REH=$ROOT/build/rehlds-aarch64/rehlds; LIBDIR=linuxarm64
  else                        Q=$QEMU_V7; SYS=$SYS32; H=$SMOKE/dltest-armv7;  REH=$ROOT/build/rehlds-armv7/rehlds;  LIBDIR=linuxarm32
  fi
  # stage libsteam_api next to the engine ($ORIGIN rpath)
  cp "$REHLDS/rehlds/lib/$LIBDIR/libsteam_api.so" "$REH/"
  run $Q $SYS $H $arch \
    "$REH/engine_i486.so" \
    "$REH/filesystem/FileSystem_Stdio/filesystem_stdio.so" \
    "$REH/HLTV/Core/core.so" \
    "$REH/HLTV/DemoPlayer/demoplayer.so" \
    "$REH/HLTV/Director/director.so" \
    "$ROOT/build/metamod-$arch/metamod/metamod_$arch.so" \
    "$ROOT/build/regamedll-$arch/regamedll/cs.so" \
    "$ROOT/build/reunion-$arch/reunion_mm_$arch.so" \
    "$ROOT/build/rehlmaster-$arch/rehlmaster.so"
  # proxy.so carries a plain NEEDED on libsteam_api: resolvable via the
  # staged copy next to the engine
  run_ldpath $Q $SYS $H "$arch proxy" "$REH" "$REH/HLTV/Proxy/proxy.so"
done

exit $fail

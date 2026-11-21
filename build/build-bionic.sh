#!/bin/bash
# build-bionic.sh — build the whole stack against Android Bionic (NDK clang,
# libc++ static).  Output binaries run natively in Termux (no proot).
#
# Requires: ANDROID_NDK env var pointing at an NDK checkout (r26+), or
# edit the default below.  API level 24 (dladdr etc.; Termux floor).
set -x
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOGS=$ROOT/build/logs
mkdir -p "$LOGS"
cd "$ROOT"

export ANDROID_NDK=${ANDROID_NDK:-$HOME/android/ndk}
TCA=$ROOT/build/toolchain-bionic-aarch64.cmake
TCV=$ROOT/build/toolchain-bionic-armv7.cmake

fail=0

build_cmake() {
  local name=$1 src=$2 bdir=$3 tc=$4; shift 4
  # always configure from scratch: stale build dirs mix old and new flags
  rm -rf "$bdir"
  cmake -S "$src" -B "$bdir" -DCMAKE_TOOLCHAIN_FILE="$tc" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=OFF "$@" \
    > "$LOGS/${name}-configure.log" 2>&1 \
  && cmake --build "$bdir" -j4 > "$LOGS/${name}-build.log" 2>&1 \
  || { echo "$name FAILED"; fail=1; }
}

build_cmake rehlds-bionic-aarch64  src/buildchain/ReHLDS       build/rehlds-bionic-aarch64  $TCA
build_cmake metamod-bionic-aarch64 src/buildchain/Metamod-R    build/metamod-bionic-aarch64 $TCA
build_cmake regamedll-bionic-aarch64 src/ReGameDLL_CS          build/regamedll-bionic-aarch64 $TCA -DX64BITS=ON
build_cmake reunion-bionic-aarch64 src/ReUnion/reunion         build/reunion-bionic-aarch64 $TCA

mkdir -p build/rehlmaster-bionic-aarch64
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang++ -std=c++11 -w -O3 -s -shared \
  -fno-stack-protector -fno-strict-aliasing -fno-strict-overflow -fvisibility=hidden -fPIC \
  -Isrc/rehlmaster/src \
  -Isrc/rehlmaster/dep/rehlsdk/common -Isrc/rehlmaster/dep/rehlsdk/dlls -Isrc/rehlmaster/dep/rehlsdk/engine -Isrc/rehlmaster/dep/rehlsdk/public \
  -Isrc/rehlmaster/dep/metamod \
  src/rehlmaster/src/*.cpp \
  -o build/rehlmaster-bionic-aarch64/rehlmaster.so \
  || { echo "REHLMASTER BIONIC AARCH64 FAILED"; fail=1; }

mkdir -p build/hlmaster-bionic-aarch64
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang -O3 -w -s -fvisibility=hidden \
  -fno-strict-aliasing -fno-strict-overflow \
  src/hlmaster/hlmaster.c -o build/hlmaster-bionic-aarch64/hlmaster \
  || { echo "HLMASTER BIONIC AARCH64 FAILED"; fail=1; }

build_cmake rehlds-bionic-armv7   src/buildchain/ReHLDS        build/rehlds-bionic-armv7    $TCV
build_cmake metamod-bionic-armv7  src/buildchain/Metamod-R     build/metamod-bionic-armv7   $TCV -DMETAMOD_CPP_CALLBACKS=ON
build_cmake regamedll-bionic-armv7 src/ReGameDLL_CS            build/regamedll-bionic-armv7 $TCV
build_cmake reunion-bionic-armv7  src/ReUnion/reunion          build/reunion-bionic-armv7   $TCV

mkdir -p build/rehlmaster-bionic-armv7
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang++ -std=c++11 -w -O3 -s -shared \
  -fno-stack-protector -fno-strict-aliasing -fno-strict-overflow -fvisibility=hidden -fPIC \
  -Isrc/rehlmaster/src \
  -Isrc/rehlmaster/dep/rehlsdk/common -Isrc/rehlmaster/dep/rehlsdk/dlls -Isrc/rehlmaster/dep/rehlsdk/engine -Isrc/rehlmaster/dep/rehlsdk/public \
  -Isrc/rehlmaster/dep/metamod \
  src/rehlmaster/src/*.cpp \
  -o build/rehlmaster-bionic-armv7/rehlmaster.so \
  || { echo "REHLMASTER BIONIC ARMv7 FAILED"; fail=1; }

mkdir -p build/hlmaster-bionic-armv7
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/armv7a-linux-androideabi24-clang -O3 -w -s -fvisibility=hidden \
  -fno-strict-aliasing -fno-strict-overflow \
  src/hlmaster/hlmaster.c -o build/hlmaster-bionic-armv7/hlmaster \
  || { echo "HLMASTER BIONIC ARMv7 FAILED"; fail=1; }

echo "=== DONE fail=$fail ==="
exit $fail

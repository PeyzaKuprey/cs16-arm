#!/bin/bash
# Build core stack for armv7 (Bootlin gcc 10.3, glibc 2.34) + aarch64 (rebuild)
set -x
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC7=$ROOT/build/toolchain-armv7.cmake
TC64=$ROOT/build/toolchain-aarch64.cmake
LOGS=$ROOT/build/logs
mkdir -p "$LOGS"
cd "$ROOT"

fail=0

build_cmake() {
  local name=$1 src=$2 bdir=$3 shift
  cmake -S "$src" -B "$bdir" -DCMAKE_TOOLCHAIN_FILE="$TC7" -DCMAKE_BUILD_TYPE=Release -DUSE_STATIC_LIBSTDC=ON "$@" > "$LOGS/${name}-configure.log" 2>&1 \
  && cmake --build "$bdir" -j4 > "$LOGS/${name}-build.log" 2>&1 \
  || { echo "$name FAILED"; fail=1; }
}

echo "=== ReHLDS armv7 ==="
cmake -S src/buildchain/ReHLDS -B build/rehlds-armv7 \
  -DCMAKE_TOOLCHAIN_FILE="$TC7" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/rehlds-armv7-configure.log" 2>&1 \
&& cmake --build build/rehlds-armv7 -j4 > "$LOGS/rehlds-armv7-build.log" 2>&1 \
|| { echo "REHLDS ARMv7 FAILED"; fail=1; }

echo "=== Metamod-R armv7 (C++ callbacks, no JIT) ==="
cmake -S src/buildchain/Metamod-R -B build/metamod-armv7 \
  -DCMAKE_TOOLCHAIN_FILE="$TC7" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON -DMETAMOD_CPP_CALLBACKS=ON \
  > "$LOGS/metamod-armv7-configure.log" 2>&1 \
&& cmake --build build/metamod-armv7 -j4 > "$LOGS/metamod-armv7-build.log" 2>&1 \
|| { echo "METAMOD ARMv7 FAILED"; fail=1; }

echo "=== ReGameDLL_CS armv7 ==="
cmake -S src/ReGameDLL_CS -B build/regamedll-armv7 \
  -DCMAKE_TOOLCHAIN_FILE="$TC7" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/regamedll-armv7-configure.log" 2>&1 \
&& cmake --build build/regamedll-armv7 -j4 > "$LOGS/regamedll-armv7-build.log" 2>&1 \
|| { echo "REGAMEDLL ARMv7 FAILED"; fail=1; }

echo "=== ReUnion armv7 ==="
cmake -S src/ReUnion/reunion -B build/reunion-armv7 \
  -DCMAKE_TOOLCHAIN_FILE="$TC7" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/reunion-armv7-configure.log" 2>&1 \
&& cmake --build build/reunion-armv7 -j4 > "$LOGS/reunion-armv7-build.log" 2>&1 \
|| { echo "REUNION ARMv7 FAILED"; fail=1; }

echo "=== rehlmaster armv7 ==="
TC_ROOT=$ROOT/toolchains/armv7
mkdir -p build/rehlmaster-armv7
${TC_ROOT}/bin/arm-buildroot-linux-gnueabihf-g++ -std=c++11 -w -march=armv7-a -mtune=cortex-a53 -O3 -s -shared -static-libgcc -static-libstdc++ \
  -fno-stack-protector -fno-strict-aliasing -fno-strict-overflow -fvisibility=hidden -fPIC \
  -Isrc/rehlmaster/src \
  -Isrc/rehlmaster/dep/rehlsdk/common -Isrc/rehlmaster/dep/rehlsdk/dlls -Isrc/rehlmaster/dep/rehlsdk/engine -Isrc/rehlmaster/dep/rehlsdk/public \
  -Isrc/rehlmaster/dep/metamod \
  src/rehlmaster/src/*.cpp \
  -o build/rehlmaster-armv7/rehlmaster.so \
|| { echo "REHLMASTER ARMv7 FAILED"; fail=1; }


echo "=== hlmaster armv7 (standalone master server) ==="
mkdir -p build/hlmaster-armv7
${TC_ROOT}/bin/arm-buildroot-linux-gnueabihf-gcc -O3 -w -march=armv7-a -mtune=cortex-a53 -mfpu=neon -mfloat-abi=hard -s -fvisibility=hidden \
  -fno-strict-aliasing -fno-strict-overflow -fomit-frame-pointer -fno-stack-protector \
  src/hlmaster/hlmaster.c -o build/hlmaster-armv7/hlmaster \
  || { echo "HLMASTER ARMv7 FAILED"; fail=1; }

echo "=== DONE fail=$fail ==="
exit $fail
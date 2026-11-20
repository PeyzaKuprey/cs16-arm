#!/bin/bash
# Build core stack for aarch64 (Bootlin gcc 10.3, glibc 2.34 floor)
set -x
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=$ROOT/build/toolchain-aarch64.cmake
LOGS=$ROOT/build/logs
mkdir -p "$LOGS"
cd "$ROOT"

fail=0

echo "=== ReHLDS aarch64 ==="
cmake -S src/buildchain/ReHLDS -B build/rehlds-aarch64 \
  -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/rehlds-aarch64-configure.log" 2>&1 \
&& cmake --build build/rehlds-aarch64 -j4 > "$LOGS/rehlds-aarch64-build.log" 2>&1 \
|| { echo "REHLDS FAILED"; fail=1; }

echo "=== Metamod-R aarch64 ==="
cmake -S src/buildchain/Metamod-R -B build/metamod-aarch64 \
  -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/metamod-aarch64-configure.log" 2>&1 \
&& cmake --build build/metamod-aarch64 -j4 > "$LOGS/metamod-aarch64-build.log" 2>&1 \
|| { echo "METAMOD FAILED"; fail=1; }

echo "=== ReGameDLL_CS aarch64 ==="
cmake -S src/ReGameDLL_CS -B build/regamedll-aarch64 \
  -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DX64BITS=ON -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/regamedll-aarch64-configure.log" 2>&1 \
&& cmake --build build/regamedll-aarch64 -j4 > "$LOGS/regamedll-aarch64-build.log" 2>&1 \
|| { echo "REGAMEDLL FAILED"; fail=1; }

echo "=== ReUnion aarch64 ==="
cmake -S src/ReUnion/reunion -B build/reunion-aarch64 \
  -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_STATIC_LIBSTDC=ON \
  > "$LOGS/reunion-aarch64-configure.log" 2>&1 \
&& cmake --build build/reunion-aarch64 -j4 > "$LOGS/reunion-aarch64-build.log" 2>&1 \
|| { echo "REUNION AARCH64 FAILED"; fail=1; }

echo "=== rehlmaster aarch64 ==="
TC_ROOT=$ROOT/toolchains/aarch64
mkdir -p build/rehlmaster-aarch64
${TC_ROOT}/bin/aarch64-buildroot-linux-gnu-g++ -std=c++11 -w -O3 -s -shared -static-libgcc -static-libstdc++ \
  -fno-stack-protector -fno-strict-aliasing -fno-strict-overflow -fvisibility=hidden -fPIC \
  -Isrc/rehlmaster/src \
  -Isrc/rehlmaster/dep/rehlsdk/common -Isrc/rehlmaster/dep/rehlsdk/dlls -Isrc/rehlmaster/dep/rehlsdk/engine -Isrc/rehlmaster/dep/rehlsdk/public \
  -Isrc/rehlmaster/dep/metamod \
  src/rehlmaster/src/*.cpp \
  -o build/rehlmaster-aarch64/rehlmaster.so \
|| { echo "REHLMASTER AARCH64 FAILED"; fail=1; }

echo "=== DONE fail=$fail ==="
exit $fail
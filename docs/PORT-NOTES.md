# Port notes — x86 assumptions fanned out to ARM

The port keeps upstream x86 behavior untouched; every change is either a
build-system generalization or an arch-conditional replacement of an x86
instruction/ABI assumption.  This file is the map; the patchsets under
`patches/` are the source of truth.

## ReHLDS (patches/rehlds)

- `cmake/ArchFlags.cmake` (new logic in an existing file): centralizes
  `ARCH_BITNESS_FLAG` (empty on ARM, `-m32` on i386), `ARCH_SSE_FLAG`,
  `ARCH_TUNE_FLAG` (`-mtune=cortex-a53` — gcc rejects `generic` on ARM),
  `ARCH_PIC` (ON — shared objects need it on ARM, upstream i386 linked
  no-PIC), `ARCH_LIB_DIR` (`linuxarm32`/`linuxarm64` next to the existing
  `linux32`/`linux64`), `ARCH_IS_ARM`.
- HLTV CMakeLists: `-flto` dropped on ARM — gcc LTO + shared-object
  linking emitted `R_AARCH64_ADR_PREL_PG_HI21` relocations that fail
  (`proxy.so` refused to link).
- `REHLDS_JIT` (delta-compression code emission) gated to non-armv7: the
  AsmJit backend isn't wired for 32-bit ARM; the scalar delta fallback in
  `delta.cpp` covers it.  aarch64 keeps the (multi-arch) JIT.
- `sse_mathfun.h` / `crc32c.cpp`: include `sse2neon.h` under ARM+NEON —
  replaces `_mm_*` SSE intrinsics with NEON equivalents.  The armv7 engine
  builds and runs with it.
- `osconfig.h`: `smmintrin.h`/`xmmintrin.h` are x86-only, guarded.
- `dedicated/` CMakeLists: same flag fan-out (no `-mtune=generic`).

## Metamod-R (patches/metamod-r)

armv7 has no AsmJit backend, and metamod-r's whole hook mechanism on x86
is generated machine code (a trampoline per hooked function, plus a
dispatcher unrolling the current plugin list).  The port adds
`METAMOD_CPP_CALLBACKS=ON`:

- `callback_cpp.h` — for each entry of `DLL_FUNCTIONS`,
  `NEW_DLL_FUNCTIONS` and `enginefuncs_t`, a statically compiled C++
  wrapper with the exact SDK signature forwards to a generic
  `dispatch<Ret, Args...>()` that mirrors the JIT orchestration:
  pre-hooks (mm_hook), per-plugin loop with `MRES_*` handling, original
  call with supercede short-circuit, post-hooks, return-value override,
  and `g_metaGlobals` save/restore for nesting.  Variadic engine
  functions (`void (A, const char*, ...)`) are formatted then dispatched
  in fixed form, like the JIT's va entry.  Each wrapper reads its
  `jitdata_t` live, so plugin load/unload needs no code regeneration.
- `compile_engine_tramps()` / `compile_gamedll_tramps()` — under the C++
  mode the public tables (`g_meta_engfuncs` handed to the gamedll,
  `sFunctionTable`/`sNewFunctionTable` handed to the engine) get the
  wrapper pointers directly, reading originals from the source tables.
  The JIT path's rebuildable-indirection trampolines are x86-only and
  would otherwise execute x86 bytes on ARM.
- `meta_rebuild_callbacks()` — the JIT-only live-frame return-address
  fixup (`is_callback_retaddr` / `handler_slot_at_retaddr`) is skipped in
  C++ mode; wrapper addresses are stable, so a rebuild just refreshes the
  `jitdata_t` snapshots.
- aarch64 keeps the real JIT (`callback_jit_a64.cpp`, AsmJit a64 backend).

Debugging archaeology worth knowing: the first armv7 build "worked" at
compile time but crashed on the first engine-table call, because (1) the
CMake option was never turned into a `target_compile_definitions`, (2)
`engine_api.cpp` was missing the `callback_cpp.h` include, and (3) the
tramp tables still carried x86 JIT output.  All three are fixed in the
patchset — if you add a new arch or mode, check all three layers.

## ReGameDLL_CS (patches/regamedll)

- `ARCH_ARM` detection: skip x86 tuning flags, force
  `POSITION_INDEPENDENT_CODE ON` for the shared object (upstream i386
  links no-PIC deliberately).
- `DebuggerBreak()`: `int3` is x86-only; `__builtin_trap` elsewhere.

## ReUnion (patches/reunion)

- CMakeLists: no `-m32`/`-msse3` on ARM, PIC on, `-fpermissive` on ARM
  only, arch-suffixed output (`reunion_mm_armv7.so` /
  `reunion_mm_aarch64.so`).
- `Rijndael.cpp` / `RijndaelChanged.cpp`: the S-box tables are declared
  `const char` with negative initializers.  ARM's plain `char` is
  unsigned by default (AAPCS), so `-14` etc. became brace-init narrowing
  errors — x86 never saw them because x86 `char` is signed.  Fixed by
  declaring the tables `signed char` (x86-identical; all consumers mask
  `& 0xFF` or cast through `unsigned char`).
- dep/rehlsdk: `cpuid.h`/`__get_cpuid` are x86-only (`sys_shared.cpp`),
  `immintrin.h` only needed under `REHLDS_SSE` (`crc32c.cpp` — not
  defined in ReUnion's build), x86 intrin includes in `osconfig.h`
  guarded.
- `reunion_authorizers.cpp`: `std::min(size_t, uint32_t)` — same-width
  types on armv7 (both `unsigned int`) but not on aarch64 (`unsigned
  long` vs `unsigned int`); the two caps are `size_t` now.
- `reunion/version/appversion.h` pinned by hand (upstream generates it
  from a sibling ReHLDS checkout this tree doesn't carry; the file is
  gitignored upstream, hence `git add -f` in the patchset).

## rehlmaster (patches/rehlmaster)

- `osconfig.h` x86 intrin guard.
- Built directly with the cross g++ and `-static-libstdc++` (see
  `build/build-*.sh`): the plugin ends up with NEEDED = libc/libm only,
  no target libstdc++ required on the deployment host.

## Toolchain / ABI floor

Bootlin gcc-10.3 / glibc-2.34 (stable-2021.11-1) for both arches.  armv7
builds with `-march=armv7-a -mtune=cortex-a53 -mfpu=neon
-mfloat-abi=hard` (NEON enabled explicitly; the Bootlin default is
VFP-only).  Produced binaries require glibc >= 2.34 on the target
(Debian bookworm and newer, proot-distro included).

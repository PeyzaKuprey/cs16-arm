# cs16-arm

Native **ARM (armv7-a + aarch64) port of the Counter-Strike 1.6 dedicated
server stack** — ReHLDS engine, ReGameDLL_CS gamedll, Metamod-R, ReUnion and
rehlmaster.  Every binary is native ARM ELF; no box86/qemu in the deployment
path.  Built with Bootlin gcc-10.3 toolchains against glibc 2.34, so the
output runs on any Debian bookworm-or-newer target, including proot-distro
on Android (tested lineage: Redmi 9C-class Cortex-A53) and SBC-class arm64
boards.

Started as an ARM port on top of the goldsrc-net `64bit` branch line; this
repository holds the glue: pinned upstream sources + patchset, build
scripts, drop-in assembly and smoke tests.

## Stack

| Layer | Project | Upstream | Pinned at |
|---|---|---|---|
| Engine | [ReHLDS](https://github.com/goldsrc-net/ReHLDS) (fork line) | `goldsrc-net/ReHLDS` | `12d78ba` |
| Plugin loader | [Metamod-R](https://github.com/goldsrc-net/Metamod-R) | `goldsrc-net/Metamod-R` | `b2ea6fb` |
| Gamedll | [ReGameDLL_CS](https://github.com/s1lentq/ReGameDLL_CS) | `s1lentq/ReGameDLL_CS` | `1f16a7f` |
| Auth | [ReUnion](https://github.com/rehlds/ReUnion) | `rehlds/ReUnion` | `df6ccc9` |
| Master ping | [rehlmaster](https://github.com/anzz1/rehlmaster) | `anzz1/rehlmaster` | `8fe006b` |
| Master server | [hlmaster](https://github.com/anzz1/hlmaster) | `anzz1/hlmaster` | `9e41a4e` |

Exact SHAs live in `scripts/fetch-sources.sh`; the whole port is a patchset
per project under `patches/` (applied on an `arm` branch, see below).

Two build lines:

- **Bionic** (`build/build-bionic.sh`) — Android NDK clang, libc++ static:
  native Termux binaries, no proot.  Requires `$ANDROID_NDK`
  (developer.android.com/ndk, r26+).  Deploy guide: `docs/TERMX.md`.
- **glibc** (`build/build-armv7.sh` / `build-aarch64.sh`) — Bootlin gcc
  toolchains: runs under proot-distro / any glibc ARM rootfs.

## Quick start (glibc line)

```bash
bash scripts/fetch-toolchains.sh    # ~260 MB Bootlin toolchains into ./toolchains
bash scripts/fetch-sources.sh       # clone upstreams at pinned SHAs + apply patches
bash build/build-armv7.sh           # or build-aarch64.sh; logs into build/logs/
bash scripts/assemble-dropin.sh     # dist/<arch>/ overlay + hlds-dropin-cs16-<arch>.zip
bash scripts/smoke-test.sh          # dlopen every artifact under qemu-user
```

Deploy: extract `dist/hlds-dropin-cs16-<arch>.zip` over a stock HLDS
install (`steamcmd +force_install_dir ~/hlds +login anonymous +app_set_config
90 mod cstrike +app_update 90 validate +quit`), run `bash apply-liblist.sh`,
then `./hlds_run -game cstrike +map de_dust2`.  See
`dist/README-dropin.md` for the details and layout.

## What the port actually changes

Every project keeps upstream x86 behavior byte-for-byte on x86; the patches
fan the i386-only assumptions out to ARM.  Highlights (full notes in
`docs/PORT-NOTES.md`):

- **ReHLDS** — `cmake/ArchFlags.cmake` replaces hardcoded `-m32`/`-msse3`/
  no-PIC with per-arch flags; HLTV LTO dropped on ARM (gcc LTO produced
  non-PIC relocations in `proxy.so`); delta-emission JIT gated off on
  armv7 (AsmJit backend not wired there — scalar fallback covers it);
  `sse2neon` for SSE math / CRC32C on NEON; x86-only `cpuid`/intrin
  includes guarded.
- **Metamod-R** — armv7 uses a new `METAMOD_CPP_CALLBACKS` mode: instead of
  the x86 AsmJit trampoline JIT, every hooked function gets a statically
  compiled C++ wrapper with the exact SDK signature dispatching to plugins
  (`metamod/src/callback_cpp.h`).  aarch64 keeps the ported AsmJit a64 JIT.
  Three stacked wiring bugs (missing compile definition, missing include,
  x86 trampolines still written into the public tables) are documented in
  the patchset — worth reading before touching the mode.
- **ReGameDLL_CS** — arch flags, PIC shared object, `int3`-only
  `DebuggerBreak`.
- **ReUnion** — same flags; Rijndael S-box tables are explicit `signed
  char` (ARM's `char` is unsigned by default → brace-init narrowing
  errors); `size_t`/`uint32_t` `min()` fix for aarch64; arch-suffixed
  output names.
- **rehlmaster** — x86 intrin guard; `-static-libstdc++` so the plugin has
  no target libstdc++ dependency.
- **hlmaster** — the standalone master server compiles as-is on both
  arches (pure C, no arch assumptions); built into
  `build/hlmaster-<arch>/hlmaster`.  See `docs/AUX-PROJECTS.md`.

## Verification status (Bionic line)

- ✅ full stack builds against Bionic for **both arches**: ReHLDS
  (engine + dedicated + HLTV), Metamod-R, ReGameDLL_CS, ReUnion,
  rehlmaster, hlmaster — NEEDED lists are bionic-clean (`libc.so`,
  `libdl.so`, `libm.so`; zero glibc references)
- ✅ drop-in zips: `dist-bionic/hlds-dropin-cs16-bionic-{armv7,aarch64}.zip`
- ⏳ on-device soak in Termux — pending hardware

## Verification status (glibc line)

- ✅ all 11 artifacts per arch: ARM ELF, dlopen-clean under qemu-user
- ✅ full end-to-end under qemu-user with real steamcmd cstrike content:
  engine → Metamod-r → ReUnion → ReGameDLL CS 5.30 → de_dust2 spawn →
  live frame loop; **both arches answer `getchallenge` over UDP**
  (`S2C_CHALLENGE` replies observed)
- ⚠️ Source-style `A2S_INFO` is answered by Valve's steamclient.so, not the
  engine (`SV_ConnectionlessPacket` skips it), and Valve's binary refuses
  to run under qemu-user (futex robust_list anti-emulation check).  On
  real ARM hardware the real steamclient.so is expected to work —
  goldsrc-net verified VAC engagement on real aarch64 silicon.  For
  emulation testing use `tools/smoketest/steamclient_stub.cpp`, a minimal
  SteamClient012 backend that satisfies the `libsteam_api` shim.
- ⏳ soak on real ARM hardware still pending

## Repo layout

```
patches/<project>/    port patchset (git format-patch off the arm branch)
build/                build + toolchain scripts; artifacts land in build/<proj>-<arch>/
scripts/              fetch-sources / fetch-toolchains / assemble-dropin / smoke-test
tools/smoketest/      dlopen harness, SteamClient012 stub, test-lib fetcher
docs/                 port notes, testing notes
```

`toolchains/`, `src/`, `build/`, `dist/` are generated/ignored — see
`.gitignore`.

## License

The glue in this repository (scripts, docs, build files, the dlopen harness
and the steamclient stub) is MIT — see `LICENSE`.  **Each upstream project
keeps its own license** (GPL-3.0 for ReHLDS/Metamod-R/ReGameDLL_CS,
LGPL-3.0 for ReUnion, MIT for rehlmaster — verify against each tree); the
patchsets modify those projects and inherit their licenses.  Nothing from
Valve is included; the server content comes from your own steamcmd
install.

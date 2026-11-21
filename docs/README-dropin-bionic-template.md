# hlds-dropin-cs16-bionic-<arch>

Native Counter-Strike 1.6 dedicated server overlay for **Android / Termux**
(`<arch>`), built against **Bionic** with the Android NDK (r26+, API 24).
No proot, no chroot, no Steam, no box86/qemu — every binary is a native ARM ELF.

This is a **Bionic** build. It is NOT the glibc/Bootlin drop-in: do not run
`hlds_run`, do not expect Debian/glibc layout, and do not install SteamCMD.

## What this contains

- `engine_i486.so`, `filesystem_stdio.so`, `hlds_linux`, `hltv`,
  `core.so`, `demoplayer.so`, `director.so`, `proxy.so` — all **PIE** (ET_DYN)
  because the Bionic loader rejects non-PIE executables (ET_EXEC).
- `libsteam_api.so` — from-source SteamWorks shim, shipped in this folder.
  It is the only extra `NEEDED` entry of the engine.
- `cstrike/dlls/cs.so` — ReGameDLL_CS game DLL.
- `cstrike/addons/metamod/dlls/metamod_<arch>.so` — Metamod-R.
- `cstrike/addons/reunion/dlls/reunion_mm_<arch>.so` — ReUnion auth.
- `cstrike/addons/metamod/dlls/rehlmaster.so` — GoldSrc master ping.
- `apply-liblist.sh` — wires Metamod-R into `cstrike/liblist.gam`.

Every `.so` and executable links only to `libc.so`, `libdl.so`, `libm.so`
(and the engine to `libsteam_api.so` from this folder). There are no
`TEXTREL` relocations and the stack is non-executable.

## Install in Termux

1. Install Termux from F-Droid (the Play Store build is outdated), then:

   ```
   pkg update -y
   pkg install -y root-repo
   pkg install -y termux-api
   termux-setup-storage
   ```

2. Put your CS 1.6 game data in `~/hlds` first (the `cstrike/` and `valve/`
   folders from your cache archive, e.g. the `xash/` folder of
   `Counter-Strike-1.6-v1.35-cache1.zip`). **Game data is not included here.**

3. Unzip this overlay on top of `~/hlds`:

   ```
   cd ~/hlds
   unzip ~/storage/downloads/hlds-dropin-cs16-bionic-<arch>.zip
   bash apply-liblist.sh
   ```

4. Start the server directly — `hlds_run` is not shipped for Bionic:

   ```
   cd ~/hlds
   LD_LIBRARY_PATH=$PWD:$PREFIX/lib ./hlds_linux -console -game cstrike \
     -nosteam +map de_dust2 +sv_lan 1
   ```

   Use `-port 27015 +maxplayers 16` as usual. Add `+sv_lan 1` for LAN-only
   testing while ReUnion/Steam auth is being validated.

## Steam / auth notes

- `-nosteam` skips the Steam client startup. The engine still dlopen()s the
  shim; if it reports `Unable to initialize Steam`, either keep `-nosteam`
  or force the stub:

  ```
  STEAM_API_DLOPEN_FORCE=1 LD_LIBRARY_PATH=$PWD:$PREFIX/lib ./hlds_linux ...
  ```

  The stub lives in `tools/smoketest/steamclient_stub.cpp` in the source repo.
- ReUnion authorizes clients without Steam. Make sure
  `cstrike/addons/reunion/reunion.cfg` is readable and that
  `reunion_mm_<arch>.so` is listed first in `plugins.ini`.
- A2S_INFO replies are normally served by `steamclient.so`. With the stub,
  the server may stay silent to A2S_INFO while `getchallenge` still works.
  This is expected; LAN play is unaffected.

## Verify the binaries (optional)

```
cd ~/hlds
readelf -h hlds_linux | grep Type
readelf -h hltv | grep Type
readelf -d hlds_linux | grep -E 'NEEDED|TEXTREL'
```

Expected: `Type: DYN (Shared object file)` for `hlds_linux` and `hltv`;
`NEEDED` only for `libdl.so`, `libm.so`, `libc.so`; no `TEXTREL` line.

## Notes on the ARM port

- `engine_i486.so` keeps its legacy filename for `liblist.gam` compatibility;
  it is an ARM ELF regardless of the name.
- On armv7, Metamod-R uses `METAMOD_CPP_CALLBACKS=ON` (statically compiled C++
  wrappers instead of the x86 JIT trampoline). On aarch64 the ported AsmJit
  aarch64 backend is used.
- Built by `build/build-bionic.sh` and packaged by
  `scripts/assemble-bionic.sh` in the `cs16-arm` repo. See `docs/TERMX.md`.

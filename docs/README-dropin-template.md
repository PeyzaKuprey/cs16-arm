# hlds-dropin-cs16-<arch>

Drop-in overlay that turns a stock Steam HLDS install into a **native-ARM
Counter-Strike 1.6 dedicated server** for `<arch>` (ReHLDS engine, ReGameDLL_CS
gamedll, Metamod-R, ReUnion, rehlmaster).  No box86/qemu-32 needed — every
binary is native ARM.

Built by `build/build-armv7.sh` / `build/build-aarch64.sh` in this repo
(Bootlin gcc-10.3 toolchains, glibc 2.34 floor → runs on Debian bookworm and
newer, including proot-distro on Android).

## What this contains

- **ReHLDS engine + HLTV** at the overlay root: `engine_i486.so`,
  `filesystem_stdio.so`, `hlds_linux`, `hltv`, `core.so`, `demoplayer.so`,
  `director.so`, `proxy.so`, plus the from-source `libsteam_api.so` shim
  (SteamWorks v1.60 ABI; VAC engages).
- **ReGameDLL_CS** gamedll: `cstrike/dlls/cs.so`.
- **Metamod-R**: `cstrike/addons/metamod/dlls/metamod_<arch>.so`
  (+ `config.ini`, `plugins.ini`).
- **ReUnion** (auth): `cstrike/addons/reunion/dlls/reunion_mm_<arch>.so`
  (+ `reunion.cfg`).
- **rehlmaster** (GoldSrc master-server ping): wired in `plugins.ini`.
- `apply-liblist.sh` — wires metamod into `cstrike/liblist.gam`.

## What this does NOT contain

CS game data (maps, models, wads).  Install the base server once:

```
steamcmd +force_install_dir ~/hlds +login anonymous \
  +app_set_config 90 mod cstrike +app_update 90 validate +quit
```

## How to apply

1. Have the HLDS install at, say, `~/hlds/` (per above).
2. Extract this overlay over the same directory (overwrite conflicts are
   intentional: ReHLDS replaces the stock i386 engine which will not run on
   ARM anyway).
3. Wire metamod: `bash apply-liblist.sh`
4. Start:
   ```
   cd ~/hlds && ./hlds_run -game cstrike +map de_dust2 +maxplayers 16
   ```
   (If your base install lacks `hlds_run` for ARM, invoke `./hlds_linux`
   directly with the same arguments.)

## Configuration entrypoints

- `cstrike/addons/metamod/plugins.ini` — plugin list.  ReUnion and rehlmaster
  are wired; add more (e.g. amxmodx when an ARM build is available).
- `cstrike/addons/reunion/reunion.cfg` — ReUnion auth provider config.
- `cstrike/addons/metamod/config.ini` — Metamod-R debug level / exec_cfg.
- rehlmaster: console cvars `sv_master1..5 <host>` for extra master servers.

## Notes on the ARM port

- 32-bit x86 code paths (ReHLDS JIT for delta compression, SSE CPU checks,
  cpuid, Rijndael signed-char tables) are either emulated through
  arch-neutral replacements (AsmJit aarch64 backend, scalar delta fallback)
  or replaced with the ARM-equivalent (NEON sse2neon) — see each repo's
  uncommitted diff in `src/`.
- Metamod-R on armv7 runs with `METAMOD_CPP_CALLBACKS=ON`: instead of the
  x86 AsmJit trampoline JIT, every hooked function gets a statically
  compiled C++ wrapper with the exact SDK signature dispatching to plugins.
  On aarch64 the (ported) AsmJit a64 JIT is used as usual.
- `engine_i486.so` keeps the legacy filename for drop-in compatibility with
  `liblist.gam`/tooling expectations; it is an ARM ELF regardless.

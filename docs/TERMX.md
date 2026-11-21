# Native Termux deployment (Bionic build)

The `build-bionic` line produces binaries linked against **Android Bionic**
(NDK clang, libc++ static, API 24).  They run **directly in Termux** — no
proot, no glibc shim, no box86.  Termux's own Android 7+ userland (API 24+)
satisfies the bionic floor.

## Install

```bash
pkg update && pkg install clang wget unzip  # git, for updates
termux-setup-storage                        # if you want to copy content from /sdcard
mkdir -p ~/hlds && cd ~/hlds
unzip ~/storage/downloads/hlds-dropin-cs16-bionic-<arch>.zip -d .
```

`<arch>`: pick by `uname -m` in Termux — `aarch64` → aarch64, `armv7l`/`armv8l`
→ armv7.

## Server content (maps, models, wads)

`steamcmd` is x86 and won't run on the phone.  Get HLDS content on a PC:

```
steamcmd +force_install_dir ~/hlds +login anonymous \
  +app_set_config 90 mod cstrike +app_update 90 validate +quit
```

then copy `~/hlds/cstrike` + `~/hlds/valve` to the phone
(`~/storage/downloads/` → `cp -r` into `~/hlds`), preserving the base
layout.  Only game data is needed — the PC's engine binaries are i386 and
will be replaced by the overlay's ARM ones.

## Wire up and launch

```bash
cd ~/hlds && bash apply-liblist.sh
IP=$(ifconfig wlan0 2>/dev/null | awk '/inet /{print $2}' | head -1)
LD_LIBRARY_PATH=$PWD:$PREFIX/lib ./hlds_linux -console -game cstrike \
  -nosteam +map de_dust2 +maxplayers 16 +ip $IP -port 27015
```

The Bionic overlay does **not** ship `hlds_run` — launch `hlds_linux`
directly as shown.  It is built as PIE (`ET_DYN`), which the Android loader
requires; a non-PIE executable fails with `unexpected e_type: 2`.  Players on
the LAN connect to `<phone-ip>:27015`; for internet play forward UDP
27015 (and 27020 HLTV if used) on the router.

## Steam / A2S specifics on-device

- The overlay ships the from-source `libsteam_api.so` shim (Bionic build).
  Valve's `steamclient.so` does not exist for Android — without it,
  `SteamGameServer_Init` fails and the engine exits (`Unable to initialize
  Steam`).  Two supported workarounds:
  - **LAN/no-Steam play**: put `tools/smoketest/steamclient_stub.cpp`
    compiled per-arch (or the prebuilt stub from the glibc line — ELF
    ABI doesn't matter here?  it does: compile it with the NDK, same
    command as in scripts/smoke-test.sh but with the bionic toolchain)
    next to the engine and set
    `STEAM_API_DLOPEN_FORCE=$PWD/steamclient_stub-<arch>.so`.
  - **Full Steam/VAC**: needs a real Android `steamclient.so` — not
    available; this is a Valve ecosystem gap, not a port gap.
- Server-browser queries (`A2S_INFO 'T'`) are answered by steamclient.so —
  so with the stub they're silent; `getchallenge` and direct connects
  work.

## Keep-alive

```bash
termux-wake-lock
```
plus Android settings: Termux → battery → unrestricted, and disable MIUI's
app auto-close.  Optionally `termux-services`/runit to supervise the
server.

## Which build line to use when

| | Bionic (this line) | glibc (`build/build-*.sh`) |
|---|---|---|
| Runs in | Termux natively | proot-distro (Debian) |
| libc | Bionic API 24 | glibc ≥ 2.34 |
| steamclient | no (stub for LAN) | real one (aarch64) |
| Overhead | none | proot syscall translation |

# Testing under qemu-user — how far it goes and why

`scripts/smoke-test.sh` runs the fast tier.  This document describes what
was verified end-to-end, what the emulator cannot do, and the workarounds.

## Tier 1 — dlopen smoke test (scripts/smoke-test.sh)

Builds `tools/smoketest/dltest.c` (dlopens argv, exits non-zero on failure)
per arch, plus `tools/smoketest/steamclient_stub.cpp` (see below), then runs
under qemu-user with the toolchain sysroot:

```
qemu-aarch64-static -L toolchains/aarch64/.../sysroot tools/smoketest/dltest-aarch64 <artifact...>
```

Verified green for all 11 artifacts per arch: engine, filesystem_stdio,
HLTV core/demoplayer/director/proxy, metamod, cs.so, reunion, rehlmaster.

## Tier 2 — full server boot with real content

1. Get a stock HLDS install with cstrike content (x86 host is fine — the
   download runs natively):
   ```
   steamcmd +force_install_dir ~/hlds +login anonymous \
     +app_set_config 90 mod cstrike +app_update 90 validate +quit
   ```
2. Overlay `dist/<arch>/` onto it and run `bash apply-liblist.sh`.
3. Run under qemu-user with the toolchain sysroot and
   `STEAM_API_DLOPEN_FORCE=<path to steamclient_stub-<arch>.so>`.

Observed: engine init → Metamod-r → ReUnion → ReGameDLL CS 5.30 → de_dust2
spawn (BSP + WADs opened, syscall trace shows thousands of frames) → frame
loop polling the UDP game socket.

**Both arches answer `getchallenge` over UDP** with a proper
`S2C_CHALLENGE` (`A00000000 <challenge> 2`) — the full
recvfrom → parse → dispatch → sendto path works.

Note: map spawn under qemu-user is slow (minutes, not seconds); the server
is silent during spawn and prints nothing until done.

## The steamclient.so problem

Source-style queries (`A2S_INFO 'T'`, players, rules) are answered by
**Valve's steamclient.so**, not the engine — `SV_ConnectionlessPacket()`
explicitly skips them.  Valve's aarch64 steamclient.so refuses to run
under qemu-user: it checks `futex robust_list` registration and dies
(`Fatal error: futex robust_list not initialized by pthreads`).  That is
an emulator limitation, not a port bug; on real ARM hardware the real
steamclient.so is expected to work (the goldsrc-net aarch64 drop-in
verified VAC engagement on real silicon).

For emulation, `tools/smoketest/steamclient_stub.cpp` implements a minimal
SteamClient012 backend matching the vendored (1.34-era) Steamworks SDK in
ReHLDS: the exact call sequence `libsteam_api`'s `SteamGameServer_Init`
performs (SetLocalIPBinding → CreateLocalUser → GetISteam* →
InitGameServer), plus the callback-poll exports.  Steam auth is stubbed
(`BSecure() == false`), which is fine for LAN/local testing.

If you want the desktop-lib closure Valve's steamclient.so needs under
qemu (X11/GL/pulse/glib/systemd/gnutls/alsa/FLAC…), 
`tools/smoketest/fetch-arm64-deblibs.sh` pulls the Debian bookworm arm64
packages into a supplemental `LD_LIBRARY_PATH` dir and removes the
libc-family libraries so the toolchain sysroot keeps precedence.

## Known qemu-user artifacts (not port bugs)

- `qemu: uncaught target signal 11` during FATAL-error shutdown — the
  breakpad crash handler interacting with qemu-user; the server already
  printed its error and was exiting.
- `IPC function call IClientUtils::GetSteamRealm took too long` —
  steamclient IPC watchdog under emulation (real steamclient only).
- ReHLDS's real steamclient.so loading requires the desktop-lib closure
  above; without it `libsteam_api` falls back through its probe list and
  `SteamGameServer_Init` fails → `Unable to initialize Steam` → clean
  FATAL (use the stub in emulation, or `-nomaster`+`sv_lan 1` on hardware
  for LAN play without Steam).

## Not verified under emulation

- real Steam auth / VAC (needs Valve's steamclient.so on real hardware)
- A2S_INFO/players/rules replies (same)
- long-run stability and performance (needs real ARM hardware)

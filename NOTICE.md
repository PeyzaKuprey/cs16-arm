# NOTICE — upstream sources and pinned revisions

This repository does not vendor upstream source.  `scripts/fetch-sources.sh`
clones each project at the exact revision below, creates an `arm` branch and
applies the matching patchset from `patches/`.

| Project | Upstream | Pinned SHA | License |
|---|---|---|---|
| ReHLDS | https://github.com/goldsrc-net/ReHLDS.git | `12d78baf470f6c208d5652cc4e230bf82ee24748` | GPL-3.0 (LGPL parts) — confirm in tree |
| Metamod-R | https://github.com/goldsrc-net/Metamod-R.git | `b2ea6fb08e5ba5c70b19f82b7cf9e8d7b7b76c13` | GPL-3.0 |
| ReGameDLL_CS | https://github.com/s1lentq/ReGameDLL_CS | `1f16a7f25c14225931f8df1abc51f68d18ded839` | GPL-3.0 |
| ReUnion | https://github.com/rehlds/ReUnion | `df6ccc9747b0bf98225856380776371d559c1d93` | LGPL-3.0 |
| rehlmaster | https://github.com/anzz1/rehlmaster | `8fe006b40d4e30f0634fc80aa8011a0d9aa6b308` | MIT |

ReHLDS/Metamod-R/ReGameDLL_CS line forks track the goldsrc-net `64bit`
branch — the 64-bit-clean port line those projects maintain; our patchset
extends the same approach to 32-bit ARM.

Toolchains: Bootlin glibc stable-2021.11-1 (gcc 10.3.0, binutils 2.36.1,
glibc 2.34) for armv7-eabihf and aarch64, fetched by
`scripts/fetch-toolchains.sh` from toolchains.bootlin.com (each unpacks
with its own README/license copies).

Also not included here: anything from Valve Corporation — HLDS install
base, cstrike game content, steamclient.so.  Obtain those through your own
steamcmd install.

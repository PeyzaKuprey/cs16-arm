# Auxiliary projects

Two more projects live in the author's workspace alongside the port.  One
is integrated here, the other is out of scope — documented for completeness.

## hlmaster — integrated (built for both arches)

https://github.com/anzz1/hlmaster @ `9e41a4e` — a minimal GoldSrc master
server in ~470 lines of C: plain UDP, no external deps, byte-swap
hand-rolled (no arch-specific code — compiles as-is on ARM).

Fetched by `scripts/fetch-sources.sh`, built by `build/build-*.sh` into
`build/hlmaster-<arch>/hlmaster` (standalone binary; UDP :27010, 13MB RAM
at default limits).  Pair it with the rehlmaster metamod plugin's
`sv_master1..5` cvars to list ARM servers on your own master.

Note: the upstream repo carries no LICENSE file at the pinned SHA — treat
redistribution accordingly (we only fetch + compile it, same as the other
pinned upstreams).

## cs16-stats — out of scope (not part of this repo)

A Python server-census/statistics toolkit living in the author's workspace
(`src/cs16-stats/` in the dev tree): A2S crawling, discovery, geolocation,
dashboard export.  Pure Python, arch-neutral, has its own repo and
README — nothing to port, nothing to build here.  It consumed the ARM
servers' query responses during testing (the `getchallenge` checks
mirrored its probe logic).

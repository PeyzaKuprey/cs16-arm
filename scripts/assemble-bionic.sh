#!/bin/bash
# assemble-dropin.sh — collect built artifacts into deploy-ready drop-in
# overlays (dist/<arch>/) and zip them.  Run after build-armv7.sh and
# build-aarch64.sh (and scripts/fetch-sources.sh, for the config templates).
#
# Usage:  bash scripts/assemble-dropin.sh [armv7|aarch64]   (default: both)
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=$ROOT/src

assemble() {
  local arch=$1
  local B=$ROOT/build/rehlds-bionic-$arch/rehlds
  local D=$ROOT/dist-bionic/$arch
  # the libsteam_api shim is produced into the source tree (cmake output dir)
  local LIB=$SRC/buildchain/ReHLDS/rehlds/lib/$( [ $arch = aarch64 ] && echo linuxarm64 || echo linuxarm32 )

  echo "== assembling dist-bionic/$arch"
  rm -rf "$D"
  mkdir -p "$D"/cstrike/{dlls,addons/metamod/dlls,addons/reunion/dlls}

  # engine + HLTV at the overlay root (same layout as the reference drop-in)
  cp "$B/engine_i486.so"                      "$D/"
  cp "$B/filesystem/FileSystem_Stdio/filesystem_stdio.so" "$D/filesystem_stdio.so"
  cp "$B/dedicated/hlds_linux"                "$D/"
  cp "$B/HLTV/Console/hltv"                   "$D/"
  cp "$B/HLTV/Core/core.so"                   "$D/"
  cp "$B/HLTV/DemoPlayer/demoplayer.so"       "$D/"
  cp "$B/HLTV/Director/director.so"           "$D/"
  cp "$B/HLTV/Proxy/proxy.so"                 "$D/"
  cp "$LIB/libsteam_api.so"                   "$D/"

  # gamedll + plugins under cstrike/
  cp "$ROOT/build/regamedll-bionic-$arch/regamedll/cs.so"                    "$D/cstrike/dlls/"
  cp "$ROOT/build/metamod-bionic-$arch/metamod/metamod_$arch.so"             "$D/cstrike/addons/metamod/dlls/"
  cp "$ROOT/build/reunion-bionic-$arch/reunion_mm_$arch.so"                  "$D/cstrike/addons/reunion/dlls/"
  cp "$ROOT/build/rehlmaster-bionic-$arch/rehlmaster.so"                     "$D/cstrike/addons/metamod/dlls/"

  # configs (templates from the source trees)
  cp "$SRC/buildchain/Metamod-R/metamod/extra/config.ini"             "$D/cstrike/addons/metamod/"
  cp "$SRC/ReUnion/reunion/dist/reunion.cfg"                          "$D/cstrike/addons/reunion/"

  # metamod plugin list: reunion + rehlmaster wired
  printf 'linux addons/reunion/dlls/reunion_mm_%s.so\nlinux addons/metamod/dlls/rehlmaster.so\n' "$arch" \
    > "$D/cstrike/addons/metamod/plugins.ini"

  # liblist.gam patcher + README
  cat > "$D/apply-liblist.sh" <<EOF
#!/usr/bin/env bash
# apply-liblist.sh — point cstrike/liblist.gam at metamod-r as the gamedll.
# Run from your HLDS install dir after extracting this overlay.  Idempotent.
set -euo pipefail
lib="\${1:-cstrike/liblist.gam}"
val="addons/metamod/dlls/metamod_$arch.so"
if [ ! -f "\$lib" ]; then
  echo "error: \$lib not found.  Run from your HLDS install dir."
  exit 1
fi
if grep -q '^gamedll_linux ' "\$lib"; then
  sed -i.bak "s|^gamedll_linux .*|gamedll_linux \"\$val\"|" "\$lib"
else
  printf 'gamedll_linux "%s"\n' "\$val" >> "\$lib"
fi
echo "set gamedll_linux \"\$val\" in \$lib"
EOF
  chmod +x "$D/apply-liblist.sh"

  if [ -f "$ROOT/docs/README-dropin-template.md" ]; then
    sed "s/<arch>/$arch/g" "$ROOT/docs/README-dropin-template.md" > "$D/README-dropin.md"
  fi

  echo "== zipping hlds-dropin-cs16-$arch.zip"
  python3 - "$D" "$ROOT/dist-bionic/hlds-dropin-cs16-bionic-$arch.zip" "$arch" <<'EOF'
import zipfile, os, sys
src, out, arch = sys.argv[1], sys.argv[2], sys.argv[3]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, src))
print("   ->", out, os.path.getsize(out), "bytes")
EOF
}

for arch in ${@:-armv7 aarch64}; do
  assemble "$arch"
done
echo "done"

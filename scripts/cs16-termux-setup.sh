#!/data/data/com.termux/files/usr/bin/bash
# cs16-termux-setup.sh — the only file you need in Termux.
# It detects the CPU, downloads the matching Bionic overlay from the release,
# extracts it into ~/hlds, configures Metamod/ReUnion and starts the server.
#
# Run:  bash cs16-termux-setup.sh
# Optional: CS16_NO_START=1 bash cs16-termux-setup.sh   (setup without start)
set -eu

TAG=${CS16_TAG:-v1.0.4-bionic}
BASE=${CS16_BASE:-https://github.com/PeyzaKuprey/cs16-arm/releases/download/$TAG}
DEST=${CS16_HOME:-$HOME/hlds}
MAP=${CS16_MAP:-de_dust2}
PORT=${CS16_PORT:-27015}
MAXP=${CS16_MAXPLAYERS:-16}

say() { printf '%s\n' "$*"; }

need() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  say "Termux: installing $1"
  pkg install -y "$1"
}

need curl
need unzip

UNAME_M=$(uname -m)
case "$UNAME_M" in
  aarch64|arm64|armv8l)
    ARCH=aarch64
    ;;
  armv7l|armv6l|arm)
    ARCH=armv7
    ;;
  *)
    # Android emulators may report the host CPU while still listing an ARM ABI.
    ABI=$(getprop ro.product.cpu.abilist 2>/dev/null || true)
    case "$ABI" in
      *arm64-v8a*) ARCH=aarch64 ;;
      *armeabi-v7a*) ARCH=armv7 ;;
      *)
        say "unsupported CPU: $UNAME_M (ABI: $ABI)"
        exit 1
        ;;
    esac
    ;;
esac

URL="$BASE/hlds-dropin-cs16-bionic-$ARCH.zip"
ZIP="$DEST/hlds-dropin-$ARCH.zip"
say "CPU: $(uname -m) -> overlay: $ARCH"
say "downloading: $URL"
mkdir -p "$DEST"
curl -fL --retry 3 -o "$ZIP" "$URL"

say "extracting into $DEST"
cd "$DEST"
unzip -o "$ZIP"
bash apply-liblist.sh

say "done. Server directory: $DEST"
say "put your cstrike/ and valve/ game data there if not present yet."
if [ "${CS16_NO_START:-0}" = 1 ]; then
  say "CS16_NO_START=1 — not starting the server."
  exit 0
fi

say "starting: $MAP on port $PORT"
cd "$DEST"
LD_LIBRARY_PATH=$PWD ./hlds_linux -console -game cstrike -nosteam \
  +map "$MAP" +maxplayers "$MAXP" -port "$PORT" +sv_lan 1

#!/bin/bash
# start-kali.sh — one-shot Kali rootfs bootstrap + login for Binder/code-server
set -e

BIN="$HOME/bin"
KALI="$HOME/kali"
PROOT="$BIN/proot"
URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-amd64.tar.xz"
# Fallback: tiny Alpine rootfs (~3MB) if Kali xz still OOMs
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-minirootfs-3.20.3-x86_64.tar.gz"
MEMLIMIT="${MEMLIMIT:-256MiB}"

export PATH="$BIN:$PATH"

# 1. proot (static) — skip if present
if [ ! -x "$PROOT" ]; then
  echo "[*] fetching proot..."
  mkdir -p "$BIN"
  curl -L -o "$PROOT" https://proot.gitlab.io/proot/bin/proot \
    || curl -L -o "$PROOT" https://github.com/proot-me/proot/releases/download/v5.4.0/proot-v5.4.0-x86_64-static
  chmod +x "$PROOT"
fi

# RAM gate — a kernel OOM kill is SIGKILL(9): uncatchable, so we MUST decide
# BEFORE attempting the xz extract. Need ~1.5GB available to be safe.
MIN_MB="${MIN_MB:-1500}"
AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "${KALI_FALLBACK:-}" != "alpine" ] && [ "$AVAIL_MB" -lt "$MIN_MB" ]; then
  echo "[!] low RAM: ${AVAIL_MB}MB available (< ${MIN_MB}MB) — Kali xz extract would OOM-kill."
  echo "[!] auto-selecting Alpine minirootfs to keep the terminal alive."
  KALI_FALLBACK=alpine
fi

# 2. rootfs — skip if already extracted (kali-* or alpine-* dir)
ROOTFS=$(ls -d "$KALI"/kali-*-rootfs "$KALI"/rootfs 2>/dev/null | head -n1 || true)
if [ -z "$ROOTFS" ]; then
  mkdir -p "$KALI" && cd "$KALI"
  if [ "${KALI_FALLBACK:-}" = "alpine" ]; then
    echo "[*] fetching Alpine minirootfs (ultra low-RAM fallback)..."
    mkdir -p "$KALI/rootfs"
    # gzip streams with negligible RAM; no tarball stored on disk
    curl -L "$ALPINE_URL" | tar -xz -C "$KALI/rootfs"
    ROOTFS="$KALI/rootfs"
  else
    echo "[*] fetching + streaming-extracting Kali rootfs (memlimit=$MEMLIMIT)..."
    # Stream: never store the 100MB+ tarball; cap xz decompressor RAM.
    # If xz can't fit the dictionary in $MEMLIMIT it exits non-zero -> auto Alpine fallback.
    if ! curl -L "$URL" | xz -d -c --memlimit-decompress="$MEMLIMIT" | tar -x; then
      echo "[!] Kali extract failed under $MEMLIMIT — falling back to Alpine..."
      mkdir -p "$KALI/rootfs"
      curl -L "$ALPINE_URL" | tar -xz -C "$KALI/rootfs"
      ROOTFS="$KALI/rootfs"
    else
      ROOTFS=$(ls -d "$KALI"/kali-*-rootfs | head -n1)
    fi
  fi
fi

# 3. enter Kali as fake-root
echo "[*] entering Kali ($ROOTFS)"
exec "$PROOT" -0 -r "$ROOTFS" \
  -b /proc -b /sys -b /dev -b /etc/resolv.conf \
  -w /root /bin/bash

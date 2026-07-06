#!/bin/bash
# start-kali.sh — one-shot Kali rootfs bootstrap + login for Binder/code-server
set -e

BIN="$HOME/bin"
KALI="$HOME/kali"
PROOT="$BIN/proot"
URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-full-amd64.tar.xz"

export PATH="$BIN:$PATH"

# 1. proot (static) — skip if present
if [ ! -x "$PROOT" ]; then
  echo "[*] fetching proot..."
  mkdir -p "$BIN"
  curl -L -o "$PROOT" https://proot.gitlab.io/proot/bin/proot \
    || curl -L -o "$PROOT" https://github.com/proot-me/proot/releases/download/v5.4.0/proot-v5.4.0-x86_64-static
  chmod +x "$PROOT"
fi

# 2. rootfs — skip if already extracted
ROOTFS=$(ls -d "$KALI"/kali-*-rootfs 2>/dev/null | head -n1 || true)
if [ -z "$ROOTFS" ]; then
  echo "[*] fetching Kali rootfs (one-time this session)..."
  mkdir -p "$KALI" && cd "$KALI"
  curl -L -o kali.tar.xz "$URL"
  echo "[*] extracting..."
  tar -xJf kali.tar.xz && rm -f kali.tar.xz
  ROOTFS=$(ls -d "$KALI"/kali-*-rootfs | head -n1)
fi

# 3. enter Kali as fake-root
echo "[*] entering Kali ($ROOTFS)"
exec "$PROOT" -0 -r "$ROOTFS" \
  -b /proc -b /sys -b /dev -b /etc/resolv.conf \
  -w /root /bin/bash

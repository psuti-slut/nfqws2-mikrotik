#!/bin/sh
set -e

# install nfqws2
if [ ! -d /opt/zapret2 ]; then
  echo "Installing NFQWS2"
  sleep 1
  cd /opt
  RELEASE_URL=$(
      wget -qO- https://api.github.com/repos/bol-van/zapret2/releases/latest |
      grep '"browser_download_url"' |
      grep -E 'zapret2-v[0-9.]+\.zip"' |
      sed -E 's/.*"browser_download_url": *"([^"]+)".*/\1/' |
      head -n 1
    )
  [ -n "$RELEASE_URL" ] || { echo "Failed to get release URL"; exit 1; }
  FILE_NAME=$(basename "$RELEASE_URL")
  wget -O "$FILE_NAME" "$RELEASE_URL"
  ZIP_FILE=$(ls zapret2-v*.zip | head -n 1)
  unzip "$ZIP_FILE" > /dev/null 2>&1
  EXTRACTED_DIR=$(unzip -l "$ZIP_FILE" | awk '{print $4}' | grep '/$' | head -n 1 | cut -d/ -f1)
  rm -rf "$ZIP_FILE"
  mv "$EXTRACTED_DIR" zapret2
  cd zapret2
  chmod +x *.sh
  ./install_bin.sh
  BIN_DIR="/opt/zapret2/binaries"
  LINK="/opt/zapret2/nfq2/nfqws2"
  TARGET=$(readlink "$LINK")
  KEEP_DIR=$(basename "$(dirname "$TARGET")")
  echo "Keeping binaries directory: $KEEP_DIR"
  cd "$BIN_DIR"
  for dir in *; do \
      [ "$dir" = "$KEEP_DIR" ] && continue; \
      [ -d "$dir" ] || continue; \
      echo "Removing unused binaries: $dir"; \
      rm -rf "$dir"; \
  done
fi

# set default config
if [ ! -f /opt/zapret2/config ]; then
    echo "Set default config NFQWS2"
    cp /opt/zapret2/config.default /opt/zapret2/config
    sed -i 's/^NFQWS2_ENABLE=.*/NFQWS2_ENABLE=1/' /opt/zapret2/config
    sed -i 's/^[#]*FWTYPE=.*/FWTYPE=nftables/' /opt/zapret2/config
fi

nft add table ip nat
nft add chain ip nat postrouting { type nat hook postrouting priority 100 \; }
nft add rule ip nat postrouting masquerade

if [ $# -gt 0 ]; then
  exec "$@"
else
  echo "NFQWS2 $(/opt/zapret2/nfq2/nfqws2 --version)"
  /opt/zapret2/init.d/sysv/zapret2 start
  exec sleep infinity
fi

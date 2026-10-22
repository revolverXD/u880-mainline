#!/bin/bash
# Download and unpack Valve's native Linux ARM64 Steam client packages (manifest steam_client_linuxarm64, list in arm64-packages.txt: name|file|sha256) into $D. Run on the tablet.
set -u
D=${D:-/home/USER/steam-arm}; mkdir -p $D/pkgs $D/root; cd $D/pkgs
while IFS='|' read -r name file sha; do
  [ -f $file ] || curl -sfL -o $file https://client-update.steamstatic.com/$file || { echo "DL-FAIL $name"; continue; }
  echo "$sha  $file" | sha256sum -c --quiet - || { echo "SHA-FAIL $name"; continue; }
  unzip -qo $file -d $D/root && echo "ok $name"
done < "${1:-/root/arm64-packages.txt}"
echo FETCH-DONE

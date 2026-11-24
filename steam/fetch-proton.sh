#!/bin/bash
# Download ARM64 Proton builds from GitHub releases, verify sha512, unpack into Steam's compatibilitytools.d. Run on the tablet as the user.
set -u
CT=/home/USER/.local/share/Steam/compatibilitytools.d; mkdir -p $CT /home/USER/proton-dl; cd /home/USER/proton-dl
get() { # repo tag basename
  local url=https://github.com/$1/releases/download/$2/$3
  curl -sfL -o $3-aarch64.tar.gz $url-aarch64.tar.gz && curl -sfL -o $3-aarch64.sha512sum $url-aarch64.sha512sum || { echo "DL-FAIL $3"; return; }
  sha512sum -c --quiet $3-aarch64.sha512sum && tar -xzf $3-aarch64.tar.gz -C $CT && echo "ok $3" || echo "SHA-FAIL $3"
}
get Droid-Deck/DroidDeck-Proton DroidDeck-Proton-11-12.8 DroidDeck-Proton-11-12.8
get GloriousEggroll/proton-ge-custom GE-Proton11-14 GE-Proton11-14
ls $CT; echo PROTON-DONE

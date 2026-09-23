#!/usr/bin/env bash
# Brings an official FreeSWITCH sound package into the tree as the 48 kHz
# master of its voice (or of the music): downloads it from
# files.freeswitch.org, checks the published sha256, and puts the files under
# freeswitch/<lang>/<region>/<voice>/<category>/48000/ (music/48000/), the
# way kazoo-configs-freeswitch's lang/*.xml name them (the package may spell
# the region differently: ru/RU → ru/ru). Any other rate directory of the
# same voice is dropped: the build (hack/build-release.sh) makes the rates
# with sox from the masters in the tree, never from the network.
#
# Usage: hack/import-freeswitch-sounds.sh <package> <version> [<dest>]
#   e.g. hack/import-freeswitch-sounds.sh en-us-allison 1.0.2
#        hack/import-freeswitch-sounds.sh ru-RU-elena 1.0.51 ru/ru/elena
#        hack/import-freeswitch-sounds.sh music 1.0.52
# Then review `git status` and commit with the package and version named.
set -euo pipefail
PKG=${1:?package (en-us-callie, en-us-allison, fr-ca-june, ru-RU-elena, music, ...)}
VERSION=${2:?version}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MIRROR=${MIRROR:-https://files.freeswitch.org/releases/sounds}
RATE=48000
f="freeswitch-sounds-${PKG}-${RATE}-${VERSION}.tar.gz"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
echo "fetching $f"
curl -fsSL -o "$tmp/$f" "$MIRROR/$f"
sha=$(curl -fsSL "$MIRROR/$f.sha256" | awk '{print $NF}')
echo "$sha  $tmp/$f" | sha256sum -c - >/dev/null
mkdir -p "$tmp/x" && tar xzf "$tmp/$f" -C "$tmp/x"
# the package's own top path: en/us/callie or music
src=$(cd "$tmp/x" && find . -type f -name '*.wav' -print -quit | cut -d/ -f2- | sed -E "s|/[^/]+/${RATE}/[^/]+$||")
[ "$PKG" = music ] && src=music
dest=${3:-$(echo "$src" | tr 'A-Z' 'a-z')}
target="$ROOT/freeswitch/$dest"
echo "$PKG $VERSION: $src → freeswitch/$dest"
# every other rate directory of this voice goes: the 48 kHz files are the masters
mkdir -p "$target"
find "$target" -type d -name '[0-9][0-9][0-9][0-9]*' | while read -r d; do rm -rf "$d"; done   # 8000, 16000, ... (no -regex: BSD find)
cp -a "$tmp/x/$src/." "$target/"
n=$(find "$target" -path "*/${RATE}/*.wav" | wc -l | tr -d ' ')
echo "freeswitch/$dest: $n masters at ${RATE} Hz ($(find "$target" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') categories)"

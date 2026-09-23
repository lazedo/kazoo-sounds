#!/usr/bin/env bash
# Builds the release tarball kazoo-sounds-<tag>.tar.gz from the tree alone:
#   freeswitch/  every sound at 8000, 16000, 32000 and 48000 — the way
#                FreeSWITCH's own sound packages are built (the spec files
#                run sox from the 48 kHz masters). The masters are what the
#                tree holds: the highest rate directory of each category —
#                48000/ for the voices brought in from the official packages
#                (hack/import-freeswitch-sounds.sh) and the music, whatever
#                the others have. Everything that is not a sound under a
#                rate directory (prompts.xml, sounds without one) is kept as
#                is. No network.
#   kazoo-core/  verbatim: the system_media prompts kazoo imports.
# Needs bash, tar, sox (soxi), sha256sum. Output under $OUT (./build).
set -euo pipefail
TAG=${1:?usage: $0 <tag>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$ROOT/build}
RATES="8000 16000 32000 48000"
DIST=$OUT/kazoo-sounds-$TAG
MASTERS=$ROOT/freeswitch
rm -rf "$DIST"
mkdir -p "$DIST"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }

# the tree as is, then every rate directory rebuilt from its masters
mkdir -p "$DIST/freeswitch"
cp -a "$MASTERS/." "$DIST/freeswitch/"
n=0
# a category is a directory that holds rate directories, or sounds of its own
find "$MASTERS" -type f -name '*.wav' | while read -r f; do
    d=$(dirname "$f")
    case "$(basename "$d")" in
        *[!0-9]*) echo "$d" ;;      # sounds of its own
        *) dirname "$d" ;;          # a rate directory: its parent
    esac
done | sort -u | while read -r cat; do
    rel=${cat#"$MASTERS/"}
    # masters: the highest rate directory, else the category's own sounds
    top=$(find "$cat" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9]*' | sed -E 's|.*/||' | sort -n | tail -1)
    if [ -n "$top" ]; then srcdir="$cat/$top"; else srcdir="$cat"; fi
    for r in $RATES; do rm -rf "$DIST/freeswitch/$rel/$r"; mkdir -p "$DIST/freeswitch/$rel/$r"; done
    for f in "$srcdir"/*.wav; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        if ! have=$(soxi -r "$f" 2>/dev/null); then log "skipping unreadable $f"; continue; fi
        for r in $RATES; do
            if [ "$have" = "$r" ]; then
                cp "$f" "$DIST/freeswitch/$rel/$r/$name"
            else
                sox -V1 "$f" -r "$r" -c 1 -b 16 -e signed-integer "$DIST/freeswitch/$rel/$r/$name" rate -v
            fi
        done
    done
    n=$((n + 1))
    if [ $((n % 25)) -eq 0 ]; then log "$n categories done ($rel)"; fi
done

cp -a "$ROOT/kazoo-core" "$DIST/"
cp "$ROOT/README.md" "$DIST/"
for r in $RATES; do
    log "freeswitch/*/$r: $(find "$DIST/freeswitch" -path "*/$r/*.wav" | wc -l | tr -d ' ') sounds"
done
log "kazoo-core: $(find "$DIST/kazoo-core" -type f | wc -l | tr -d ' ') files"
tar czf "$OUT/kazoo-sounds-$TAG.tar.gz" -C "$OUT" "kazoo-sounds-$TAG"
sha256sum "$OUT/kazoo-sounds-$TAG.tar.gz" | tee "$OUT/kazoo-sounds-$TAG.tar.gz.sha256"
log "built $OUT/kazoo-sounds-$TAG.tar.gz ($(du -h "$OUT/kazoo-sounds-$TAG.tar.gz" | cut -f1))"

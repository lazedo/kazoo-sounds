#!/usr/bin/env bash
# Builds the release tarball kazoo-sounds-<tag>.tar.gz:
#   freeswitch/  every voice at 8000, 16000, 32000 and 48000 — the way
#                FreeSWITCH's own sound packages are built (sox from the
#                48 kHz masters, see freeswitch-sounds-*.spec upstream). The
#                masters are the official packages freeswitch/sources.txt
#                lists, else the repo's own files (whatever rate they are).
#                Everything that is not a sound under a rate directory
#                (prompts.xml, sounds without a rate directory) is kept as is.
#   kazoo-core/  verbatim: the system_media prompts kazoo imports.
# Needs bash, curl, tar, sox (soxi), sha256sum. Output under $OUT (./build).
set -euo pipefail
TAG=${1:?usage: $0 <tag>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-$ROOT/build}
RATES="8000 16000 32000 48000"
MIRROR=${MIRROR:-https://files.freeswitch.org/releases/sounds}
WORK=$OUT/work
DIST=$OUT/kazoo-sounds-$TAG
rm -rf "$WORK" "$DIST"
mkdir -p "$WORK/pkg" "$WORK/masters" "$DIST"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }

# masters: the repo's freeswitch/ tree...
cp -a "$ROOT/freeswitch/." "$WORK/masters/"
rm -f "$WORK/masters/sources.txt"
# ...with the official packages on top of it
while read -r pkg version dest sha; do
    case "$pkg" in ''|'#'*) continue ;; esac
    f="freeswitch-sounds-$pkg-48000-$version.tar.gz"
    log "fetching $f"
    curl -fsSL -o "$WORK/pkg/$f" "$MIRROR/$f"
    echo "$sha  $WORK/pkg/$f" | sha256sum -c - >/dev/null
    x="$WORK/pkg/x-$pkg"
    rm -rf "$x" && mkdir -p "$x"
    tar xzf "$WORK/pkg/$f" -C "$x"
    # -quit, not head: under pipefail a closed pipe would fail the build (SIGPIPE)
    src=$(cd "$x" && find . -type f -name '*.wav' -print -quit | cut -d/ -f2-4)
    [ -n "$src" ] || { echo "no sounds in $f" >&2; exit 1; }
    rm -rf "$WORK/masters/$dest"
    mkdir -p "$WORK/masters/$dest"
    cp -a "$x/$src/." "$WORK/masters/$dest/"
    log "$pkg $version → freeswitch/$dest ($(find "$WORK/masters/$dest" -name '*.wav' | wc -l | tr -d ' ') files)"
done < "$ROOT/freeswitch/sources.txt"

# the tree as is, then every rate directory rebuilt from its masters
mkdir -p "$DIST/freeswitch"
cp -a "$WORK/masters/." "$DIST/freeswitch/"
n=0
# a category is a directory that holds rate directories, or sounds of its own
find "$WORK/masters" -type f -name '*.wav' | while read -r f; do
    d=$(dirname "$f")
    case "$(basename "$d")" in
        *[!0-9]*) echo "$d" ;;      # sounds of its own
        *) dirname "$d" ;;          # a rate directory: its parent
    esac
done | sort -u | while read -r cat; do
    rel=${cat#"$WORK/masters/"}
    # masters: the highest rate directory, else the category's own sounds
    top=$(find "$cat" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9]+' | sed -E 's|.*/||' | sort -n | tail -1)
    if [ -n "$top" ]; then srcdir="$cat/$top"; else srcdir="$cat"; fi
    for r in $RATES; do rm -rf "$DIST/freeswitch/$rel/$r"; mkdir -p "$DIST/freeswitch/$rel/$r"; done
    for f in "$srcdir"/*.wav; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        # two "sounds" in the upstream tree are a 49-byte JSON error body
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

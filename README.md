# kazoo-sounds
The multilingual prompts used by KAZOO both on FreeSWITCH and in the core

## FreeSWITCH sounds at every sample rate (lazedo fork)

The `freeswitch/` tree holds the *masters* of each voice: the official
FreeSWITCH packages at 48 kHz for callie, allison, june (fr-ca), elena
(ru-ru) and the music, brought in with `hack/import-freeswitch-sounds.sh
<package> <version>` (download, published sha256 checked, files placed
under `<lang>/<region>/<voice>/<category>/48000/`, any other rate of that
voice dropped); the voices that only exist here keep the files they have.

Nothing is built here. The kazoo operator points at this repository
(`spec.media.sounds`: `url`, `ref` = branch, tag or commit, `rates`) and a
Job of its own fetches the tree at that ref and builds the sounds bucket:
`kazoo-core/` as is, and every category of `freeswitch/` at the requested
sample rates — 8000, 16000, 32000 and 48000 unless the spec says which —
made with sox from the category's master, the way the FreeSWITCH sound
packages themselves are built. Only the requested rates exist in the
bucket; FreeSWITCH's mod_sndfile opens `<category>/<channel rate>/<file>`
and finds it at the first probe, or falls back to the rates that are there.

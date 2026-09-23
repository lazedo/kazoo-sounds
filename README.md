# kazoo-sounds
The multilingual prompts used by KAZOO both on FreeSWITCH and in the core

## FreeSWITCH sounds at every sample rate (lazedo fork)

The `freeswitch/` tree holds the *masters* of each voice: the official
FreeSWITCH packages at 48 kHz for callie, allison, june (fr-ca), elena
(ru-ru) and the music, brought in with `hack/import-freeswitch-sounds.sh
<package> <version>` (download, published sha256 checked, files placed
under `<lang>/<region>/<voice>/<category>/48000/`, any other rate of that
voice dropped); the voices that only exist here keep the files they have.

A tag builds the release tarball `kazoo-sounds-<tag>.tar.gz`
(`hack/build-release.sh`, `.github/workflows/release.yml`): every sound at
8000, 16000, 32000 and 48000, made with sox from the masters — the way the
FreeSWITCH sound packages themselves are built — plus `kazoo-core/` as is.
No network at build time. The kazoo operator streams the asset into the
sounds bucket (`spec.media.sounds.tarball`); FreeSWITCH's mod_sndfile opens
`<category>/<channel rate>/<file>` and finds it at the first probe.

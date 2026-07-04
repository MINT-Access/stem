# MINT Access stem — Pre-Release Refinements

This document tracks small issues, wording improvements, and polish items to address before the next release tag. Items are added as they are noticed during development and should be reviewed and resolved before tagging the next version.

---

## To be triaged (noticed but not yet fully specified)

*(Add items here as they come up during development — move to a numbered section above once the fix is clear)*

---

## Resolved

### Items 1–2 resolved: demo/demo.html labels and "musical" framing

**Fixed:** Item 1 (per-app `primary_wav_label` fields replacing the generic
"Full narrative (recommended)" label on every app) and item 2 (replacing
"musical sonification" framing with precise, non-aesthetic language in
`demo_html.wl`'s header, intro section, and asteroids description) were
both already implemented by the time this v1.3.0 consolidation pass began
— confirmed by inspection of the shipped `demo_html.wl` (17
`primary_wav_label` entries, one per app; zero remaining "musical"
occurrences in the header/intro/asteroids text) rather than assumed. This
entry closes out the tracking for both, since neither had been formally
marked resolved despite being done.

### Item 3 resolved: demo_html.wl — images/ section

**Fixed:** Already implemented — the `images` entry's description mentions
the spectral colour-to-pitch mapping ("violet is the lowest pitch, red is
the highest") and the `scan_horizontal` pedagogical mode, a
`listening_guide_note` links to `images/LISTENING_GUIDE.md`, and the audio
label reads "Listen — Hilbert curve brightness scan (log scale)" exactly
as specified. Confirmed by inspection, not assumed.

### Item 4 resolved (kept as-is): demo.wl — scan_horizontal as a second images preset

**Decision:** `demo.wl` continues to run `images/` in `brightness` mode
only, per this item's own documented alternative. `scan_horizontal` remains
available via CLI and is covered by the recommended listening sequence in
`images/LISTENING_GUIDE.md`. Adding a second demo run would add runtime
without a commensurate benefit for the demo context specifically (as
opposed to the dedicated listening guide, where the pedagogical comparison
belongs).

### Items 6–7 resolved: dynamical/ demo_html.wl entry and full consolidation

**Fixed:** Already implemented — `demo_html.wl`'s `appMeta` has a complete
`dynamical` entry (title, description, listening guide, `sweep_audio.wav`
primary WAV, `sweep.gif`, CLI) positioned immediately after `lorenz` in
`$appOrder`; `docs/APPS.md` has a full `dynamical` entry with all config
keys and named presets; root `README.md` includes `dynamical` in the
repository layout, Quick Start, Projects section, and afplay examples.
Confirmed by inspection of all four locations, not assumed.

### Item 5 resolved: cellular/ note-holding enhancement

**Fixed:** `cellular/src/sonify.wl` now uses run-length articulation with relative threshold (default 15% — corrected here from this document's earlier "3%," which did not match the actual shipped `cellular/config.json` value). Stable periods produce sustained tones; population changes produce new notes. Both Game of Life and Rule 110 modes updated. EventLayer accent tones preserved. CSV gains `articulated` and `run_length` columns. Config keys added: `articulation_mode`, `articulation_threshold`, `articulation_threshold_abs`, `base_note_duration`.

**Note:** Implemented after the v1.2.0 tag; included in the v1.3.0 release notes and consolidation pass.

### Speech/audio mechanism consistency (v1.3.0, Part A)

**Fixed:** `signal/src/sonify.wl`'s `SpeakToBuffer` was the last app-audio
speech generator calling platform-native TTS (`say`/`espeak-ng`/PowerShell)
directly with no `SpeechSynthesize[]` attempt. It now follows the same
three-tier pattern already used by `images/`, `thermo/`, `montecarlo/`,
`dynamical/`, and `magnetic/`: `SpeechSynthesize[]` first, platform-native
TTS as fallback (old code preserved verbatim as `SpeakToBufferPlatform`),
silence if both fail. Also replaced an old upsample hack that only handled
an exact 2x sample-rate ratio with the general `ResampleLinear` used
elsewhere. Audited `pendulum/`, `lorenz/`, `asteroids/`, `cellular/`,
`quantum/`, `primes/`, and `relativity/`: none of them generate
audio-embedded speech at all (STEMSay console-only), so nothing to migrate
there. `stem-core/src/accessibility.wl`'s `STEMSay` was not touched.

### Item 8 resolved: docs/APPS.md — thermo/ entry

**Fixed:** Added a complete `## thermo` entry (four modes, all
`simulation.thermo.*` config keys, mode-prefixed output files, correctness
checks, paradigm note), sourced from `thermo/config.json` and
`thermo/src/model.wl`.

### Item 9 resolved: Root README.md — thermo/ entry

**Fixed:** Repository layout diagram, Quick Start CLI examples (all four
modes), a full Projects subsection, and afplay examples
(`distribution_audio.wav`, `cooling_audio.wav`) all added.

### Item 11 resolved: cellular/ note-holding — docs/APPS.md

**Fixed:** Added the four new `simulation.cellular.*` config keys
(`articulation_mode`, `articulation_threshold`, `articulation_threshold_abs`,
`base_note_duration`) to the `cellular/` entry in `docs/APPS.md`, sourced
from the actual `cellular/config.json` (the real default for
`articulation_threshold` is `0.15`, not the `0.03` this document previously
stated — see the correction on item 5, above). Also added the two output
files (`life_rpentomino_data.csv`, `rule110_data.csv`) the note-holding
enhancement produces, which were missing from the `docs/APPS.md` output
table entirely.

### Item 12 resolved: docs/APPS.md — montecarlo/ entry

**Fixed:** Added a complete `## montecarlo` entry (three modes, all
`simulation.montecarlo.*`/`sonification.montecarlo.*` config keys,
mode-prefixed output files, correctness checks, dual-paradigm note),
sourced from `montecarlo/config.json` and `montecarlo/src/model.wl`.

### Item 13 resolved: Root README.md — montecarlo/ entry

**Fixed:** Repository layout diagram, Quick Start CLI examples (all three
modes), a full Projects subsection (Ising model, Metropolis algorithm,
Onsager T_c, universality), and afplay examples (`sweep_audio.wav`,
`critical_audio.wav`) all added.

### Item 15 resolved: docs/APPS.md — magnetic/ entry

**Fixed:** Added a complete `## magnetic` entry (four modes, all
`simulation.magnetic.*` config keys, mode-prefixed output files,
correctness checks), sourced from `magnetic/config.json` and
`magnetic/src/model.wl`.

### Item 16 resolved: Root README.md — magnetic/ entry

**Fixed:** Repository layout diagram, Quick Start CLI examples (all four
modes), a full Projects subsection (Lorentz force, cyclotron frequency,
Van Allen belts, multi-particle chord), and afplay examples
(`mirror_audio.wav`, `cyclotron_audio.wav`) all added.

**Also fixed while updating root README.md/AGENTS.md (not separately
numbered above):** both documents' app counts were stale at "thirteen"/"13"/
"12" in various places; the actual count is **16** apps (confirmed by
listing app directories and cross-checked against `demo.wl`'s "16 unique
apps" run report), not the 17 this consolidation pass's brief assumed —
corrected throughout rather than propagated. Root `AGENTS.md` was also
missing `dynamical/` entirely from its per-project AGENTS list, repo
structure diagram, and "How to run"/"Tests" sections (a pre-existing gap
predating this pass, not one of the numbered items) — closed at the same
time since leaving a released app out of "the listing" while updating "the
listing" would be a strange result.

### Items 10, 14, 17 resolved: demo.wl and demo_html.wl — thermo/, montecarlo/, magnetic/

**Fixed:** The demo.wl side of all three items was already done in earlier
sessions (thermo, montecarlo, and magnetic were already present in
`$demoApps`, in that order, positioned after `quantum` and before `primes`
— confirmed by running each app's `--config-dump` cleanly and by a full
`demo.wl` run reporting 17/17 passes with 16 unique apps). The remaining
work — `demo_html.wl` — is now done: added `appMeta` entries for all
three apps and inserted them into `$appOrder` after `quantum`, before
`lorenz` (not "before primes" as this item's own text stated — the page's
listening order already has `primes` earlier, at position 5, ahead of
`quantum` at position 6; `demo.wl`'s *run* order and `demo_html.wl`'s
*page* order have never been identical, and the fix follows the page's
own established order rather than the run order). Also updated the
header/footer version strings (v1.2.0 → v1.3.0), the "thirteen" app-count
text (→ "sixteen"), and the "14 passes total" comment (→ "17 passes
total"). Ran `demo_html.wl`: all 16 apps report "OK — all outputs
present" with zero `[WARNING]` lines; the generated `demo/demo.html` has
16 correctly numbered sections (1–16) in the right order, verified by
grep and by rendering screenshots of the three new sections in a browser.

### v1.3.0 release notes and archival

**Fixed:** `RELEASE_NOTES_v1.3.0.md` written (thermo/, montecarlo/,
magnetic/ sections; speech-consistency and cellular note-holding
infrastructure sections; updated Getting Started with the montecarlo
quench crown jewel). `RELEASE_NOTES_v1.2.0.md` moved to
`docs/archive/RELEASE_NOTES_v1.2.0.md`, matching the v1.0.0/v1.1.0
archival pattern. Root README.md's version badge already pointed to
`RELEASE_NOTES_v1.3.0.md` from Part B, now valid since the file exists.

---

**v1.3.0 consolidation complete. Next consolidation target: v1.4.0.**

*Last updated: 2026-07-05*

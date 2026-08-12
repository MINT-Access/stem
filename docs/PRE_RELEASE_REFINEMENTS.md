# MINT Access stem — Pre-Release Refinements

This document tracks small issues, wording improvements, and polish items to address before the next release tag. Items are added as they are noticed during development and should be reviewed and resolved before tagging the next version.

---

## To be triaged (noticed but not yet fully specified)

*(Add items here as they come up during development — move to a numbered section above once the fix is clear)*

---

## Resolved

### v1.4.0 consolidation, Part C: release notes, archival, badge link — Fixed in v1.4.0

**Fixed:** `RELEASE_NOTES_v1.4.0.md` written in the same structure, tone,
and level of detail as `RELEASE_NOTES_v1.3.0.md` — an opening paragraph
situating the release, one prose subsection per new app (`hydrogen/`,
`bayes/`, `scattering/`, `resonance/`, `fluid/`, in demo listening order)
each covering the scientific concept with a real-world anchor, the
sonification approach, sensory listening guidance, and a runnable
`afplay` example, a new "What comes next" section documenting the
strategic pause, an updated three-command "Getting started" section
(demo runtime corrected to the actual measured 306.6 s / ~5 minutes for
22 passes / 21 unique apps, not the brief's guessed 12-15 minutes; crown
jewel set to `resonance/`'s galilean mode per spec), and an updated
Acknowledgements section thanking the broader Wolfram Language community.
`RELEASE_NOTES_v1.3.0.md` moved to `docs/archive/RELEASE_NOTES_v1.3.0.md`
via `git mv`, matching the v1.0.0/v1.1.0/v1.2.0 archival pattern. Root
`README.md`'s version badge already pointed to `RELEASE_NOTES_v1.4.0.md`
(set ahead of the file's existence back in Part A, the same "badge
updated ahead of the file" pattern the v1.3.0 pass used) and is now
valid; the inline body link ("See RELEASE_NOTES_v1.3.0.md for full app
descriptions...") still pointed at the now-archived v1.3.0 file and has
been updated to `RELEASE_NOTES_v1.4.0.md` to match.

**Consistent with Parts A and B:** this document uses **21** apps
throughout, not the "22" figure repeated in each part's own brief text —
the release notes' opening paragraph and "Getting started" section say
"twenty-one" apps / "all twenty-one apps," matching `docs/APPS.md`, root
`README.md`, `AGENTS.md`, `demo.wl`, and `demo_html.wl`, all already
corrected to this count in Parts A and B. Introducing "22" into the
public-facing release notes at this final step would have reopened the
exact inconsistency the last two passes closed.

### v1.4.0 consolidation, Part B: demo.wl and demo_html.wl for hydrogen/, scattering/, resonance/, fluid/ (bayes/ already done)

**Fixed:** Items 20 (hydrogen/), 26 (scattering/), 29 (resonance/), and 32
(fluid/) — the `demo.wl`/`demo_html.wl` integration left open by Part A.
Confirmed by inspection (not assumed) that `demo.wl`'s `$demoApps` already
contained `hydrogen` (spectrum mode, positioned after `quantum`, before
`thermo`), `resonance` (galilean mode, after `lagrange`, before `cellular`),
and `fluid` (karman mode, after `waves`, before `quantum`) from earlier
sessions — only `scattering` was actually still missing. Added a
`scattering` entry (discovery mode) to `$demoApps` immediately after
`magnetic`, before `primes` — honouring the "after magnetic/" half of this
item's own instruction literally (magnetic and primes are already
adjacent) rather than "before resonance/" (an alternate phrasing floated
in Part B's own brief), which is not achievable without moving `resonance`
seven positions earlier — the identical "before X" mismatch bayes/thermo/
montecarlo/magnetic/fluid/resonance's own build notes hit, resolved the
same way. Updated `demo.wl`'s header comment ("20 apps" -> "21 apps"),
`demo/README.md`'s generated app-count text ("20" -> "21"), the
hand-curated numbered listening-order list (inserted `scattering` as a
new item 9, ahead of `hydrogen`, on the reasoning that discovering the
nucleus narratively precedes explaining the atom built around it —
renumbering `hydrogen`..`cosmology` from 9-20 to 10-21), and the `afplay`
example list.

`demo_html.wl` had only `bayes` among the five v1.4.0 apps in its
`appMeta`/`$appOrder` (per item 23, already resolved) — `hydrogen`,
`scattering`, `resonance`, and `fluid` were still entirely missing. Added
full `appMeta` entries for all four (title, description, listening guide,
primary/secondary WAV labels, GIF, alt text, CLI, `listening_guide_note`
pointing to each app's `LISTENING_GUIDE.md`, matching the `bayes`/`images`
precedent), using the exact content this task's own brief specified,
adapted to this file's actual `secondary_wavs` schema (list of
`<|"file"->..., "label"->...|>` associations, not the brief's flat
parallel-list form) and given the mandatory `gif_static`/`gif_alt` keys
`GifFigure` requires (omitted from the brief's snippets). `$appOrder`
gained all four apps, each placed by the same rule used above: honour
whichever half of "after X, before Y" already holds true in this array,
insert immediately after X otherwise-adjacent app when Y does not. Three
of the four resolved to literal placements per the brief's own primary
instruction (`fluid` after `waves`/before `pendulum` — both hold here
directly; `resonance` after `lagrange`, landing before `images` since
`asteroids` already precedes `lagrange`; `hydrogen` after `quantum`,
landing before `thermo` since `primes` already precedes `quantum`), while
`scattering` needed the same "after magnetic" resolution as in `demo.wl`
(landing before `lorenz`, since `primes` already precedes `magnetic` in
this array). Also updated the header/footer version strings (v1.3.0 ->
v1.4.0), the "Seventeen"/"seventeen" app-count text (-> "Twenty-one"/
"twenty-one"), and the "19 passes total, 18 unique apps" summary comment
(-> "22 passes total, 21 unique apps").

Verified, not assumed: ran the full `demo.wl` (22/22 passes, 21 unique
apps, 306.6s total, including live asteroid data and the new `scattering`
run) and then `demo_html.wl` (21/21 sections "OK — all outputs present",
zero `[WARNING]` lines; the generated `demo/demo.html` has 21 correctly
numbered sections, 1-21, in the specified order, confirmed by grepping
both the nav list and the section headings — they match exactly).
Confirmed every secondary WAV/GIF referenced in the four new `appMeta`
entries actually exists in `demo/<app>/output/` (each app's own
`output/` directory already had all three of its modes' outputs from
earlier development sessions, which `demo.wl`'s copy step — copying
every file present in `<app>/output/`, not just the invoked mode's
"expected" list — carried into `demo/<app>/output/` even though `demo.wl`
itself only invokes one mode per app).

### v1.4.0 consolidation, Part A: docs for hydrogen/, bayes/, scattering/, resonance/, fluid/

**Fixed:** Items 18-19 (hydrogen/), 21-22 (bayes/), 24-25 (scattering/),
27-28 (resonance/), and 30-31 (fluid/) — `docs/APPS.md` and root
`README.md` entries for all five v1.4.0 apps. `docs/APPS.md` gained full
entries (all modes, config keys sourced from each app's actual
`config.json`, output filenames sourced from each app's `main.wl`) for
all five, positioned after `magnetic`. Root `README.md` gained: five
repository-layout lines; Quick Start CLI examples for all three modes of
each app; five Projects subsections (matched in length/level to the
existing subsections); nine `afplay` examples
(`spectrum_audio.wav`/`transitions_audio.wav` for hydrogen,
`coin_audio.wav`/`model_audio.wav` for bayes, `discovery_audio.wav` for
scattering, `galilean_audio.wav`/`kirkwood_audio.wav` for resonance,
`karman_audio.wav`/`strouhal_audio.wav` for fluid); and the version badge
bumped to 1.4.0, linking to `RELEASE_NOTES_v1.4.0.md` (not yet
created — Part C's job, same "badge updated ahead of the file" pattern
the v1.3.0 pass used).

Root `AGENTS.md` also updated (not separately numbered above, same
"leave the listing complete" precedent set by the v1.3.0 pass's
`dynamical/` fix): all five apps added to the per-project `AGENTS.md`
list, the repo-structure diagram, the "How to run" CLI block, and the
"Tests" block (all five ship a `tests/test_model.wl`). The "Sonification
paradigms" section was extended: `hydrogen` (`orbitals` mode) added to
the spatial-field-based group alongside `images`/`cosmology`, noting it
is the project's other quantum-mechanics app alongside `quantum`; `bayes`
(`coin`/`gaussian` modes) added to the spectral-synthesis-based group
alongside `thermo`, noted as the project's first statistics app reusing
`thermo`'s exact technique; `scattering` and `resonance` noted as joining
`lagrange`/`magnetic` in the orbital/celestial-mechanics group, `fluid`
as joining `waves` in the continuum-mechanics group; a note that
`resonance` is the first app to use two sonification paradigms in
different modes of the same app (event-based `galilean`, versus
spectral-synthesis-based `kirkwood`/`saturn`); and a note that `fluid`'s
vortex-particle-method wake model is an educational approximation, not a
CFD tool, with a future-enhancement pointer to a full FEM/Navier-Stokes
solve if runtime permits.

Per-app `README.md` files for all five were spot-checked against
`relativity/README.md` and `thermo/README.md` for structural parity
(physics section, mode descriptions with sensory listening language,
config-key table, output-filename table, `LISTENING_GUIDE.md` reference)
and found already complete — no changes needed. (No app `README.md` in
this repo links back to the root `README.md`; that is not an established
convention here, so none was added.)

**Correction, not assumed:** this brief's own text states "the project
now has 22 apps." Counting actual app directories (`ls -d */`, excluding
`stem-core/`, `config/`, `docs/`, and the gitignored `demo/`) gives
**21**, matching this brief's own itemised list (8 + 5 + 3 + 5 = 21), not
22. `docs/APPS.md`'s and root `README.md`'s app-count text now reads
"twenty-one"/"21" throughout, not "twenty-two"/"22" — the same kind of
stale-count correction the v1.3.0 pass made ("sixteen" -> the real count
of that pass). Items 20, 23, 26, 29, 32 (demo.wl/demo_html.wl
integration) remain open above — those are Part B; note that `demo.wl`
itself (inspected, not assumed) already contains entries for `hydrogen`,
`bayes`, `resonance`, and `fluid` from earlier sessions — only
`scattering` (item 26) is actually still missing from `demo.wl` itself,
though all five still need their `demo_html.wl` `appMeta` entries per
items 20/23/26/29/32's own text.

### Item 23 resolved: demo.wl and demo_html.wl — add bayes/

### Item 23 resolved: demo.wl and demo_html.wl — add bayes/

**Fixed:** `demo.wl`'s `$demoApps` array gained a `bayes` entry (coin mode,
defaults: theta_true=0.7, 100 flips — no CLI overrides needed since the
demo preset matches `bayes/config.json`'s own defaults exactly), inserted
between `primes` and `images` per this item's instruction (the array's
`primes` entry is already immediately followed by `images`, so no
reordering conflict here, unlike the demo_html.wl case below). Header
comment, demo/README.md's app count ("17" -> "18 STEM apps"), the
numbered listening-order list, and the afplay examples list were all
updated; the listening-order list and afplay list place `bayes` right
after `primes` (position 6, renumbering `quantum`..`cosmology` from
6-17 to 7-18) since that list has always been a separate hand-curated
narrative order from the run-order array, not identical to it.

`demo_html.wl`'s `$appOrder` gained `"bayes"` positioned after
`"primes"` and before `"quantum"` — **not** "before images" as this
item's own text stated. The page's listening order already has
`primes` at position 5 immediately followed by `quantum` at position 6,
with `images` much later at position 14 (seven apps further along);
following the page's own established order (the same resolution
`demo.wl`/`demo_html.wl`'s items 10/14/17 for thermo/montecarlo/magnetic
used for an identical "before X" mismatch) keeps the
primes-(number theory) -> bayes-(probability) -> quantum-(physics)
domain-shift the original build note intended, without uprooting bayes
from primes by seven apps. A full `appMeta` entry was added (title,
description, listening guide, primary WAV label, `coin.gif`, secondary
WAVs `gaussian_audio.wav`/`model_audio.wav`, `listening_guide_note`
pointing to `bayes/LISTENING_GUIDE.md`, matching the `images` entry's
precedent for apps with a dedicated listening guide). Header/intro
app-count text updated "Sixteen"/"sixteen" -> "Seventeen"/"seventeen"
(this file's own `$appOrder` count, which still does not include
`hydrogen` — that remains a separate, still-open gap, item 20 above,
not touched by this fix) and the summary footer's pass-count comment
updated to "19 passes total, 18 unique apps" (matching `demo.wl`'s
actual current totals).

Verified, not assumed: ran the full `demo.wl` (19/19 passes, 18 unique
apps, 275.1s total) and then `demo_html.wl` (17/17 sections "OK — all
outputs present", zero `[WARNING]` lines, generated `demo/demo.html`
with `bayes` correctly numbered "6." in both the nav list and its own
section, all four of its audio/GIF references resolving to real files).

**Note:** Items 21 (docs/APPS.md) and 22 (root README.md) for bayes/
remain open above — this item covered only the demo integration.

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

**v1.4.0 consolidation complete. v1.5.0 has since shipped (eleven new
apps, plus a full correctness audit that found and fixed five real
bugs) — see `RELEASE_NOTES_v1.5.0.md` for the full writeup. That
release did not go through this document's per-pass tracking workflow,
so no `v1.5.0 consolidation` entries appear above; nothing was left
open here that needed one. Project enters strategic pause phase again.
Next development phase: v1.6.0 (date TBD).**

*Last updated: 2026-08-12*

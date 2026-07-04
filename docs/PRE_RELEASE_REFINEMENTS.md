# MINT Access stem — Pre-Release Refinements

This document tracks small issues, wording improvements, and polish items to address before the next release tag. Items are added as they are noticed during development and should be reviewed and resolved before tagging the next version.

---

## Active items

*(none currently)*

---

## To be triaged (noticed but not yet fully specified)

*(Add items here as they come up during development — move to a numbered section above once the fix is clear)*

---

## Resolved items

### 1. Audio player labels — "Full narrative" misleading for non-signal apps

Added a `primary_wav_label` field to every entry in `demo_html.wl`'s `appMeta` association. Only `signal` retains "Full narrative (recommended)"; all other apps now have accurate, descriptive labels (e.g. "Listen — Rössler attractor", "Listen — L4 tadpole orbit, Sun-Jupiter").

**Fixed in v1.2.0.**

### 2. "Musical sonification" framing — replace throughout

Replaced "musical sonification"/"musical WAV"/"musical audio sonification" style phrasing with precise, non-aesthetic language across `demo_html.wl` (header, intro section, asteroids/signal/lorenz descriptions) and the `asteroids/`, `pendulum/`, and `lorenz/` READMEs and AGENTS.md files. Retained "musical scale"/"musical pitch mapping" where it names an actual technical mechanism (e.g. `ScaleLookup`, `$StemScales`) rather than describing the output as an aesthetic product.

**Fixed in v1.2.0.**

### 3. demo_html.wl — images/ section needs updating

Updated the `images` entry in `demo_html.wl`'s `appMeta`: description now covers the spectral colour-to-pitch mapping and the `scan_horizontal` pedagogical mode, the listening guide reflects logarithmic brightness scaling, a note pointing to `images/LISTENING_GUIDE.md` was added to the "Run it yourself" section, and the audio label was updated to "Listen — Hilbert curve brightness scan (log scale)".

**Fixed in v1.2.0.**

### 4. demo.wl — consider scan_horizontal as second images demo preset

**Decision:** demo.wl continues to run `images/` in brightness mode only. The scan_horizontal → brightness pedagogical sequence remains documented in `images/LISTENING_GUIDE.md` and available via CLI; adding a second run to the demo would increase runtime without commensurate benefit for a demo context.

**Resolved (kept as-is) in v1.2.0.**

### 6. demo_html.wl — add dynamical/ section

Added a full `appMeta` entry for `dynamical/` (title, description, listening guide, primary/secondary WAVs, GIF, CLI, GitHub path), positioned after `lorenz` and before `asteroids` in both `appMeta` and `$appOrder` — matching demo.wl's execution order. Also fixed two related rendering bugs found while verifying the new entry: `\[Rule]` (a Wolfram-only private-use-area character, invisible in browsers) was used for the "→" arrow in every app's "View source on GitHub" link and in the new dynamical label — replaced with `\[RightArrow]` (standard Unicode) throughout.

**Fixed in v1.2.0.**

### 7. Stage 2/3 consolidation needed for dynamical/

Completed: verified inclusion in `demo.wl` (runs in sweep mode, positioned after lorenz/before cellular in the app list, outputs land in `demo/dynamical/output/`, included in `demo-report.md`); added a full `docs/APPS.md` entry with all config keys; updated root `README.md` (repository layout, Quick Start, Projects section, afplay examples, version badge); updated `demo_html.wl` (see item 6).

**Fixed in v1.2.0.**

---

## Resolved in v1.2.0 patch (post-tag)

### Item 5 resolved: cellular/ note-holding enhancement

**Fixed:** `cellular/src/sonify.wl` now uses run-length articulation with relative threshold (default 15%). Stable periods produce sustained tones; population changes produce new notes. Both Game of Life and Rule 110 modes updated. EventLayer accent tones preserved. CSV gains `articulated` and `run_length` columns. Config keys added: `articulation_mode`, `articulation_threshold`, `articulation_threshold_abs`, `base_note_duration`.

**Note:** This was implemented after the v1.2.0 tag. Should be included in the next consolidation pass and release notes for v1.3.0.

---

*Last updated: 2026-07-04*

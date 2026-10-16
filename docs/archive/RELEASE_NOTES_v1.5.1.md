# stem — Release Notes (v1.5.1)

v1.5.1 is a patch release: no new apps, no new features, just fixes.
It closes out a follow-up correctness pass that started with a single
observation — an animation that looked subtly wrong ahead of an
external publication — and grew into a genuine second audit, this time
of the project's animation and audio-export machinery rather than its
physics. Two real bugs were found and fixed in the shared
infrastructure every app depends on, plus a cluster of smaller,
app-specific fixes and a broad documentation-consistency sweep.

As with v1.5.0's correctness audit, every fix in this release was
verified against actual generated output — not just against the fix
report describing it — and that discipline caught two real gaps this
time that a first pass of fixes had missed. More on that below; it's
worth understanding, because it shaped how this release was checked.

---

## Animation framing: `pendulum/`

`pendulum/`'s double-pendulum animation clipped visible content on
**76% of its frames** — a fixed plot boundary that didn't account for
the double pendulum's genuine physical ability to flip a rod above its
own pivot, which is normal chaotic behaviour, not an edge case. At
several points enough of the mechanism was cut off that a rod's joint,
or the entire second rod and bob, simply wasn't visible. This wasn't
caught by any of `pendulum/`'s own tests or correctness checks, none of
which cover animation framing — it was caught by a sighted reviewer
looking closely at the animation itself.

Fixed by computing the plot's bounds from the actual simulated
trajectory (both bobs, the full time range), with a genuine safety
margin, clamped so the bounds can never be asked to exceed the double
pendulum's exact theoretical maximum reach (`L1+L2` from the pivot) —
a hard physical fact that costs nothing to check and rules out this
whole class of future mistake. Verified by scanning every frame of
every animation this app produces (not a sample) and confirming
content never approaches the image boundary; the same boundary-check
script is now the standard this project uses to verify any animation
with a large-amplitude or chaotic trajectory.

---

## Animation/audio synchronisation

A broader, related problem, found while investigating the above: GIF
and WAV files across the project were frequently generated as
independent computations rather than derived from one shared duration
value, meaning nothing prevented them from silently drifting apart.
Once looked for directly, this affected **every one of the other 31
apps in the project** to varying degrees — from a barely-perceptible
few percent, up to one case (`lorenz/`'s stress-test preset) where the
GIF played for under 5 seconds while its paired audio ran for two
full minutes.

Fixed across all 31 apps by deriving both the GIF's playback duration
and the WAV's length from the same computation, so they can no longer
drift apart by construction. `signal/`'s four-WAVs-per-mode structure
needed special handling — its GIF syncs to the `clean`/`noisy`/
`recovered` trio, deliberately not to the much longer spoken
`narrative_full` file, which is now documented explicitly rather than
left as an easy wrong assumption. `cellular/`'s Rule 110 modes needed
a different fix on their own terms: their visualisation is a single
static spacetime diagram (the natural way to show a 1D automaton's
whole history at once), not a frame-by-frame animation, so the fix
there was making that one frame hold for the audio's full length
rather than flashing and vanishing.

**Two gaps in this fix were found by an independent verification pass
that checked every generated preset rather than a representative
sample** — the same lesson v1.5.0's correctness audit already taught,
re-learned here in a different part of the codebase:

- **`lorenz/`'s `rho9996` preset** — the specific stress-test case that
  had originally motivated the whole fix — had not actually inherited
  it, due to a separate call site the first pass missed. Found and
  fixed; all of `lorenz/`'s presets (including new ones added
  specifically to stress-test a wider range: `classic`, `slow`,
  `stable`, `wild`) are now verified in sync.
- **`asteroids/`** surfaced a real design question, not just a bug: its
  audio duration scales with asteroid count (`n × (noteDuration +
  gapDuration)`), completely unbounded — a full year's ~1800 asteroids
  would produce a ~20-minute GIF/WAV pair once correctly synced,
  technically consistent but not a reasonable listening experience.
  Resolved by capping total duration and compressing per-asteroid
  spacing for busy date ranges (`SonificationStepDuration`, `Clip[
  maxTotalDuration/n, {minStepDuration, noteDuration+gapDuration}]`) —
  typical presets (up to roughly a month of data) are unaffected;
  busier ones compress toward a fixed ~90-second target rather than
  growing without bound. Verified against ten presets spanning 10 to
  1827 asteroids; every one lands within 0.3% of its target duration.

---

## Shared infrastructure

`stem-core`'s CLI/config parser couldn't correctly handle list-valued
override values at all — silently breaking any app whose config
exposes a list (`qubit/`'s `gate_sequence`, `lorenz/`'s
`initial_conditions`) whenever a user tried to override it from the
command line. Fixed in the shared parser; verified directly against
`qubit/`, generating three presets with genuinely different gate
sequences (1 gate, 5 gates, 11 gates) from three different CLI
invocations — confirming the parser now works in practice, not just
in isolation.

---

## Correctness and consistency

- `ExportSonification`'s call signature had drifted out of sync with
  its own definition, silently producing no WAV output at all (not an
  error — just nothing) in three apps' experiment scripts
  (`asteroids/`, `lorenz/`, `pendulum/`). Fixed, along with a related
  piece of dead "Scale" machinery removed rather than left as
  unreachable code implying a feature that doesn't exist.
- A "the Nth independently-verified example" style claim, used
  throughout several apps' documentation to describe how many times a
  given check had been independently reproduced, had drifted out of
  sync with the actual count in eight apps' docs — sometimes
  undercounting, sometimes overcounting. Corrected across all affected
  files.
- A cluster of smaller, app-specific fixes: a wrong config fallback
  default in `pendulum/` (previously masked by every documented example
  happening to override it explicitly), and several dead config keys
  removed from apps that no longer read them.

---

## Documentation

A broad sweep corrected stale version numbers, stale app counts, and
claims that had drifted out of sync across `README.md`, `demo.wl`,
`demo_html.wl`, `stem-core/README.md` and `AGENTS.md`,
`ACCESSIBILITY.md`, and individual apps' own documentation — the same
kind of drift v1.5.0's own release taught us to watch for (the
project's historical app count had silently been wrong before v1.5.0
even started). Lower-stakes than the fixes above, but worth doing
properly rather than leaving small inconsistencies to accumulate.

---

## A note on how this release was verified

Every fix described above was checked against real generated output —
actual measured GIF frame counts and durations, actual WAV file
lengths, actual CLI invocations run and their output inspected — not
against a summary describing what should be true. That discipline is
what caught the two gaps in the `lorenz`/`asteroids` fix: a first pass
had verified one representative preset per app and reasonably assumed
the pattern held everywhere else, which is exactly where the two real
remaining bugs were hiding. The lesson carried into this release's own
verification: check every preset a feature actually ships with, not
the one that's easiest to check.

---

## Acknowledgements

This release was developed with [Claude Code](https://claude.ai/claude-code)
(Anthropic), across several sessions dedicated specifically to
correctness and consistency rather than new features — the same
discipline v1.5.0's audit established, applied here to the project's
animation and export pipeline.

# stem — Release Notes (v1.6.0)

v1.6.0 has two halves. The first is new material: `dynamical/` grows
from a single bifurcation sweep into four modes built for a talk on
chaos in a bug population, with the Lyapunov exponent and the
separation of two nearby orbits made audible. The second is the
infrastructure underneath every app: GIF timing, loudness, narration,
text encoding and GIF export were each moved into `stem-core` and
measured, and the project now runs, and has been checked, on three
platforms instead of one.

As in v1.5.0 and v1.5.1, every change was verified against the files
the apps actually wrote, not against a description of the fix. Every
number in these notes comes from one of the verification files in the
repository and names it; docs/RELEASE_NOTES_v1.6.0_EVIDENCE.md lists
which file backs which section.

---

## `dynamical/`: four modes for the chaos talk

**`lyapunov` mode** sweeps r from 2.5 to 4.0 (750 steps, 120 s of
sweep) and sounds the Lyapunov exponent as a tone against a reference
at λ = 0, so the listener hears order (below the reference) and chaos
(above it) without reading a plot. The tone runs from 155.6 to
355.7 Hz, A-weighted so that equal distances from λ = 0 sound equally
far; the default run finds 15 zero crossings, each listed with its r
and its time in the audio, and the list recomputed from the CSV equals
the console's (dynamical/VERIFICATION_lyapunov_mode.md). At each
period doubling the tone rises to meet the reference and falls back
without crossing it, because λ is exactly zero at a bifurcation; the
dips below the reference that come later are the periodic windows,
which the console lists with their periods, 6, 5 and 3
(dynamical/VERIFICATION_polish_feigenbaum.md). The `lyapunov_window`
preset covers r = 3.40 to 3.90, from the last period doublings through
the onset of chaos to the period-3 window.

**`divergence` mode** starts two orbits a millionth apart and plays
them in the left and right channels. At r = 4.0 they separate past 0.1
at iteration 18, against 16.6 predicted from λ; the fitted growth rate
is 0.6709 per iteration against the predicted λ = 0.6931 (ratio
0.968). The two channels are sample-identical until the first
iteration whose notes differ (iteration 15), so the moment the ear can
tell them apart is the moment the mapping can
(dynamical/VERIFICATION_divergence_mode.md). Four presets cover the
range: `divergence_chaotic`, `divergence_edge`, `divergence_periodic`,
`divergence_stable`.

**Narration and pacing.** Every mode now opens and closes with spoken
narration timed to fit its slot: the divergence intros take 10.82 to
11.53 s of an 11.53 s slot (limit 12 s), and the sweep's intro 14.37 s
(limit 15 s) before 320 s of notes; all 17 runs of the narration check
exited cleanly (dynamical/VERIFICATION_narration.md). Two new iterate
presets, extinction (r = 0.8) and growth (r = 2.0), join the five
existing ones, and each preset's files are now named after it, so two
presets in a row no longer overwrite each other
(dynamical/VERIFICATION_polish_feigenbaum.md).

**An honest Feigenbaum check.** The old check compared one ratio of
bifurcation intervals with Feigenbaum's constant and reported a
1.761% "error" as if a finite ratio should equal it. The check now
computes three successive ratios and passes when they approach the
constant: 4.75145 (1.76% away), 4.65625 (0.277%), 4.66824 (0.0205%),
with the last within the 0.5% tolerance. `dynamical/`'s tests went
from 102 to 113 (dynamical/VERIFICATION_polish_feigenbaum.md).

---

## `stem-core`

**GIF timing in whole centiseconds.** GIF frame delays are stored in
centiseconds, and 32 apps each rounded them their own way, through 71
GIF exports, 24 copies of the same frame-rate limits and seven private
rate helpers. `GIFFramePlan` now chooses the delay in whole
centiseconds first and derives the frame count from it, and
`SyncWAVToGIF` measures both written files and prints one sentence
saying how far apart they are. Before the change 36 of 86 GIF/WAV
pairs were more than one frame delay apart (worst 1.500 s, and primes'
still frame played for 0.080 s against a 10 s WAV); after it, all 86
are within one frame delay and 84 within half a delay, the largest
difference 0.240 s at a 0.5 s delay
(stem-core/VERIFICATION_gif_centisecond.md).

**A loudness meter that follows ITU-R BS.1770-4.** The previous meter
counted partial 400 ms blocks at the start and end of a file, which
read 2.5 to 6 dB low and put a full-scale reference tone at
−0.062 LUFS instead of 0. `MeasureIntegratedLoudness` now implements
the standard directly: its K-weighting coefficients agree with the
published ones to 1e-12, the reference tone reads +0.0028 LUFS at
44.1 kHz (the value the standard's filter gives at that rate), and on
the sparse files where the two meters disagreed most the gap to an
independent implementation fell from 2.11 LU to 0.0454 LU
(stem-core/VERIFICATION_loudness_limiter.md).

**An opt-in peak limiter.** Some sonifications are too dynamic to
reach the −17 LUFS target without clipping, so the peak ceiling held
them back: `lorenz/` measured −21.51 LUFS. A look-ahead limiter
(ceiling −1 dBFS, 5 ms attack, 50 ms release), enabled per app and per
mode in config, brings lorenz mode to −17.02 LUFS with a maximum gain
reduction of 10.22 dB; with the limiter off the output is
byte-identical to before (stem-core/VERIFICATION_loudness_limiter.md).

**One speech helper, English voices, one retry.** Every narrated app
now gets its spoken audio from `STEMSpeakToBuffer`, which tries
`SpeechSynthesize[]`, then the platform's own tool (given the text
through a UTF-8 file), then nothing: with no speech available the app
still writes its WAV and prints one sentence saying what was left out.
Of the 83 narrated runs in a 109-run sweep, most were byte-identical
before and after, including the two reference files, henon attractor
and dynamical lyapunov_window; with speech switched off, each of the 20
narrated apps tested still wrote its WAV with one warning sentence
(docs/VERIFICATION_speech_encoding.md). The voice
is now always an English one chosen by name: of the Mac's 367 voices,
87 are English, and only Samantha reproduces `SpeechSynthesize[]`'s
default exactly, so the Mac narration is unchanged; before this, the
`say` fallback read English narration with the Mac's German default
voice. `SpeechSynthesize[]` fails now and then, which is the likely
cause, not proven, of the run-to-run intro differences in the other
narrated runs of that sweep; a failed sentence is now retried once
(docs/VERIFICATION_windows_fixes.md).

**UTF-8 throughout.** Text is read and written as UTF-8 everywhere,
and no script run with `wolframscript -file` keeps a non-ASCII
character in a string literal (0 left), because those files are read
as Latin-1; "Hénon" reaches the speech tool as the bytes
48 C3 A9 6E 6F 6E (docs/VERIFICATION_speech_encoding.md).

**GIF export in chunks.** `Export` holds every frame's quantised data
as integer lists while it builds a GIF, so memory grew with the frame
count. `ExportGIF` now exports in chunks and splices the files; every
frame carries its own colour table, so the result is byte-identical.
Peak memory: pendulum double 10256 MB to 684 MB, dynamical lyapunov
12818 MB to 662 MB, quantum qho 4275 MB to 591 MB, mandelbrot 1780 MB
to 823 MB, at the same wall time (docs/VERIFICATION_gif_memory.md). A
GIF that cannot be written is now reported in one sentence and the app
still writes its WAV, exiting with code 2; forced on all 31 apps that
write a GIF, every one kept its WAV (docs/VERIFICATION_linux_gif.md).

**A platform line for every report.** `STEMPlatformDescription[]`
prints "macOS 26.7.1 (Tahoe) on ARM64" or "Windows 11 25H2 (build
26200) on x86-64" instead of "Windows NT" or a bare version number;
the mappings are unit-tested with fixed inputs, 21 tests
(docs/VERIFICATION_platform_naming.md).

---

## Portability

**Three supported platforms.** Every app's default mode and the full
demo were run with the smoke test on macOS 26 on Apple silicon, on
Windows 11 x86-64 and on Ubuntu 26.04 LTS x86-64: 32 of 32 apps and
33 of 33 demo runs on each, with two consecutive clean runs on Linux.
Under Parallels the Windows engine runs about three times slower than
the Mac (3.2 times for the demo); Linux about four times slower (3.9 times for the apps, 4.5 for the demo)
(docs/VERIFICATION_platform_naming.md,
docs/VERIFICATION_release_v1.6.0.md).

**The smoke test and its wrapper.** `tools/smoke_test.wl` runs every
app and the demo in one kernel and writes one report; it now keeps a
log per app, written line by line, records memory, disk and kernel
settings, can resume a run that was interrupted, and reads the
pendulum GIF one frame at a time for its frame check, which lowered
that check's peak from 5383 MB to 402 MB
(docs/VERIFICATION_gif_memory.md, docs/VERIFICATION_smoke_wrapper.md).
`tools/smoke_test.sh` runs it on a machine nobody is watching and
appends how the run ended to the report: a kernel killed with SIGSEGV
leaves "with exit code 139 (SIGSEGV, segmentation fault)" in the last
line (docs/VERIFICATION_smoke_wrapper.md). The Linux failures that
this machinery was built to catch, an intermittent GIF export error
and a run that stopped in the frame check, are kept in `docs/` with
their reports. For the GIF errors, the export's memory was cut by an
order of magnitude and the errors stopped; the library's own reason was
never captured (docs/VERIFICATION_linux_gif.md).

**The Planck data path never worked.** `cosmology/`'s
`--simulation.cosmology.source=planck` read numbers written as
`2.00000000e+00` with a parser that does not read e-notation, so every
row was dropped and the app always fell back to the simulated
spectrum. It now reads the Planck 2018 data (1999 points) and, on a
spectrum smoothed over 15 multipoles, finds the first acoustic peak at
l = 224, inside the expected 180 to 260
(docs/VERIFICATION_portability_mac.md).

**NASA requests that say why they failed.** `asteroids/` fetches with
the built-in `URLRead` and uses curl only when it gets no response;
the parsed data are equal either way
(docs/VERIFICATION_portability_mac.md). When NASA refuses a request,
the app now says so in one sentence with the server's status and
error message, which key was used, and the key's length (never the
key itself; NASA keys are 40 characters), where it used to print only
"could not fetch data" (docs/VERIFICATION_platform_naming.md).

---

## Supporting-app fixes

**`pendulum/`** wrote one frame too many: 501 frames for 20 s of audio.
It now writes 500, and every pendulum preset's GIF and WAV have the
same duration to the millisecond
(docs/VERIFICATION_supporting_apps_fixes.md).

**`lorenz/`** now discards the first 5 s of the trajectory, the climb
onto the attractor, whose start-up peak held the whole file quiet:
lorenz mode rose from −25.01 to −21.58 LUFS, and with the limiter
above it reaches −17.02 LUFS
(docs/VERIFICATION_supporting_apps_fixes.md,
stem-core/VERIFICATION_loudness_limiter.md).
`--simulation.lorenz.transient_seconds=0` restores the climb.

**`henon/`** holds its first frame through the spoken intro and ends
its animation within one frame of the notes, in its attractor and
sweep modes: the
attractor's final image appears at 28.56 s against notes ending at
28.57 s (docs/VERIFICATION_supporting_apps_fixes.md).

---

## Also in this release

- `mandelbrot/`: an opt-in escape-gradient colour mode, and a
  visited-region overlay that no longer buries the fractal
  (mandelbrot/VERIFICATION_overlay_fix.md).
- `tools/make_presentation_video.wl`: a GIF + WAV to MP4 generator with
  opening and closing holds (tools/VERIFICATION_hold_feature.md).
- `demo_outreach.wl`: a reusable, curated outreach-page generator.
- `relativity/`: the chirp's audio time-stretch no longer changes its
  pitch.

## Supported platforms

macOS 26 on Apple silicon (Wolfram Engine 15.0.1), Windows 11 x86-64
(15.0.0) and Ubuntu 26.04 LTS x86-64 (15.0.0); 8 GB of RAM. See the
README's Supported platforms section for the reports behind each.

# Release v1.6.0 close-out: verification (measured 2026-10-16)

## Context
- Repo HEAD eb61918 (main); every change is uncommitted, as asked (the release is tagged by hand).
- Mac measurements: macOS 26.7.1, Apple silicon, Wolfram Engine 15.0.1.
- Linux evidence: two full smoke runs on Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, x86-64, Wolfram Engine 15.0.0, 14.98 GB memory, run through tools/smoke_test.sh (the version before item 1 below).

## 1. Wrapper: explicit report path
- Cause found in the evidence: docs/smoke_test_Linux-x86-64_2026-10-16_1719.txt ends with two lines, "The smoke test process ended at 18:48." (its own) and "The smoke test process ended at 20:17." (the 18:48 run's); docs/smoke_test_Linux-x86-64_2026-10-16_1848.txt has no end line.
- Why: the wrapper looked for the newest smoke_test_*.txt written since its start; the first run's own end line rewrote the 1719 report just after the second run started, so the second run took that file as its report.
- Fix (tools/smoke_test.sh, tools/smoke_test.ps1): the report path is fixed before the start and passed as --out: --out if given; with --resume the newest smoke_test_<SystemID>_*.txt; otherwise smoke_test_<SystemID>_<date>_<HHMM>.txt from the start time, with _2, _3 if a run in the same minute used the name.
- SystemID in the shell wrapper from uname: Darwin/arm64 MacOSX-ARM64, Darwin/x86_64 MacOSX-x86-64, Linux/x86_64 Linux-x86-64, Linux/aarch64 Linux-ARM64; in the PowerShell wrapper Windows-x86-64 or Windows-ARM64 from PROCESSOR_ARCHITECTURE.
- The smoke_wrapper_*.txt fallback file is gone (a run without a report gets its line in the report path itself); its .gitignore line removed.
- tools/smoke_test.ps1: not run and not parsed (no PowerShell on this Mac).
- Command: `tools/smoke_test.sh --quick; tools/smoke_test.sh --quick` back to back -> exit 0 and 0.
- Run 1 report smoke_test_MacOSX-ARM64_2026-10-16_2049.txt ends: "Summary: 6 of 6 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 4/4 runs passed, no step skipped." then "The smoke test process ended at 20:55." (one end line).
- Run 2 report smoke_test_MacOSX-ARM64_2026-10-16_2055.txt ends: the same Summary, then "The smoke test process ended at 21:01." (one end line).

## 2. Linux evidence filed in docs/
- docs/smoke_test_Linux-x86-64_2026-10-16_1719.txt (started 17:19) and docs/smoke_test_Linux-x86-64_2026-10-16_1848.txt (started 18:48), copied unchanged from ~/Downloads, including the misplaced end line described above.
- 1719: Summary "32 of 32 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 33/33 runs passed, no step skipped."; Messages: none; demo.wl 2235.6 s; app runs 2379.3 s in total.
- 1848: the same Summary; Messages: none; demo.wl 2238.6 s; app runs 2381.7 s in total.
- Both: pendulum frame check PASS (500 frames, 960x932 px, worst margins 119, 37, 37, 37 px, 0 frames under the margin).
- Both: narration voice "SLT (en-us, female), chosen automatically; English voices listed: 43"; espeak-ng and espeak not found; SpeechSynthesize["Test."] returned audio (0.72 s and 0.64 s).
- Both: asteroids -18.13 LUFS, peak -0.26 dBFS (held at the peak ceiling; live data of one week).
- Both: free space 835.03 / 835.04 GB on ext4, /tmp a 7.49 GB tmpfs, overcommit 0, core_pattern piped to apport.
- docs/demo_report_Linux-x86-64_2026-10-16.md: from a separate standalone `wolframscript -file demo.wl` run on the same machine, not from either smoke run (the 1848 run's demo/demo-report.md was overwritten by it); "Generated: Fri 16 Oct 2026 22:27:32", Wolfram 15.0.0 for Linux x86 (64-bit), Ubuntu 26.04.1 LTS; "Total elapsed: 1989.3 s | 33 passed", no failed or skipped step.
- Kept as the record of the failures fixed: the 2026-10-13, 10-14, 10-15 and 10-16 (01:17) Linux reports and the zipped logs of 10-15 and 10-16.

## Speed, Linux and Windows against the Mac
- Mac reference: docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt (full run, docs/VERIFICATION_smoke_wrapper.md; filed in docs/ unchanged on 2026-10-17, see docs/VERIFICATION_release_wording.md).
- Command: a Python sum of the "seconds" column over the 31 apps common to both reports, asteroids excluded (live data).
- Linux 1719: apps 2169.7 s vs Mac 552.8 s, ratio 3.92; demo.wl 2235.6 s vs 500.1 s, ratio 4.47.
- Linux 1848: apps 2172.5 s vs Mac 552.8 s, ratio 3.93; demo.wl 2238.6 s vs 500.1 s, ratio 4.48.
- Windows (Parallels, x64 engine under emulation): 3.5 for the apps, 3.2 for demo.wl (docs/VERIFICATION_platform_naming.md).
- The README now says "about four times slower" for Linux (the brief said about 2.5; the measured ratios do not support that).

## 3. README
- Supported: Ubuntu 26.04 LTS x86-64, Wolfram Engine 15.0.0, 32 of 32 apps, demo.wl 33 of 33, two consecutive clean runs, both reports linked, 3.9 and 4.5 times the Mac's time; the 10-13 to 10-15 runs named as the record of the failures fixed; the crash and unattended-run notes kept under it.
- Memory: 8 GB minimum (peak 5.2 GB on the Mac, docs/VERIFICATION_smoke_wrapper.md), unchanged.
- Narration: Samantha on macOS; SLT, bundled with Wolfram Engine, on Linux and Windows, so no espeak-ng is needed.
- asteroids loudness: live data differ per week and a week's file can be held below -17 LUFS by the peak ceiling (-18.1 LUFS in the two Linux runs), so the figure is not a regression indicator.
- The macOS entry links docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt, the full Mac run of 2026-10-16 (filed 2026-10-17); docs/smoke_test_MacOSX-ARM64_2026-10-07.txt is kept.

## 4. Release notes
- RELEASE_NOTES_v1.6.0.md: dynamical modes; stem-core; portability; supporting-app fixes; also in this release; supported platforms. Every number names its verification file.
- docs/RELEASE_NOTES_v1.6.0_EVIDENCE.md: one line per section naming the files that back it.
- Version badge 1.6.0 linking RELEASE_NOTES_v1.6.0.md; the README's release-notes sentence names v1.6.0 for the changes and keeps v1.5.1 for the app descriptions it holds.
- There is no v1.5.1 git tag; "since v1.5.1" means since commit 7c236c5 ("release: v1.5.1").

## 5. Final check
- Every test suite: 36 Wolfram suites, `wolframscript -file <app>/tests/test_*.wl`, all passing:
- asteroids 29, bayes 23, bell 35, blackbody 23, brownian 24, cellular 16, clt 23, compton 25, cosmology 27, dynamical 114, fluid 5, grover 24, henon 44, hydrogen 23, images 51, lagrange 43, lorenz 34, magnetic 18, mandelbrot 27, montecarlo 19, pendulum 18, primes 17, quantum 14, quantum_statistics 26, quantum_tunnelling 20, qubit 33, relativity 16, resonance 11, scattering 7, signal 13, thermo 28, waves 23 passed, 0 failed each.
- stem-core: test_gifsync 54, test_loudness 31, test_platform 21, test_speech 27 passed, 0 failed each.
- lagrange, magnetic, resonance and scattering print "Passed: n / Failed: 0" and were rerun to record their exit code: 0 each.
- `python3 pendulum/tests/verify_animation_frames.py` -> ALL PASS, exit 0.
- Command: `tools/smoke_test.sh --quick` after the last change -> exit 0; report smoke_test_MacOSX-ARM64_2026-10-16_2109.txt ends "Summary: 6 of 6 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 4/4 runs passed, no step skipped." then "The smoke test process ended at 21:15."
- `git status --short`: only the files listed below, plus the long-untracked docs/STATE_supporting_apps.md.

## Files changed
- Modified: tools/smoke_test.sh, tools/smoke_test.ps1, README.md, .gitignore.
- Modified after the close-out: demo_html.wl (the page's version now comes from the highest RELEASE_NOTES_v*.md; it showed v1.5.0).
- New: RELEASE_NOTES_v1.6.0.md, docs/RELEASE_NOTES_v1.6.0_EVIDENCE.md, docs/VERIFICATION_release_v1.6.0.md, docs/smoke_test_Linux-x86-64_2026-10-16_1719.txt, docs/smoke_test_Linux-x86-64_2026-10-16_1848.txt, docs/demo_report_Linux-x86-64_2026-10-16.md.

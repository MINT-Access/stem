# Smoke test wrapper, timed names, streamed frame check: verification (measured 2026-10-16)

## Context
- Acts on the overnight Linux runs smoke_test_Linux-x86-64_2026-10-15.txt and _2026-10-16.txt with their smoke_logs (docs/smoke_test_Linux-x86-64_2026-10-15.txt, _2026-10-16.txt and docs/smoke_logs_Linux-x86-64_2026-10-15.zip, _2026-10-16.zip, filed after this record was written): neither reached its Summary line.
- The 2026-10-15 report ends after mandelbrot; the machine's journal (boot -1) ends with a system reboot at 01:04.
- The 2026-10-16 report ends with the header "== Pendulum frame clipping (margin >= 3 px on every frame) ==" and no result: it stopped inside the frame check, which loaded all 500 frames of pendulum's GIF.
- Both Linux reports: 14.98 GB total memory, overcommit 0, core_pattern piped to apport; /var/crash held only orca crash files.
- Repo HEAD aeb47d9 (main); every change is uncommitted, as asked.
- Machine for every measurement: macOS 26.7.1, Apple silicon, 32 GB RAM, Wolfram Engine 15.0.1.

## 1. Names with the time
- Default report: smoke_test_<SystemID>_<date>_<HHMM>.txt (DateString Year-Month-Day_HourMinute); log directory smoke_logs_<SystemID>_<date>_<HHMM>/ (derived from the report name, as before).
- Measured names: smoke_test_MacOSX-ARM64_2026-10-16_1329.txt, _1341.txt, _1344.txt with smoke_logs_MacOSX-ARM64_2026-10-16_1329/, _1341/, _1344/.
- --resume without --out still picks the newest smoke_test_<SystemID>_*.txt by modification time.
- Two runs started in the same minute would share a name (not tested).
- README, AGENTS.md and tools/README.md use the new names; dated records (audit, earlier VERIFICATION files) are left as written.

## 2. The wrapper (tools/smoke_test.sh, tools/smoke_test.ps1)
- tools/smoke_test.sh starts `wolframscript -file tools/smoke_test.wl -- <its arguments>`, tees the console to the terminal and a temporary file, and waits.
- Report path: --out=<path> if given, otherwise the newest smoke_test_*.txt in the repository root written since the wrapper started (covers --resume, which rewrites the report).
- Heartbeat: every 10 s smoke_heartbeat_<SystemID>_<date>_<HHMM>.txt next to the report is rewritten with the local time, seconds since the start, the app being run and wolframscript's pid; at the end it holds the end line.
- The app comes from the console's last "running <app> ..." line, not the report: the report holds only finished apps and has no "running" lines.
- At the end the console is kept as smoke_console_<SystemID>_<date>_<HHMM>.txt and one line is appended to the report.
- With a Summary line in the report: "The smoke test process ended at HH:MM."; without: "The smoke test process ended at HH:MM with exit code N (SIG<name>, <meaning>) after T s.", the signal part only for exit codes above 128.
- A kernel killed by a signal makes wolframscript exit with 128 + the signal number: SIGKILL gave 137 (2026-10-15 test), SIGSEGV gave 139 with "The product exited for an unknown reason." on the console.
- If no report was written, the line goes to smoke_wrapper_<date>_<HHMM>.txt (named so that --resume's smoke_test_*.txt glob does not pick it up).
- The wrapper exits with wolframscript's exit code.
- .gitignore: /smoke_console_*.txt, /smoke_heartbeat_*.txt, /smoke_wrapper_*.txt added next to /smoke_test_*.txt and /smoke_logs_*/.
- tools/smoke_test.ps1: the same steps with Start-Process, the console redirected to a file and echoed, NTSTATUS names for common crash codes (0xC0000005 access violation, 0xC00000FD stack overflow, ...); not run, and not parsed: no PowerShell on this Mac.

### Normal --quick run
- Command: `tools/smoke_test.sh --quick` -> wrapper exit 0.
- Report smoke_test_MacOSX-ARM64_2026-10-16_1329.txt ends: "Summary: 6 of 6 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 4/4 runs passed, no step skipped." then the appended line "The smoke test process ended at 13:35."
- Heartbeat file at the end: "2026-10-16 13:35:36 ended: The smoke test process ended at 13:35."
- Files next to the report: smoke_console_MacOSX-ARM64_2026-10-16_1329.txt, smoke_heartbeat_MacOSX-ARM64_2026-10-16_1329.txt, smoke_logs_MacOSX-ARM64_2026-10-16_1329/ (7 logs).

### Kernel killed during a --quick run
- Command: `tools/smoke_test.sh --quick` in the background; after henon's report line, `kill -SEGV` to the WolframKernel process.
- Heartbeat while alive: "2026-10-16 13:43:23 alive, 111 s since the start; running mandelbrot (wolframscript pid 75418)".
- Wrapper exit code: 139.
- Report smoke_test_MacOSX-ARM64_2026-10-16_1341.txt ends with the app lines of dynamical, henon and images, then: "The smoke test process ended at 13:43 with exit code 139 (SIGSEGV, segmentation fault) after 115 s."
- Heartbeat after: "2026-10-16 13:43:27 ended: The smoke test process ended at 13:43 with exit code 139 (SIGSEGV, segmentation fault) after 115 s."

## 3. Frame-clipping check without the whole GIF in memory
- Before: Import[path, "ImageList"] (500 Image objects, 1280 MB as ByteCount), then a loop over them.
- Partial import tried first: Import[path, {"ImageList", {250}}] took 4.27 s and {"ImageList", 476 ;; 500} 4.14 s, the same as all 500 frames (4.11 s): the importer decodes the whole file each time, so it was not used.
- After: the GIF's bytes are read once (4.8 MB), its blocks are walked (GIFFrameBlocks), and each frame is decoded alone with ImportByteArray from header + that frame's blocks + trailer; only the running worst margins and the violation count are kept.
- This holds when every frame covers the whole canvas and has no transparent colour (what ExportGIF writes); otherwise the check falls back to the whole-list import.
- All 500 frames decoded alone are pixel-identical to the whole-list import (ImageData "Byte" compared; 13 s).
- Result unchanged: 500 frames, 960x932 px, worst margins top 119, bottom 37, left 30, right 30 px, 0 frames under the margin.
- The helper is FrameContentMargins: FrameMargins is a protected built-in option name, and the first measurement of the new check failed on it (SetDelayed::write) before the rename.

### Peak memory of the check alone (same 50 ms RSS sampler as docs/VERIFICATION_gif_memory.md)
- Command: `clip/run.sh old` (FrameClipCheck from HEAD's tools/smoke_test.wl) and `clip/run.sh new`, each in its own kernel on pendulum/output/double_animation.gif.
- Old: RSS before the check 285 MB, peak during the check 5383 MB (+5098 MB), 112.9 s.
- New: RSS before the check 285 MB, peak during the check 402 MB (+117 MB), 119.8 s.

### In the full smoke test
- Before (2026-10-15 full run, 1 s samples): after waves ended at about 1.55 GB, the frame check rose to 3.81, 4.38 and 5.96 GB within three seconds and stayed at 3.41 GB for about 30 s; 5.96 GB was that run's overall peak, attributed to waves in docs/VERIFICATION_gif_memory.md and the README (corrected).
- After (2026-10-16 full run through the wrapper, 0.5 s samples): frame check peak 1.57 GB over 230 samples (115 s); the kernel held about 1.5 GB before it.
- Overall peak of the full run now 5.23 GB, during dynamical; then fluid 3.18 GB, demo.wl 2.78 GB, images 2.18 GB, hydrogen 2.09 GB, brownian 2.05 GB.
- README Supported section: peak 5.2 GB (dynamical), 8 GB of RAM the minimum; the 6.0 GB figure explained as the old frame check.

## Full smoke test (Mac, through the wrapper)
- Command: `tools/smoke_test.sh` (full) -> wrapper exit 0; report smoke_test_MacOSX-ARM64_2026-10-16_1344.txt.
- "Summary: 32 of 32 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 33/33 runs passed, no step skipped." followed by "The smoke test process ended at 14:06."
- "[PASS] double_animation.gif: 500 frames, 960x932 px, worst margins top 119, bottom 37, left 30, right 30 px, 0 frames under the margin"
- demo.wl 500.1 s, 33/33.
- Diff with the 2026-10-15 16:23 report (times masked): memory available 16.59 GB vs 19.08 GB, free space 1388.12 GB vs 1388.19 GB, the log directory name, asteroids (live NASA data: 22.78 s, -18.13 LUFS, peak -0.26 dBFS), demo.wl 500.1 s vs 502.5 s, and the appended end line.

## 4. README
- Supported platforms, Linux: unattended runs: HandleLidSwitch=ignore in /etc/systemd/logind.conf, `sudo systemctl mask sleep.target suspend.target`, run inside tmux through tools/smoke_test.sh, read the result from the report's last line; apport does not keep crash reports for Wolfram Engine, so a segmentation fault shows only in that line.
- The crash bullet now continues with `tools/smoke_test.sh --resume`.
- Checking an installation: the wrapper (both scripts) as the way to run on a machine nobody is watching, with an example end line; the time in report names.

## Files changed
- tools/smoke_test.wl, README.md, AGENTS.md, tools/README.md, .gitignore.
- New: tools/smoke_test.sh, tools/smoke_test.ps1, docs/VERIFICATION_smoke_wrapper.md.

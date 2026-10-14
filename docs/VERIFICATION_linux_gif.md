# Intermittent GIF export failure on Linux: verification (measured 2026-10-14)

## Context
- Acts on the Linux smoke test of 2026-10-13 (Ubuntu 26.04.1 LTS, Wolfram Engine 15.0.0 x86-64): Export::fmterr "Invalid GIF format." for pendulum and quantum in the smoke run and for lorenz, dynamical iterate, henon, resonance, fluid, thermo, montecarlo and mandelbrot in the demo run.
- The reports: docs/smoke_test_Linux-x86-64_2026-10-13.txt and docs/demo_report_Linux-x86-64_2026-10-13.md (filed after this record was written; first read from ~/Downloads).
- Repo HEAD 2196612 (main); every change is uncommitted, as asked.
- Machine for every measurement: macOS 26.7.1 on Apple silicon, 32 GB RAM, Wolfram Engine 15.0.1; no Linux machine here.
- Scripts used (in the session scratchpad, not in the repo): force_gif_fail.wl (every GIF Export issues Export::fmterr and returns $Failed, other formats untouched), force_all.wl, force_demo.wl, force_smoke.wl, capture_frames.wl, repro.wl, mem1.wl, peak.wl, diag.wl, retry.wl, seeded.wl.
- Harness note: wolframscript run with an app's main.wl path as an argument ran that file instead of the harness, so the harness takes the app name (`wolframscript -file force_gif_fail.wl -- pendulum`).

## What the Linux report shows
- In the smoke run each failure cascaded: Export::fmterr, then ReadByteArray::noopen (GIFFrameDelays on the missing file), Part::partd ($Failed[[11]]), StringJoin::string (FmtDec[-Infinity] from Max[{}]).
- In the demo run only the first three Export::fmterr messages are shown; from the fourth on Wolfram replaced them with General::stop, so lorenz, henon, mandelbrot and the others failed with no message of their own ("error during execution").
- henon and mandelbrot list no WAV in the Linux demo report: their failure stopped the run before the audio.
- demo.wl itself was stopped at the smoke test's 1800 s limit (3 x 600 s); the Linux demo needed 1878 s.

## Part 1: a failed GIF export is a reported event
- stem-core/src/export.wl ExportGIF: the export runs in EvaluationData; it counts as written only if Export did not return $Failed and the file starts with GIF87a/GIF89a.
- On failure: one sentence, then $Failed is returned and the path is added to $STEMGIFFailures (its messages to $STEMGIFFailureMessages).
- The sentence: `[GIF FAILED] <app>: the GIF <path> (<n> frames, <w>x<h> px) was not written; the first message was: <message> The app continues without it and will exit with code 2.`
- The first message prefers an Export:: message (an unwritable path first raises internal StringForm::string and OpenAppend::noopen).
- A truncated file left by the failed export is deleted and the sentence says so ("A truncated 524288-byte file was removed.").
- An existing GIF at the path is deleted before exporting, so an old file is never mistaken for a new one.
- Each export runs with a fresh $MessageList, so after three failures in one kernel the next one still reports Export::fmterr instead of being replaced by General::stop (the Linux demo case).
- SyncWAVToGIF: for a failed (or absent) GIF it prints one sentence, `GIF/WAV sync skipped: the GIF <file> was not written, so there is nothing to time the WAV against; the WAV is unchanged.`, and reads neither file's frames.
- STEMDescribeGIF: for a failed GIF, `Animation: not written (the GIF export failed, see above) — <path>`.
- STEMExitStatus[]: new; the last line of all 32 main.wl files; after a failed GIF it prints `Exit code 2: the GIF export failed for <files>; the WAV and the other output files were written.` and exits with 2; otherwise it does nothing.
- Inside demo.wl ($STEMInHostRun = True in its Block) STEMExitStatus does not exit, so the demo continues.
- STEMRunApp (smoke test, experiments.wl): resets the failure lists per run; new status `GIF FAILED` (WAV written, GIF failed, exit 0 or 2), new record key "gifFailures"; STEMRunExperiments prints a sentence for it and counts it as not as expected.
- demo.wl: runs each app in EvaluationData instead of Check; a message counts as an error only if it is not one of the failed GIF export's own; new status `NO GIF` (console and report "× NO GIF (WAV written)"), a note naming the GIF and message, a "GIF failed" count, and the WAVs of NO GIF runs in the audio guide.
- demo.wl: a GIF reported as failed is not counted again as a missing expected file.
- Smoke test: status GIF FAILED with the WAV measured; the frame check prints `[SKIP] double_animation.gif: the frame-clearance check was skipped because the GIF was not written.`; the summary names the apps whose GIF failed; exit 1 if any GIF failed.

### Forced failure, standalone (wrapper returning $Failed with Export::fmterr)
- Command: `wolframscript -file force_gif_fail.wl -- pendulum` -> exit code 2.
- pendulum console lines:
- `Export::fmterr: Invalid GIF format.`
- `  [GIF FAILED] pendulum: the GIF /Users/mintaccess/Projects/stem/pendulum/output/double_animation.gif (500 frames, 960x932 px) was not written; the first message was: Export::fmterr : Invalid GIF format. The app continues without it and will exit with code 2.`
- `  Animation: not written (the GIF export failed, see above) — /Users/mintaccess/Projects/stem/pendulum/output/double_animation.gif`
- `  Audio: 20. s — /Users/mintaccess/Projects/stem/pendulum/output/double_audio.wav`
- `  GIF/WAV sync skipped: the GIF double_animation.gif was not written, so there is nothing to time the WAV against; the WAV is unchanged.`
- `  Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -4.52 dBFS.`
- `  Exit code 2: the GIF export failed for double_animation.gif; the WAV and the other output files were written.`
- Command: `wolframscript -file force_gif_fail.wl -- quantum` -> exit code 2.
- quantum console lines:
- `Export::fmterr: Invalid GIF format.`
- `  [GIF FAILED] quantum: the GIF /Users/mintaccess/Projects/stem/quantum/output/qho_density.gif (251 frames, 1200x600 px) was not written; the first message was: Export::fmterr : Invalid GIF format. The app continues without it and will exit with code 2.`
- `  Animation: not written (the GIF export failed, see above) — /Users/mintaccess/Projects/stem/quantum/output/qho_density.gif`
- `  Audio: 12.55 s — /Users/mintaccess/Projects/stem/quantum/output/qho_audio.wav`
- `  GIF/WAV sync skipped: the GIF qho_density.gif was not written, so there is nothing to time the WAV against; the WAV is unchanged.`
- `  Exit code 2: the GIF export failed for qho_density.gif; the WAV and the other output files were written.`
- quantum prints no loudness line in any run (before this change too); its WAV is written and listed.
- No ReadByteArray::noopen, Part::partd or StringJoin::string in either run; Export::fmterr is the only message.
- Compared with the normal run, the forced quantum console differs only in the four lines above (diff of both logs).
- Unwritable path: a directory created at pendulum/output/double_animation.gif; `wolframscript -file pendulum/main.wl` -> exit code 2, reported the same way (Export::fdir is the first message).

### Forced failure, in one kernel
- force_all.wl (STEMRunApp on all 32 default modes, every GIF failing): 31 apps GIF FAILED, exit 2, WAV written (relativity and signal 4 WAVs), one "sync skipped" line each; cosmology OK (its default mode writes no GIF).
- In that run (before the $MessageList fix) bell's run showed General::stop and the later apps no message: the reason for the fresh $MessageList; the unit test now checks five failures in one evaluation.
- henon and mandelbrot, which lost their WAV on Linux, wrote it in the forced run.
- force_demo.wl (demo.wl --quick, every GIF failing): 4 of 4 steps ran; console `Status: NO GIF  (the GIF export failed for double_animation.gif (Export::fmterr : Invalid GIF format); the WAV and the other files listed were written)`; summary `GIF failed:     4 (WAV written, GIF not)`; report rows `× NO GIF (WAV written)`; the four WAVs listed in the audio guide.
- force_smoke.wl (smoke --quick, every GIF failing): exit 1; six rows `GIF FAILED` with WAV length, LUFS and peak measured; `[SKIP] double_animation.gif: the frame-clearance check was skipped because the GIF was not written.`; `demo.wl | MESSAGES | 39.9 s | passed 0/4, GIF failed in 4 (WAV written) | Export::fmterr : Invalid GIF format.`
- Forced smoke summary: `Summary: 6 of 6 apps wrote a WAV; 6 GIF exports failed (dynamical, henon, images, mandelbrot, pendulum, signal); demo.wl MESSAGES, 0/4 runs passed, GIF failed in 4 (WAV written), no step skipped.`

### Normal runs unchanged
- Baseline: `git archive HEAD` unpacked in the scratchpad; pendulum (double) and quantum (qho) run there and in the working tree, both with SeedRandom[1] first (seeded.wl).
- Byte-identical: double_animation.gif, double_results.csv, qho_density.gif, qho_timeseries.csv.
- qho_density.png: identical pixel data (same IDAT chunks); only the PNG "Creation Time" text chunk differs.
- WAVs are not byte-reproducible even in the unchanged baseline: two seeded baseline runs of pendulum differ, and two unseeded ones differ by up to 42 LSB in 1196658 of 1764000 samples (same length); baseline vs new differ by the same amount (42 LSB, 1197635 samples). Source: the unseeded RandomReal roughness layer in stem-core/sonification.wl and at least one other non-deterministic step.
- Console output, baseline vs new: identical except pendulum's peak (-4.51 / -4.52 dBFS), which also varies between baseline runs.
- Command: `wolframscript -file tools/smoke_test.wl` (full) -> exit 0: `Summary: 32 of 32 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 33/33 runs passed, no step skipped.`; Messages: none; demo.wl 497.5 s; pendulum frame check PASS.
- That run also regenerated the default-mode GIFs that the forced runs had removed from the apps' output/ folders.
- Tests: `wolframscript -file stem-core/tests/test_gifsync.wl` -> 45 passed, 0 failed (13 new: failed export returns $Failed, writes no file, is recorded, only Export::fmterr, the sentence's content, sync skip, describe line, exit code 2, no exit inside demo, no exit without failure, five failures without General::stop, unwritable target, normal export unchanged).
- test_loudness 31/31, test_platform 21/21, test_speech 27/27.

## Part 2: cause
### How Export writes a GIF in 15.0 (read from the installed code)
- SystemFiles/Formats/GIF/Export.m registers exportElementsToRasterFormat["GIF"]; frames that are already Image objects are not rasterised again (Graphics would be rasterised there, one Rasterize per frame).
- ExportGIF passes Image frames (STEMRasterize at 144 dpi beforehand), so Export does no rasterising of its own.
- System`Convert`GIFDump`GIFSet: conforms the frames, quantises every frame (GIFTools`GIFImageQuantize) into one colour map and index array per frame, converts both to NumericArray, then calls GIFTools`GIFWrite on the target file.
- GIFTools`GIFWrite (SystemFiles/Links/GIFTools/Kernel/GIFTools.wl) calls the LibraryLink function $WriteColormaps inside Quiet @ Catch, so the library's own error is discarded.
- No temporary file: GIFWrite writes the target path directly (consistent with the full-volume result below).
- Export::fmterr is issued by System`Convert`CommonGraphicsDump`validateResultFromLowLevel when GIFWrite returns $Failed, a Failure or a LibraryFunctionError; a failed quantisation or NumericArray conversion raises Export::errelem instead.
- So "Invalid GIF format." means the library write step failed, and the message carries no reason.

### Conditions for Export::fmterr, documented or plausible
- The output volume is full or the write fails (ENOSPC, EIO, quota): reproduced below.
- The GIF library cannot allocate memory for its buffers (plausible: the whole frame set is held in memory, see peak memory below).
- The target is not writable in a way the library sees only when it opens the file (permissions, a path that vanished); a directory at the path gives Export::fdir instead, before the library.
- An error inside the library on unusual input (not plausible here: the same frames export on macOS and Windows).

### Reproduction attempts on the Mac
- Frame sets: the exact lists pendulum and quantum hand to Export, captured to MX (capture_frames.wl): pendulum 500 frames 960x932 (1280 MB in memory), quantum 251 frames 1200x600 (517 MB).
- Command: `wolframscript -file repro.wl -- base` -> both written, no messages (15.1 s and 33.1 s).
- Memory limit: `wolframscript -file mem1.wl` (quantum frames, MemoryConstrained around Export at 32 MB, 256 MB, 1 GB, 4 GB, 16 GB).
- 32 MB, 256 MB, 1 GB: the export was aborted ($Aborted escaped MemoryConstrained's failure value), no file, no Export::fmterr.
- 4 GB, 16 GB: written, no messages.
- Result: a kernel memory limit gives an abort, not Export::fmterr.
- Peak memory (peak.wl, MaxMemoryUsed around Export): pendulum 8546 MB for a 1280 MB frame list; quantum 3448 MB for 517 MB.
- Nearly full volume: a 64 MB HFS+ disk image filled to 512 KB free (`hdiutil create -size 64m`, then dd).
- `wolframscript -file repro.wl -- disk <volume>`, $TemporaryDirectory on the full volume, output on the normal disk: both written, no messages (the exporter does not stage through $TemporaryDirectory).
- Same, output on the full volume: Export returned $Failed with `Export::fmterr: Invalid GIF format.` for both frame sets: reproduced.
- The failed export left a truncated file that starts with GIF89a (524288 bytes = the free space).
- Open files: `sh -c "ulimit -n 256; wolframscript -file repro.wl -- files"`, 103 streams open: both written, no messages.
- Conclusion: a full output volume reproduces the Linux message exactly; memory exhaustion of the GIF library is the other candidate (8.5 GB peak for pendulum), not reproducible here with MemoryConstrained.
- Consistent with Linux: failures were intermittent, more frequent in the demo run (which copies every output file into demo/, doubling the disk use), and hit the apps with the largest frame lists first.
- To confirm on the Linux VM: `df -h ~/Projects/stem /tmp` and `free -h` before a run, or STEM_GIF_DIAG=1 below.

### STEM_GIF_DIAG=1
- Before each export one line: free space in $TemporaryDirectory and in the output directory (df -Pk; PowerShell PSDrive.Free on Windows), MemoryInUse, MemoryAvailable, frame count, ByteCount of the rasterised frame list, open-file limit (ulimit -n; "no per-process limit reported" on Windows).
- After a failure: one retry after a 2 s pause and one sentence; the retry is a diagnostic, not a fix, and the export still counts as failed (exit 2, sync skipped).
- Command: `STEM_GIF_DIAG=1 wolframscript -file diag.wl` (quantum frames through ExportGIF, normal disk, then the full volume).
- Normal export, as printed: `  GIF diagnostics before exporting qho_density.gif: free space 1388.88 GB in the temporary directory (/private/var/folders/jc/bmdfzv5n78g7f6tqdt9d1b500000gn/T) and 1388.88 GB in the output directory; MemoryInUse 628.3 MB, MemoryAvailable 18.62 GB; 251 frames, rasterised frame list 517.2 MB; open-file limit 1048576.`
- Full volume, as printed: `  GIF diagnostics before exporting qho_density.gif: free space 1388.88 GB in the temporary directory (/private/var/folders/jc/bmdfzv5n78g7f6tqdt9d1b500000gn/T) and 512 KB in the output directory; MemoryInUse 641 MB, MemoryAvailable 18.62 GB; 251 frames, rasterised frame list 517.2 MB; open-file limit 1048576.`
- `Export::fmterr: Invalid GIF format.`
- `  [GIF FAILED] quantum: the GIF .../full/quantum/output/qho_density.gif (251 frames, 1200x600 px) was not written; the first message was: Export::fmterr : Invalid GIF format. A truncated 524288-byte file was removed. The app continues without it and will exit with code 2.`
- `  GIF diagnostics: one retry after a 2 s pause failed too (Export::fmterr : Invalid GIF format); the retry is a diagnostic, not a fix, so the export still counts as failed.`
- Retry that succeeds (retry.wl, first Export fails, second works): `  GIF diagnostics: one retry after a 2 s pause wrote the GIF; the retry is a diagnostic, not a fix, so the export still counts as failed.` then `  GIF/WAV sync skipped: the GIF x.gif's export failed (only a diagnostic retry wrote the file), so it is not timed against the WAV; the WAV is unchanged.`
- Not run: the Windows free-space branch (PowerShell) and Linux df; both are untested here.

## Part 3: smoke test on slower machines
- New option `--demo-timeout-seconds=N` (default 3600; it was 3 x 600 = 1800 s); a non-positive or non-numeric value prints a warning and uses 3600.
- The report prints `demo.wl time limit: 3600 s (--demo-timeout-seconds)` above the demo line.
- On a timeout the demo line names the finished steps and the running one instead of "passed ?", read from demo.wl's own "=== Demo k/N: app ===" and "Status:" lines.
- Command: `wolframscript -file tools/smoke_test.wl -- --quick --demo-timeout-seconds=25` -> `demo.wl | TIMEOUT | 25 s | stopped at the 25 s limit after 1 finished steps, while running step 2 of 4 (dynamical) | -` and `demo.wl finished steps: pendulum PASS.` (wording since corrected to "1 finished step").
- Summary in that run: `... demo.wl TIMEOUT, timed out after 1 finished steps while running dynamical, no step skipped.` (same correction).
- The demo line also gives the demo's GIF failures ("passed 0/4, GIF failed in 4 (WAV written)").

## Files changed
- stem-core/src/export.wl, stem-core/src/accessibility.wl, stem-core/src/runapp.wl, stem-core/tests/test_gifsync.wl.
- demo.wl, tools/smoke_test.wl.
- All 32 main.wl files (one line, `STEMExitStatus[];`, with a comment): asteroids, bayes, bell, blackbody, brownian, cellular, clt, compton, cosmology, dynamical, fluid, grover, henon, hydrogen, images, lagrange, lorenz, magnetic, mandelbrot, montecarlo, pendulum, primes, quantum, quantum_statistics, quantum_tunnelling, qubit, relativity, resonance, scattering, signal, thermo, waves.
- AGENTS.md, stem-core/AGENTS.md, README.md.
- New: docs/VERIFICATION_linux_gif.md.

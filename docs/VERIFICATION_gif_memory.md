# GIF export memory, smoke test evidence, write path: verification (measured 2026-10-15)

## Context
- Acts on docs/smoke_test_Linux-x86-64_2026-10-13.txt and docs/smoke_test_Linux-x86-64_2026-10-14.txt (Ubuntu 26.04.1, Wolfram Engine 15.0.0 x86-64, 14 GB RAM, /tmp a 7.5 GB tmpfs): compton scatter's GIF failed with Export::fmterr twice (the export and the diagnostic retry); the run on the 13th ended in a kernel segmentation fault.
- Repo HEAD bd072ea (main); every change is uncommitted, as asked.
- Machine for every measurement: macOS 26.7.1, Apple silicon, 32 GB RAM, Wolfram Engine 15.0.1; no Linux machine here.
- Memory figures are the kernel process's resident set size (ps -o rss), sampled every 50 ms (stage runs) or 1 s (smoke runs); MaxMemoryUsed is not used for totals because it counts only kernel-tracked memory, not the GIF library's own allocations (it reported 0 MB for GIFWrite).
- Scripts (session scratchpad, not in the repo): capture_graphics.wl (saves the frames an app hands to ExportGIF, before rasterising), rss_stages.wl + run_rss.sh (stage markers + external RSS sampler; mode old loads HEAD's export.wl), stages.wl, proto.wl, loop.wl, lowlevel.wl, lowlevel2.wl, full_smoke.sh.
- Harness note: wolframscript drops a --flag argument that follows positional script arguments, so app arguments reach capture_graphics.wl through CAP_ARGS (`CAP_ARGS="--simulation.mode=lyapunov" wolframscript -file capture_graphics.wl -- dynamical dynamical_lyapunov`).

## Part 2: where the memory goes (old ExportGIF, one Export of all frames)
- Command: `run_rss.sh pendulum_double old` (500 frames, 960x932 px).
- pendulum, RSS with the frames loaded: 326 MB.
- pendulum, rasterise (STEMRasterize per frame): 4.3 s, peak 1587 MB.
- pendulum, conformFrames: 0.2 s, peak 2420 MB.
- pendulum, quantise (GIFTools`GIFImageQuantize per frame, then Normal of every frame's indices to integer lists and NumericArray): 13.2 s, peak 10540 MB.
- pendulum, write (GIFTools`GIFWrite): 1.0 s, peak 2561 MB.
- Command: `run_rss.sh compton_scatter old` (78 frames, 920x920 px).
- compton, rasterise: 0.7 s, peak 485 MB.
- compton, conformFrames: 0.0 s, peak 504 MB.
- compton, quantise: 1.8 s, peak 1766 MB.
- compton, write: 0.2 s, peak 703 MB.
- Kernel-tracked only (`stages.wl`, MaxMemoryUsed, relative to the start of each stage): quantum quantise +1759 MB, whole Export +2794 MB; compton quantise +558 MB, whole Export +937 MB; GIFWrite 0 MB (library memory is not tracked).
- Where the multiple goes: quantizeImages (System`Convert`CommonGraphicsExportDump) quantises every frame, then builds NumericArray[First @* Normal /@ rawData]: every frame's index data as 64-bit integer lists at once (8 bytes a pixel, 3.6 GB for pendulum), plus the quantiser's per-frame results.
- All frames of every captured set have one size (compton 920x920, quantum 1200x600, pendulum 960x932), Byte RGB with alpha, so conformFrames pads nothing.

## Part 2: the reduction
- GIFTools exposes no streaming or append call: its export functions $WriteFrames and $WriteColormaps take all frames at once (SystemFiles/Links/GIFTools/Kernel/GIFTools.wl).
- The GIF format allows splicing: Export writes no global colour table and no comment block; the header, screen descriptor and NETSCAPE loop block come once, then each frame is a Graphic Control Extension plus an image with its own local colour table (block walk of pendulum's GIF: 500 GCE + 500 image blocks).
- ExportGIF now rasterises and exports the frames in chunks of at most $STEMGIFChunkPixels = 24,000,000 pixels (never a one-frame chunk) and splices the chunk files: header of the first, frame blocks of all, one trailer 0x3B.
- Fallback to one Export: frames of another size than the first (Export would pad all to the largest), a chunk header that differs, the legacy numeric frame-rate form, lists that fit in one chunk.
- Chunk counts: compton 3 (28 frames each), quantum 8 (33), pendulum 20 (26), mandelbrot 3 (58), dynamical sweep 30 (23, from its diagnostics line).
- Option 3 (8-bit frames, a shared palette) was not needed.

### Peak and wall time, old (HEAD) vs new, same captured frames
- Command: `run_rss.sh <set> old` and `run_rss.sh <set> new`; RSS with the frames loaded 315 to 321 MB in every run.
- pendulum double, old: peak 10256 MB, 18.8 s.
- pendulum double, new: peak 684 MB, 18.5 s.
- quantum qho, old: peak 4275 MB, 44.1 s.
- quantum qho, new: peak 591 MB, 39.8 s.
- mandelbrot mandelbrot, old: peak 1780 MB, 6.5 s.
- mandelbrot mandelbrot, new: peak 823 MB, 6.5 s.
- dynamical lyapunov, old: peak 12818 MB, 30.5 s.
- dynamical lyapunov, new: peak 662 MB, 29.9 s.

### Byte identity
- Reference GIFs: written by the unchanged code (HEAD) in the capture runs.
- New code, same frames (rss_stages.wl, ReadByteArray comparison): identical for pendulum, quantum, mandelbrot, dynamical lyapunov.
- New code, app runs: `cmp pendulum/output/double_animation.gif ref` identical, 4790709 bytes (full smoke run).
- `cmp mandelbrot/output/mandelbrot_mandelbrot.gif ref` identical, 10178371 bytes (full smoke run).
- `cmp compton/output/scatter.gif ref` identical, 596468 bytes (full smoke run).
- `wolframscript -file quantum/main.wl` then `cmp quantum/output/qho_density.gif ref`: identical, 3583496 bytes (after the smoke run the file differed because demo.wl runs quantum with alpha=3.0 afterwards and overwrites it).
- `wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov` then `cmp dynamical/output/lyapunov.gif ref`: identical, 19221409 bytes.
- Unit tests (stem-core/tests/test_gifsync.wl, 9 new): 11 frames with a small chunk budget make chunks of 3, 3, 3, 2 frames; a trailing one-frame chunk joins the one before; the spliced file is byte-identical to one Export; no part files are left; 11 frames of 0.1 s read back; mixed sizes fall back with the same bytes; a failure inside a chunked export is reported with its message and no part files.

### Memory requirement (full smoke test with demo.wl, new code)
- Command: `full_smoke.sh` (wolframscript -file tools/smoke_test.wl, kernel RSS sampled each second, tagged with the running app).
- Run 1: overall peak 5.17 GB; waves 5.17 GB, dynamical 5.01 GB, demo.wl 3.36 GB, fluid 3.25 GB.
- Run 2: overall peak 5.96 GB; waves 5.96 GB, dynamical 5.36 GB, demo.wl 3.36 GB, fluid 3.16 GB.
- The peak is no longer a GIF export: waves (its finite-element solve) leads.
- README Supported section: peak 5.2 to 6.0 GB, so 8 GB of RAM is the minimum.
- On the 14 GB Linux VM the old export of dynamical lyapunov alone (12.8 GB on the Mac) would leave about 1 GB; a plausible cause of the segmentation fault on the 13th, not confirmed.
- Compton's export (old peak 1.77 GB, 0.6 MB file) is not explained by memory on a 14 GB machine early in the run; its cause remains open (see Part 3).

## Part 1: evidence kept by the smoke test
- Per-app logs: STEMRunApp option "LogFile" sends the app's console output and its messages ($Output and $Messages) to the file through the output stream method "STEMFlushed" (BinaryWrite and Flush on every write); the file is kept.
- Flush test: lines were on disk before Close, and a line written just before Quit[3] was on disk after the kernel exited.
- Log directory: smoke_logs_<SystemID>_<date>/<app>.txt next to the report (demo.wl: demo.txt); 33 files in the full run.
- The report is written line by line through the same stream method (it used to be exported once at the end).
- Messages section: for every app that failed or issued a message, the status, message count and log path, the messages, "GIF lines from the log" (diagnostics, [GIF FAILED], retry) and "the 20 log lines before the first message".
- Environment block, new lines on the Mac: `Memory: 32 GB total, 19.08 GB available (MemoryAvailable[])`.
- `Free space: 1388.19 GB on the output volume (/Users/mintaccess/Projects/stem, apfs); 1388.19 GB in $TemporaryDirectory (/private/var/folders/jc/bmdfzv5n78g7f6tqdt9d1b500000gn/T, apfs)`.
- `Per-app console logs: /Users/mintaccess/Projects/stem/smoke_logs_MacOSX-ARM64_2026-10-15`.
- On Linux only (not run here): MemAvailable from /proc/meminfo, `Kernel overcommit (/proc/sys/vm/overcommit_memory): <n> (<meaning>)`, `Core dumps (/proc/sys/kernel/core_pattern): <pattern>`; file system from `df -PT`.
- Windows file system from `(Get-Volume -FilePath <dir>).FileSystemType`: not run here.
- Forced failure with diagnostics (`STEM_GIF_DIAG=1 wolframscript -file force_smoke.wl -- smoke`, every GIF Export failing, smoke --quick): exit 1; dynamical's Messages entry, as written:
- `dynamical (GIF FAILED, 2 messages; full log smoke_logs_MacOSX-ARM64_forced/dynamical.txt):`
- `  GIF diagnostics before exporting sweep.gif: free space 1388.48 GB in the temporary directory (...) and 1388.48 GB in the output directory; MemoryInUse 1.08 GB, MemoryAvailable 18.01 GB; 677 frames of 1200x840 px, rasterised about 1.91 GB in all, exported in 30 chunk(s); open-file limit unlimited.`
- `  [GIF FAILED] dynamical: the GIF .../dynamical/output/sweep.gif (677 frames, 1200x840 px) was not written; the first message was: Export::fmterr : Invalid GIF format. ...`
- `  GIF diagnostics: one retry after a 2 s pause failed too (Export::fmterr : Invalid GIF format); ...`
- followed by `the 20 log lines before the first message (Export::fmterr: Invalid "GIF" format.):` and those 20 lines.
- STEMRunApp registers "STEMFlushed" once per kernel (each app run reloads stem-core; registering again raised DefineOutputStreamMethod::name in the first test run).

### --resume after a kernel crash
- Command: smoke --quick to a scratch report, `kill -9` of the kernel while images ran (after henon's line): first run exit code 137.
- The report as left: environment block and the lines of dynamical and henon.
- images.txt as left: 22 lines, ending in the middle of images' sonification step.
- Command: `wolframscript -file tools/smoke_test.wl -- --quick --resume --out=<report>` -> exit 0; console `--resume: 2 app lines kept from <report>`; images, mandelbrot, pendulum, signal and demo.wl run.
- Report line: `[INTERRUPTED] the previous run stopped while images was running; its log up to that point is smoke_logs_MacOSX-ARM64_crash/images.interrupted.txt, and images is run again.`
- images.interrupted.txt is byte-identical to the log at the kill (cmp).
- Final report: 6 app lines in order, demo.wl OK 4/4, Summary unchanged in form.
- Without --out, --resume picks the newest smoke_test_<SystemID>_*.txt in the repository root.

## Part 3: the write path
- Command: `wolframscript -file loop.wl` (compton's 78 frames, rasterised once, 200 exports to one path each way).
- (a) ExportGIF, existing file deleted first, chunked: 0 of 200 returned $Failed, 0 differed from the reference, 0 messages, 389 s.
- (b) Export over the existing file, no delete: 0 of 200 returned $Failed, 0 differed, 0 messages, 392 s.
- (c) Export with the previous file open in a Wolfram read stream (BinaryReadList, then GIFFrameDelays): 200 of 200 returned $Failed with Export::noopen and OpenAppend::aofil (Wolfram refuses to write a file it has open); no Export::fmterr.
- stem-core never leaves a GIF open: GIFFrameDelays uses ReadByteArray and the smoke test BinaryReadList, both of which close the file.
- GIFTools write function (GIFTools.wl): GIFWrite calls the LibraryLink function $WriteColormaps inside Quiet @ Catch; Export turns any failure into Export::fmterr (validateResultFromLowLevel).
- GIFTools.dylib (macOS ARM64 build; the Linux build is not installed here) imports: fopen, fdopen, open, fwrite, fread, fclose, close, malloc, calloc, realloc, new/delete.
- No temporary file: no mkstemp, tmpfile, tmpnam, getenv, rename or unlink among the imports.
- No thread pool: no pthread, dispatch, OpenMP or std::thread symbols among the imports.
- Locale: std::locale appears only through iostream and std::to_string, used for message text; the GIF bytes (delays as integer centiseconds, indices, colour tables) do not pass through formatted output.
- Stack: the library imports __chkstk_darwin, so some function has a stack frame over one page or of variable size; whether that is proportional to the frame size cannot be read from the binary.
- The library is giflib-based: its strings include "GIFLIB operation failed.", "Failed to write to given file", "Failed to allocate required memory", "Could not open GIF file.", "Could not close GIF file.".
- New: while ExportGIF runs, a temporary rule on GIFTools`GIFWrite (Internal`InheritedBlock) records a failed result and the [GIF FAILED] sentence adds "The GIF library reported: ...".
- Test, 64 KB free on a 64 MB volume (`lowlevel.wl`): `[GIF FAILED] compton: ... the first message was: Export::fmterr : Invalid GIF format. The GIF library reported: An error occurred in the library function. (FunctionError). ...`
- The Failure object carries only the generic LibraryLink text and tag (FunctionError), not giflib's own message (`lowlevel2.wl`, InputForm of the result; $LastFailureParameters unset); a memory failure would carry a different LibraryLink tag.
- With 512 KB free the chunked export wrote its parts and failed at the splice: `BinaryWrite::errwstrm: Could not write to stream ...`, reported the same way.
- Segmentation fault: README Linux entry now says where the crashed app's log is, where the core file lands (core_pattern, apport /var/crash, coredumpctl) and to run `gdb -batch -ex bt <WolframKernel binary> <core>` if gdb is present, then --resume.

## Verification
- `wolframscript -file tools/smoke_test.wl` (full, Mac): exit 0; `Summary: 32 of 32 apps wrote a WAV; every GIF export succeeded; demo.wl OK, 33/33 runs passed, no step skipped.`; Messages: none; pendulum frame check PASS (worst margins 119, 37, 30, 30 px).
- Diff with smoke_test_MacOSX-ARM64_2026-10-14.txt (times masked): the three new environment lines; demo.wl 502.5 s vs 497.5 s; asteroids 24.12 s vs 25.46 s, peak -0.4 vs -0.68 dBFS, intro no vs yes (live NASA data for a different week; asteroids has no narration, the intro column is a silence heuristic).
- The full run was done twice: a stray `smoke_test.wl -- --help` call (no such option) started a second run that overwrote the first report and part of its logs; it was stopped and the full run repeated; the figures above are from the repeat, the first run's memory peaks are kept as Run 1.
- `wolframscript -file stem-core/tests/test_gifsync.wl` -> 54 passed, 0 failed.
- `wolframscript -file stem-core/tests/test_loudness.wl` -> 31 passed, 0 failed.
- `wolframscript -file stem-core/tests/test_platform.wl` -> 21 passed, 0 failed.
- `wolframscript -file stem-core/tests/test_speech.wl` -> 27 passed, 0 failed.

## Files changed
- stem-core/src/export.wl, stem-core/src/runapp.wl, stem-core/tests/test_gifsync.wl, tools/smoke_test.wl.
- README.md, AGENTS.md, stem-core/AGENTS.md, .gitignore (smoke_logs_*/).
- New: docs/VERIFICATION_gif_memory.md.
- Not changed: docs/smoke_test_Linux-x86-64_2026-10-14.txt (yours, untracked), docs/STATE_supporting_apps.md.

# Platform naming, supported platforms, Windows leftovers: verification (measured 2026-10-11)

## Context
- Repo HEAD 7a84146 (main); every change is uncommitted, as asked.
- Machine for every measurement: macOS 26.7.1 on Apple silicon, Wolfram Engine 15.0.1 for Mac OS X ARM (64-bit).
- No PowerShell on this Mac (`which pwsh powershell`: not found), so the live Windows branch of STEMPlatformDescription[] was not run; its string mapping is unit-tested with fixed inputs.

## Part 1: STEMPlatformDescription[]
- New module stem-core/src/platform.wl, loaded by stem-core/init.wl after hilbert.wl; no other module depends on it.
- macOS: `sw_vers -productVersion`; major 26 Tahoe, 15 Sequoia, 14 Sonoma; other majors print without a name.
- Windows: one PowerShell call reads CurrentBuildNumber and DisplayVersion (ReleaseId if DisplayVersion is absent) from HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion; `cmd /c ver` supplies the build if PowerShell fails.
- Windows product: build >= 22000 is Windows 11, 10240 to 19045 is Windows 10, anything else prints as plain "Windows"; no build gives "(build unknown)".
- Linux: PRETTY_NAME from /etc/os-release without quotes, `uname -r` as the kernel; no os-release gives "Linux".
- Architecture is $ProcessorType (the engine's), so the x64 engine under Parallels emulation reports x86-64.
- The live result is computed once per kernel (memoised).
- Line produced on the Mac: `macOS 26.7.1 (Tahoe) on ARM64`.
- Command: `wolframscript -code 'Get["stem-core/init.wl"]; Print[STEMPlatformDescription[]]'` -> macOS 26.7.1 (Tahoe) on ARM64.
- Expected on the Windows test VM (from the 2026-10-10 report's NT 10.0.26200): `Windows 11 25H2 (build 26200) on x86-64`, if the registry DisplayVersion is 25H2; not run here.
- demo.wl: the `$osVersion` block (sw_vers / uname -sr / PowerShell OSVersion.VersionString, which printed "Microsoft Windows NT 10.0.26200.0") is removed; the System line is now `- Operating system: <STEMPlatformDescription[]>`.
- tools/smoke_test.wl: `SystemID: ..., OperatingSystem: ...` replaced by `Operating system: <description>; SystemID: <SystemID>` (SystemID kept: it names the report file).
- Other places that print the OS: none found (`grep -rn 'osVersion\|$OperatingSystem\|$SystemID\|sw_vers\|uname' --include='*.wl' .`); demo_html.wl and demo_outreach.wl use $OperatingSystem only to choose an open command.
- New test stem-core/tests/test_platform.wl: 6 macOS cases, 9 Windows cases, 3 Linux cases, 3 checks on the live string (contains " on ", no "Windows NT", not a bare version number).
- Command: `wolframscript -file stem-core/tests/test_platform.wl` -> Results: 21 passed, 0 failed (exit 0).
- Documented in AGENTS.md (API table, test list) and stem-core/AGENTS.md (load order, module section, dependency graph; the graph also gains the missing hilbert.wl row).

## Part 2: Supported platforms in the README
- New section "## Supported platforms" directly after the introduction, before "Repository layout".
- Supported: macOS 26 on Apple silicon with Wolfram Engine 15.0.1, linked to docs/smoke_test_MacOSX-ARM64_2026-10-07.txt.
- Supported: Windows 11 x86-64 with Wolfram Engine 15.0.0, linked to docs/smoke_test_Windows-x86-64_2026-10-10.txt and docs/demo_report_Windows-x86-64_2026-10-11.md; Parallels on Apple silicon, x64 engine under emulation.
- "About three times slower": demo.wl 1700 s on Windows vs 537 s on the Mac (3.2x); the 31 apps common to both smoke reports, asteroids excluded, 2074.8 s vs 589.0 s (3.5x).
- Pending: Linux x86-64 (Ubuntu), to be added when its smoke report exists in docs/.
- Not supported: Linux on ARM, worded as "Wolfram offers no general Linux-ARM build (only a Raspberry Pi package, untested here)": a web search found Wolfram's Raspberry Pi ARM64 package, so "not available" would be inaccurate.
- Not supported: Wolfram Engine before 15, untested.
- Voice note: Samantha on macOS, SLT on Windows (the 2026-10-10 Windows smoke report's voice line), so narration length differs; GIF/WAV sync verified on every run by SyncWAVToGIF.
- Badge: now "Wolfram Engine | supported platforms" linking to #supported-platforms instead of repeating versions.
- Prerequisites "Tested on ..." paragraph replaced by one sentence pointing to the section, plus the smoke test pointer.
- Caveat: the Mac smoke report linked (2026-10-07) predates the 2026-10-09 voice and report changes; today's Mac run is --quick only (6 apps), so it is not filed in docs/.

## Part 3: Windows leftovers
- README Quick start Windows notes: now "four ways"; new bullet: `wolframscript -code` strips double quotes from its argument on Windows, so code with quoted strings goes in a .wl file run with -file.
- README: removed the stale "Not yet run on a Windows machine (docs/PORTABILITY_AUDIT.md, B4)" from the Paths bullet.
- asteroids/README.md: after the NASA_API_KEY block, one line: the error sentence reports the key's length (never the key); NASA keys are 40 characters.
- docs/voiceover-wolframscript-guide.md Troubleshooting: the same line; `$NASAAPIKEY` corrected to NASA_API_KEY (or DEMO_KEY).
- tools/smoke_test.wl: the SpeechSynthesize["Test."] probe retries once and reports "returns audio (x s)", "returned audio on the second attempt (x s); the first attempt gave $Failed" or "no audio on either of two attempts (...)".
- Probe branches checked by replacing SpeechSynthesize in a Block (fails once, then audio; always fails): both sentences printed as above.

## Part 4: Windows reports filed
- `cp ~/Downloads/smoke_test_Windows-x86-64_2026-10-10.txt docs/smoke_test_Windows-x86-64_2026-10-10.txt` (run started 2026-10-10 23:19; 32 of 32 apps, demo.wl 33/33, no messages).
- `cp ~/Downloads/demo-report.md docs/demo_report_Windows-x86-64_2026-10-11.md` (generated Sun 11 Oct 2026 00:33:37 by the same run).
- Copied, not moved: the originals stay in ~/Downloads.
- The 2026-10-09 pair is unchanged in docs/ as the record of the first run.
- The filed 2026-10-10 demo report still says "Windows: Microsoft Windows NT 10.0.26200.0": it predates Part 1 and is kept as produced.

## Verification runs (Mac)
- Command: `wolframscript -file tools/smoke_test.wl -- --quick` -> exit 0, smoke_test_MacOSX-ARM64_2026-10-11.txt (repo root, gitignored).
- Environment line: `Operating system: macOS 26.7.1 (Tahoe) on ARM64; SystemID: MacOSX-ARM64`.
- Environment line: `SpeechSynthesize["Test."]: returns audio (0.5 s)` (first attempt succeeded).
- Summary: `6 of 6 apps wrote a WAV; demo.wl OK, 4/4 runs passed, no step skipped.`; Messages: none.
- demo/demo-report.md written by that run, System section: `- Wolfram Language: 15.0.1 for Mac OS X ARM (64-bit) (July 2, 2026)` and `- Operating system: macOS 26.7.1 (Tahoe) on ARM64`.
- Command: `for t in stem-core/tests/test_*.wl; do wolframscript -file $t; done` -> test_gifsync 31/31, test_loudness 31/31, test_platform 21/21, test_speech 27/27; all exit 0.

## Files changed
- Modified: AGENTS.md, README.md, asteroids/README.md, demo.wl, docs/voiceover-wolframscript-guide.md, stem-core/AGENTS.md, stem-core/init.wl, tools/smoke_test.wl.
- New: stem-core/src/platform.wl, stem-core/tests/test_platform.wl, docs/smoke_test_Windows-x86-64_2026-10-10.txt, docs/demo_report_Windows-x86-64_2026-10-11.md, docs/VERIFICATION_platform_naming.md.
- Untouched: docs/STATE_supporting_apps.md (still untracked).

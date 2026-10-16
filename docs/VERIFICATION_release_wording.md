# Release v1.6.0 wording corrections (2026-10-17)

Text edits only; no code changed; nothing committed. Repo HEAD eb61918 (main), with the uncommitted v1.6.0 close-out in the working tree.

## 1. lyapunov_window preset
- File: RELEASE_NOTES_v1.6.0.md
- Old: "A `lyapunov_window` preset zooms in on the period-3 window."
- New: "The `lyapunov_window` preset covers r = 3.40 to 3.90, from the last period doublings through the onset of chaos to the period-3 window."
- Range checked in dynamical/src/model.wl: "lyapunov_window" -> <|"r_min" -> 3.40, "r_max" -> 3.90, "steps" -> 500, "duration_seconds" -> 40.0, ...|>.

## 2. iterate presets
- File: RELEASE_NOTES_v1.6.0.md
- Old: "New `iterate` presets (extinction, growth, fixed_point, period2, period4, period3_window, chaos) give the talk one file per regime, named after the preset so two presets in a row no longer overwrite each other (dynamical/VERIFICATION_polish_feigenbaum.md)."
- New: "Two new iterate presets, extinction (r = 0.8) and growth (r = 2.0), join the five existing ones, and each preset's files are now named after it, so two presets in a row no longer overwrite each other (dynamical/VERIFICATION_polish_feigenbaum.md)."
- The presets live in $dynamicalPresets in dynamical/src/model.wl (dynamical/config.wl does not exist; dynamical/config.json holds only "preset": "").
- Command: `git show 7c236c5:dynamical/src/model.wl > model_v151.wl`, then `wolframscript -code 'Get["model_v151.wl"]; Print["7c236c5: ", KeyValueMap[#1 -> #2["r"] &, $dynamicalPresets]]; ClearAll[$dynamicalPresets]; Get["dynamical/src/model.wl"]; Print["now:     ", KeyValueMap[#1 -> Lookup[#2, "r", Missing[]] &, $dynamicalPresets]]'`
- Output: `7c236c5: {fixed_point -> 2.8, period2 -> 3.2, period4 -> 3.5, period3_window -> 3.83, chaos -> 4.}`
- Output: `now:     {extinction -> 0.8, growth -> 2., fixed_point -> 2.8, period2 -> 3.2, period4 -> 3.5, period3_window -> 3.83, chaos -> 4.}`

## 3. lyapunov paragraph, two added sentences
- File: RELEASE_NOTES_v1.6.0.md
- Old: (none; added after "... equals the console's (dynamical/VERIFICATION_lyapunov_mode.md).")
- New: "At each period doubling the tone rises to meet the reference and falls back without crossing it, because λ is exactly zero at a bifurcation; the dips below the reference that come later are the periodic windows, which the console lists with their periods, 6, 5 and 3 (dynamical/VERIFICATION_polish_feigenbaum.md)."
- Citation: dynamical/VERIFICATION_polish_feigenbaum.md instead of dynamical/VERIFICATION_lyapunov_mode.md, which holds the crossings (r 3.626/3.634, 3.739/3.744, 3.829/3.848) but neither statement; polish_feigenbaum holds the narration "It touches zero at each doubling: 3, 3.449 and 3.544. Later dips are windows of order." and the console's window list ("... it is the period-6 window", "... the period-5 window", "... the period-3 window").

## 4. Linux GIF errors, cause not isolated
- File: RELEASE_NOTES_v1.6.0.md
- Old: "The Linux failures that this machinery was built to catch, an intermittent GIF export error and a run that stopped in the frame check, are kept in `docs/` with their reports."
- New: the same sentence, followed by "For the GIF errors, the export's memory was cut by an order of magnitude and the errors stopped; the library's own reason was never captured (docs/VERIFICATION_linux_gif.md)."

## 5. README, Linux crash bullet
- File: README.md
- Old: "If the kernel crashes on Linux (segmentation fault), the smoke report ends at the last finished app, `smoke_logs_<SystemID>_<date>_<HHMM>/<app>.txt` holds the crashing app's output up to the crash, and the core file goes where the report's "Core dumps" line (`/proc/sys/kernel/core_pattern`) says (on Ubuntu usually `/var/crash/*.crash` from apport, or `coredumpctl` with systemd-coredump); a stack trace from `gdb -batch -ex bt <WolframKernel binary> <core>`, if gdb is present, is what to report; then continue with `tools/smoke_test.sh --resume`."
- New: "Ubuntu's apport does not keep crash reports for Wolfram Engine; the report's last line, written by the wrapper, is where a crash shows, and `tools/smoke_test.sh --resume` continues the run."
- After the edit `grep -n 'coredumpctl\|/var/crash' README.md` finds nothing.

## 6. Mac reference report
- Command: `cp smoke_test_MacOSX-ARM64_2026-10-16_1344.txt docs/` then `cmp` of the two files: identical (copied unchanged); docs/smoke_test_MacOSX-ARM64_2026-10-07.txt kept, neither report edited.
- File: README.md
- Old: "([smoke report](docs/smoke_test_MacOSX-ARM64_2026-10-07.txt))."
- New: "([smoke report](docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt))."
- File: docs/VERIFICATION_release_v1.6.0.md
- Old: "- Mac reference: smoke_test_MacOSX-ARM64_2026-10-16_1344.txt (full run, docs/VERIFICATION_smoke_wrapper.md)."
- New: "- Mac reference: docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt (full run, docs/VERIFICATION_smoke_wrapper.md; filed in docs/ unchanged on 2026-10-17, see docs/VERIFICATION_release_wording.md)."
- File: docs/VERIFICATION_release_v1.6.0.md
- Old: "- The macOS entry still links docs/smoke_test_MacOSX-ARM64_2026-10-07.txt (before this round's changes); the current full Mac report (2026-10-16_1344) is in the repository root, gitignored, not filed."
- New: "- The macOS entry links docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt, the full Mac run of 2026-10-16 (filed 2026-10-17); docs/smoke_test_MacOSX-ARM64_2026-10-07.txt is kept."
- File: docs/RELEASE_NOTES_v1.6.0_EVIDENCE.md (the report was not cited there by path; added to the platforms line)
- Old: "docs/VERIFICATION_smoke_wrapper.md (Mac full run)."
- New: "docs/VERIFICATION_smoke_wrapper.md and docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt (Mac full run, the reference for the speed ratios)."
- `git status --short` after the copy:
- ` M .gitignore`
- ` M README.md`
- ` M demo_html.wl`
- ` M tools/smoke_test.ps1`
- ` M tools/smoke_test.sh`
- `?? RELEASE_NOTES_v1.6.0.md`
- `?? docs/RELEASE_NOTES_v1.6.0_EVIDENCE.md`
- `?? docs/STATE_supporting_apps.md`
- `?? docs/VERIFICATION_release_v1.6.0.md`
- `?? docs/demo_report_Linux-x86-64_2026-10-16.md`
- `?? docs/smoke_test_Linux-x86-64_2026-10-16_1719.txt`
- `?? docs/smoke_test_Linux-x86-64_2026-10-16_1848.txt`
- `?? docs/smoke_test_MacOSX-ARM64_2026-10-16_1344.txt`

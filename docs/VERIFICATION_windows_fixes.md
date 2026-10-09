# Fixes from the Windows test: verification (measured 2026-10-09)

## Context
- Acts on docs/smoke_test_Windows-x86-64_2026-10-09.txt and docs/demo_report_Windows-x86-64_2026-10-09.md. Repo HEAD 219a2e7 (main); every change is uncommitted, as asked.
- Machine for every measurement here: macOS, Wolfram 15.0.1 for Mac OS X ARM (64-bit). The PowerShell and espeak-ng branches were changed but not run (no Windows or Linux here).
- Baseline = `git archive HEAD` unpacked in the scratchpad ("base"); after = the working tree.

## Part 1: explicit English narration voice
- SpeechSynthesize[]: the voice is chosen by name from VoiceStyleData[] (cached per kernel): Samantha, then Daniel, then the first en-US/en-GB voice by name with female before male, then any English voice. A failed synthesis is retried once.
- say: say -v ? is parsed; Samantha, then Daniel, then the first en_ voice by name; with none, say is skipped and one sentence says so. PowerShell: the first installed en-US voice by name (GetInstalledVoices), then en-GB; none: skipped with one sentence. espeak-ng/espeak: -v en.
- Config: simulation.speech.voice and simulation.speech.rate_wpm, read by LoadConfig into $STEMSpeechConfig, so no app changed. STEM_SPEECH=platform|synthesize|off forces a tier (STEM_SPEECH_OFF=1 still works).
- VoiceStyleData[] on the Mac: 367 voices, 87 English; first call 1.78 s, cached call 0.02 s; no progress lines printed.
- Which named voice equals SpeechSynthesize[]'s default: all 87 English voices tested on "Each note is one year." (AudioData identical): Samantha only. The rule picks Samantha first, so the default config keeps the Mac narration unchanged.
- Command: `wolframscript -file t1.wl` (STEMSpeakToBuffer on "This is the end of the Hénon attractor." vs SpeechSynthesize[] with no voice, resampled the same way): 87480 samples, identical: True
- Command: `wolframscript -file henon/main.wl -- --simulation.mode=attractor` in base and in the working tree, then `cmp`: henon_attractor.wav byte-identical
- henon intro before: holds 18.17 s of spoken intro; after: holds 18.17 s of spoken intro
- henon prints once: `Narration voice: Samantha (en-US, female) through SpeechSynthesize[], chosen automatically, at the voice's own rate.`
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window` in base and in the working tree, then `cmp`: lyapunov_window_audio.wav byte-identical
- dynamical intro before: holds 24.73 s of spoken intro; after: holds 24.73 s of spoken intro
- dynamical prints once: `Narration voice: Samantha (en-US, female) through SpeechSynthesize[], chosen automatically, at the voice's own rate.`
- Forced say tier (`STEM_SPEECH=platform`, t1.wl): `Narration voice: Samantha (en_US) through the macOS say command, chosen automatically, at the voice's own rate.`; 87480 samples, the same length as `say -v Samantha -f t.txt -o s.aiff` run directly (43740 samples at 22050 Hz). Before this change the say tier used the system default voice, Viktor (Enhanced), German.
- henon --simulation.speech.voice=Daniel: `Narration voice: Daniel (en-GB, male) through SpeechSynthesize[], set by simulation.speech.voice, at the voice's own rate.`
- henon --simulation.speech.voice=Daniel: `Timing: the WAV holds 18.77 s of spoken intro and a 0.4 s pause, then 10 s of notes from 19.17 s, then a 0.4 s pause and 1.99 s of spoken outro, 31.57 s in total.`
- henon --simulation.speech.rate_wpm=220: `Narration voice: Samantha (en-US, female) through SpeechSynthesize[], chosen automatically, time-stretched to 220 words per minute.`
- henon --simulation.speech.rate_wpm=220: `Timing: the WAV holds 17.49 s of spoken intro and a 0.4 s pause, then 10 s of notes from 17.89 s, then a 0.4 s pause and 1.91 s of spoken outro, 30.2 s in total.`
- rate_wpm, first version: each clip was stretched by its own words per minute, which failed (at 220 wpm the henon intro went 18.17 -> 11.73 s, the outro 1.98 -> 2.18 s, because "1.40" is one word but four spoken ones). Now one factor per voice from a fixed calibration sentence without numbers; intro and outro both shrink by 0.963. The henon run above predates the sentence naming the calibration rate (about 212 wpm for Samantha, from 18.17 / 17.49 x 220).

## Part 1: speech rate on the Mac (for the Windows "Test." 1.32 s vs 0.50 s)
- Command: `wolframscript -file rate.wl` (leading/trailing silence = samples with |x| < 1e-3 at the ends)
- SpeechSynthesize Samantha | "Test." | 1 words | 0.502 s total | leading silence 0 s | trailing silence 0.025 s | 119.5 wpm over the whole clip | 125.8 wpm over the speech
- SpeechSynthesize Samantha | "The logistic map gives next year's population from this year's. The population x is a fraction of the maximum, and r, the growth rate, is 4." | 26 words | 8.627 s total | leading silence 0 s | trailing silence 0.026 s | 180.8 wpm over the whole clip | 181.4 wpm over the speech
- say Samantha (via STEMSpeakToBuffer) | "Test." | 1 words | 0.502 s total | leading silence 0 s | trailing silence 0.025 s | 119.5 wpm over the whole clip | 125.8 wpm over the speech
- say Samantha (via STEMSpeakToBuffer) | "The logistic map gives next year's population from this year's. The population x is a fraction of the maximum, and r, the growth rate, is 4." | 26 words | 8.627 s total | leading silence 0 s | trailing silence 0.026 s | 180.8 wpm over the whole clip | 181.4 wpm over the speech
- On the Mac "Test." is 0.502 s with 0.025 s of trailing silence, and a 26-word narration sentence runs at 181 words per minute. Windows reported 1.32 s for "Test." from SpeechSynthesize[] with its default voice; the next Windows smoke report prints the chosen voice, so the comparison can then be made voice for voice.

## Part 1: SpeechSynthesize[] fails intermittently on the Mac
- Fresh-kernel trials of SpeechSynthesize["Each note is one year."]: default voice 3 of 3 returned audio; named Samantha 3 of 3; VoiceStyleData[] then named Samantha 2 of 3. Earlier single trials: VoiceStyleData[] then default voice failed once and worked once.
- In the working-tree smoke run, the environment probe SpeechSynthesize["Test."] returned no audio ("no audio (Symbol)"), while every app in the same run narrated normally.
- Without a retry, such a failure dropped that sentence to say with the German default voice. That is the likely cause (not proven) of the unexplained run-to-run intro-length differences in docs/VERIFICATION_speech_encoding.md and docs/VERIFICATION_portability_mac.md. The helper now retries once, and the say fallback is English.

## Part 1: stem-core speech tests
- Command: `wolframscript -file stem-core/tests/test_speech.wl` -> exit 0
- PASS  equal rates return the data unchanged
- PASS  22050 -> 44100 doubles the length and keeps the end points
- PASS  the tool was called with -f <file>
- PASS  the text itself was not passed as an argument
- PASS  the file holds the text as UTF-8 (Hénon = 48 C3 A9 6E 6F 6E)
- PASS  audio came back (36884 samples at 44.1 kHz)
- PASS  the temporary text and audio files were deleted
- PASS  STEMSpeakToBuffer returns the same samples as the platform tier
- PASS  one random draw per platform call (seeded runs stay reproducible)
- PASS  STEMSpeechAvailable[] is False with every tool missing and SpeechSynthesize[] off
- PASS  returns {} when no tier produces audio
- PASS  prints exactly one warning line
- PASS  the warning names the app
- PASS  the warning names the tiers tried
- PASS  the warning states the narration lost (35 words at 175 wpm = 12 s)
- PASS  the warning is one sentence (ends with a full stop, no full stop inside)
- PASS  the narration text is still printed
- PASS  a WAV built around the empty narration exports and imports (1 s of notes)
- PASS  SpeechSynthesize[] gets an English voice by name (Samantha, en-US)
- PASS  on the Mac that voice is Samantha, the voice SpeechSynthesize[] uses by default
- PASS  a configured voice that exists is used as given
- PASS  say gets an English voice from say -v ?, never the system default (Samantha, en_US)
- PASS  STEM_SPEECH=platform skips SpeechSynthesize[] and say reads it (50076 samples)
- PASS  one sentence names the voice and the tier: Narration voice: Samantha (en_US) through the macOS say command, chosen automatically, at the voice's own rate.
- PASS  simulation.speech.rate_wpm 240 makes say faster (3.29 s -> 2.54 s)
- PASS  STEMSpeechAvailable[] is False
- PASS  returns {} and warns once, naming the switch
- Results: 27 passed, 0 failed.

## Part 2: documentation and playback
- README prerequisites: the Windows row "Windows Media Player, built into Windows 10/11" is now "PowerShell `Media.SoundPlayer`, built in, plays a WAV in the terminal".
- README: one sentence added: audio plays only from an interactive desktop session; over SSH the commands run but nothing is heard.
- README tested line and badge: macOS Wolfram Engine 15.0.1 (MacOSX-ARM64) and Windows 11 on Apple silicon via Parallels with the x64 Wolfram Engine 15.0.0 under emulation (Windows-x86-64), 32 of 32 apps; Linux untested.
- STEMPlayCmd (the closing "Play audio:" hint, 48 call sites) on Windows: `STEMPlayCmd["C:\stem\henon\output\h.wav", "Windows"]` -> `(New-Object Media.SoundPlayer "C:\stem\henon\output\h.wav").PlaySync()` (new optional platform argument, because $OperatingSystem cannot be blocked).
- demo.wl audio guide (demo-report.md) and listening block (demo/README.md) now use the running platform: afplay on macOS, aplay on Linux, PowerShell Media.SoundPlayer with $PWD on Windows. Windows forms: `(New-Object Media.SoundPlayer "$PWD\demo\henon\output\henon_attractor.wav").PlaySync()`; wildcard `Get-ChildItem demo\asteroids\output\*.wav | ForEach-Object { (New-Object Media.SoundPlayer $_.FullName).PlaySync() }`; fence ```powershell
- Start-Process wmplayer replaced in asteroids, cellular, dynamical, hydrogen, images, lorenz, primes, quantum, relativity, signal and stem-core READMEs and docs/voiceover-wolframscript-guide.md; pendulum/README.md and relativity/README.md wording; dated records (archive, audit, demo_report_Windows-x86-64_2026-10-09.md) left as written.

## Part 3: demo report, lines that changed (demo.wl --quick)
- Command: `wolframscript -file demo.wl -- --quick` in base and in the working tree, `diff` of demo/demo-report.md (changed timings left out):
- `-- Wolfram Language: 15.`
- `+- Wolfram Language: 15.0.1 for Mac OS X ARM (64-bit) (July 2, 2026)`
- `-- **Duration:** 26. s`
- `-- **Duration:** 22. s`
- `-| `lyapunov_window_audio.wav` | 14.2 MB |`
- `-| `lyapunov_window_data.csv` | 52. KB |`
- `-| `lyapunov_window.gif` | 19.7 MB |`
- `-| `life_rpentomino_animation.gif` | 2. MB |`
- `-| `life_rpentomino_audio.wav` | 3. MB |`
- `+| `life_rpentomino_animation.gif` | 2 MB |`
- `+| `life_rpentomino_audio.wav` | 3 MB |`
- `-All audio files are in `demo/<app>/output/`. Play them with:`
- `+All audio files are in `demo/<app>/output/`. The commands below are for macOS, the platform this report was made on; run them from the repository root, in an interactive desktop session (audio does not play over SSH).`
- `-- Windows: `Start-Process wmplayer demo\<app>\output\<file>.wav``
- `+- Windows PowerShell: `(New-Object Media.SoundPlayer "$PWD\demo\<app>\output\<file>.wav").PlaySync()``
- `-afplay demo/dynamical/output/lyapunov_window_audio.wav`
- Full run, working tree (`wolframscript -file demo.wl`, NASA_API_KEY set): 33 passed; dynamical sweep lists 3 files (sweep_audio.wav, sweep_data.csv, sweep.gif), dynamical iterate 3 (iterate_period3_window_*), lorenz 3 (rossler_*). On Windows the second dynamical run listed 6 files (its own plus the first run's) and lorenz listed 6, including older lorenz_* files.
- Full report numbers ending in a bare dot (". s", ". MB", ". KB", "15."): 0
- full report system line: `- Wolfram Language: 15.0.1 for Mac OS X ARM (64-bit) (July 2, 2026)`
- full report system line: `- macOS: 26.7.1`

## Part 3: smoke test, lines that changed (tools/smoke_test.wl --quick)
- Command: `wolframscript -file tools/smoke_test.wl -- --quick --out=<file>` in base and in the working tree; diff without timings:
- `-SpeechSynthesize["Test."]: returns audio (0.5 s)`
- `+SpeechSynthesize["Test."]: no audio (Symbol)`
- `+Narration voice for SpeechSynthesize[]: Samantha (en-US, female), chosen automatically; English voices listed: 87`
- `+Narration voice for say: Samantha (en_US), chosen automatically`
- `+demo.wl skipped steps: no step skipped.`
- `-Summary: 6 of 6 apps wrote a WAV; demo.wl OK.`
- `+Summary: 6 of 6 apps wrote a WAV; demo.wl OK, 4/4 runs passed, no step skipped.`
- Live check of the skip sentence: STEMRunApp on the full demo.wl with NASA_API_KEY unset, then the smoke test's parser on its log: `status OK; passed {32/33}; skipped steps: asteroids, because NASA_API_KEY not set`

## Files changed
- M AGENTS.md
- M README.md
- M asteroids/README.md
- M cellular/README.md
- M demo.wl
- M docs/voiceover-wolframscript-guide.md
- M dynamical/README.md
- M hydrogen/README.md
- M images/README.md
- M lorenz/README.md
- M pendulum/README.md
- M primes/README.md
- M quantum/README.md
- M relativity/README.md
- M signal/README.md
- M stem-core/AGENTS.md
- M stem-core/README.md
- M stem-core/config.wl
- M stem-core/src/accessibility.wl
- M stem-core/src/speech.wl
- M stem-core/tests/test_speech.wl
- M tools/smoke_test.wl
- ?? docs/demo_report_Windows-x86-64_2026-10-09.md
- ?? docs/smoke_test_Windows-x86-64_2026-10-09.txt
- ?? s.aiff
- ?? docs/VERIFICATION_windows_fixes.md

# dynamical/ divergence mode — verification (measured 2026-09-24)

## Context
- Repo HEAD: 596aab4 (main); divergence-mode changes uncommitted. wolframscript on Mac OS X ARM.
- Every value below comes from a run made on 2026-09-24 in this session, after the last code change (later edits touched docs only).
- Measurement scripts (session scratchpad, not in the repo): measure_div.py (Python: wave for WAV duration, PIL for GIF frame delays, soundfile + pyloudnorm for loudness and peak, soundfile int16 read for the left/right comparison, the exported CSV for separations and note mapping).
- Mapping's audible resolution: one quantisation step of the note mapping — 1/15 of the x range in pitch (one of 16 scale degrees, bin 0.0667) and 1/15 of the shared maximum step size in volume (16 levels); the resolution is the smaller of the two, in x units.
- A separation above the resolution always changes the note; a smaller one changes it only when the two values straddle a rounding boundary.
- Sample layout: note n starts at WAV sample intro_samples + n x 3528 (0.08 s at 44100 Hz); intro_samples = 1408870 in all five files.

## Commands
- Default: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence`
- divergence_chaotic: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_chaotic`
- divergence_edge: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_edge`
- divergence_periodic: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_periodic`
- divergence_stable: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_stable`
- File measurements: `python3 measure_div.py divergence divergence_chaotic divergence_edge divergence_periodic divergence_stable`
- Tests: `wolframscript -file dynamical/tests/test_model.wl`
- Regression: `wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov`
- Regression: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate`

## Default mode (r = 4.0, chaotic)
- Exit code: 0
- Output WAV: dynamical/output/divergence_audio.wav
- WAV duration (Python wave): 60.2056 s
- GIF frames: 301
- GIF frame delay: 0.20 s
- GIF duration (PIL): 60.2000 s
- GIF minus WAV: -0.0056 s
- App's sync sentence: "GIF/WAV sync: the GIF has 301 frames of 0.2 s each and plays for 60.2 s, the WAV plays for 60.206 s, and the GIF is 0.006 s shorter than the WAV."
- Integrated loudness (stem-core, app's loudness line): -17 LUFS
- Integrated loudness (pyloudnorm): -17.04 LUFS
- Peak: -2.20 dBFS
- Saturation iteration measured (first n with separation > 0.1): 18
- Saturation iteration predicted (Log[0.1/1e-6]/lambda): 16.6
- Saturation marker: 440 Hz at 1.44 s into the sonified part (18 x 0.08 s)
- Fit range: iterations 0 to 18
- Fitted slope: 0.6709 per iteration
- Predicted lambda (LyapunovExponent[r, 0.3, 1000, 10000, -100]): 0.6931
- Ratio fitted / predicted: 0.968
- Maximum separation: 0.993, at iteration 136
- Mapping resolution: 0.0667 (pitch bin 0.0667 in x, volume bin 0.0667 in step size)
- First iteration with separation >= resolution: 16 (separation 0.07113)
- First iteration with different notes (CSV): 15, pitch differs (separation 0.02644, 0.40 of a bin)
- Iteration 15 values: x 0.17695, y 0.15051; scaled 15x + 1 = 3.654 rounds to degree 4, 15y + 1 = 3.258 rounds to degree 3; the boundary x = 0.1667 lies between them
- First differing WAV sample: 1461791 = intro_samples + 15 x 3528 + 1 (at a note's first sample its sine is 0, so both channels still agree there)
- Left and right channels sample-identical before that sample: yes (iterations 0 to 14, 1461791 samples)
- Identity up to the resolution iteration (16): no, it ends one iteration earlier, at 15, by a rounding-boundary straddle at 0.40 of a bin

## Preset divergence_chaotic (r = 4.0, chaotic)
- Exit code: 0
- Output WAV: dynamical/output/divergence_chaotic_audio.wav
- WAV duration (Python wave): 60.2056 s
- GIF frames: 301
- GIF frame delay: 0.20 s
- GIF duration (PIL): 60.2000 s
- GIF minus WAV: -0.0056 s
- App's sync sentence: "GIF/WAV sync: the GIF has 301 frames of 0.2 s each and plays for 60.2 s, the WAV plays for 60.206 s, and the GIF is 0.006 s shorter than the WAV."
- Integrated loudness (stem-core, app's loudness line): -17 LUFS
- Integrated loudness (pyloudnorm): -17.04 LUFS
- Peak: -2.20 dBFS
- Saturation iteration measured (first n with separation > 0.1): 18
- Saturation iteration predicted (Log[0.1/1e-6]/lambda): 16.6
- Saturation marker: 440 Hz at 1.44 s into the sonified part (18 x 0.08 s)
- Fit range: iterations 0 to 18
- Fitted slope: 0.6709 per iteration
- Predicted lambda (LyapunovExponent[r, 0.3, 1000, 10000, -100]): 0.6931
- Ratio fitted / predicted: 0.968
- Maximum separation: 0.993, at iteration 136
- Mapping resolution: 0.0667 (pitch bin 0.0667 in x, volume bin 0.0667 in step size)
- First iteration with separation >= resolution: 16 (separation 0.07113)
- First iteration with different notes (CSV): 15, pitch differs (separation 0.02644, 0.40 of a bin)
- Iteration 15 values: x 0.17695, y 0.15051; scaled 15x + 1 = 3.654 rounds to degree 4, 15y + 1 = 3.258 rounds to degree 3; the boundary x = 0.1667 lies between them
- First differing WAV sample: 1461791 = intro_samples + 15 x 3528 + 1 (at a note's first sample its sine is 0, so both channels still agree there)
- Left and right channels sample-identical before that sample: yes (iterations 0 to 14, 1461791 samples)
- Identity up to the resolution iteration (16): no, it ends one iteration earlier, at 15, by a rounding-boundary straddle at 0.40 of a bin
- divergence_chaotic WAV byte-identical to the default WAV: yes

## Preset divergence_edge (r = 3.57, edge)
- Exit code: 0
- Output WAV: dynamical/output/divergence_edge_audio.wav
- WAV duration (Python wave): 60.2056 s
- GIF frames: 301
- GIF frame delay: 0.20 s
- GIF duration (PIL): 60.2000 s
- GIF minus WAV: -0.0056 s
- App's sync sentence: "GIF/WAV sync: the GIF has 301 frames of 0.2 s each and plays for 60.2 s, the WAV plays for 60.206 s, and the GIF is 0.006 s shorter than the WAV."
- Integrated loudness (stem-core, app's loudness line): -17 LUFS
- Integrated loudness (pyloudnorm): -17.04 LUFS
- Peak: -5.55 dBFS
- Saturation iteration measured: none, the separation never exceeded 0.1 in 150 iterations
- Saturation iteration predicted: 1070 (beyond the 150 computed)
- Final separation: 0.000132
- Fit range: iterations 0 to 150
- Fitted slope: 0.01376 per iteration
- Predicted lambda (LyapunovExponent[r, 0.3, 1000, 10000, -100]): 0.01076
- Ratio fitted / predicted: 1.28
- Maximum separation: 0.000319, at iteration 142
- Mapping resolution: 0.0367 (pitch bin 0.0667 in x, volume bin 0.0367 in step size)
- First iteration with separation >= resolution: none
- First iteration with different notes (CSV): none
- Left and right channels sample-identical over the whole WAV: yes (2655067 of 2655067 samples)

## Preset divergence_periodic (r = 3.2, periodic)
- Exit code: 0
- Output WAV: dynamical/output/divergence_periodic_audio.wav
- WAV duration (Python wave): 60.2056 s
- GIF frames: 301
- GIF frame delay: 0.20 s
- GIF duration (PIL): 60.2000 s
- GIF minus WAV: -0.0056 s
- App's sync sentence: "GIF/WAV sync: the GIF has 301 frames of 0.2 s each and plays for 60.2 s, the WAV plays for 60.206 s, and the GIF is 0.006 s shorter than the WAV."
- Integrated loudness (stem-core, app's loudness line): -17 LUFS
- Integrated loudness (pyloudnorm): -17.04 LUFS
- Peak: -5.49 dBFS
- Saturation iteration measured: none, the separation never exceeded 0.1 in 150 iterations
- Saturation iteration predicted: none (lambda negative)
- Final separation: exactly 0, reached at iteration 42
- Fit range: iterations 0 to 31
- Fitted slope: -0.3997 per iteration
- Predicted lambda (LyapunovExponent[r, 0.3, 1000, 10000, -100]): -0.9163
- Ratio fitted / predicted: 0.436
- Maximum separation: 6.81e-6, at iteration 13
- Mapping resolution: 0.0248 (pitch bin 0.0667 in x, volume bin 0.0248 in step size)
- First iteration with separation >= resolution: none
- First iteration with different notes (CSV): none
- Left and right channels sample-identical over the whole WAV: yes (2655067 of 2655067 samples)

## Preset divergence_stable (r = 2.8, stable)
- Exit code: 0
- Output WAV: dynamical/output/divergence_stable_audio.wav
- WAV duration (Python wave): 60.2056 s
- GIF frames: 301
- GIF frame delay: 0.20 s
- GIF duration (PIL): 60.2000 s
- GIF minus WAV: -0.0056 s
- App's sync sentence: "GIF/WAV sync: the GIF has 301 frames of 0.2 s each and plays for 60.2 s, the WAV plays for 60.206 s, and the GIF is 0.006 s shorter than the WAV."
- Integrated loudness (stem-core, app's loudness line): -17 LUFS
- Integrated loudness (pyloudnorm): -17.03 LUFS
- Peak: -3.54 dBFS
- Saturation iteration measured: none, the separation never exceeded 0.1 in 150 iterations
- Saturation iteration predicted: none (lambda negative)
- Final separation: exactly 0, reached at iteration 102
- Fit range: iterations 0 to 61
- Fitted slope: -0.2245 per iteration
- Predicted lambda (LyapunovExponent[r, 0.3, 1000, 10000, -100]): -0.2231
- Ratio fitted / predicted: 1.01
- Maximum separation: 1.12e-6, at iteration 1
- Mapping resolution: 0.0192 (pitch bin 0.0667 in x, volume bin 0.0192 in step size)
- First iteration with separation >= resolution: none
- First iteration with different notes (CSV): none
- Left and right channels sample-identical over the whole WAV: yes (2655067 of 2655067 samples)

## Same length of the four presets
- WAV durations: 60.2056 s, 60.2056 s, 60.2056 s, 60.2056 s
- GIF durations: 60.2 s each, 301 frames
- Speech slots (longest of the four presets' texts): intro 31.55 s, outro 15.78 s

## Correctness checks (identical in all seven main.wl runs)
- Summary line: "Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS] 5[PASS] 6[PASS]"
- Check 1: "1. Feigenbaum ratio: 4.7514  (delta = 4.6692, 1.761% error)"
- Check 2: "2. Fixed point (r=2.8): analytic 0.642857  numeric 0.642857"
- Check 3: "3. Period-2 (r=3.2): 2 distinct values, sum 1.3125 (expected 1.3125)"
- Check 4: "4. Lyapunov (r=4.0): 0.693116  (log 2 = 0.693147, 0.004498% error)"
- Check 5a: "[PASS] At r = 2.8 the Lyapunov exponent is -0.223144 and the fixed-point value Log[0.8] is -0.223144; they differ by 5.55*^-16, within the tolerance of 0.01."
- Check 5b: "[PASS] At r = 3.2 the Lyapunov exponent is -0.916291 and the closed-form period-2 value 0.5 Log|f'(x1) f'(x2)| is -0.916291; they differ by 1.11*^-16, within the tolerance of 0.01."
- Check 5c: "[PASS] At r = 3.835 the Lyapunov exponent is -0.309518, and inside the period-3 window it must be negative; it is."
- Check 5d: "[PASS] At r = 4 the Lyapunov exponent is 0.693076 and the fully chaotic value Log[2] is 0.693147; they differ by 0.0000714, within the tolerance of 0.01."
- Check 6a: "[PASS] At r = 4 two orbits started 1.*^-6 apart separate with a fitted slope of 0.6709 per iteration (iterations 0 to 18) and LyapunovExponent predicts 0.6931; they differ by 3.2 percent, within the tolerance of 25 percent."
- Check 6b: "[PASS] At r = 2.8 two orbits started 1.*^-6 apart converge with a fitted slope of -0.2245 per iteration (iterations 0 to 61) and LyapunovExponent predicts -0.2231; they differ by 0.6 percent, within the tolerance of 25 percent."

## Unit tests
- Result: "Results: 77 passed, 0 failed."
- Exit code: 0
- Tests before this change: 60
- New tests: 17 (divergence mode)

## Regression
- lyapunov exit code: 0
- lyapunov WAV duration: 154.3 s
- lyapunov first upward crossing: r = 3.570, 108.45 s into the audio
- lyapunov sync sentence: "GIF/WAV sync: the GIF has 309 frames of 0.5 s each and plays for 154.5 s, the WAV plays for 154.296 s, and the GIF is 0.204 s longer than the WAV."
- lyapunov loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -9.21 dBFS."
- lyapunov values equal to VERIFICATION_lyapunov_mode.md: yes (duration, crossing, sync, loudness, peak)
- iterate exit code: 0
- iterate WAV duration: 32.55 s
- iterate sync sentence: "GIF/WAV sync: the GIF has 148 frames of 0.22 s each and plays for 32.56 s, the WAV plays for 32.553 s, and the GIF is 0.007 s longer than the WAV."

# dynamical/ polish and Feigenbaum convergence — verification (measured 2026-10-06)

## Context
- Repo HEAD: 68b80a1 (main); this work and the previous narration work are uncommitted, as asked. wolframscript on Mac OS X ARM; speech from macOS say.
- Every value below comes from runs made in this session after the last code change.
- "Before" values: a lyapunov run on the code as it was at the start of this session (before.log), and the divergence_edge run of the previous narration round (VERIFICATION_narration.md).
- Durations from the files: WAV = Python wave frames / rate; GIF = sum of PIL frame durations; sync difference = GIF minus WAV. Loudness = pyloudnorm integrated LUFS; peak = max |sample| in dBFS.
- Intro and outro lengths come from the app's Timing line (speech buffer lengths that are joined into the WAV).

## Commands
- sweep: `wolframscript -file dynamical/main.wl`
- iterate: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate`
- iterate_fixed_point: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=fixed_point`
- iterate_growth: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=growth`
- lyapunov: `wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov`
- lyapunov_window: `wolframscript -file dynamical/main.wl -- --simulation.mode=lyapunov --simulation.dynamical.preset=lyapunov_window`
- divergence: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence`
- divergence_edge: `wolframscript -file dynamical/main.wl -- --simulation.mode=divergence --simulation.dynamical.preset=divergence_edge`
- Tests: `wolframscript -file dynamical/tests/test_model.wl`
- Run script: p2/run.sh (scratchpad; runs the commands above in this order, removing the two preset file sets first); report: p2/report.py

## Part 2: new check 1 output (sweep run; identical in all 8 runs, see below)
- "Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS] 5[PASS] 6[PASS]"
- "1a. The period-doubling points, located by bisection where the cycle's multiplier reaches -1 (each to a half-width below 9.9*^-13 in r), are r1 = 3.0000000 (period 2 born), r2 = 3.4494897 (period 4 born), r3 = 3.5440904 (period 8 born), r4 = 3.5644073 (period 16 born), r5 = 3.5687594 (period 32 born)."
- "1b. delta_1 = (r2 - r1) / (r3 - r2) = 4.75145, which is 0.0822 above 4.669201609 (1.76 percent)."
- "1c. delta_2 = (r3 - r2) / (r4 - r3) = 4.65625, which is 0.013 below 4.669201609 (0.277 percent)."
- "1d. delta_3 = (r4 - r3) / (r5 - r4) = 4.66824, which is 0.000959 below 4.669201609 (0.0205 percent)."
- "1e. [PASS] The differences from the Feigenbaum constant shrink at every step (0.0822, 0.013, 0.000959), so the ratios approach the constant, and delta_3 is 0.0205 percent from it, within the tolerance of 0.5 percent. The constant itself is the limit of these ratios; no finite ratio equals it."
- Expected values in the brief: r1..r5 = 3, 3.449490, 3.544090, 3.564407, 3.568759; delta = 4.7514, 4.6562, 4.6683. Computed r1..r5 agree to all 7 printed decimals; delta_2 = 4.656251 and delta_3 = 4.668242 round to 4.6563 and 4.6682, one unit in the fourth decimal from the brief's figures.
- r5 resolved: yes; every point bisected to a half-width below 1e-12 in r (requirement: at least 1e-7). r6 = 3.5696916 and r7 = 3.5698913 also resolve with the same code (prototype run, not part of the check).
- Pass rule: delta_3 within 0.5 percent of 4.669201609 and |delta_k - delta| strictly decreasing.

## Checks 2 to 6, before and after
- Before: "2. Fixed point (r=2.8): analytic 0.642857  numeric 0.642857"
- Before: "3. Period-2 (r=3.2): 2 distinct values, sum 1.3125 (expected 1.3125)"
- Before: "4. Lyapunov (r=4.0): 0.693116  (log 2 = 0.693147, 0.004498% error)"
- Before: "5a. [PASS] At r = 2.8 the Lyapunov exponent is -0.223144 and the fixed-point value Log[0.8] is -0.223144; they differ by 5.55*^-16, within the tolerance of 0.01."
- Before: "5b. [PASS] At r = 3.2 the Lyapunov exponent is -0.916291 and the closed-form period-2 value 0.5 Log|f'(x1) f'(x2)| is -0.916291; they differ by 1.11*^-16, within the tolerance of 0.01."
- Before: "5c. [PASS] At r = 3.835 the Lyapunov exponent is -0.309518, and inside the period-3 window it must be negative; it is."
- Before: "5d. [PASS] At r = 4 the Lyapunov exponent is 0.693076 and the fully chaotic value Log[2] is 0.693147; they differ by 0.0000714, within the tolerance of 0.01."
- Before: "6a. [PASS] At r = 4 two orbits started 1.*^-6 apart separate with a fitted slope of 0.6709 per iteration (iterations 0 to 18) and LyapunovExponent predicts 0.6931; they differ by 3.2 percent, within the tolerance of 25 percent."
- Before: "6b. [PASS] At r = 2.8 two orbits started 1.*^-6 apart converge with a fitted slope of -0.2245 per iteration (iterations 0 to 61) and LyapunovExponent predicts -0.2231; they differ by 0.6 percent, within the tolerance of 25 percent."
- Checks 2 to 6 print identically to before in all 8 runs: yes
- Summary line before: "Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS] 5[PASS] 6[PASS]"; after: "Checks: 1[PASS] 2[PASS] 3[PASS] 4[PASS] 5[PASS] 6[PASS]"
- Check 1 before: "1. Feigenbaum ratio: 4.7514  (delta = 4.6692, 1.761% error)"
- New check 1 lines identical in all runs: yes

## sweep
- Exit code: 0; wall time 79 s
- Files: dynamical/output/sweep_audio.wav, dynamical/output/sweep.gif
- WAV duration (file): 338.2852 s
- GIF duration (file): 338.50 s, 677 frames of 0.50 s
- Sync difference GIF minus WAV: +0.2148 s
- App sync line: "GIF/WAV sync: the GIF has 677 frames of 0.5 s each and plays for 338.5 s, the WAV plays for 338.285 s, and the GIF is 0.215 s longer than the WAV."
- Loudness (pyloudnorm): -17.05 LUFS integrated; peak -1.13 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -1.13 dBFS."
- Intro 14.37 s of speech, notes 320 s, outro 3.11 s of speech, total 338.29 s
- Narration convention warnings: 0

## iterate
- Exit code: 0; wall time 23 s
- Files: dynamical/output/iterate_audio.wav, dynamical/output/iterate.gif
- WAV duration (file): 46.2121 s
- GIF duration (file): 46.19 s, 149 frames of 0.31 s
- Sync difference GIF minus WAV: -0.0221 s
- App sync line: "GIF/WAV sync: the GIF has 149 frames of 0.31 s each and plays for 46.19 s, the WAV plays for 46.212 s, and the GIF is 0.022 s shorter than the WAV."
- Loudness (pyloudnorm): -17.03 LUFS integrated; peak -4.79 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -4.79 dBFS."
- Intro 10.46 s of speech, notes 24.08 s, outro 10.87 s of speech, total 46.21 s
- Narration convention warnings: 0

## iterate_fixed_point
- Exit code: 0; wall time 23 s
- Files: dynamical/output/iterate_fixed_point_audio.wav, dynamical/output/iterate_fixed_point.gif
- WAV duration (file): 48.6184 s
- GIF duration (file): 48.64 s, 152 frames of 0.32 s
- Sync difference GIF minus WAV: +0.0216 s
- App sync line: "GIF/WAV sync: the GIF has 152 frames of 0.32 s each and plays for 48.64 s, the WAV plays for 48.618 s, and the GIF is 0.022 s longer than the WAV."
- Loudness (pyloudnorm): -17.05 LUFS integrated; peak -2.92 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -2.92 dBFS."
- Intro 12.78 s of speech, notes 24.08 s, outro 10.96 s of speech, total 48.62 s
- Narration convention warnings: 0

## iterate_growth
- Exit code: 0; wall time 26 s
- Files: dynamical/output/iterate_growth_audio.wav, dynamical/output/iterate_growth.gif
- WAV duration (file): 49.5705 s
- GIF duration (file): 49.50 s, 150 frames of 0.33 s
- Sync difference GIF minus WAV: -0.0705 s
- App sync line: "GIF/WAV sync: the GIF has 150 frames of 0.33 s each and plays for 49.5 s, the WAV plays for 49.57 s, and the GIF is 0.07 s shorter than the WAV."
- Loudness (pyloudnorm): -17.05 LUFS integrated; peak -2.96 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -2.96 dBFS."
- Intro 13.32 s of speech, notes 24.08 s, outro 11.37 s of speech, total 49.57 s
- Narration convention warnings: 0

## lyapunov
- Exit code: 0; wall time 53 s
- Files: dynamical/output/lyapunov_audio.wav, dynamical/output/lyapunov.gif
- WAV duration (file): 155.3747 s
- GIF duration (file): 155.50 s, 311 frames of 0.50 s
- Sync difference GIF minus WAV: +0.1253 s
- App sync line: "GIF/WAV sync: the GIF has 311 frames of 0.5 s each and plays for 155.5 s, the WAV plays for 155.375 s, and the GIF is 0.125 s longer than the WAV."
- Loudness (pyloudnorm): -17.04 LUFS integrated; peak -9.20 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -9.2 dBFS."
- Intro 19.81 s of speech, notes 120 s, outro 14.77 s of speech, total 155.37 s
- Narration, intro: "Here r runs from 2.5 to 4. The steady tone is zero, the moving tone the Lyapunov exponent: chaos above, order below. It touches zero at each doubling: 3, 3.449 and 3.544. Later dips are windows of order. Beating means a crossing; short high tones mark bifurcations."
- Narration, outro: "End: chaos from 3.57; widest windows period 6 from 3.626 to 3.634, 5 from 3.739 to 3.744 and 3 from 3.829 to 3.848."
- Narration convention warnings: 0

## lyapunov_window
- Exit code: 0; wall time 46 s
- Files: dynamical/output/lyapunov_window_audio.wav, dynamical/output/lyapunov_window.gif
- WAV duration (file): 75.4328 s
- GIF duration (file): 75.50 s, 302 frames of 0.25 s
- Sync difference GIF minus WAV: +0.0672 s
- App sync line: "GIF/WAV sync: the GIF has 302 frames of 0.25 s each and plays for 75.5 s, the WAV plays for 75.433 s, and the GIF is 0.067 s longer than the WAV."
- Loudness (pyloudnorm): -17.04 LUFS integrated; peak -7.31 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -7.31 dBFS."
- Intro 19.81 s of speech, notes 40 s, outro 14.83 s of speech, total 75.43 s
- Narration, intro: "Here r runs from 3.4 to 3.9. The steady tone is zero, the moving tone the Lyapunov exponent: chaos above, order below. It touches zero at each doubling: 3.449 and 3.544. Later dips are windows of order. Beating means a crossing; short high tones mark bifurcations."
- Narration, outro: "End: chaos from 3.57; widest windows period 6 from 3.627 to 3.633, 5 from 3.738 to 3.743 and 3 from 3.829 to 3.849."
- Narration convention warnings: 0

## divergence
- Exit code: 0; wall time 52 s
- Files: dynamical/output/divergence_audio.wav, dynamical/output/divergence.gif
- WAV duration (file): 65.0207 s
- GIF duration (file): 65.12 s, 296 frames of 0.22 s
- Sync difference GIF minus WAV: +0.0993 s
- App sync line: "GIF/WAV sync: the GIF has 296 frames of 0.22 s each and plays for 65.12 s, the WAV plays for 65.021 s, and the GIF is 0.099 s longer than the WAV."
- Loudness (pyloudnorm): -17.04 LUFS integrated; peak -1.80 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -1.8 dBFS."
- Intro 11.53 s of speech, notes 40 s, outro 8.88 s of speech (padded to 12.69 s), total 65.02 s
- Narration, intro: "Two populations start one part in a million apart, one in each ear; the middle tone is their distance. The chaotic case, r equals 4: the tone climbs to a high marker at iteration 18."
- Narration, outro: "End of the chaotic case: the separation passed one tenth at iteration 18, and the Lyapunov exponent predicted iteration 16.6."
- Narration convention warnings: 0

## divergence_edge
- Exit code: 0; wall time 82 s
- Files: dynamical/output/divergence_edge_audio.wav, dynamical/output/divergence_edge.gif
- WAV duration (file): 65.0207 s
- GIF duration (file): 65.12 s, 296 frames of 0.22 s
- Sync difference GIF minus WAV: +0.0993 s
- App sync line: "GIF/WAV sync: the GIF has 296 frames of 0.22 s each and plays for 65.12 s, the WAV plays for 65.021 s, and the GIF is 0.099 s longer than the WAV."
- Loudness (pyloudnorm): -17.04 LUFS integrated; peak -5.84 dBFS
- App loudness line: "Loudness: the WAV was normalised to -17 LUFS and measures -17 LUFS integrated, with a peak of -5.84 dBFS."
- Intro 10.82 s of speech (padded to 11.53 s), notes 40 s, outro 12.69 s of speech, total 65.02 s
- Narration, intro: "Two populations start one part in a million apart, one in each ear; the middle tone is their distance. The edge of chaos, r equals 3.57: the tone barely rises."
- Narration, outro: "End of the edge of chaos: the separation never exceeded one tenth; its maximum was 2.6 times ten to the minus 4, because the Lyapunov exponent, 0.011, is so small."
- Narration convention warnings: 0

## Part 1a: lyapunov narration, old and new
- Old intro (lyapunov default): 38.7 s of speech: "Lyapunov exponent of the logistic map, r from 2.5 to 4. The steady tone is zero. The moving tone is the Lyapunov exponent. Above the steady tone the orbit is chaotic, and nearby starting points separate exponentially. Below it they converge. On the way up, the moving tone comes up to the steady tone and falls away again at each period doubling, at r equals 3, 3.449 and 3.544, because the exponent is exactly zero at a bifurcation. Each later dip below the steady tone is a window of order inside the chaos. Beating between the two tones means a crossing is near. Short high tones mark the bifurcation points."
- Old outro (lyapunov default): 24.94 s of speech: "End of the Lyapunov sweep from r equals 2.5 to 4. The exponent first rose above zero at r equals 3.570, where chaos begins. The widest windows of order were from r equals 3.626 to 3.634, period 6; from 3.739 to 3.744, period 5; and from 3.829 to 3.848, period 3."
- New intro (lyapunov default): 19.81 s of speech (limit 20 s): "Here r runs from 2.5 to 4. The steady tone is zero, the moving tone the Lyapunov exponent: chaos above, order below. It touches zero at each doubling: 3, 3.449 and 3.544. Later dips are windows of order. Beating means a crossing; short high tones mark bifurcations."
- New outro (lyapunov default): 14.77 s of speech (limit 15 s): "End: chaos from 3.57; widest windows period 6 from 3.626 to 3.634, 5 from 3.739 to 3.744 and 3 from 3.829 to 3.848."
- New intro (lyapunov_window): 19.81 s; new outro (lyapunov_window): 14.83 s
- Facts kept in the intro: what the two tones are (steady tone zero, moving tone the Lyapunov exponent), which side is chaotic (chaos above, order below), touching zero at each doubling with r = 3, 3.449, 3.544, later dips are windows of order, beating means a crossing, short high tones mark bifurcations. The r range is said once, in the intro; the outro does not repeat it (tested).
- Facts kept in the outro: end marker, onset of chaos (r = 3.57), the three widest windows with both bounds and their periods.

## Part 1b: preset-named iterate files
- After the fixed_point run (`ls -l`):
  - 1416550 Oct 6 21:36 dynamical/output/iterate_fixed_point.gif
  - 8576336 Oct 6 21:36 dynamical/output/iterate_fixed_point_audio.wav
  - 18464 Oct 6 21:36 dynamical/output/iterate_fixed_point_data.csv
- After the growth run that followed it (`ls -l`):
  - 1374387 Oct 6 21:36 dynamical/output/iterate.gif
  - 8151856 Oct 6 21:36 dynamical/output/iterate_audio.wav
  - 1416550 Oct 6 21:36 dynamical/output/iterate_fixed_point.gif
  - 8576336 Oct 6 21:36 dynamical/output/iterate_fixed_point_audio.wav
  - 18464 Oct 6 21:36 dynamical/output/iterate_fixed_point_data.csv
  - 1323525 Oct 6 21:37 dynamical/output/iterate_growth.gif
  - 8744272 Oct 6 21:37 dynamical/output/iterate_growth_audio.wav
  - 10207 Oct 6 21:37 dynamical/output/iterate_growth_data.csv
- Both presets' files exist after running two presets in a row: yes
- iterate_fixed_point app line: "Audio: 48.62 s — /Users/mintaccess/Projects/stem/dynamical/output/iterate_fixed_point_audio.wav"
- iterate_growth app line: "Audio: 49.57 s — /Users/mintaccess/Projects/stem/dynamical/output/iterate_growth_audio.wav"
- iterate app line: "Audio: 46.21 s — /Users/mintaccess/Projects/stem/dynamical/output/iterate_audio.wav"
- Scripts updated: demo.wl now expects output/iterate_period3_window_audio.wav, .gif and _data.csv; experiments.wl already names its iterate runs iterate_<preset>, so it writes the same names.

## Part 1c: divergence edge outro
- Old (from VERIFICATION_narration.md, previous round): "End of the edge of chaos: the separation reached only 9.1 times ten to the minus 6, as the small Lyapunov exponent, 0.011, predicted."
- New: "End of the edge of chaos: the separation never exceeded one tenth; its maximum was 2.6 times ten to the minus 4, because the Lyapunov exponent, 0.011, is so small."
- Console: "The maximum separation reached is 0.000259, at iteration 110."
- New edge outro length: 12.69 s of speech (old 10.78 s)

## Part 1d: lyapunov window list
- lyapunov: "The onset of chaos: the Lyapunov exponent first crosses zero upward at r = 3.570, heard 105.82 s into the audio."
- lyapunov: "A window of order at r = 3.589 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.002 in r and 0.16 s in the audio; it is heard from 107.35 s, and its period was not identified."
- lyapunov: "A window of order at r = 3.605 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.002 in r and 0.16 s in the audio; it is heard from 108.57 s, and its period was not identified."
- lyapunov: "A window of order runs from r = 3.626 to r = 3.634, 0.0074 wide in r and 0.6 s long in the audio from 110.29 s, and it is the period-6 window."
- lyapunov: "A window of order runs from r = 3.739 to r = 3.744, 0.0048 wide in r and 0.38 s long in the audio from 119.32 s, and it is the period-5 window."
- lyapunov: "A window of order runs from r = 3.829 to r = 3.848, 0.0196 wide in r and 1.57 s long in the audio from 126.51 s, and it is the period-3 window."
- lyapunov: "A window of order at r = 3.854 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.002 in r and 0.16 s in the audio; it is heard from 128.48 s, and its period was not identified."
- lyapunov: "A window of order at r = 3.906 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.002 in r and 0.16 s in the audio; it is heard from 132.64 s, and it is the period-5 window."
- lyapunov_window: "The onset of chaos: the Lyapunov exponent first crosses zero upward at r = 3.570, heard 33.81 s into the audio."
- lyapunov_window: "A window of order at r = 3.582 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 34.76 s, and its period was not identified."
- lyapunov_window: "A window of order at r = 3.605 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 36.59 s, and its period was not identified."
- lyapunov_window: "A window of order runs from r = 3.627 to r = 3.633, 0.0062 wide in r and 0.5 s long in the audio from 38.34 s, and it is the period-6 window."
- lyapunov_window: "A window of order at r = 3.663 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 41.17 s, and its period was not identified."
- lyapunov_window: "A window of order at r = 3.703 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 44.41 s, and its period was not identified."
- lyapunov_window: "A window of order runs from r = 3.738 to r = 3.743, 0.005 wide in r and 0.4 s long in the audio from 47.26 s, and it is the period-5 window."
- lyapunov_window: "A window of order at r = 3.801 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 52.26 s, and its period was not identified."
- lyapunov_window: "A window of order runs from r = 3.829 to r = 3.849, 0.0206 wide in r and 1.65 s long in the audio from 54.49 s, and it is the period-3 window."
- lyapunov_window: "A window of order at r = 3.854 spans a single r step of the sweep: the exponent is below zero only at that step, so its width is less than the grid spacing of 0.001 in r and 0.08 s in the audio; it is heard from 56.48 s, and its period was not identified."
- Before (lyapunov): "A window of order runs from r = 3.589 to r = 3.590, 0.0003 wide in r and 0.03 s long in the audio from 126.24 s, and its period was not identified."

## Bifurcation points in the lyapunov animation and CSV
- lyapunov.gif expected tick columns (px) for the in-range r1..r5: 549, 928, 1008, 1025, 1029
- lyapunov.gif frame 1 (1440x1200 px): green tick pixels above the top panel in rows 53 to 66, in 5 column groups at x = 548-549, 927-928, 1007-1008, 1024-1025, 1027-1029
- lyapunov_data.csv columns: r, lambda, at_floor, sweep_time_s, audio_time_s, lambda_tone_hz, crossing, crossing_r, bifurcation_period_born, bifurcation_r
- lyapunov_data.csv row r = 2.998664886515354: bifurcation_period_born 2, bifurcation_r 3.000000000
- lyapunov_data.csv row r = 3.4492656875834444: bifurcation_period_born 4, bifurcation_r 3.449489743
- lyapunov_data.csv row r = 3.543391188251001: bifurcation_period_born 8, bifurcation_r 3.544090360
- lyapunov_data.csv row r = 3.5634178905206944: bifurcation_period_born 16, bifurcation_r 3.564407266
- lyapunov_data.csv row r = 3.567423230974633: bifurcation_period_born 32, bifurcation_r 3.568759420
- lyapunov_window.gif expected tick columns (px) for the in-range r1..r5: 253, 492, 544, 555
- lyapunov_window.gif frame 1 (1440x1200 px): green tick pixels above the top panel in rows 53 to 66, in 4 column groups at x = 252-253, 491-493, 542-544, 553-555
- lyapunov_window_data.csv columns: r, lambda, at_floor, sweep_time_s, audio_time_s, lambda_tone_hz, crossing, crossing_r, bifurcation_period_born, bifurcation_r
- lyapunov_window_data.csv row r = 3.4490981963927854: bifurcation_period_born 4, bifurcation_r 3.449489743
- lyapunov_window_data.csv row r = 3.5432865731462924: bifurcation_period_born 8, bifurcation_r 3.544090360
- lyapunov_window_data.csv row r = 3.564328657314629: bifurcation_period_born 16, bifurcation_r 3.564407266
- lyapunov_window_data.csv row r = 3.5683366733466935: bifurcation_period_born 32, bifurcation_r 3.568759420
- Tick pixel x expected for r in [rMin, rMax]: 2 x (64 + (r - rMin) / (rMax - rMin) x 632), the panel padding of 64 px left and 24 px right at 720 px, doubled by the 144 dpi rasterisation.

## Unit tests
- Command: `wolframscript -file dynamical/tests/test_model.wl`
- Result: "Results: 113 passed, 0 failed."
- Exit code: 0
- Failing tests: none
- Tests before this round: 102; removed: 4 (old single-ratio Feigenbaum tests); now 113

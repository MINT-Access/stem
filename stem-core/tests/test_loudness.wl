#!/usr/bin/env wolframscript

(* stem-core/tests/test_loudness.wl — ITU-R BS.1770-4 integrated loudness
   (MeasureIntegratedLoudness) against signals whose loudness is known
   analytically, not against another meter.

   Reference point. BS.1770 calibrates the K-weighting so that a 0 dBFS
   997 Hz sine in one channel reads -3.01 LKFS; in both channels (G = 1
   each) it reads 0.00. At 44.1 kHz the bilinear transform warps the
   filter slightly: |H(997 Hz)|^2 = +0.6938 dB instead of +0.6910 dB at
   48 kHz, so the full-scale stereo sine is
     L_fs = -0.691 + 10 log10(2 * 0.5 * |H|^2) = +0.0028 LUFS
   and a sine at -A dBFS is L_fs - A.

   Gated signals (400 ms blocks, 100 ms hop, complete blocks only):
   - On/off: on 0-10 s, off 10-20 s, on 20-30 s, off 30-40 s at -20 dBFS.
     397 blocks. Fully-on blocks: 97 + 97. Blocks straddling an on/off
     edge hold 75, 50 or 25 percent of the sine (three per edge, three
     edges: 4.5 sine-powers over 9 blocks); they pass the relative gate
     (at most -6 dB below the on-level, the gate is about -10 dB). Silent
     blocks fail the absolute gate (the K-filter's decaying tail after
     an edge passes it for one block but fails the relative gate). So
       L = L_on + 10 log10((194 + 4.5) / (194 + 9)) = L_on - 0.0974
         = -19.9972 - 0.0974 = -20.0946 LUFS.
     The gate cannot make this equal L_on exactly: BS.1770's own blocks
     straddle the edges. It is within 0.1 LU of the on-level.
   - Two levels: 0-20 s at -20 dBFS, 20-40 s at -40 dBFS. Ungated mean
     power is about half the loud level (-2.97 dB), so the relative gate
     sits about 13 dB below the loud level and rejects every quiet
     block (-20 dB). Kept: 197 loud blocks and the three straddling
     blocks with powers 0.7525, 0.505 and 0.2575 of the loud level:
       L = L_loud + 10 log10((197 + 1.515) / 200) = L_loud - 0.0324
         = -19.9972 - 0.0324 = -20.0296 LUFS. *)

$stemCoreRoot = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition], Print["  PASS  ", label]; passed++, Print["  FAIL  ", label]; failed++];
near[x_, expected_, tol_] := NumericQ[x] && Abs[x - expected] <= tol;

sr = 44100;
sine[amp_, dur_] := amp Sin[2.0 Pi 997 Range[0, Round[dur sr] - 1] / sr];
silence[dur_] := ConstantArray[0.0, Round[dur sr]];
stereo[x_] := {x, x};
show[label_, x_] := Print["    ", label, ": ", x];

Print["=== stem-core loudness meter (BS.1770-4) ==="];
Print[""];

Print["-- K-weighting coefficients --"];
Module[{c48 = KWeightingCoefficients[48000]},
  show["48 kHz", c48];
  AssertTrue["48 kHz shelf b = {1.53512485958697, -2.69169618940638, 1.19839281085285} (published)",
    Max[Abs[c48[[1, "b"]] - {1.53512485958697, -2.69169618940638, 1.19839281085285}]] < 10^-12];
  AssertTrue["48 kHz shelf a = {1, -1.69065929318241, 0.73248077421585} (published)",
    Max[Abs[c48[[1, "a"]] - {1.0, -1.69065929318241, 0.73248077421585}]] < 10^-12];
  AssertTrue["48 kHz high pass b = {1, -2, 1}, a = {1, -1.99004745483398, 0.99007225036621} (published)",
    c48[[2, "b"]] == {1.0, -2.0, 1.0} && Max[Abs[c48[[2, "a"]] - {1.0, -1.99004745483398, 0.99007225036621}]] < 10^-12];
  AssertTrue["44.1 kHz coefficients differ from the 48 kHz ones (re-derived, not reused)",
    Max[Abs[KWeightingCoefficients[44100][[1, "b"]] - c48[[1, "b"]]]] > 10^-3];
];
Print[""];

Print["-- Blocks --"];
AssertTrue["40 s at 44.1 kHz gives 397 complete 400 ms blocks on a 100 ms hop",
  Length[BlockMeanSquares[sine[0.1, 40], sr]] === 397];
AssertTrue["a block mean square of a 0.1-amplitude sine is 0.005 (+-1e-5)",
  near[Median[BlockMeanSquares[sine[0.1, 10], sr]], 0.005, 10^-5]];
Print[""];

Print["-- Analytic levels --"];
Module[{l},
  l = MeasureIntegratedLoudness[stereo[sine[1.0, 10]], sr]; show["full-scale 997 Hz stereo", l];
  AssertTrue["full-scale 997 Hz sine in both channels = +0.0028 LUFS (+-0.002); BS.1770 calibration 0.00 (+-0.01)",
    near[l, 0.0028, 0.002] && near[l, 0.0, 0.01]];
  l = MeasureIntegratedLoudness[{sine[1.0, 10]}, sr]; show["full-scale 997 Hz mono", l];
  AssertTrue["full-scale 997 Hz sine in one channel = -3.0075 LUFS (-3.01 per BS.1770, +-0.01)",
    near[l, -3.0075, 0.002] && near[l, -3.01, 0.01]];
  l = MeasureIntegratedLoudness[stereo[sine[0.1, 10]], sr]; show["-20 dBFS stereo", l];
  AssertTrue["-20 dBFS 997 Hz sine in both channels = -19.9972 LUFS (+-0.002)", near[l, -19.9972, 0.002]];
];
Print[""];

Print["-- Gating --"];
Module[{onoff, two, l},
  onoff = Join[sine[0.1, 10], silence[10], sine[0.1, 10], silence[10]];
  l = MeasureIntegratedLoudness[stereo[onoff], sr]; show["on/off at -20 dBFS", l];
  AssertTrue["on/off: silent blocks rejected, result = -20.0946 LUFS (+-0.01)", near[l, -20.0946, 0.01]];
  AssertTrue["on/off: result within 0.1 LU of the on-level (-19.9972)", near[l, -19.9972, 0.1]];
  AssertTrue["on/off: without gating the result would be 3 dB lower (ungated mean of all 397 blocks)",
    Module[{z = Total[BlockMeanSquares[KWeight[#, sr], sr] & /@ stereo[onoff]]},
      near[-0.691 + 10 Log10[Mean[z]], -19.9972 + 10 Log10[198.5 / 397], 0.02]]];
  two = Join[sine[0.1, 20], sine[0.01, 20]];
  l = MeasureIntegratedLoudness[stereo[two], sr]; show["two-level -20/-40 dBFS", l];
  AssertTrue["two-level: relative gate rejects the quiet half, result = -20.0296 LUFS (+-0.01)", near[l, -20.0296, 0.01]];
  AssertTrue["two-level: result within 0.1 LU of the loud level (-19.9972)", near[l, -19.9972, 0.1]];
];
Print[""];

Print["-- Edge cases and NormalizeToLoudness --"];
AssertTrue["digital silence measures -Infinity", MeasureIntegratedLoudness[stereo[silence[5]], sr] === -Infinity];
AssertTrue["audio shorter than one 400 ms block measures -Infinity",
  MeasureIntegratedLoudness[stereo[sine[0.5, 0.3]], sr] === -Infinity];
AssertTrue["scaling by 2 raises the reading by 6.0206 dB",
  near[MeasureIntegratedLoudness[stereo[2 sine[0.1, 10]], sr] - MeasureIntegratedLoudness[stereo[sine[0.1, 10]], sr],
       20 Log10[2.0], 10^-9]];
AssertTrue["the Audio form gives the same reading as the list form",
  near[MeasureIntegratedLoudness[Audio[stereo[sine[0.1, 5]], SampleRate -> sr]],
       MeasureIntegratedLoudness[stereo[sine[0.1, 5]], sr], 10^-4]];
AssertTrue["NormalizeToLoudness brings a -20 dBFS sine to -17 LUFS",
  near[MeasureIntegratedLoudness[NormalizeToLoudness[stereo[sine[0.1, 10]], -17.0, 0.97, sr], sr], -17.0, 10^-6]];
Print[""];

Print["-- Peak limiter --"];
Module[{x, st, r, g, o, lim = <|"ceiling_dbfs" -> -1.0, "attack_ms" -> 5.0, "release_ms" -> 50.0|>, burstStart = 44100},
  x = sine[0.05, 10]; x[[burstStart ;; burstStart + 2000]] += 0.9 Sin[2.0 Pi 997 Range[burstStart - 1, burstStart + 1999] / sr];
  st = {x, x};
  r = PeakLimit[st, sr, -1.0, 5.0, 50.0]; g = r["gain"];
  AssertTrue["PeakLimit: output peak is at most the -1 dBFS ceiling (+1e-9)",
    20 Log10[Max[Abs[Flatten[r["data"]]]]] <= -1.0 + 10^-9];
  AssertTrue["PeakLimit: material far from the burst passes unchanged (gain 1 for the first 0.9 s)",
    Max[Abs[g[[1 ;; Round[0.9 sr]]] - 1.0]] < 10^-12];
  AssertTrue["PeakLimit: the gain is already reduced 2 ms before the burst (look-ahead)",
    g[[burstStart - Round[0.002 sr]]] < 1.0];
  AssertTrue["PeakLimit: both channels get the same gain (linked)", r["data"][[1]] === r["data"][[2]]];
  o = LimitedNormalizeToLoudness[st, -17.0, 0.97, sr, lim];
  AssertTrue["LimitedNormalizeToLoudness reaches -17 LUFS within 0.02 LU where plain normalisation is peak-held",
    near[MeasureIntegratedLoudness[o, sr], -17.0, 0.02] &&
    MeasureIntegratedLoudness[NormalizeToLoudness[st, -17.0, 0.97, sr], sr] < -20.0];
  AssertTrue["LimitedNormalizeToLoudness keeps the peak at or below -1 dBFS", 20 Log10[Max[Abs[Flatten[o]]]] <= -1.0 + 10^-9];
  AssertTrue["$StemLastLimiter reports the maximum gain reduction (> 0 dB) and the ceiling",
    $StemLastLimiter["maxReductionDB"] > 0 && $StemLastLimiter["ceilingDB"] == -1.0];
];
Module[{x, r},
  x = sine[0.05, 3]; x[[1 ;; 200]] += 0.95 Sin[2.0 Pi 997 Range[0, 199] / sr];   (* loud at the very start *)
  r = PeakLimit[{x, x}, sr, -1.0, 5.0, 50.0];
  AssertTrue["PeakLimit: a peak within the first 5 ms is held at the ceiling too",
    20 Log10[Max[Abs[Flatten[r["data"]]]]] <= -1.0 + 10^-9];
];
AssertTrue["LimiterSettings: off by default (no audio.limiter block)", LimiterSettings[<||>] === None];
AssertTrue["LimiterSettings: enabled false is off", LimiterSettings[<|"audio" -> <|"limiter" -> <|"enabled" -> False|>|>|>] === None];
AssertTrue["LimiterSettings: defaults -1 dBFS, 5 ms, 50 ms when enabled",
  LimiterSettings[<|"audio" -> <|"limiter" -> <|"enabled" -> True|>|>|>] ===
    <|"ceiling_dbfs" -> -1.0, "attack_ms" -> 5.0, "release_ms" -> 50.0|>];
AssertTrue["LimiterSettings: modes restricts it (on for lorenz, off for rossler)",
  LimiterSettings[<|"simulation" -> <|"mode" -> "rossler"|>, "audio" -> <|"limiter" -> <|"enabled" -> True, "modes" -> {"lorenz"}|>|>|>] === None &&
  AssociationQ[LimiterSettings[<|"simulation" -> <|"mode" -> "lorenz"|>, "audio" -> <|"limiter" -> <|"enabled" -> True, "modes" -> {"lorenz"}|>|>|>]]];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

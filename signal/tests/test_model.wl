#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the signal processing model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyze.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label];
    passed++,
    Print["  FAIL  ", label];
    failed++
  ]

Print["Running tests..."];
Print[""];

(* --- ChordModel tests --- *)

chordCfg = <|
  "simulation" -> <|
    "mode" -> "chord",
    "chord" -> <|
      "frequencies" -> {261.63, 329.63, 392.00},
      "amplitudes"  -> {1.0, 0.8, 0.6},
      "duration"    -> 1.0,
      "noise_level" -> 0.0
    |>
  |>,
  "sonification" -> <| "sample_rate" -> 44100 |>
|>;

chord = ChordModel[chordCfg];

(* Test 1: returns an Association with required keys *)
AssertTrue["ChordModel returns Association with clean/noisy keys",
  AssociationQ[chord] && KeyExistsQ[chord, "clean"] && KeyExistsQ[chord, "noisy"]];

(* Test 2: correct sample count (1 second at 44100 Hz) *)
AssertTrue["ChordModel produces correct number of samples",
  Length[chord["clean"]] === 44100];

(* Test 3: with zero noise, clean === noisy *)
AssertTrue["Zero noise: clean equals noisy",
  Max[Abs[chord["clean"] - chord["noisy"]]] < 1*^-10];

(* Test 4: mode field is set correctly *)
AssertTrue["ChordModel mode field is \"chord\"",
  chord["mode"] === "chord"];

(* Test 5: known frequency present in spectrum — peak near 261.63 Hz *)
(* Use a noiseless 1-second chord; the DFT bin at 261 Hz should dominate *)
With[{
  sr = 44100,
  n  = Length[chord["clean"]],
  pwr = Abs[Fourier[chord["clean"]]]^2},
  binHz   = N[sr / n];
  peakBin = First[Ordering[-pwr[[;; Ceiling[n/2]]], 1]];
  peakHz  = (peakBin - 1) * binHz;
  AssertTrue["Dominant peak is near 261.63 Hz (within 2 Hz)",
    Abs[peakHz - 261.63] < 2.0]
];

(* --- SweepModel tests --- *)

sweepCfg = <|
  "simulation" -> <|
    "mode" -> "sweep",
    "sweep" -> <|
      "start_hz"    -> 100.0,
      "end_hz"      -> 500.0,
      "duration"    -> 1.0,
      "noise_level" -> 0.0
    |>
  |>,
  "sonification" -> <| "sample_rate" -> 44100 |>
|>;

sweep = SweepModel[sweepCfg];

(* Test 6: returns correct keys and mode *)
AssertTrue["SweepModel returns Association with mode=sweep",
  AssociationQ[sweep] && sweep["mode"] === "sweep"];

(* Test 7: correct sample count *)
AssertTrue["SweepModel produces correct number of samples",
  Length[sweep["clean"]] === 44100];

(* Test 8: amplitude of clean signal is bounded (sinusoid peaks at 1) *)
AssertTrue["Sweep clean signal amplitude within [-1.1, 1.1]",
  Max[Abs[sweep["clean"]]] <= 1.1];

(* --- AMModel tests --- *)

amCfg = <|
  "simulation" -> <|
    "mode" -> "am",
    "am" -> <|
      "carrier_hz"       -> 440.0,
      "modulator_hz"     -> 4.0,
      "modulation_depth" -> 0.8,
      "duration"         -> 1.0,
      "noise_level"      -> 0.0
    |>
  |>,
  "sonification" -> <| "sample_rate" -> 44100 |>
|>;

am = AMModel[amCfg];

(* Test 9: mode field correct *)
AssertTrue["AMModel mode field is \"am\"",
  am["mode"] === "am"];

(* Test 10: AM signal has three frequency components in its known list *)
AssertTrue["AMModel reports 3 known frequency components",
  Length[am["frequencies"]] === 3];

(* Test 11: sidebands are at carrier ± modulator *)
AssertTrue["Sidebands at 436 Hz and 444 Hz",
  MemberQ[Round[am["frequencies"]], 436] && MemberQ[Round[am["frequencies"]], 444]];

(* --- ComputeSNR tests --- *)

(* Test 12: SNR of clean signal with itself is very high *)
AssertTrue["SNR of identical signals is > 80 dB",
  ComputeSNR[chord["clean"], chord["clean"]] > 80.0];

(* Test 13: SNR is lower when noise is added *)
noisyCfg = chordCfg;
noisyCfg = DeepMerge[noisyCfg, <|"simulation" -> <|"chord" -> <|"noise_level" -> 0.5|>|>|>];
noisyChord = ChordModel[noisyCfg];
AssertTrue["SNR is lower with noise than without",
  ComputeSNR[noisyChord["noisy"], noisyChord["clean"]] <
  ComputeSNR[noisyChord["clean"], noisyChord["clean"]]];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Signal processing parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its CSV, GIF, WAV, and PNG outputs
   to output/ under a named prefix so results are easy to compare.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyze.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* --- Helper: run one named experiment --- *)

RunSignalExperiment[name_String, label_String, signalFn_, cfg_Association] :=
  Module[{signal, analysis},
    Print[""];
    Print[">>> Experiment: ", name, "  — ", label];

    signal   = signalFn[cfg];
    analysis = FourierAnalysis[signal, cfg];

    STEMPrintN["SNR before filtering", analysis["snr_before"], "dB", {5, 1}];
    STEMPrintN["SNR after filtering",  analysis["snr_after"],  "dB", {5, 1}];

    (* Rename output files to the experiment name prefix *)
    With[{
      defaultPrefix = analysis["mode"],
      expCfg = DeepMerge[cfg, <|"experiment_name" -> name|>]},

      AnimateSignal[analysis, expCfg, $outDir];
      SonifySignal[analysis, expCfg, $outDir];

      Print["    Output prefix: output/", defaultPrefix, "_*"]
    ]
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- chord_clean: C major chord with very low noise --- *)
(* Low noise makes Fourier recovery trivial; the clean and recovered
   audio are nearly identical. Good baseline to hear what the chord
   sounds like before noise is added. *)
Print[""];
Print[">>> Experiment: chord_clean  — C major chord, low noise"];
With[{
  cfg = <|
    "simulation" -> <| "mode" -> "chord",
      "chord" -> <|
        "frequencies" -> {261.63, 329.63, 392.00},
        "amplitudes"  -> {1.0, 0.8, 0.6},
        "duration"    -> 3.0,
        "noise_level" -> 0.1
      |>
    |>,
    "sonification" -> <| "sample_rate" -> 44100 |>
  |>},
  signal   = ChordModel[cfg];
  analysis = FourierAnalysis[signal, cfg];
  STEMPrintN["SNR before", analysis["snr_before"], "dB", {5,1}];
  STEMPrintN["SNR after",  analysis["snr_after"],  "dB", {5,1}];
  AnimateSignal[analysis, cfg, $outDir];
  SonifySignal[analysis, cfg, $outDir];
  Print["    Output: output/chord_*"]
];


(* --- noisy_chord: C major chord with heavy noise --- *)
(* Strong noise (level 1.5) masks the chord almost completely.
   Fourier filtering still recovers the main tones but the SNR gain
   is more dramatic — listen to the noisy vs. recovered WAVs. *)
Print[""];
Print[">>> Experiment: noisy_chord  — C major chord, heavy noise (level 1.5)"];
With[{
  cfg = <|
    "simulation" -> <| "mode" -> "chord",
      "chord" -> <|
        "frequencies" -> {261.63, 329.63, 392.00},
        "amplitudes"  -> {1.0, 0.8, 0.6},
        "duration"    -> 3.0,
        "noise_level" -> 1.5
      |>
    |>,
    "sonification" -> <| "sample_rate" -> 44100 |>
  |>},
  signal   = ChordModel[cfg];
  analysis = FourierAnalysis[signal, cfg];
  STEMPrintN["SNR before", analysis["snr_before"], "dB", {5,1}];
  STEMPrintN["SNR after",  analysis["snr_after"],  "dB", {5,1}];
  AnimateSignal[analysis, cfg, $outDir];
  SonifySignal[analysis, cfg, $outDir];
  Print["    Output: output/chord_*"]
];


(* --- frequency_sweep: 100 → 4000 Hz chirp --- *)
(* A wide-range sweep. The Fourier spectrum shows a diagonal ridge
   spanning the full frequency range. The recovered audio should sound
   identical to the clean chirp despite the added noise. *)
Print[""];
Print[">>> Experiment: frequency_sweep  — 100 to 4000 Hz, 4 s"];
With[{
  cfg = <|
    "simulation" -> <| "mode" -> "sweep",
      "sweep" -> <|
        "start_hz"    -> 100.0,
        "end_hz"      -> 4000.0,
        "duration"    -> 4.0,
        "noise_level" -> 0.3
      |>
    |>,
    "sonification" -> <| "sample_rate" -> 44100 |>
  |>},
  signal   = SweepModel[cfg];
  analysis = FourierAnalysis[signal, cfg];
  STEMPrintN["SNR before", analysis["snr_before"], "dB", {5,1}];
  STEMPrintN["SNR after",  analysis["snr_after"],  "dB", {5,1}];
  AnimateSignal[analysis, cfg, $outDir];
  SonifySignal[analysis, cfg, $outDir];
  Print["    Output: output/sweep_*"]
];


(* --- am_radio: 1 kHz carrier modulated at 100 Hz --- *)
(* Higher frequencies than the default AM preset. The two sidebands
   (900 and 1100 Hz) are close to the carrier and easy to hear as a
   beating effect. *)
Print[""];
Print[">>> Experiment: am_radio  — 1000 Hz carrier, 100 Hz modulator"];
With[{
  cfg = <|
    "simulation" -> <| "mode" -> "am",
      "am" -> <|
        "carrier_hz"       -> 1000.0,
        "modulator_hz"     -> 100.0,
        "modulation_depth" -> 0.8,
        "duration"         -> 3.0,
        "noise_level"      -> 0.35
      |>
    |>,
    "sonification" -> <| "sample_rate" -> 44100 |>
  |>},
  signal   = AMModel[cfg];
  analysis = FourierAnalysis[signal, cfg];
  STEMPrintN["SNR before", analysis["snr_before"], "dB", {5,1}];
  STEMPrintN["SNR after",  analysis["snr_after"],  "dB", {5,1}];
  AnimateSignal[analysis, cfg, $outDir];
  SonifySignal[analysis, cfg, $outDir];
  Print["    Output: output/am_*"]
];


(* --- heavy_noise: chord at noise level 3.0 — extreme degradation --- *)
(* Noise so heavy the chord is inaudible. Fourier recovery still works
   because the three tone peaks still protrude above the noise floor in
   the power spectrum. Demonstrates the robustness of frequency-domain
   filtering. *)
Print[""];
Print[">>> Experiment: heavy_noise  — C major chord, extreme noise (level 3.0)"];
With[{
  cfg = <|
    "simulation" -> <| "mode" -> "chord",
      "chord" -> <|
        "frequencies" -> {261.63, 329.63, 392.00},
        "amplitudes"  -> {1.0, 0.8, 0.6},
        "duration"    -> 3.0,
        "noise_level" -> 3.0
      |>
    |>,
    "sonification" -> <| "sample_rate" -> 44100 |>
  |>},
  signal   = ChordModel[cfg];
  analysis = FourierAnalysis[signal, cfg];
  STEMPrintN["SNR before", analysis["snr_before"], "dB", {5,1}];
  STEMPrintN["SNR after",  analysis["snr_after"],  "dB", {5,1}];
  AnimateSignal[analysis, cfg, $outDir];
  SonifySignal[analysis, cfg, $outDir];
  Print["    Output: output/chord_*"]
];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

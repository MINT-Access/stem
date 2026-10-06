#!/usr/bin/env wolframscript

(* dynamical/experiments.wl — Curated preset runs for the logistic map.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to dynamical/output/, including the spoken intro and outro. *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, rStart, rEnd, rSteps, rCfg, preset, nTransient, nAttractor,
          nIterations, noteDuration, x0, sr,
          outWAV, outGIF, outCSV,
          rActual, itX0, presetDesc, sweepModel, sweepResult, iterateModel, iterateResult,
          timing, gifFrames, gifFps},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["dynamical", {}], overrides];

    mode         = GetCfg[cfg, {"simulation", "mode"},                       "sweep"];
    rStart       = N @ GetCfg[cfg, {"simulation", "dynamical", "r_start"},      2.5];
    rEnd         = N @ GetCfg[cfg, {"simulation", "dynamical", "r_end"},        4.0];
    rSteps       =     GetCfg[cfg, {"simulation", "dynamical", "r_steps"},      500];
    rCfg         = N @ GetCfg[cfg, {"simulation", "dynamical", "r"},            3.8];
    preset       =     GetCfg[cfg, {"simulation", "dynamical", "preset"},       ""];
    nTransient   =     GetCfg[cfg, {"simulation", "dynamical", "n_transient"},  200];
    nAttractor   =     GetCfg[cfg, {"simulation", "dynamical", "n_attractor"},  100];
    nIterations  =     GetCfg[cfg, {"simulation", "dynamical", "n_iterations"}, 300];
    noteDuration = N @ GetCfg[cfg, {"simulation", "dynamical", "note_duration"}, 0.08];
    x0           = N @ GetCfg[cfg, {"simulation", "dynamical", "x0"},           0.5];
    sr           =     GetCfg[cfg, {"sonification", "sample_rate"},             44100];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    If[mode === "sweep",

      sweepModel  = SweepModel[rStart, rEnd, rSteps, x0, nTransient, nAttractor];
      sweepResult = SonifySweep[sweepModel, noteDuration, sr];
      timing = ExportNarratedWAV[outWAV, SpeakNarration[BuildSweepIntroText[rStart, rEnd], sr],
        sweepResult["leftBuf"], sweepResult["rightBuf"], SpeakNarration[BuildSweepOutroText[rStart, rEnd], sr], sr];
      STEMDescribeWAV[outWAV, timing["total"]];
      {gifFrames, gifFps} = AnimateSweepBifurcation[sweepModel, sweepResult["eventRs"], outGIF,
        <|"intro" -> timing["intro"], "stepDuration" -> $sweepNotesPerStep * noteDuration, "total" -> timing["total"]|>];
      STEMDescribeGIF[outGIF, gifFrames, gifFps];
      ExportSweepCSV[sweepResult, sweepModel["rValues"], outCSV],

      rActual    = PresetR[preset, rCfg];
      itX0       = PresetX0[preset, x0];
      presetDesc = PresetDescription[preset];
      iterateModel  = IterateModelData[rActual, itX0, nIterations, preset];
      iterateResult = SonifyIterate[iterateModel, noteDuration, sr];
      timing = ExportNarratedWAV[outWAV,
        SpeakNarration[BuildIterateIntroText[rActual, presetDesc, nIterations, itX0], sr],
        iterateResult["leftBuf"], iterateResult["rightBuf"], SpeakNarration[BuildIterateOutroText[rActual], sr], sr];
      STEMDescribeWAV[outWAV, timing["total"]];
      {gifFrames, gifFps} = AnimateIterateTimeSeries[iterateModel, outGIF,
        <|"intro" -> timing["intro"], "noteDuration" -> noteDuration, "total" -> timing["total"]|>];
      STEMDescribeGIF[outGIF, gifFrames, gifFps];
      ExportIterateCSV[iterateResult, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   The recommended listening sequence (LISTENING_GUIDE.md) — run in
   order to hear the complete route from extinction to chaos. *)

RunExperiment["iterate_extinction", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "extinction" |> |>
|>];

RunExperiment["iterate_growth", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "growth" |> |>
|>];

RunExperiment["iterate_fixed_point", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "fixed_point" |> |>
|>];

RunExperiment["iterate_period2", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "period2" |> |>
|>];

RunExperiment["iterate_period4", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "period4" |> |>
|>];

RunExperiment["iterate_period3_window", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "period3_window" |> |>
|>];

RunExperiment["iterate_chaos", <|
  "simulation" -> <| "mode" -> "iterate", "dynamical" -> <| "preset" -> "chaos" |> |>
|>];

(* 6. The full sweep — the entire route to chaos in one file.
   r_steps reduced from the 500 default to keep experiment runtime
   reasonable; note_duration also shortened slightly. *)
RunExperiment["sweep_full", <|
  "simulation" -> <|
    "mode" -> "sweep",
    "dynamical" -> <| "r_steps" -> 150, "note_duration" -> 0.06 |>
  |>
|>];

(* 7. A fast-rhythm sweep: shorter notes make more of the sweep audible
   per minute, at the cost of individual notes being less distinct. *)
RunExperiment["sweep_fast_rhythm", <|
  "simulation" -> <|
    "mode" -> "sweep",
    "dynamical" -> <| "r_steps" -> 150, "note_duration" -> 0.03 |>
  |>
|>];

(* 8. A narrow sweep zoomed into the period-doubling cascade itself
   (r 2.9 to 3.6), so the doublings are close together and easy to
   compare directly against each other. *)
RunExperiment["sweep_cascade_zoom", <|
  "simulation" -> <|
    "mode" -> "sweep",
    "dynamical" -> <| "r_start" -> 2.9, "r_end" -> 3.6, "r_steps" -> 120, "note_duration" -> 0.06 |>
  |>
|>];

(* 9. Manual r override (not a named preset): deep in the chaotic
   region, away from the period-3 window, for comparison. *)
RunExperiment["iterate_deep_chaos", <|
  "simulation" -> <|
    "mode" -> "iterate",
    "dynamical" -> <| "r" -> 3.99, "preset" -> "" |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

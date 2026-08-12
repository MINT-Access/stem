#!/usr/bin/env wolframscript

(* bell/experiments.wl — Curated runs across all three bell modes.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to bell/output/, including the prepended spoken intro. *)

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
  Module[{cfg, mode, sr, duration,
          corrModel, chshModel, measModel,
          outWAV, outGIF, outPNG, outCSV,
          rawLeft, rawRight, introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["bell", {}], overrides];

    mode     = GetCfg[cfg, {"simulation", "mode"}, "correlations"];
    sr       =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    duration = N @ GetCfg[cfg, {"sonification", "duration"},     8.0];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "correlations",
        corrModel = CorrelationsModel[cfg];
        PrintCorrelationsSummary[corrModel];

        {rawLeft, rawRight} = BuildCorrelationsAudio[corrModel, 220.0, 1400.0, duration, sr];
        introText   = BuildCorrelationsIntroText[];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateCorrelations[corrModel, outGIF, outPNG, totalDurSec];
        ExportCorrelationsCSV[corrModel, outCSV],

      mode === "chsh",
        chshModel = ChshModel[cfg];
        PrintChshSummary[chshModel];

        {rawLeft, rawRight} = BuildChshAudio[chshModel, 220.0, 1400.0, 2.5, sr];
        introText   = BuildChshIntroText[chshModel["S"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateChsh[chshModel, outGIF, outPNG, totalDurSec];
        ExportChshCSV[chshModel, outCSV],

      mode === "measurement",
        measModel = MeasurementModel[cfg];
        PrintMeasurementSummary[measModel];

        {rawLeft, rawRight} = BuildMeasurementAudio[measModel, 220.0, 1400.0, duration, sr];
        introText   = BuildMeasurementIntroText[measModel["nTrials"], measModel["trueE"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportMeasurementPNG[measModel, outPNG];
        ExportMeasurementCSV[measModel, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) — run
   in order to hear entanglement from three complementary angles. *)

RunExperiment["correlations_default", <|
  "simulation" -> <| "mode" -> "correlations" |>
|>];

RunExperiment["chsh_default", <|
  "simulation" -> <| "mode" -> "chsh" |>
|>];

RunExperiment["measurement_default", <|
  "simulation" -> <| "mode" -> "measurement" |>
|>];

(* 4. CHSH at the "naive" 90-degree-separated angles (a=0,a'=90,b=0,
   b'=90) instead of the derived-optimal 45-degree-offset set — S=2
   exactly here, the same as the classical bound, audible as the
   verdict tone's two pitches landing on top of each other instead of
   pulling apart. Demonstrates the optimisation in ChshOptimalityCheck
   actually matters (see AGENTS.md design decision 2). *)
RunExperiment["chsh_naive_angles", <|
  "simulation" -> <|
    "mode" -> "chsh",
    "bell" -> <| "chsh_a_deg" -> 0.0, "chsh_ap_deg" -> 90.0,
                 "chsh_b_deg" -> 0.0, "chsh_bp_deg" -> 90.0 |>
  |>
|>];

(* 5. Measurement at perpendicular settings (a=0,b=90 deg) — true
   E(a,b)=0, no correlation at all: Alice's and Bob's click streams
   should sound completely independent of each other. *)
RunExperiment["measurement_uncorrelated", <|
  "simulation" -> <|
    "mode" -> "measurement",
    "bell" -> <| "alice_angle_deg" -> 0.0, "bob_angle_deg" -> 90.0 |>
  |>
|>];

(* 6. Measurement at opposite settings (a=0,b=180 deg) — true
   E(a,b)=-1, perfect ANTI-correlation: whenever Alice gets +1, Bob
   gets -1 and vice versa, every single trial. *)
RunExperiment["measurement_anticorrelated", <|
  "simulation" -> <|
    "mode" -> "measurement",
    "bell" -> <| "alice_angle_deg" -> 0.0, "bob_angle_deg" -> 180.0 |>
  |>
|>];

(* 7. A correlations sweep centred on a different Bob angle (45 deg
   instead of 0) — the same Cos(delta) vs triangular-classical shapes,
   just shifted, confirming the sweep only depends on the DIFFERENCE
   a-b, not on the absolute angles. *)
RunExperiment["correlations_shifted", <|
  "simulation" -> <|
    "mode" -> "correlations",
    "bell" -> <| "b_angle_deg" -> 45.0 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

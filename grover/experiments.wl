#!/usr/bin/env wolframscript

(* grover/experiments.wl — Curated runs across all three grover modes.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to grover/output/, including the prepended spoken intro. *)

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
          searchModel, compareModel, geometryModel,
          outWAV, outGIF, outPNG, outCSV,
          rawLeft, rawRight, introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["grover", {}], overrides];

    mode     = GetCfg[cfg, {"simulation", "mode"}, "search"];
    sr       =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    duration = N @ GetCfg[cfg, {"sonification", "duration"},     8.0];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "search",
        searchModel = SearchModel[cfg];
        PrintSearchSummary[searchModel];

        {rawLeft, rawRight} = BuildSearchAudio[searchModel, 220.0, 1400.0, 0.28, sr];
        introText   = BuildSearchIntroText[searchModel["nItems"], searchModel["optimalK"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateSearch[searchModel, outGIF, outPNG, totalDurSec];
        ExportSearchCSV[searchModel, outCSV],

      mode === "compare",
        compareModel = CompareModel[cfg];
        PrintCompareSummary[compareModel];

        {rawLeft, rawRight} = BuildCompareAudio[compareModel, 440.0, 6.0, sr];
        introText   = BuildCompareIntroText[compareModel["nItems"], Round[compareModel["classicalAtN"]], compareModel["quantumAtN"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateCompare[compareModel, outGIF, outPNG, totalDurSec];
        ExportCompareCSV[compareModel, outCSV],

      mode === "geometry",
        geometryModel = GeometryModel[cfg];
        PrintGeometrySummary[geometryModel];

        {rawLeft, rawRight} = BuildGeometryAudio[geometryModel, 220.0, 1400.0, duration, sr];
        introText   = BuildGeometryIntroText[geometryModel["nItems"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateGeometry[geometryModel, outGIF, outPNG, totalDurSec];
        ExportGeometryCSV[geometryModel, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) — run
   in order to hear Grover's algorithm from three complementary angles. *)

RunExperiment["search_default", <|
  "simulation" -> <| "mode" -> "search" |>
|>];

RunExperiment["compare_default", <|
  "simulation" -> <| "mode" -> "compare" |>
|>];

RunExperiment["geometry_default", <|
  "simulation" -> <| "mode" -> "geometry" |>
|>];

(* 4. A larger N, showing the optimal k grow (roughly as sqrt(N)) and
   the search take noticeably longer to reach its peak. *)
RunExperiment["search_large_n", <|
  "simulation" -> <|
    "mode" -> "search",
    "grover" -> <| "n_items" -> 1024, "marked_index" -> 777, "n_iterations" -> 50 |>
  |>
|>];

(* 5. A tiny N=4 (only 2 qubits): the smallest genuinely interesting
   Grover search, exactly one optimal iteration, P(marked)=1 exactly. *)
RunExperiment["search_tiny", <|
  "simulation" -> <|
    "mode" -> "search",
    "grover" -> <| "n_items" -> 4, "marked_index" -> 3, "n_iterations" -> 5 |>
  |>
|>];

(* 6. compare mode at a larger single N, showing a more dramatic race —
   classical needs hundreds of queries, quantum only a couple dozen —
   while keeping the audio's tick count (and therefore its length)
   reasonable via BuildCompareAudio's own auto-scaled tick interval. *)
RunExperiment["compare_large_n", <|
  "simulation" -> <|
    "mode" -> "compare",
    "grover" -> <| "n_items" -> 512, "marked_index" -> 250 |>
  |>
|>];

(* 7. geometry mode at N=16 — a larger rotation angle per iteration
   (theta~14.5deg vs the default N=64's ~7.2deg), so the rotation
   completes noticeably faster and the pitch/pan cycle more quickly. *)
RunExperiment["geometry_n16", <|
  "simulation" -> <|
    "mode" -> "geometry",
    "grover" -> <| "n_items" -> 16, "marked_index" -> 5, "n_iterations" -> 8 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

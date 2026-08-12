#!/usr/bin/env wolframscript

(* henon/experiments.wl — Curated runs across all three Hénon modes.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to henon/output/, including the prepended spoken intro. *)

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
  Module[{cfg, mode, a, b, x0, y0, nTransient, nPoints,
          aMin, aMax, aSteps, nAttractor, nForward, reverseSteps, noteDuration, sr,
          outWAV, outGIF, outPNG, outCSV,
          attractorModel, dimension, rawLeft, rawRight,
          sweepModel, landmarks, sweepResult,
          reverseModel, reverseResult,
          introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["henon", {}], overrides];

    mode         = GetCfg[cfg, {"simulation", "mode"},                        "attractor"];
    a            = N @ GetCfg[cfg, {"simulation", "henon", "a"},               1.4];
    b            = N @ GetCfg[cfg, {"simulation", "henon", "b"},               0.3];
    x0           = N @ GetCfg[cfg, {"simulation", "henon", "x0"},              0.1];
    y0           = N @ GetCfg[cfg, {"simulation", "henon", "y0"},              0.1];
    nTransient   =     GetCfg[cfg, {"simulation", "henon", "n_transient"},      500];
    nPoints      =     GetCfg[cfg, {"simulation", "henon", "n_points"},        2000];
    aMin         = N @ GetCfg[cfg, {"simulation", "henon", "a_min"},            0.2];
    aMax         = N @ GetCfg[cfg, {"simulation", "henon", "a_max"},            1.4];
    aSteps       =     GetCfg[cfg, {"simulation", "henon", "a_steps"},          250];
    nAttractor   =     GetCfg[cfg, {"simulation", "henon", "n_attractor"},      40];
    nForward     =     GetCfg[cfg, {"simulation", "henon", "n_forward"},        40];
    reverseSteps =     GetCfg[cfg, {"simulation", "henon", "reverse_steps"},    10];
    noteDuration = N @ GetCfg[cfg, {"simulation", "henon", "note_duration"},   0.08];
    sr           =     GetCfg[cfg, {"sonification", "sample_rate"},           44100];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "attractor",
        attractorModel = HenonAttractorModel[x0, y0, a, b, nTransient, nPoints];
        dimension = BoxCountingDimension[attractorModel["trajectory"]];
        PrintAttractorSummary[attractorModel, dimension];

        {rawLeft, rawRight} = AttractorStereoBuffer[attractorModel, cfg];
        introText   = BuildAttractorIntroText[a, b];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportAttractorAnimation[attractorModel["trajectory"], outGIF, totalDurSec];
        ExportAttractorPNG[attractorModel["trajectory"], outPNG];
        ExportAttractorCSV[BuildAttractorTrajectory[attractorModel], cfg, outCSV],

      mode === "sweep",
        sweepModel = HenonSweepModel[aMin, aMax, aSteps, b, x0, y0, nTransient, nAttractor];
        landmarks  = HenonSweepLandmarks[b];
        PrintSweepSummary[sweepModel, landmarks];

        sweepResult = SonifySweep[sweepModel, landmarks, noteDuration, sr];
        introText   = BuildSweepIntroText[aMin, aMax, landmarks];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, sweepResult["leftBuf"]];
        finalRight  = Join[introBuffer, pauseBuffer, sweepResult["rightBuf"]];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateSweepBifurcation[sweepModel, landmarks, outGIF, totalDurSec];
        ExportSweepPNG[sweepModel, landmarks, outPNG];
        ExportSweepCSV[sweepResult, sweepModel["aValues"], outCSV],

      mode === "reverse",
        reverseModel = HenonReverseModel[x0, y0, a, b, nTransient, nForward, reverseSteps];
        PrintReverseSummary[reverseModel];

        reverseResult = SonifyReverse[reverseModel, noteDuration, sr];
        introText     = BuildReverseIntroText[reverseSteps];
        introBuffer   = BuildIntroBuffer[introText, sr];
        introBuffer   = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer   = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft     = Join[introBuffer, pauseBuffer, reverseResult["leftBuf"]];
        finalRight    = Join[introBuffer, pauseBuffer, reverseResult["rightBuf"]];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportReversePNG[reverseModel, outPNG];
        ExportReverseCSV[reverseResult, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) —
   run in order to hear the map's chaos structure from three angles. *)

RunExperiment["attractor_canonical", <|
  "simulation" -> <| "mode" -> "attractor" |>
|>];

RunExperiment["sweep_full", <|
  "simulation" -> <| "mode" -> "sweep" |>
|>];

RunExperiment["reverse_demo", <|
  "simulation" -> <| "mode" -> "reverse" |>
|>];

(* 4. A faster sweep zoomed into the period-doubling cascade itself
   (a 0.3 to 1.1), so the doublings are close together and easy to
   compare directly against each other. *)
RunExperiment["sweep_cascade_zoom", <|
  "simulation" -> <|
    "mode" -> "sweep",
    "henon" -> <| "a_min" -> 0.3, "a_max" -> 1.1, "a_steps" -> 150, "note_duration" -> 0.06 |>
  |>
|>];

(* 5. A sweep zoomed into the chaotic band itself, to hear the
   period-seven window's brief return to order up close. *)
RunExperiment["sweep_chaos_zoom", <|
  "simulation" -> <|
    "mode" -> "sweep",
    "henon" -> <| "a_min" -> 1.05, "a_max" -> 1.4, "a_steps" -> 150, "note_duration" -> 0.06 |>
  |>
|>];

(* 6. A more weakly-dissipative Hénon map (b=0.5 rather than the
   canonical 0.3): area contraction is weaker, so Lyapunov exponents
   sum to log(0.5)~=-0.693 rather than log(0.3)~=-1.204 — closer to
   zero, meaning less net contraction per step. NOTE: a must be
   reduced from the canonical 1.4 to stay both bounded AND genuinely
   chaotic — the Hénon map's bounded region shrinks as b grows, and
   a naive (a,b)=(1.4,0.9) actually diverges to Overflow[] within a
   few hundred iterations, while (0.4,0.9) stays bounded but only
   settles to a period-2 cycle (not chaotic at all — verified while
   building this app; see AGENTS.md pitfall notes). (a,b)=(1.05,0.5)
   was checked to be both bounded (|x|,|y| < ~1.7) and genuinely
   chaotic (no detected periodicity in a 300-point tail; box-counting
   dimension estimate ~1.20). *)
RunExperiment["attractor_weakly_dissipative", <|
  "simulation" -> <|
    "mode" -> "attractor",
    "henon" -> <| "a" -> 1.05, "b" -> 0.5 |>
  |>
|>];

(* 7. A longer reverse-mode inverse demonstration (still short by
   design): watch the round-trip error grow with reverse_steps. *)
RunExperiment["reverse_demo_longer", <|
  "simulation" -> <|
    "mode" -> "reverse",
    "henon" -> <| "reverse_steps" -> 20 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

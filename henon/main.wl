#!/usr/bin/env wolframscript

(* ========================================================
   Hénon Map — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=sweep
          wolframscript -file main.wl -- --simulation.mode reverse
          Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =). *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i++
    ]
  ];
  result
];

cfg  = LoadConfig["henon", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "attractor"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

STEMHeading["Hénon Map"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at the canonical (a,b)=(1.4,0.3),
   independent of the active mode's own configured parameters, the
   same convention dynamical/main.wl uses for its own checks section
   (FixedPointCheck/Period2Check/LyapunovCheck run at their own fixed
   r values regardless of the run's chosen r). Checks 1, 2 and 4 test
   EXACT relations (tight tolerance); check 3 is an empirical
   benchmark comparison (generous tolerance) — see model.wl. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$jacobianChk = JacobianCheck[1.4, 0.3];
$lyaps       = HenonLyapunovExponents[1.4, 0.3, 50000, 2000];
$lyapSumChk  = LyapunovSumCheck[$lyaps, 0.3];
$lyapBenchChk = LyapunovBenchmarkCheck[$lyaps];
$inverseChk  = InverseExactnessCheck[1.4, 0.3];
PrintCorrectnessChecks[$jacobianChk, $lyapSumChk, $lyapBenchChk, $inverseChk];
Print["    1. Constant Jacobian determinant: max|det - (-b)| = ", FmtN[$jacobianChk["maxError"], 3],
      "  (exact relation, tight tolerance)"];
Print["    2. Lyapunov exponent sum: ", FmtN[$lyapSumChk["sum"], 6], " vs log(b) = ",
      FmtN[$lyapSumChk["expected"], 6], "  (exact relation, tight tolerance)"];
Print["    3. Largest Lyapunov exponent: ", FmtN[$lyapBenchChk["lambda1"], 6], " vs benchmark ~0.42",
      "  (empirical comparison, generous tolerance)"];
Print["    4. Inverse map exactness: max round-trip error = ", FmtN[$inverseChk["maxError"], 3],
      "  (exact relation, tight tolerance)"];
Print[""];

Which[

  (* ===== attractor (default) ===== *)
  mode === "attractor",

    a          = N @ GetCfg[cfg, {"simulation", "henon", "a"},          1.4];
    b          = N @ GetCfg[cfg, {"simulation", "henon", "b"},          0.3];
    x0         = N @ GetCfg[cfg, {"simulation", "henon", "x0"},         0.1];
    y0         = N @ GetCfg[cfg, {"simulation", "henon", "y0"},         0.1];
    nTransient =     GetCfg[cfg, {"simulation", "henon", "n_transient"}, 500];
    nPoints    =     GetCfg[cfg, {"simulation", "henon", "n_points"},   2000];

    Print["  a = ", FmtN[a, 4], "   b = ", FmtN[b, 4]];
    Print["  Transient: ", nTransient, "   Points on attractor: ", nPoints];
    Print[""];

    Print["[2/5] Settling onto the attractor..."];
    STEMSay["Settling onto the attractor"];
    attractorModel = HenonAttractorModel[x0, y0, a, b, nTransient, nPoints];
    If[!TrajectoryIsBounded[attractorModel["trajectory"]],
      Print["Error: trajectory diverged at a=", FmtN[a, 4], ", b=", FmtN[b, 4],
            " — the Hénon map's bounded region depends on BOTH parameters together; ",
            "try a smaller a for this b (canonical a=1.4 requires b near 0.3)."];
      Exit[1]
    ];
    dimension = BoxCountingDimension[attractorModel["trajectory"]];
    PrintAttractorSummary[attractorModel, dimension];
    Print[""];

    Print["[3/5] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "henon_attractor.csv"}];
    ExportAttractorCSV[BuildAttractorTrajectory[attractorModel], cfg, outCSV];
    Print[""];

    Print["[4/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "henon_attractor.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "henon_attractor.png"}];
    ExportAttractorAnimation[attractorModel["trajectory"], outGIF];
    ExportAttractorPNG[attractorModel["trajectory"], outPNG];
    STEMDescribeGIF[outGIF, 100, 12];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "henon_attractor.wav"}];
    {rawLeft, rawRight} = AttractorStereoBuffer[attractorModel, cfg];
    introText   = BuildAttractorIntroText[a, b];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== sweep ===== *)
  mode === "sweep",

    b           = N @ GetCfg[cfg, {"simulation", "henon", "b"},          0.3];
    x0          = N @ GetCfg[cfg, {"simulation", "henon", "x0"},         0.1];
    y0          = N @ GetCfg[cfg, {"simulation", "henon", "y0"},         0.1];
    aMin        = N @ GetCfg[cfg, {"simulation", "henon", "a_min"},      0.2];
    aMax        = N @ GetCfg[cfg, {"simulation", "henon", "a_max"},      1.4];
    aSteps      =     GetCfg[cfg, {"simulation", "henon", "a_steps"},    250];
    nTransient  =     GetCfg[cfg, {"simulation", "henon", "n_transient"}, 500];
    nAttractor  =     GetCfg[cfg, {"simulation", "henon", "n_attractor"}, 40];
    noteDuration = N @ GetCfg[cfg, {"simulation", "henon", "note_duration"}, 0.08];

    Print["  a: ", FmtN[aMin, 4], " -> ", FmtN[aMax, 4], "   b = ", FmtN[b, 4]];
    Print["  a_steps: ", aSteps, "   Attractor points per step: ", nAttractor];
    Print[""];

    Print["[2/5] Building sweep model and locating landmarks..."];
    STEMSay["Building sweep and locating bifurcation landmarks"];
    sweepModel = HenonSweepModel[aMin, aMax, aSteps, b, x0, y0, nTransient, nAttractor];
    landmarks  = HenonSweepLandmarks[b];
    PrintSweepSummary[sweepModel, landmarks];
    Print[""];

    Print["[3/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    sweepResult = SonifySweep[sweepModel, landmarks, noteDuration, sr];
    introText   = BuildSweepIntroText[aMin, aMax, landmarks];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, sweepResult["leftBuf"]];
    finalRight  = Join[introBuffer, pauseBuffer, sweepResult["rightBuf"]];
    outWAV = FileNameJoin[{$projectRoot, "output", "henon_sweep.wav"}];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/5] Exporting sweep data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "henon_sweep.csv"}];
    ExportSweepCSV[sweepResult, sweepModel["aValues"], outCSV];
    Print[""];

    Print["[5/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "henon_sweep.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "henon_sweep.png"}];
    AnimateSweepBifurcation[sweepModel, landmarks, outGIF];
    ExportSweepPNG[sweepModel, landmarks, outPNG];
    STEMDescribeGIF[outGIF, aSteps - 1, 12];
    Print["  PNG written: ", outPNG];
    Print[""],

  (* ===== reverse ===== *)
  mode === "reverse",

    a            = N @ GetCfg[cfg, {"simulation", "henon", "a"},           1.4];
    b            = N @ GetCfg[cfg, {"simulation", "henon", "b"},           0.3];
    x0           = N @ GetCfg[cfg, {"simulation", "henon", "x0"},          0.1];
    y0           = N @ GetCfg[cfg, {"simulation", "henon", "y0"},          0.1];
    nTransient   =     GetCfg[cfg, {"simulation", "henon", "n_transient"},  500];
    nForward     =     GetCfg[cfg, {"simulation", "henon", "n_forward"},    40];
    reverseSteps =     GetCfg[cfg, {"simulation", "henon", "reverse_steps"}, 10];
    noteDuration = N @ GetCfg[cfg, {"simulation", "henon", "note_duration"}, 0.08];

    Print["  a = ", FmtN[a, 4], "   b = ", FmtN[b, 4]];
    Print["  Forward segment points: ", nForward, "   Inverse-demo steps: ", reverseSteps];
    Print[""];

    Print["[2/5] Building forward / reversed / inverse-demo segments..."];
    STEMSay["Building forward, reversed, and inverse demonstration segments"];
    reverseModel = HenonReverseModel[x0, y0, a, b, nTransient, nForward, reverseSteps];
    If[!TrajectoryIsBounded[reverseModel["forwardSeg"]],
      Print["Error: trajectory diverged at a=", FmtN[a, 4], ", b=", FmtN[b, 4],
            " — the Hénon map's bounded region depends on BOTH parameters together; ",
            "try a smaller a for this b (canonical a=1.4 requires b near 0.3)."];
      Exit[1]
    ];
    PrintReverseSummary[reverseModel];
    Print[""];

    Print["[3/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    reverseResult = SonifyReverse[reverseModel, noteDuration, sr];
    introText     = BuildReverseIntroText[reverseSteps];
    introBuffer   = BuildIntroBuffer[introText, sr];
    introBuffer   = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer   = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft     = Join[introBuffer, pauseBuffer, reverseResult["leftBuf"]];
    finalRight    = Join[introBuffer, pauseBuffer, reverseResult["rightBuf"]];
    outWAV = FileNameJoin[{$projectRoot, "output", "henon_reverse.wav"}];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/5] Exporting reverse-demo data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "henon_reverse.csv"}];
    ExportReverseCSV[reverseResult, outCSV];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outPNG = FileNameJoin[{$projectRoot, "output", "henon_reverse.png"}];
    ExportReversePNG[reverseModel, outPNG];
    Print["  PNG written: ", outPNG];
    Print[""],

  (* ===== unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"attractor\", \"sweep\", or \"reverse\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

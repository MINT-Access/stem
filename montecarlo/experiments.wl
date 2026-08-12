#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — 2D Ising model parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own GIF, WAV, and CSV to output/
   so the results can be compared side by side.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

$sr = 44100;
$Tc = $OnsagerTc[1.0];

RunToFile[name_String, cfg_Association, sonifyResult_Association] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[
      NormalizeBuffer[{sonifyResult["left"], sonifyResult["right"]}, 0.92],
      outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];

$cfg = <| "sonification" -> <| "montecarlo" -> <| "spatial_layer_gain" -> -12 |> |> |>;


(* --- sweep_default: 32x32, T 4.0 -> 0.5, crossing T_c --- *)
Print[""];
Print[">>> Experiment: sweep_default"];
sweepDefault = RunSweepMode[32, 4.0, 0.5, 50, 200, 100, 1.0];
sweepSon = SonifyIsingRun[sweepDefault, sweepDefault["T"], $Tc, $cfg];
PrintSweepSummary[sweepDefault, $Tc, sweepSon];
RunToFile["sweep_default", $cfg, sweepSon];
{$gifFrames, $gifFps} = AnimateSweep[sweepDefault, $Tc,
  FileNameJoin[{$outDir, "sweep_default_animation.gif"}], sweepSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "sweep_default_animation.gif"}], $gifFrames, $gifFps];
ExportSweepCSV[sweepDefault, sweepSon["articulated"], FileNameJoin[{$outDir, "sweep_default_stats.csv"}]];

(* --- sweep_fine: finer temperature resolution --- *)
Print[""];
Print[">>> Experiment: sweep_fine"];
sweepFine = RunSweepMode[32, 4.0, 0.5, 100, 200, 100, 1.0];
sweepFineSon = SonifyIsingRun[sweepFine, sweepFine["T"], $Tc, $cfg];
RunToFile["sweep_fine", $cfg, sweepFineSon];
{$gifFrames, $gifFps} = AnimateSweep[sweepFine, $Tc,
  FileNameJoin[{$outDir, "sweep_fine_animation.gif"}], sweepFineSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "sweep_fine_animation.gif"}], $gifFrames, $gifFps];
ExportSweepCSV[sweepFine, sweepFineSon["articulated"], FileNameJoin[{$outDir, "sweep_fine_stats.csv"}]];

(* --- critical_default: fixed at T_c --- *)
Print[""];
Print[">>> Experiment: critical_default"];
critDefault = RunCriticalMode[32, $Tc, 500, 1.0];
critSon = SonifyIsingRun[critDefault, Missing[], $Tc, $cfg];
RunToFile["critical_default", $cfg, critSon];
{$gifFrames, $gifFps} = AnimateCritical[critDefault, $Tc,
  FileNameJoin[{$outDir, "critical_default_animation.gif"}], critSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "critical_default_animation.gif"}], $gifFrames, $gifFps];
ExportFixedTCSV[critDefault, critSon["articulated"], FileNameJoin[{$outDir, "critical_default_stats.csv"}]];

(* --- critical_above: fixed well above T_c, paramagnetic disorder --- *)
Print[""];
Print[">>> Experiment: critical_above"];
critAbove = RunCriticalMode[32, 3.5, 500, 1.0];
critAboveSon = SonifyIsingRun[critAbove, Missing[], $Tc, $cfg];
RunToFile["critical_above", $cfg, critAboveSon];
{$gifFrames, $gifFps} = AnimateCritical[critAbove, 3.5,
  FileNameJoin[{$outDir, "critical_above_animation.gif"}], critAboveSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "critical_above_animation.gif"}], $gifFrames, $gifFps];
ExportFixedTCSV[critAbove, critAboveSon["articulated"], FileNameJoin[{$outDir, "critical_above_stats.csv"}]];

(* --- critical_below: fixed well below T_c, ferromagnetic order --- *)
Print[""];
Print[">>> Experiment: critical_below"];
critBelow = RunCriticalMode[32, 1.0, 500, 1.0];
critBelowSon = SonifyIsingRun[critBelow, Missing[], $Tc, $cfg];
RunToFile["critical_below", $cfg, critBelowSon];
{$gifFrames, $gifFps} = AnimateCritical[critBelow, 1.0,
  FileNameJoin[{$outDir, "critical_below_animation.gif"}], critBelowSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "critical_below_animation.gif"}], $gifFrames, $gifFps];
ExportFixedTCSV[critBelow, critBelowSon["articulated"], FileNameJoin[{$outDir, "critical_below_stats.csv"}]];

(* --- quench_default: 4.0 -> 0.5 instantaneous --- *)
Print[""];
Print[">>> Experiment: quench_default"];
quenchDefault = RunQuenchMode[32, 0.5, 400, 1.0, 42];
quenchSon = SonifyIsingRun[quenchDefault, Missing[], $Tc, $cfg];
RunToFile["quench_default", $cfg, quenchSon];
{$gifFrames, $gifFps} = AnimateQuench[quenchDefault, 0.5,
  FileNameJoin[{$outDir, "quench_default_animation.gif"}], quenchSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "quench_default_animation.gif"}], $gifFrames, $gifFps];
ExportFixedTCSV[quenchDefault, quenchSon["articulated"], FileNameJoin[{$outDir, "quench_default_stats.csv"}]];

(* --- quench_large: 64x64, slower domain coarsening --- *)
Print[""];
Print[">>> Experiment: quench_large"];
quenchLarge = RunQuenchMode[64, 0.5, 400, 1.0, 42];
quenchLargeSon = SonifyIsingRun[quenchLarge, Missing[], $Tc, $cfg];
RunToFile["quench_large", $cfg, quenchLargeSon];
{$gifFrames, $gifFps} = AnimateQuench[quenchLarge, 0.5,
  FileNameJoin[{$outDir, "quench_large_animation.gif"}], quenchLargeSon["totalDuration"]];
STEMDescribeGIF[FileNameJoin[{$outDir, "quench_large_animation.gif"}], $gifFrames, $gifFps];
ExportFixedTCSV[quenchLarge, quenchLargeSon["articulated"], FileNameJoin[{$outDir, "quench_large_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

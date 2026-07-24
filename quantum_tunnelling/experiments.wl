#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Quantum tunnelling parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own GIF/PNG, WAV, and CSV to output/
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
$audioFreqMin = 150.0; $audioFreqMax = 2500.0;

RunToFile[name_String, left_List, right_List] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{left, right}, 0.92], outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];

MockCfg[assoc_Association] := <| "simulation" -> <| "quantum_tunnelling" -> assoc |> |>;


(* --- barrier_default: comfortably audible T (~2.35%) --- *)
Print[""];
Print[">>> Experiment: barrier_default"];
bar1 = BarrierModel[MockCfg[<| "preset" -> "default" |>]];
PrintBarrierSummary[bar1];
{l1, r1} = BuildBarrierAudio[bar1, $audioFreqMin, $audioFreqMax, $sr];
RunToFile["barrier_default", l1, r1];
AnimateBarrier[bar1, FileNameJoin[{$outDir, "barrier_default_animation.gif"}],
                     FileNameJoin[{$outDir, "barrier_default_plot.png"}]];
ExportBarrierCSV[bar1, FileNameJoin[{$outDir, "barrier_default_stats.csv"}]];

(* --- barrier_stm: scanning tunnelling microscope scale --- *)
Print[""];
Print[">>> Experiment: barrier_stm"];
bar2 = BarrierModel[MockCfg[<| "preset" -> "stm" |>]];
PrintBarrierSummary[bar2];
{l2, r2} = BuildBarrierAudio[bar2, $audioFreqMin, $audioFreqMax, $sr];
RunToFile["barrier_stm", l2, r2];
AnimateBarrier[bar2, FileNameJoin[{$outDir, "barrier_stm_animation.gif"}],
                     FileNameJoin[{$outDir, "barrier_stm_plot.png"}]];
ExportBarrierCSV[bar2, FileNameJoin[{$outDir, "barrier_stm_stats.csv"}]];

(* --- barrier_alpha_decay: illustrative nuclear scale --- *)
Print[""];
Print[">>> Experiment: barrier_alpha_decay"];
bar3 = BarrierModel[MockCfg[<| "preset" -> "alpha_decay" |>]];
PrintBarrierSummary[bar3];
{l3, r3} = BuildBarrierAudio[bar3, $audioFreqMin, $audioFreqMax, $sr];
RunToFile["barrier_alpha_decay", l3, r3];
AnimateBarrier[bar3, FileNameJoin[{$outDir, "barrier_alpha_decay_animation.gif"}],
                     FileNameJoin[{$outDir, "barrier_alpha_decay_plot.png"}]];
ExportBarrierCSV[bar3, FileNameJoin[{$outDir, "barrier_alpha_decay_stats.csv"}]];

(* --- barrier_manual: a custom manual configuration, resonance-adjacent --- *)
Print[""];
Print[">>> Experiment: barrier_manual"];
bar4 = BarrierModel[MockCfg[<| "preset" -> "manual", "energy_ev" -> 1.5,
                               "barrier_height_ev" -> 2.0, "barrier_width_nm" -> 0.3,
                               "mass_ev" -> $ElectronMassEnergyEV |>]];
PrintBarrierSummary[bar4];
{l4, r4} = BuildBarrierAudio[bar4, $audioFreqMin, $audioFreqMax, $sr];
RunToFile["barrier_manual", l4, r4];
AnimateBarrier[bar4, FileNameJoin[{$outDir, "barrier_manual_animation.gif"}],
                     FileNameJoin[{$outDir, "barrier_manual_plot.png"}]];
ExportBarrierCSV[bar4, FileNameJoin[{$outDir, "barrier_manual_stats.csv"}]];

(* --- sweep_default: full 0.1-3nm width sweep --- *)
Print[""];
Print[">>> Experiment: sweep_default"];
sweep1 = SweepModel[MockCfg[<| "energy_ev" -> 1.0, "barrier_height_ev" -> 2.0,
                               "width_min_nm" -> 0.1, "width_max_nm" -> 3.0, "n_steps" -> 100,
                               "mass_ev" -> $ElectronMassEnergyEV |>]];
PrintSweepSummary[sweep1];
{ls1, rs1} = BuildSweepAudio[sweep1, $audioFreqMin, $audioFreqMax, 6.0, $sr];
RunToFile["sweep_default", ls1, rs1];
AnimateSweep[sweep1, FileNameJoin[{$outDir, "sweep_default_animation.gif"}],
                     FileNameJoin[{$outDir, "sweep_default_plot.png"}]];
ExportSweepCSV[sweep1, FileNameJoin[{$outDir, "sweep_default_stats.csv"}]];

(* --- energy_default: full 0.1-6eV energy sweep, crossing V0=2eV --- *)
Print[""];
Print[">>> Experiment: energy_default"];
energy1 = EnergyModel[MockCfg[<| "barrier_height_ev" -> 2.0, "barrier_width_nm" -> 0.5,
                                 "energy_min_ev" -> 0.1, "energy_max_ev" -> 6.0, "n_steps" -> 100,
                                 "mass_ev" -> $ElectronMassEnergyEV |>]];
PrintEnergySummary[energy1];
{le1, re1} = BuildEnergyAudio[energy1, $audioFreqMin, $audioFreqMax, 8.0, $sr];
RunToFile["energy_default", le1, re1];
AnimateEnergy[energy1, FileNameJoin[{$outDir, "energy_default_animation.gif"}],
                       FileNameJoin[{$outDir, "energy_default_plot.png"}]];
ExportEnergyCSV[energy1, FileNameJoin[{$outDir, "energy_default_stats.csv"}]];

(* --- energy_wide: a wider sweep showing several resonance peaks --- *)
Print[""];
Print[">>> Experiment: energy_wide"];
energy2 = EnergyModel[MockCfg[<| "barrier_height_ev" -> 2.0, "barrier_width_nm" -> 0.5,
                                 "energy_min_ev" -> 0.1, "energy_max_ev" -> 20.0, "n_steps" -> 150,
                                 "mass_ev" -> $ElectronMassEnergyEV |>]];
PrintEnergySummary[energy2];
{le2, re2} = BuildEnergyAudio[energy2, $audioFreqMin, $audioFreqMax, 8.0, $sr];
RunToFile["energy_wide", le2, re2];
AnimateEnergy[energy2, FileNameJoin[{$outDir, "energy_wide_animation.gif"}],
                       FileNameJoin[{$outDir, "energy_wide_plot.png"}]];
ExportEnergyCSV[energy2, FileNameJoin[{$outDir, "energy_wide_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

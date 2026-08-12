#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Compton scattering parameter experiments

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
$audioFreqMin = 200.0; $audioFreqMax = 3000.0;
$EMinKev = 1.0; $EMaxKev = 5000.0;

RunToFile[name_String, left_List, right_List] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{left, right}, 0.92], outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];

MockCfg[assoc_Association] := <| "simulation" -> <| "compton" -> assoc |> |>;


(* --- scatter_compton1923: Compton's own 1923 Mo K-alpha values --- *)
Print[""];
Print[">>> Experiment: scatter_compton1923"];
scat1 = ScatterModel[MockCfg[<| "wavelength_pm" -> 71.0, "angle_deg" -> 90.0 |>]];
PrintScatterSummary[scat1];
{l1, r1} = BuildScatterAudio[scat1, $audioFreqMin, $audioFreqMax, $EMinKev, $EMaxKev, $sr];
RunToFile["scatter_compton1923", l1, r1];
AnimateScatter[scat1, FileNameJoin[{$outDir, "scatter_compton1923_animation.gif"}],
                      FileNameJoin[{$outDir, "scatter_compton1923_plot.png"}], N[Length[l1]] / $sr];
ExportScatterCSV[scat1, FileNameJoin[{$outDir, "scatter_compton1923_stats.csv"}]];

(* --- scatter_backscatter: theta=180, maximum possible shift --- *)
Print[""];
Print[">>> Experiment: scatter_backscatter"];
scat2 = ScatterModel[MockCfg[<| "wavelength_pm" -> 71.0, "angle_deg" -> 180.0 |>]];
PrintScatterSummary[scat2];
{l2, r2} = BuildScatterAudio[scat2, $audioFreqMin, $audioFreqMax, $EMinKev, $EMaxKev, $sr];
RunToFile["scatter_backscatter", l2, r2];
AnimateScatter[scat2, FileNameJoin[{$outDir, "scatter_backscatter_animation.gif"}],
                      FileNameJoin[{$outDir, "scatter_backscatter_plot.png"}], N[Length[l2]] / $sr];
ExportScatterCSV[scat2, FileNameJoin[{$outDir, "scatter_backscatter_stats.csv"}]];

(* --- scatter_gammaray: a much higher-energy photon (1 MeV), dramatic shift --- *)
Print[""];
Print[">>> Experiment: scatter_gammaray"];
scat3 = ScatterModel[MockCfg[<| "wavelength_pm" -> PhotonWavelengthPm[1000.0], "angle_deg" -> 90.0 |>]];
PrintScatterSummary[scat3];
{l3, r3} = BuildScatterAudio[scat3, $audioFreqMin, $audioFreqMax, $EMinKev, $EMaxKev, $sr];
RunToFile["scatter_gammaray", l3, r3];
AnimateScatter[scat3, FileNameJoin[{$outDir, "scatter_gammaray_animation.gif"}],
                      FileNameJoin[{$outDir, "scatter_gammaray_plot.png"}], N[Length[l3]] / $sr];
ExportScatterCSV[scat3, FileNameJoin[{$outDir, "scatter_gammaray_stats.csv"}]];

(* --- sweep_default: full 0-180 degree sweep at Compton's own wavelength --- *)
Print[""];
Print[">>> Experiment: sweep_default"];
sweep1 = SweepModel[MockCfg[<| "wavelength_pm" -> 71.0, "angle_min" -> 0.0, "angle_max" -> 180.0, "n_steps" -> 100 |>]];
PrintSweepSummary[sweep1];
{ls1, rs1} = BuildSweepAudio[sweep1, $audioFreqMin, $audioFreqMax, $EMinKev, $EMaxKev, 6.0, $sr];
RunToFile["sweep_default", ls1, rs1];
AnimateSweep[sweep1, FileNameJoin[{$outDir, "sweep_default_animation.gif"}],
                     FileNameJoin[{$outDir, "sweep_default_plot.png"}], N[Length[ls1]] / $sr];
ExportSweepCSV[sweep1, FileNameJoin[{$outDir, "sweep_default_stats.csv"}]];

(* --- energy_default: full 1 keV - 5 MeV incident-energy sweep --- *)
Print[""];
Print[">>> Experiment: energy_default"];
energy1 = EnergyModel[MockCfg[<| "energy_min_kev" -> 1.0, "energy_max_kev" -> 5000.0, "n_steps" -> 100, "angle_deg" -> 90.0 |>]];
PrintEnergySummary[energy1];
{le1, re1} = BuildEnergyAudio[energy1, $audioFreqMin, $audioFreqMax, 0.1, $sr];
RunToFile["energy_default", le1, re1];
AnimateEnergy[energy1, FileNameJoin[{$outDir, "energy_default_animation.gif"}],
                       FileNameJoin[{$outDir, "energy_default_plot.png"}], N[Length[le1]] / $sr];
ExportEnergyCSV[energy1, FileNameJoin[{$outDir, "energy_default_stats.csv"}]];

(* --- discovery_default: binaural Thomson vs Compton comparison --- *)
Print[""];
Print[">>> Experiment: discovery_default"];
disc1 = DiscoveryModel[MockCfg[<| "wavelength_pm" -> 71.0, "angle_min" -> 0.0, "angle_max" -> 180.0, "n_steps" -> 100 |>]];
PrintDiscoverySummary[disc1];
{ld1, rd1} = BuildDiscoveryAudio[disc1, $audioFreqMin, $audioFreqMax, $EMinKev, $EMaxKev, 8.0, $sr];
RunToFile["discovery_default", ld1, rd1];
RenderDiscoveryStaticPNG[disc1, FileNameJoin[{$outDir, "discovery_default_plot.png"}]];
ExportDiscoveryCSV[disc1, FileNameJoin[{$outDir, "discovery_default_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Statistical mechanics parameter experiments

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

RunToFile[name_String, buffers_Association] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[
      NormalizeBuffer[{buffers["left"], buffers["right"]}, 0.92],
      outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];


(* --- distribution_helium: default gas, full 100K->1000K sweep --- *)
Print[""];
Print[">>> Experiment: distribution_helium"];
distHelium = BuildDistributionAudio[4.0, 100.0, 1000.0, 100, 64, 80.0, 4000.0, 0.1, $sr];
PrintDistributionSummary[distHelium, "helium", 4.0];
RunToFile["distribution_helium", distHelium];
AnimateDistribution[distHelium, 4.0, 1000.0, FileNameJoin[{$outDir, "distribution_helium_animation.gif"}], 60];
ExportDistributionCSV[distHelium, FileNameJoin[{$outDir, "distribution_helium_stats.csv"}]];

(* --- distribution_nitrogen: heavier gas -- lower pitch at the same T --- *)
Print[""];
Print[">>> Experiment: distribution_nitrogen"];
distNitrogen = BuildDistributionAudio[28.0, 100.0, 1000.0, 100, 64, 80.0, 4000.0, 0.1, $sr];
PrintDistributionSummary[distNitrogen, "nitrogen", 28.0];
RunToFile["distribution_nitrogen", distNitrogen];
AnimateDistribution[distNitrogen, 28.0, 1000.0, FileNameJoin[{$outDir, "distribution_nitrogen_animation.gif"}], 60];
ExportDistributionCSV[distNitrogen, FileNameJoin[{$outDir, "distribution_nitrogen_stats.csv"}]];

(* --- distribution_hydrogen: lightest gas -- highest pitch at the same T --- *)
Print[""];
Print[">>> Experiment: distribution_hydrogen"];
distHydrogen = BuildDistributionAudio[2.0, 100.0, 1000.0, 100, 64, 80.0, 4000.0, 0.1, $sr];
PrintDistributionSummary[distHydrogen, "hydrogen", 2.0];
RunToFile["distribution_hydrogen", distHydrogen];
AnimateDistribution[distHydrogen, 2.0, 1000.0, FileNameJoin[{$outDir, "distribution_hydrogen_animation.gif"}], 60];
ExportDistributionCSV[distHydrogen, FileNameJoin[{$outDir, "distribution_hydrogen_stats.csv"}]];

(* --- ensemble_default: 20 helium particles at 300K --- *)
Print[""];
Print[">>> Experiment: ensemble_default"];
ensDefault = SimulateEnsemble[20, 4.0, 300.0, 200];
PrintEnsembleSummary[ensDefault, "helium"];
ensDefaultAudio = BuildEnsembleAudio[ensDefault, 80.0, 4000.0, 0.1, $sr];
RunToFile["ensemble_default", ensDefaultAudio];
AnimateEnsemble[ensDefault, FileNameJoin[{$outDir, "ensemble_default_animation.gif"}], 60];
ExportEnsembleCSV[ensDefault, FileNameJoin[{$outDir, "ensemble_default_stats.csv"}]];

(* --- ensemble_large: 50 particles at a higher temperature --- *)
Print[""];
Print[">>> Experiment: ensemble_large"];
ensLarge = SimulateEnsemble[50, 4.0, 600.0, 200];
PrintEnsembleSummary[ensLarge, "helium"];
ensLargeAudio = BuildEnsembleAudio[ensLarge, 80.0, 4000.0, 0.1, $sr];
RunToFile["ensemble_large", ensLargeAudio];
AnimateEnsemble[ensLarge, FileNameJoin[{$outDir, "ensemble_large_animation.gif"}], 60];
ExportEnsembleCSV[ensLarge, FileNameJoin[{$outDir, "ensemble_large_stats.csv"}]];

(* --- cooling_default: helium 1000K -> 50K --- *)
Print[""];
Print[">>> Experiment: cooling_default"];
coolTau = DefaultCoolingTau[5.0];
coolDefault = BuildCoolingAudio[4.0, 1000.0, 50.0, coolTau, 5.0, 64, 80.0, 4000.0, 0.1, $sr];
PrintCoolingSummary[coolDefault, "helium"];
RunToFile["cooling_default", coolDefault];
AnimateCooling[coolDefault, 4.0, FileNameJoin[{$outDir, "cooling_default_animation.gif"}], 60];
ExportCoolingCSV[coolDefault, FileNameJoin[{$outDir, "cooling_default_stats.csv"}]];

(* --- equipartition_monatomic: helium, no rotational contribution --- *)
Print[""];
Print[">>> Experiment: equipartition_monatomic"];
eqMono = BuildEquipartitionAudio[4.0, 100.0, 1000.0, 100, 64, 80.0, 4000.0, 0.1, "monatomic", $sr];
PrintEquipartitionSummary[eqMono, "monatomic"];
RunToFile["equipartition_monatomic", eqMono];
AnimateEquipartition[eqMono, FileNameJoin[{$outDir, "equipartition_monatomic_animation.gif"}], 30];
ExportEquipartitionCSV[eqMono, FileNameJoin[{$outDir, "equipartition_monatomic_stats.csv"}]];

(* --- equipartition_diatomic: nitrogen, rotational drone appears --- *)
Print[""];
Print[">>> Experiment: equipartition_diatomic"];
eqDi = BuildEquipartitionAudio[28.0, 100.0, 1000.0, 100, 64, 80.0, 4000.0, 0.1, "diatomic", $sr];
PrintEquipartitionSummary[eqDi, "diatomic"];
RunToFile["equipartition_diatomic", eqDi];
AnimateEquipartition[eqDi, FileNameJoin[{$outDir, "equipartition_diatomic_animation.gif"}], 30];
ExportEquipartitionCSV[eqDi, FileNameJoin[{$outDir, "equipartition_diatomic_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

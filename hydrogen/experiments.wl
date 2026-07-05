#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Hydrogen atom parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own audio/animation/data files to
   output/, named by experiment, so results can be compared directly
   without overwriting the plain `main.wl` run's default output files.
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

sr      = 44100;
freqMin = 100.0;
freqMax = 4000.0;


(* --- Helper: run one orbital experiment --- *)
RunOrbitalExperiment[name_String, label_String, orbitalKey_String, gridSize_Integer] :=
  Module[{orbitalModel, sonifyResult, outWAV},
    Print[""];
    Print[">>> Experiment: ", name, "  -- ", label];

    orbitalModel = ComputeOrbitalTraversal[orbitalKey, gridSize];
    PrintWaveFunctionCheck[orbitalKey];
    Print["  Pixels: ", orbitalModel["nPixels"], "  r_max: ", FmtN[orbitalModel["rMax"], 4], " a0"];

    sonifyResult = SonifyOrbitals[orbitalModel, freqMin, freqMax, 0.02, sr];
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    ExportAudioBuffer[sonifyResult["buffer"], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[sonifyResult["buffer"]]] / sr];

    AnimateOrbital[orbitalModel, FileNameJoin[{$outDir, name <> ".gif"}],
                                 FileNameJoin[{$outDir, name <> ".png"}]];
    ExportOrbitalsCSV[orbitalModel, sonifyResult["freqs"], sonifyResult["amps"],
                      FileNameJoin[{$outDir, name <> "_data.csv"}]]
  ];


(* --- Helper: run one transitions experiment --- *)
RunTransitionsExperiment[name_String, label_String, nStart_Integer, lStart_Integer,
                         nRealizations_Integer, maxSteps_Integer] :=
  Module[{cascadesList, sonifyResult, outWAV},
    Print[""];
    Print[">>> Experiment: ", name, "  -- ", label];

    SeedRandom[7];
    cascadesList = Table[SimulateCascade[nStart, lStart, maxSteps], {nRealizations}];
    Print["  Path lengths: min=", Min[Map[Length, cascadesList]],
          "  max=", Max[Map[Length, cascadesList]]];
    PrintSelectionRuleCheck[Flatten[cascadesList]];

    sonifyResult = SonifyCascades[cascadesList, freqMin, freqMax, sr];
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    Export[outWAV, Sound[SampledSoundList[{sonifyResult["left"], sonifyResult["right"]}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[sonifyResult["left"]]] / sr];

    AnimateTransitions[cascadesList, nStart, FileNameJoin[{$outDir, name <> ".gif"}]];
    ExportTransitionsCSV[cascadesList, sonifyResult["panLists"], sonifyResult["durLists"],
                         sonifyResult["freqLists"], FileNameJoin[{$outDir, name <> "_data.csv"}]]
  ];


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- orbital_1s: ground state, single central peak, no nodes --- *)
RunOrbitalExperiment["orbital_1s", "1s ground state -- single central peak, no nodes",
  "100", 32];

(* --- orbital_2s: one radial node -- a silent shell inside the sonification --- *)
RunOrbitalExperiment["orbital_2s", "2s -- one radial node between two shells",
  "200", 32];

(* --- orbital_2p: two lobes along z, an angular node at the origin plane --- *)
RunOrbitalExperiment["orbital_2p", "2p (default) -- two lobes along z, angular node",
  "210", 64];

(* --- orbital_3d_clover: four-lobe pattern, most sonically distinct orbital --- *)
RunOrbitalExperiment["orbital_3d_clover", "3d (m=+-1) -- four-lobe clover pattern",
  "321", 64];


(* --- spectrum_full: full n=2..8 spectrum, the main.wl demo preset --- *)
Print[""];
Print[">>> Experiment: spectrum_full  -- full emission spectrum, n_max=8"];
spectrumResult = BuildSpectrumAudio[8, freqMin, freqMax, 3.0, 0.3, sr];
ExportAudioBuffer[spectrumResult["chordBuf"], FileNameJoin[{$outDir, "spectrum_full_chord.wav"}], sr];
ExportAudioBuffer[spectrumResult["sweepBuf"], FileNameJoin[{$outDir, "spectrum_full_sweep.wav"}], sr];
AnimateSpectrum[spectrumResult, FileNameJoin[{$outDir, "spectrum_full.gif"}]];
ExportSpectrumCSV[spectrumResult, FileNameJoin[{$outDir, "spectrum_full_data.csv"}]];

(* --- spectrum_lyman_only: transitions ending only at n=1, all-UV chord --- *)
Print[""];
Print[">>> Experiment: spectrum_lyman_only  -- n_max=4, still spans Lyman+Balmer+Paschen alpha"];
spectrumSmall = BuildSpectrumAudio[4, freqMin, freqMax, 2.0, 0.3, sr];
ExportAudioBuffer[spectrumSmall["chordBuf"], FileNameJoin[{$outDir, "spectrum_small_chord.wav"}], sr];
ExportAudioBuffer[spectrumSmall["sweepBuf"], FileNameJoin[{$outDir, "spectrum_small_sweep.wav"}], sr];


(* --- cascade_default: n=5,l=2 start, 20 realisations (main.wl default) --- *)
RunTransitionsExperiment["cascade_default", "Default cascade: n=5,l=2, 20 realisations",
  5, 2, 20, 50];

(* --- cascade_high: n=7 start -- longer, more varied cascades --- *)
RunTransitionsExperiment["cascade_high", "Higher start: n=7,l=3, 10 realisations",
  7, 3, 10, 50];

(* --- cascade_few: 5 realisations -- easier to follow individually by ear --- *)
RunTransitionsExperiment["cascade_few", "Few realisations: n=5,l=2, 5 realisations",
  5, 2, 5, 50];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

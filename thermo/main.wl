#!/usr/bin/env wolframscript

(* ========================================================
   Classical Statistical Mechanics — Entry Point

   Sonifies the Maxwell-Boltzmann speed distribution, particle
   ensembles under elastic collisions, thermal cooling (Newton's law
   of cooling), and the equipartition theorem. Purely classical
   statistical mechanics — no quantum statistics.

   Usage:
     wolframscript -file main.wl                                        # distribution, helium, 100K->1000K
     wolframscript -file main.wl -- --simulation.mode=ensemble          # 20 particles at 300K
     wolframscript -file main.wl -- --simulation.mode=cooling           # helium cooling 1000K->50K
     wolframscript -file main.wl -- --simulation.mode=equipartition     # monatomic vs diatomic
     wolframscript -file main.wl -- --simulation.thermo.preset=nitrogen
     wolframscript -file main.wl -- --simulation.thermo.preset=hydrogen
     wolframscript -file main.wl -- --simulation.thermo.T_fixed=600
     wolframscript -file main.wl -- --simulation.thermo.n_particles=50
     wolframscript -file main.wl -- --config-dump

   Modes:
     distribution (default) -- sweep T, sonify f(v) directly as a
                               spectral envelope (one additive-synthesis
                               frame per temperature step)
     ensemble               -- N particles sampled from the MB
                               distribution, sonified as a chord that
                               reshuffles via elastic collisions
     cooling                -- exponential relaxation from T_hot to
                               T_cold; the spectral envelope contracts
                               and quiets as the gas cools
     equipartition           -- binaural comparison: left channel is
                               always the translational MB spectrum;
                               right channel is a rotational-energy
                               drone, present only for diatomic gases

   Gas presets (--simulation.thermo.preset=):
     hydrogen (2 amu)  helium (4 amu)  nitrogen (28 amu)
     oxygen (32 amu)   argon (40 amu)

   Outputs (thermo/output/):
     distribution_audio.wav / distribution.gif / distribution_data.csv
     ensemble_audio.wav     / ensemble.gif     / ensemble_data.csv
     cooling_audio.wav      / cooling.gif      / cooling_data.csv
     equipartition_audio.wav / equipartition.gif / equipartition_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

(* ── CLI preprocessing ──────────────────────────────────────────── *)
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
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["thermo", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "distribution"];

massAmuCfg = GetCfg[cfg, {"simulation", "thermo", "mass_amu"}, 4];
preset     = GetCfg[cfg, {"simulation", "thermo", "preset"},   "helium"];
massAmu    = N[GasMassAmu[preset, massAmuCfg]];
gasName    = GasDisplayName[preset];

freqMin  = N @ GetCfg[cfg, {"simulation", "thermo", "freq_min"}, 80];
freqMax  = N @ GetCfg[cfg, {"simulation", "thermo", "freq_max"}, 4000];
nBins    =     GetCfg[cfg, {"simulation", "thermo", "n_bins"},   64];
frameDur = N @ GetCfg[cfg, {"simulation", "thermo", "frame_duration"}, 0.1];
sr       =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Classical Statistical Mechanics: " <>
  Capitalize[mode]];
Print["  Mode: ", mode];
If[mode =!= "equipartition", Print["  Gas:  ", gasName, "  (", massAmu, " amu)"]];
Print[""];

STEMSay["Starting statistical mechanics sonification: " <> mode];

$nSteps5 = 5;
outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

Which[

  (* ══════════════════════════════════════════════════════
     DISTRIBUTION MODE
     ══════════════════════════════════════════════════════ *)
  mode === "distribution",

    TStart = N @ GetCfg[cfg, {"simulation", "thermo", "T_start"}, 100];
    TEnd   = N @ GetCfg[cfg, {"simulation", "thermo", "T_end"},   1000];
    nSteps =     GetCfg[cfg, {"simulation", "thermo", "n_steps"}, 100];

    Print["  T range: ", TStart, " K -> ", TEnd, " K  (", nSteps, " steps)"];
    Print[""];

    Print["[1/", $nSteps5, "] Correctness checks..."];
    PrintCoreChecks[massAmu, TStart];
    Print[""];

    Print["[2/", $nSteps5, "] Building Maxwell-Boltzmann temperature sweep..."];
    distResult = BuildDistributionAudio[massAmu, TStart, TEnd, nSteps, nBins, freqMin, freqMax, frameDur, sr];
    PrintDistributionSummary[distResult, gasName, massAmu];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the Maxwell-Boltzmann distribution"];
    introText   = BuildDistributionIntroText[gasName, massAmu, TStart, TEnd];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, distResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, distResult["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the distribution animation"];
    nFramesRendered = AnimateDistribution[distResult, massAmu, TEnd, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 12];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportDistributionCSV[distResult, outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     ENSEMBLE MODE
     ══════════════════════════════════════════════════════ *)
  mode === "ensemble",

    nParticles = Min[GetCfg[cfg, {"simulation", "thermo", "n_particles"}, 20], 50];
    TFixed     = N @ GetCfg[cfg, {"simulation", "thermo", "T_fixed"}, 300];
    nTimesteps = GetCfg[cfg, {"simulation", "thermo", "n_timesteps"}, 200];

    Print["  Particles: ", nParticles, "   T: ", TFixed, " K   Timesteps: ", nTimesteps];
    Print[""];

    Print["[1/", $nSteps5, "] Correctness checks..."];
    PrintCoreChecks[massAmu, TFixed];
    Print[""];

    Print["[2/", $nSteps5, "] Simulating particle ensemble with elastic collisions..."];
    ensembleModel = SimulateEnsemble[nParticles, massAmu, TFixed, nTimesteps];
    PrintEnsembleCheck[Last[ensembleModel["speedsHistory"]], massAmu, TFixed];
    PrintEnsembleSummary[ensembleModel, gasName];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the particle ensemble"];
    introText   = BuildEnsembleIntroText[nParticles, gasName, TFixed];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    ensResult   = BuildEnsembleAudio[ensembleModel, freqMin, freqMax, frameDur, sr];
    finalLeft   = Join[introBuffer, pauseBuffer, ensResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, ensResult["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the ensemble histogram animation"];
    nFramesRendered = AnimateEnsemble[ensembleModel, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 10];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportEnsembleCSV[ensembleModel, outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     COOLING MODE
     ══════════════════════════════════════════════════════ *)
  mode === "cooling",

    THot     = N @ GetCfg[cfg, {"simulation", "thermo", "T_hot"},  1000];
    TCold    = N @ GetCfg[cfg, {"simulation", "thermo", "T_cold"}, 50];
    duration = 5.0;
    tau      = DefaultCoolingTau[duration];

    Print["  T_hot: ", THot, " K -> T_cold: ", TCold, " K   (tau = ", FmtN[tau, 5], " s)"];
    Print[""];

    Print["[1/", $nSteps5, "] Correctness checks..."];
    PrintCoreChecks[massAmu, THot];
    Print[""];

    Print["[2/", $nSteps5, "] Building cooling curve..."];
    coolResult = BuildCoolingAudio[massAmu, THot, TCold, tau, duration, nBins, freqMin, freqMax, frameDur, sr];
    PrintCoolingSummary[coolResult, gasName];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying thermal cooling"];
    introText   = BuildCoolingIntroText[gasName, THot, TCold];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, coolResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, coolResult["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the cooling animation"];
    nFramesRendered = AnimateCooling[coolResult, massAmu, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 10];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportCoolingCSV[coolResult, outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     EQUIPARTITION MODE
     ══════════════════════════════════════════════════════ *)
  mode === "equipartition",

    TStart       = N @ GetCfg[cfg, {"simulation", "thermo", "T_start"}, 100];
    TEnd         = N @ GetCfg[cfg, {"simulation", "thermo", "T_end"},   1000];
    nSteps       = GetCfg[cfg, {"simulation", "thermo", "n_steps"}, 100];
    moleculeType = GetCfg[cfg, {"simulation", "thermo", "molecule"}, "diatomic"];

    (* Equipartition mode's mass comes from the molecule type, not the
       preset/mass_amu keys used by the other three modes — "molecule"
       selects both the DOF count and a representative gas, so the
       translational spectrum uses a mass consistent with what the
       listener is told they're hearing. *)
    massAmuEq = N @ GasMassAmu[RepresentativeGasForMoleculeType[moleculeType], 4];
    gasNameEq = RepresentativeGasForMoleculeType[moleculeType];

    Print["  Molecule: ", moleculeType, "  (representative gas: ", gasNameEq, ", ", massAmuEq, " amu)"];
    Print["  T range: ", TStart, " K -> ", TEnd, " K  (", nSteps, " steps)"];
    Print[""];

    Print["[1/", $nSteps5, "] Correctness checks..."];
    PrintCoreChecks[massAmuEq, TStart];
    PrintEquipartitionChecks[GasMassAmu["helium", 4], GasMassAmu["nitrogen", 28], TStart];
    Print[""];

    Print["[2/", $nSteps5, "] Building equipartition comparison..."];
    eqResult = BuildEquipartitionAudio[massAmuEq, TStart, TEnd, nSteps, nBins, freqMin, freqMax,
                                       frameDur, moleculeType, sr];
    PrintEquipartitionSummary[eqResult, moleculeType];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the equipartition theorem"];
    introText   = BuildEquipartitionIntroText[moleculeType, TStart, TEnd];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, eqResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, eqResult["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the equipartition animation"];
    nFramesRendered = AnimateEquipartition[eqResult, outGIF, 30];
    STEMDescribeGIF[outGIF, nFramesRendered, 8];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportEquipartitionCSV[eqResult, outCSV];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"distribution\", \"ensemble\", \"cooling\", or \"equipartition\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Statistical mechanics sonification complete. Play audio: " <> STEMPlayCmd[outWAV]]

#!/usr/bin/env wolframscript

(* ========================================================
   Brownian Motion — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=ensemble
          wolframscript -file main.wl -- --simulation.mode temperature
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

cfg  = LoadConfig["brownian", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "walk"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
seed = GetCfg[cfg, {"simulation", "brownian", "seed"}, 7];

STEMHeading["Brownian Motion"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at canonical, representative
   parameters (1 micron particle, water viscosity, room temperature,
   dt=0.01s), independent of the active mode's own configured
   parameters, the same convention henon/main.wl and dynamical/main.wl
   use for their own checks sections. Checks 1, 3 and 4 hold for ANY
   (D,dt); check 2 specifically targets this canonical scenario. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$canonicalD  = StokesEinsteinD[293.15, 1.0*^-3, 1.0*^-6];
$canonicalDt = 0.01;
$msdChk  = MSDScalingCheck[$canonicalD, $canonicalDt];
$seChk   = StokesEinsteinScaleCheck[];
$kurtChk = ExactGaussianKurtosisCheck[$canonicalD, $canonicalDt];
$sqrtChk = SqrtGrowthCheck[$canonicalD, $canonicalDt];
PrintCorrectnessChecks[$msdChk, $seChk, $kurtChk, $sqrtChk];
Print["    1. MSD scaling <r^2(t)>=4Dt: empirical = ", FmtN[$msdChk["empMSD"], 4],
      "  predicted = ", FmtN[$msdChk["predicted"], 4], "  (Monte Carlo, tight tolerance)"];
Print["    2. Stokes-Einstein realistic scale: D = ", FmtN[$seChk["D"], 4],
      " m^2/s at 1 micron/water/room-temp (expected ~1e-13 to 1e-12)"];
Print["    3. Exact-zero excess kurtosis at N=", $kurtChk["nSteps"], ": ",
      FmtN[$kurtChk["empKurt"], 6], "  (contrast: clt/'s own non-Gaussian-source ",
      "kurtosis-decay check is still visibly nonzero at N=30)"];
Print["    4. sqrt(t) growth shape: RMS ratio = ", FmtN[$sqrtChk["ratio"], 4],
      "  predicted = ", FmtN[$sqrtChk["predicted"], 4], "  (rules out linear-in-t growth)"];
Print[""];

Which[

  (* ===== walk (default) ===== *)
  mode === "walk",

    rParticleUm = N @ GetCfg[cfg, {"simulation", "brownian", "particle_radius_um"}, 1.0];
    viscosity   = N @ GetCfg[cfg, {"simulation", "brownian", "viscosity_pa_s"},     0.001];
    temperature = N @ GetCfg[cfg, {"simulation", "brownian", "temperature_k"},      293.15];
    nSteps      =     GetCfg[cfg, {"simulation", "brownian", "n_steps"},            2000];
    dt          = N @ GetCfg[cfg, {"simulation", "brownian", "dt"},                 0.01];

    Dcoeff = StokesEinsteinD[temperature, viscosity, rParticleUm * 10.0^-6];
    Print["  particle radius: ", rParticleUm, " um   viscosity: ", FmtN[viscosity, 4],
          " Pa s   T: ", temperature, " K"];
    Print["  D = ", FmtN[Dcoeff, 4], " m^2/s   Steps: ", nSteps, "   dt: ", dt, " s"];
    Print[""];

    Print["[2/5] Generating random walk..."];
    STEMSay["Generating a random walk"];
    SeedRandom[seed];
    walkTable = WalkTrajectory[nSteps, Dcoeff, dt];
    PrintWalkSummary[walkTable, Dcoeff, dt];
    Print[""];

    Print["[3/5] Exporting trajectory data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "brownian_walk.csv"}];
    ExportWalkCSV[walkTable, outCSV];
    Print[""];

    (* Audio before GIF (swapped from the original 4/5-then-5/5 order):
       the GIF's playback duration must match the WAV's ACTUAL total
       length (intro speech + pause + walk sonification) — intro speech
       length depends on the platform TTS engine and is not knowable in
       advance, so it must be measured after export before the GIF can
       be sized to match it. *)
    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "brownian_walk.wav"}];
    {rawLeft, rawRight} = WalkStereoBuffer[walkTable, cfg];
    introText   = BuildWalkIntroText[Dcoeff, nSteps];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[5/5] Rendering animation..."];
    STEMSay["Rendering animation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "brownian_walk.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "brownian_walk.png"}];
    {$gifFrames, $gifFps} = ExportWalkAnimation[walkTable, outGIF, wavDuration];
    ExportWalkPNG[walkTable, outPNG];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print["  PNG written: ", outPNG];
    Print[""],

  (* ===== ensemble ===== *)
  mode === "ensemble",

    rParticleUm = N @ GetCfg[cfg, {"simulation", "brownian", "particle_radius_um"}, 1.0];
    viscosity   = N @ GetCfg[cfg, {"simulation", "brownian", "viscosity_pa_s"},     0.001];
    temperature = N @ GetCfg[cfg, {"simulation", "brownian", "temperature_k"},      293.15];
    nSteps      =     GetCfg[cfg, {"simulation", "brownian", "n_steps"},            2000];
    dt          = N @ GetCfg[cfg, {"simulation", "brownian", "dt"},                 0.01];
    nWalkers    =     GetCfg[cfg, {"simulation", "brownian", "n_walkers"},          150];
    duration    = N @ GetCfg[cfg, {"sonification", "duration"},                    10.0];

    Dcoeff = StokesEinsteinD[temperature, viscosity, rParticleUm * 10.0^-6];
    Print["  D = ", FmtN[Dcoeff, 4], " m^2/s   Walkers: ", nWalkers, "   Steps: ", nSteps, "   dt: ", dt, " s"];
    Print[""];

    Print["[2/5] Building ensemble..."];
    STEMSay["Building the ensemble of random walkers"];
    SeedRandom[seed];
    ensembleModel = EnsembleModel[nWalkers, nSteps, Dcoeff, dt];
    PrintEnsembleSummary[ensembleModel];
    Print[""];

    Print["[3/5] Exporting ensemble data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "brownian_ensemble.csv"}];
    ExportEnsembleCSV[ensembleModel, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outPNG = FileNameJoin[{$projectRoot, "output", "brownian_ensemble.png"}];
    ExportEnsemblePNG[ensembleModel, outPNG];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "brownian_ensemble.wav"}];
    {rawLeft, rawRight} = EnsembleGlissandoBuffer[ensembleModel, 220.0, 1600.0, duration, sr];
    introText   = BuildEnsembleIntroText[nWalkers];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== temperature ===== *)
  mode === "temperature",

    rParticleUm      = N @ GetCfg[cfg, {"simulation", "brownian", "particle_radius_um"}, 1.0];
    viscosity        = N @ GetCfg[cfg, {"simulation", "brownian", "viscosity_pa_s"},     0.001];
    tempMin          = N @ GetCfg[cfg, {"simulation", "brownian", "temp_min"},           275.0];
    tempMax          = N @ GetCfg[cfg, {"simulation", "brownian", "temp_max"},           350.0];
    nTempSteps       =     GetCfg[cfg, {"simulation", "brownian", "n_temp_steps"},       6];
    nStepsPerFrame   =     GetCfg[cfg, {"simulation", "brownian", "n_steps_per_frame"},  40];
    dt               = N @ GetCfg[cfg, {"simulation", "brownian", "dt"},                 0.01];
    frameDuration    = N @ GetCfg[cfg, {"simulation", "brownian", "frame_duration"},     3.0];

    tVals = N[Subdivide[tempMin, tempMax, nTempSteps - 1]];
    dVals = StokesEinsteinD[#, viscosity, rParticleUm * 10.0^-6] & /@ tVals;

    Print["  T: ", tempMin, " K -> ", tempMax, " K   Steps: ", nTempSteps,
          "   particle radius: ", rParticleUm, " um"];
    Print[""];

    Print["[2/5] Computing D(T) via Stokes-Einstein..."];
    STEMSay["Computing the diffusion coefficient across a temperature sweep"];
    PrintTemperatureSummary[tVals, dVals];
    Print[""];

    Print["[3/5] Generating representative walks..."];
    STEMSay["Generating representative walks at each temperature"];
    SeedRandom[seed];
    walkTables = WalkTrajectory[nStepsPerFrame, #, dt] & /@ dVals;
    Print[""];

    Print["[4/5] Exporting data and rendering visualisation..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "brownian_temperature.csv"}];
    ExportTemperatureCSV[tVals, dVals, walkTables, outCSV];
    outPNG = FileNameJoin[{$projectRoot, "output", "brownian_temperature.png"}];
    ExportTemperaturePanel[tVals, walkTables, outPNG];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "brownian_temperature.wav"}];
    {rawLeft, rawRight} = BuildTemperatureAudio[tVals, dVals, nStepsPerFrame, dt, frameDuration, cfg];
    introText   = BuildTemperatureIntroText[tempMin, tempMax];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"walk\", \"ensemble\", or \"temperature\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

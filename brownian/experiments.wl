#!/usr/bin/env wolframscript

(* brownian/experiments.wl — Curated runs across all three Brownian
   motion modes. Each experiment calls the same pipeline as main.wl
   and writes its outputs to brownian/output/, including the
   prepended spoken intro. *)

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
  Module[{cfg, mode, rParticleUm, viscosity, temperature, nSteps, dt, nWalkers,
          duration, tempMin, tempMax, nTempSteps, nStepsPerFrame, frameDuration, sr, seed,
          Dcoeff, tVals, dVals, walkTable, ensembleModel, walkTables,
          outWAV, outGIF, outPNG, outCSV,
          rawLeft, rawRight, introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["brownian", {}], overrides];

    mode           = GetCfg[cfg, {"simulation", "mode"},                        "walk"];
    rParticleUm    = N @ GetCfg[cfg, {"simulation", "brownian", "particle_radius_um"}, 1.0];
    viscosity      = N @ GetCfg[cfg, {"simulation", "brownian", "viscosity_pa_s"},     0.001];
    temperature    = N @ GetCfg[cfg, {"simulation", "brownian", "temperature_k"},      293.15];
    nSteps         =     GetCfg[cfg, {"simulation", "brownian", "n_steps"},            2000];
    dt             = N @ GetCfg[cfg, {"simulation", "brownian", "dt"},                 0.01];
    nWalkers       =     GetCfg[cfg, {"simulation", "brownian", "n_walkers"},          150];
    tempMin        = N @ GetCfg[cfg, {"simulation", "brownian", "temp_min"},           275.0];
    tempMax        = N @ GetCfg[cfg, {"simulation", "brownian", "temp_max"},           350.0];
    nTempSteps     =     GetCfg[cfg, {"simulation", "brownian", "n_temp_steps"},       6];
    nStepsPerFrame =     GetCfg[cfg, {"simulation", "brownian", "n_steps_per_frame"},  40];
    frameDuration  = N @ GetCfg[cfg, {"simulation", "brownian", "frame_duration"},     3.0];
    seed           =     GetCfg[cfg, {"simulation", "brownian", "seed"},               7];
    sr             =     GetCfg[cfg, {"sonification", "sample_rate"},                 44100];
    duration       = N @ GetCfg[cfg, {"sonification", "duration"},                    10.0];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "walk",
        Dcoeff = StokesEinsteinD[temperature, viscosity, rParticleUm * 10.0^-6];
        SeedRandom[seed];
        walkTable = WalkTrajectory[nSteps, Dcoeff, dt];
        PrintWalkSummary[walkTable, Dcoeff, dt];

        {rawLeft, rawRight} = WalkStereoBuffer[walkTable, cfg];
        introText   = BuildWalkIntroText[Dcoeff, nSteps];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportWalkAnimation[walkTable, outGIF, totalDurSec];
        ExportWalkPNG[walkTable, outPNG];
        ExportWalkCSV[walkTable, outCSV],

      mode === "ensemble",
        Dcoeff = StokesEinsteinD[temperature, viscosity, rParticleUm * 10.0^-6];
        SeedRandom[seed];
        ensembleModel = EnsembleModel[nWalkers, nSteps, Dcoeff, dt];
        PrintEnsembleSummary[ensembleModel];

        {rawLeft, rawRight} = EnsembleGlissandoBuffer[ensembleModel, 220.0, 1600.0, duration, sr];
        introText   = BuildEnsembleIntroText[nWalkers];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportEnsemblePNG[ensembleModel, outPNG];
        ExportEnsembleCSV[ensembleModel, outCSV],

      mode === "temperature",
        tVals = N[Subdivide[tempMin, tempMax, nTempSteps - 1]];
        dVals = StokesEinsteinD[#, viscosity, rParticleUm * 10.0^-6] & /@ tVals;
        PrintTemperatureSummary[tVals, dVals];

        SeedRandom[seed];
        walkTables = WalkTrajectory[nStepsPerFrame, #, dt] & /@ dVals;

        {rawLeft, rawRight} = BuildTemperatureAudio[tVals, dVals, nStepsPerFrame, dt, frameDuration, cfg];
        introText   = BuildTemperatureIntroText[tempMin, tempMax];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportTemperaturePanel[tVals, walkTables, outPNG];
        ExportTemperatureCSV[tVals, dVals, walkTables, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) —
   run in order to hear the random walk from three angles. *)

RunExperiment["walk_default", <|
  "simulation" -> <| "mode" -> "walk" |>
|>];

RunExperiment["ensemble_default", <|
  "simulation" -> <| "mode" -> "ensemble" |>
|>];

RunExperiment["temperature_default", <|
  "simulation" -> <| "mode" -> "temperature" |>
|>];

(* 4. A larger particle: much smaller D, a visibly (and audibly) less
   agitated walk than the default 1-micron case — the same physics
   Perrin varied across in his own particle-size experiments. *)
RunExperiment["walk_larger_particle", <|
  "simulation" -> <|
    "mode" -> "walk",
    "brownian" -> <| "particle_radius_um" -> 5.0 |>
  |>
|>];

(* 5. A larger ensemble, fewer steps: sqrt(t) law visible sooner, with
   less Monte Carlo noise in the averaged curve. *)
RunExperiment["ensemble_large", <|
  "simulation" -> <|
    "mode" -> "ensemble",
    "brownian" -> <| "n_walkers" -> 400, "n_steps" -> 800 |>
  |>
|>];

(* 6. A wider (still physically liquid) temperature sweep, to make the
   real-but-modest D(T) trend as pronounced as it honestly gets without
   leaving water's liquid range. *)
RunExperiment["temperature_wide", <|
  "simulation" -> <|
    "mode" -> "temperature",
    "brownian" -> <| "temp_min" -> 274.0, "temp_max" -> 370.0, "n_temp_steps" -> 8 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

#!/usr/bin/env wolframscript

(* qubit/experiments.wl — Curated runs across all three qubit modes.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to qubit/output/, including the prepended spoken intro. *)

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

BlochAnglesToState[thetaDeg_, phiDeg_] :=
  Module[{theta = thetaDeg * Pi / 180.0, phi = phiDeg * Pi / 180.0},
    {N[Cos[theta / 2.0]], N[Exp[I * phi] * Sin[theta / 2.0]]}
  ];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, gateSequence, thetaDeg, phiDeg, nStepsPerGate,
          Omega, tMax, nTrials, seed, sr, duration,
          alpha0, beta0, gatesResult, tVals, p1Vals, trialsResult,
          outWAV, outGIF, outPNG, outCSV,
          rawLeft, rawRight, introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["qubit", {}], overrides];

    mode           = GetCfg[cfg, {"simulation", "mode"},                          "gates"];
    gateSequence   = GetCfg[cfg, {"simulation", "qubit", "gate_sequence"},         {"H", "T", "H", "S", "X"}];
    thetaDeg       = N @ GetCfg[cfg, {"simulation", "qubit", "initial_theta_deg"}, 0.0];
    phiDeg         = N @ GetCfg[cfg, {"simulation", "qubit", "initial_phi_deg"},   0.0];
    nStepsPerGate  =     GetCfg[cfg, {"simulation", "qubit", "n_steps_per_gate"},  30];
    Omega          = N @ GetCfg[cfg, {"simulation", "qubit", "rabi_frequency"},    1.5];
    tMax           = N @ GetCfg[cfg, {"simulation", "qubit", "rabi_duration"},     10.0];
    nTrials        =     GetCfg[cfg, {"simulation", "qubit", "n_trials"},          2000];
    seed           =     GetCfg[cfg, {"simulation", "qubit", "seed"},              7];
    sr             =     GetCfg[cfg, {"sonification", "sample_rate"},              44100];
    duration       = N @ GetCfg[cfg, {"sonification", "duration"},                 8.0];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "gates",
        {alpha0, beta0} = BlochAnglesToState[thetaDeg, phiDeg];
        gatesResult = GatesTrajectory[{alpha0, beta0}, gateSequence, nStepsPerGate];
        PrintGatesSummary[gatesResult];

        {rawLeft, rawRight} = GatesStereoBuffer[gatesResult, cfg];
        introText   = BuildGatesIntroText[gateSequence];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportGatesAnimation[gatesResult["rPath"], outGIF];
        ExportGatesPNG[gatesResult["rPath"], outPNG];
        ExportGatesCSV[gatesResult, outCSV],

      mode === "rabi",
        tVals  = N[Subdivide[0.0, tMax, 500]];
        p1Vals = RabiProbability1[Omega, #] & /@ tVals;
        PrintRabiSummary[Omega, tMax];

        {rawLeft, rawRight} = RabiStereoBuffer[Omega, tMax, 220.0, 1400.0, duration, sr];
        introText   = BuildRabiIntroText[Omega];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportRabiPNG[tVals, p1Vals, Omega, outPNG];
        ExportRabiCSV[tVals, p1Vals, outCSV],

      mode === "measurement",
        {alpha0, beta0} = BlochAnglesToState[
          GetCfg[cfg, {"simulation", "qubit", "measurement_theta_deg"}, 90.0],
          GetCfg[cfg, {"simulation", "qubit", "measurement_phi_deg"}, 0.0]];
        trialsResult = MeasurementTrials[alpha0, beta0, nTrials, seed];
        PrintMeasurementSummary[trialsResult];

        {rawLeft, rawRight} = MeasurementStereoBuffer[trialsResult, 220.0, 1400.0, duration, sr];
        introText   = BuildMeasurementIntroText[nTrials, trialsResult["trueP0"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        ExportMeasurementPNG[trialsResult, outPNG];
        ExportMeasurementCSV[trialsResult, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) —
   run in order to hear a qubit from three angles. *)

RunExperiment["gates_default", <|
  "simulation" -> <| "mode" -> "gates" |>
|>];

RunExperiment["rabi_default", <|
  "simulation" -> <| "mode" -> "rabi" |>
|>];

RunExperiment["measurement_default", <|
  "simulation" -> <| "mode" -> "measurement" |>
|>];

(* 4. A minimal gate sequence: just Hadamard, the simplest possible
   superposition-creating rotation — a quarter-turn about the (x+z)
   axis, easy to see clearly on the Bloch sphere with nothing else
   going on. *)
RunExperiment["gates_hadamard_only", <|
  "simulation" -> <|
    "mode" -> "gates",
    "qubit" -> <| "gate_sequence" -> {"H"} |>
  |>
|>];

(* 5. A longer, denser gate sequence, still all exact/textbook gates. *)
RunExperiment["gates_long_sequence", <|
  "simulation" -> <|
    "mode" -> "gates",
    "qubit" -> <| "gate_sequence" -> {"H", "S", "T", "H", "T", "S", "H", "X", "Y", "Z"} |>
  |>
|>];

(* 6. Faster Rabi driving — more oscillations in the same window,
   audibly a faster pitch wobble. *)
RunExperiment["rabi_fast", <|
  "simulation" -> <|
    "mode" -> "rabi",
    "qubit" -> <| "rabi_frequency" -> 4.0 |>
  |>
|>];

(* 7. A skewed (non-50/50) measurement state — theta=36.87 deg gives
   |alpha|^2=Cos[18.435 deg]^2~=0.9, so the running frequency should
   settle near 0.9, not 0.5. *)
RunExperiment["measurement_skewed", <|
  "simulation" -> <|
    "mode" -> "measurement",
    "qubit" -> <| "measurement_theta_deg" -> 36.87, "n_trials" -> 3000 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

#!/usr/bin/env wolframscript

(* ========================================================
   Qubit — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=rabi
          wolframscript -file main.wl -- --simulation.mode measurement
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

cfg  = LoadConfig["qubit", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "gates"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

(* BlochAnglesToState — |psi> = Cos[theta/2]|0> + Exp[I phi] Sin[theta/2]|1>,
   the Bloch-sphere convention this whole app uses (see AGENTS.md). *)
BlochAnglesToState[thetaDeg_, phiDeg_] :=
  Module[{theta = thetaDeg * Pi / 180.0, phi = phiDeg * Pi / 180.0},
    {N[Cos[theta / 2.0]], N[Exp[I * phi] * Sin[theta / 2.0]]}
  ];

STEMHeading["Qubit"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at canonical parameters (the
   default Rabi frequency and a fixed representative superposition
   state), independent of the active mode's own configured
   parameters, the same convention henon/lorenz/pendulum use for
   their own checks sections. All four hold for any valid gate/state/
   frequency — canonical values just keep the printed output
   identical across modes. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$unitaryChk = GateUnitarityCheck[];
$blochChk   = BlochLengthCheck[];
$rabiChk    = RabiFormulaCheck[1.5];
$bornChk    = BornRuleMonteCarloCheck[0.6, 0.8, 20000, 314];
PrintCorrectnessChecks[$unitaryChk, $blochChk, $rabiChk, $bornChk];
Print["    1. Gate unitarity (", Length[$unitaryChk["testGates"]], " gates): max |U^dag U - I| = ",
      FmtN[$unitaryChk["maxResid"], 3], "  (exact, tight tolerance)"];
Print["    2. Bloch length conservation (", Length[$blochChk["gateSeq"]], "-gate sequence): ",
      "max ||r|-1| = ", FmtN[$blochChk["maxError"], 3], "  (exact, tight tolerance)"];
Print["    3. Rabi formula vs independent Schrodinger integration: max error = ",
      FmtN[$rabiChk["maxError"], 3], "  (exact relation, tight tolerance)"];
Print["    4. Born rule Monte Carlo (", $bornChk["nTrials"], " trials): empirical P(0) = ",
      FmtN[$bornChk["empFreq0"], 6], " vs true ", FmtN[$bornChk["p0True"], 6],
      "  (statistical, ", FmtN[$bornChk["tolFreq"], 5], " tolerance band)"];
Print[""];

Which[

  (* ===== gates (default) ===== *)
  mode === "gates",

    gateSequence   = GetCfg[cfg, {"simulation", "qubit", "gate_sequence"},      {"H", "T", "H", "S", "X"}];
    thetaDeg       = N @ GetCfg[cfg, {"simulation", "qubit", "initial_theta_deg"}, 0.0];
    phiDeg         = N @ GetCfg[cfg, {"simulation", "qubit", "initial_phi_deg"},   0.0];
    nStepsPerGate  =     GetCfg[cfg, {"simulation", "qubit", "n_steps_per_gate"}, 30];

    {alpha0, beta0} = BlochAnglesToState[thetaDeg, phiDeg];
    Print["  Gate sequence: ", StringRiffle[gateSequence, ", "]];
    Print["  Initial state: theta=", thetaDeg, " deg, phi=", phiDeg, " deg"];
    Print[""];

    Print["[2/5] Applying gates..."];
    STEMSay["Applying gate sequence"];
    gatesResult = GatesTrajectory[{alpha0, beta0}, gateSequence, nStepsPerGate];
    PrintGatesSummary[gatesResult];
    Print[""];

    Print["[3/5] Exporting gate data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "qubit_gates.csv"}];
    ExportGatesCSV[gatesResult, outCSV];
    Print[""];

    Print["[4/5] Rendering Bloch sphere animation..."];
    STEMSay["Rendering the Bloch sphere"];
    outGIF = FileNameJoin[{$projectRoot, "output", "qubit_gates.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "qubit_gates.png"}];
    ExportGatesAnimation[gatesResult["rPath"], outGIF];
    ExportGatesPNG[gatesResult["rPath"], outPNG];
    STEMDescribeGIF[outGIF, 80, 10];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "qubit_gates.wav"}];
    {rawLeft, rawRight} = GatesStereoBuffer[gatesResult, cfg];
    introText   = BuildGatesIntroText[gateSequence];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== rabi ===== *)
  mode === "rabi",

    Omega    = N @ GetCfg[cfg, {"simulation", "qubit", "rabi_frequency"}, 1.5];
    tMax     = N @ GetCfg[cfg, {"simulation", "qubit", "rabi_duration"},  10.0];
    duration = N @ GetCfg[cfg, {"sonification", "duration"},              8.0];

    Print["  Omega: ", Omega, "   Duration: ", tMax];
    Print[""];

    Print["[2/5] Computing Rabi oscillation..."];
    STEMSay["Computing Rabi oscillation"];
    tVals  = N[Subdivide[0.0, tMax, 500]];
    p1Vals = RabiProbability1[Omega, #] & /@ tVals;
    PrintRabiSummary[Omega, tMax];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "qubit_rabi.csv"}];
    ExportRabiCSV[tVals, p1Vals, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outPNG = FileNameJoin[{$projectRoot, "output", "qubit_rabi.png"}];
    ExportRabiPNG[tVals, p1Vals, Omega, outPNG];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "qubit_rabi.wav"}];
    {rawLeft, rawRight} = RabiStereoBuffer[Omega, tMax, 220.0, 1400.0, duration, sr];
    introText   = BuildRabiIntroText[Omega];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],

  (* ===== measurement ===== *)
  mode === "measurement",

    thetaDeg = N @ GetCfg[cfg, {"simulation", "qubit", "measurement_theta_deg"}, 90.0];
    phiDeg   = N @ GetCfg[cfg, {"simulation", "qubit", "measurement_phi_deg"},   0.0];
    nTrials  =     GetCfg[cfg, {"simulation", "qubit", "n_trials"},              2000];
    seed     =     GetCfg[cfg, {"simulation", "qubit", "seed"},                  7];
    duration = N @ GetCfg[cfg, {"sonification", "duration"},                     8.0];

    {alpha, beta} = BlochAnglesToState[thetaDeg, phiDeg];
    Print["  State: theta=", thetaDeg, " deg, phi=", phiDeg, " deg   |alpha|^2=",
          FmtN[Abs[alpha]^2, 4], "   |beta|^2=", FmtN[Abs[beta]^2, 4]];
    Print["  Trials: ", nTrials];
    Print[""];

    Print["[2/5] Running measurements..."];
    STEMSay["Running repeated measurements"];
    trialsResult = MeasurementTrials[alpha, beta, nTrials, seed];
    PrintMeasurementSummary[trialsResult];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "qubit_measurement.csv"}];
    ExportMeasurementCSV[trialsResult, outCSV];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outPNG = FileNameJoin[{$projectRoot, "output", "qubit_measurement.png"}];
    ExportMeasurementPNG[trialsResult, outPNG];
    Print["  PNG written: ", outPNG];
    Print[""];

    Print["[5/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "qubit_measurement.wav"}];
    {rawLeft, rawRight} = MeasurementStereoBuffer[trialsResult, 220.0, 1400.0, duration, sr];
    introText   = BuildMeasurementIntroText[nTrials, trialsResult["trueP0"]];
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
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"gates\", \"rabi\", or \"measurement\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

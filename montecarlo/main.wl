#!/usr/bin/env wolframscript

(* ========================================================
   2D Ising Model — Metropolis Monte Carlo — Entry Point

   Sonifies the ferromagnetic phase transition of the 2D Ising model:
   a square lattice of +-1 spins, updated by the Metropolis algorithm,
   with an exact analytic critical temperature (Onsager 1944).

   Usage:
     wolframscript -file main.wl                                        # sweep, 32x32, T 4.0->0.5
     wolframscript -file main.wl -- --simulation.mode=critical           # at T_c
     wolframscript -file main.wl -- --simulation.mode=quench             # instantaneous quench
     wolframscript -file main.wl -- --simulation.montecarlo.lattice_size=64
     wolframscript -file main.wl -- --simulation.montecarlo.N_T_steps=100
     wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=3.0  # above T_c
     wolframscript -file main.wl -- --simulation.montecarlo.T_fixed=1.5  # below T_c
     wolframscript -file main.wl -- --simulation.montecarlo.random_seed=123
     wolframscript -file main.wl -- --config-dump

   Modes:
     sweep (default) -- descend T from T_start to T_end through T_c;
                        the phase transition is the loudest, most
                        turbulent moment of the sweep
     critical         -- fixed at T_c (or --T_fixed for an off-critical
                        exploration), scale-free fluctuation
     quench           -- instantaneous drop from T_hot to T_cold;
                        disorder struggling toward order

   Outputs (montecarlo/output/):
     sweep_audio.wav / sweep.gif / sweep_data.csv
     critical_audio.wav / critical.gif / critical_data.csv
     quench_audio.wav / quench.gif / quench_data.csv
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

cfg  = LoadConfig["montecarlo", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "sweep"];

jCoupling = N @ GetCfg[cfg, {"simulation", "montecarlo", "J"}, 1.0];
Tc        = $OnsagerTc[jCoupling];

nSizeCfg = GetCfg[cfg, {"simulation", "montecarlo", "lattice_size"}, 32];
nSize    = NearestPowerOfTwo[nSizeCfg];
If[nSize =!= nSizeCfg,
  Print["  [NOTE] lattice_size ", nSizeCfg, " is not a power of 2 (required for the Hilbert ",
        "spatial layer) — using ", nSize, " instead."]
];

sr = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["2D Ising Model: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print["  Lattice: ", nSize, " x ", nSize, "   J = ", jCoupling, "   T_c = ", FmtN[Tc, 6]];
Print[""];

STEMSay["Starting 2D Ising model sonification: " <> mode];

$nSteps5 = 5;
outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

(* ExportWithIntro — shared by all three modes: prepend the spoken
   intro (BuildIntroBuffer -> pause -> sonifyResult's buffers), export
   once. Returns the total duration in seconds (matches thermo/
   dynamical's pattern of exporting only after intro is prepended, so
   STEMDescribeWAV's reported duration includes the intro). *)
ExportWithIntro[sonifyResult_Association, introText_String, outPath_String] :=
  Module[{introBuffer, pauseBuffer, finalLeft, finalRight, totalDur},
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, sonifyResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, sonifyResult["right"]];
    EnsureDir[outPath];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outPath, sr];
    totalDur = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outPath, totalDur];
    totalDur
  ];

Which[

  (* ══════════════════════════════════════════════════════
     SWEEP MODE
     ══════════════════════════════════════════════════════ *)
  mode === "sweep",

    TStart = N @ GetCfg[cfg, {"simulation", "montecarlo", "T_start"}, 4.0];
    TEnd   = N @ GetCfg[cfg, {"simulation", "montecarlo", "T_end"},   0.5];
    NTSteps = GetCfg[cfg, {"simulation", "montecarlo", "N_T_steps"}, 50];
    nEquilibration = GetCfg[cfg, {"simulation", "montecarlo", "n_equilibration"}, 200];
    nMeasurement   = GetCfg[cfg, {"simulation", "montecarlo", "n_measurement"},   100];

    Print["  T: ", TStart, " -> ", TEnd, "  (", NTSteps, " steps, ", nEquilibration,
          " equilibration + ", nMeasurement, " measurement sweeps per step)"];
    Print[""];

    Print["[1/", $nSteps5, "] Running Metropolis sweep..."];
    STEMSay["Running the temperature sweep"];
    t0 = AbsoluteTime[];
    sweepResult = RunSweepMode[nSize, TStart, TEnd, NTSteps, nEquilibration, nMeasurement, jCoupling];
    Print["  Completed in ", FmtN[AbsoluteTime[] - t0, {6, 2}], " s (",
          Length[sweepResult["sweepIdx"]], " measurement sweeps recorded)"];
    Print[""];

    Print["-- Correctness checks --"];
    PrintOnsagerCheck[OnsagerTcCheck[]];
    PrintEnergyBoundsCheck[EnergyBoundsCheck[sweepResult["E"], jCoupling], jCoupling];
    PrintDetailedBalanceCheck[DetailedBalanceCheck[4, jCoupling, Tc]];
    PrintMagnetisationConvergenceCheck[MagnetisationConvergenceCheck[sweepResult["T"], sweepResult["M"]]];
    Print[""];

    Print["[2/", $nSteps5, "] Sonifying (two-layer: global observables + Hilbert spatial scan)..."];
    STEMSay["Sonifying the temperature sweep. Listen for the phase transition."];
    introText    = BuildSweepIntroText[nSize, TStart, TEnd, Tc];
    Print["  Spoken intro: ", introText];
    sonifyResult = SonifyIsingRun[sweepResult, sweepResult["T"], Tc, cfg];
    totalDur = ExportWithIntro[sonifyResult, introText, outWAV];
    PrintSweepSummary[sweepResult, Tc, sonifyResult];
    Print[""];

    Print["[3/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the spin-grid animation"];
    {$gifFrames, $gifFps} = AnimateSweep[sweepResult, Tc, outGIF, totalDur];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[4/", $nSteps5, "] Exporting data table..."];
    ExportSweepCSV[sweepResult, sonifyResult["articulated"], outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     CRITICAL MODE
     ══════════════════════════════════════════════════════ *)
  mode === "critical",

    TFixed  = N @ GetCfg[cfg, {"simulation", "montecarlo", "T_fixed"}, 2.2692];
    nSweeps = GetCfg[cfg, {"simulation", "montecarlo", "n_sweeps"}, 500];

    Print["  T_fixed: ", FmtN[TFixed, 6], "  (T_c = ", FmtN[Tc, 6], ")   Sweeps: ", nSweeps];
    Print[""];

    Print["[1/", $nSteps5, "] Running Metropolis simulation at fixed T..."];
    STEMSay["Running the critical-temperature simulation"];
    t0 = AbsoluteTime[];
    critResult = RunCriticalMode[nSize, TFixed, nSweeps, jCoupling];
    Print["  Completed in ", FmtN[AbsoluteTime[] - t0, {6, 2}], " s"];
    Print[""];

    Print["-- Correctness checks --"];
    PrintOnsagerCheck[OnsagerTcCheck[]];
    PrintEnergyBoundsCheck[EnergyBoundsCheck[critResult["E"], jCoupling], jCoupling];
    PrintDetailedBalanceCheck[DetailedBalanceCheck[4, jCoupling, TFixed]];
    Print[""];

    Print["[2/", $nSteps5, "] Sonifying (two-layer: global observables + Hilbert spatial scan)..."];
    STEMSay["Sonifying the critical point"];
    introText    = BuildCriticalIntroText[TFixed];
    Print["  Spoken intro: ", introText];
    sonifyResult = SonifyIsingRun[critResult, Missing[], Tc, cfg];
    totalDur = ExportWithIntro[sonifyResult, introText, outWAV];
    PrintCriticalSummary[critResult, TFixed, sonifyResult];
    Print[""];

    Print["[3/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the spin-grid animation"];
    {$gifFrames, $gifFps} = AnimateCritical[critResult, TFixed, outGIF, totalDur];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[4/", $nSteps5, "] Exporting data table..."];
    ExportFixedTCSV[critResult, sonifyResult["articulated"], outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     QUENCH MODE
     ══════════════════════════════════════════════════════ *)
  mode === "quench",

    THot   = N @ GetCfg[cfg, {"simulation", "montecarlo", "T_hot"},  4.0];
    TCold  = N @ GetCfg[cfg, {"simulation", "montecarlo", "T_cold"}, 0.5];
    nSweeps    = GetCfg[cfg, {"simulation", "montecarlo", "n_sweeps"}, 400];
    randomSeed = GetCfg[cfg, {"simulation", "montecarlo", "random_seed"}, 42];

    Print["  T_hot: ", THot, " -> T_cold: ", TCold, " (instantaneous)   Sweeps: ", nSweeps,
          "   Seed: ", randomSeed];
    Print[""];

    Print["[1/", $nSteps5, "] Running Metropolis simulation (quench)..."];
    STEMSay["Running the quench simulation"];
    t0 = AbsoluteTime[];
    quenchResult = RunQuenchMode[nSize, TCold, nSweeps, jCoupling, randomSeed];
    Print["  Completed in ", FmtN[AbsoluteTime[] - t0, {6, 2}], " s"];
    Print[""];

    Print["-- Correctness checks --"];
    PrintOnsagerCheck[OnsagerTcCheck[]];
    PrintEnergyBoundsCheck[EnergyBoundsCheck[quenchResult["E"], jCoupling], jCoupling];
    PrintDetailedBalanceCheck[DetailedBalanceCheck[4, jCoupling, TCold]];
    Print[""];

    Print["[2/", $nSteps5, "] Sonifying (two-layer: global observables + Hilbert spatial scan)..."];
    STEMSay["Sonifying the quench"];
    introText    = BuildQuenchIntroText[THot, TCold];
    Print["  Spoken intro: ", introText];
    sonifyResult = SonifyIsingRun[quenchResult, Missing[], Tc, cfg];
    totalDur = ExportWithIntro[sonifyResult, introText, outWAV];
    PrintQuenchSummary[quenchResult, TCold, sonifyResult];
    Print[""];

    Print["[3/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the domain-coarsening animation"];
    {$gifFrames, $gifFps} = AnimateQuench[quenchResult, TCold, outGIF, totalDur];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[4/", $nSteps5, "] Exporting data table..."];
    ExportFixedTCSV[quenchResult, sonifyResult["articulated"], outCSV];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"sweep\", \"critical\", or \"quench\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Ising model sonification complete. Play audio: " <> STEMPlayCmd[outWAV]]

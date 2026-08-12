#!/usr/bin/env wolframscript

(* ========================================================
   Quantum Tunnelling — Entry Point

   Sonifies quantum tunnelling: a particle crossing a potential
   barrier it classically has zero chance of crossing. Real-world
   consequences: alpha decay (Gamow, 1928), the scanning tunnelling
   microscope (Binnig & Rohrer, 1981, Nobel Prize 1986), and the
   tunnel diode.

   Usage:
     wolframscript -file main.wl                                              # barrier, default preset
     wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=stm
     wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=alpha_decay
     wolframscript -file main.wl -- --simulation.mode=sweep                    # barrier-width sweep
     wolframscript -file main.wl -- --simulation.mode=energy                   # energy sweep, crosses V0
     wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=manual \
                                     --simulation.quantum_tunnelling.energy_ev=1.5
     wolframscript -file main.wl -- --config-dump

   Modes:
     barrier (default) -- single event at a configured/preset energy,
                            barrier height, and width; narrated
                            incoming/marker/reflected+transmitted split
     sweep                -- barrier width sweep at fixed E<V0,
                            tunnelling regime only
     energy                -- particle-energy sweep across V0, both
                            regimes, resonances audible above it

   Outputs (quantum_tunnelling/output/):
     barrier_audio.wav / barrier.gif / barrier.png / barrier_data.csv
     sweep_audio.wav / sweep.gif / sweep.png / sweep_data.csv
     energy_audio.wav / energy.gif / energy.png / energy_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

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
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["quantum_tunnelling", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "barrier"];

sr           = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
audioFreqMin = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "audio_freq_min"}, 150];
audioFreqMax = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "audio_freq_max"}, 2500];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Quantum Tunnelling: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

Print["Correctness checks..."];
PrintTunnellingChecks[];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     BARRIER MODE
     ══════════════════════════════════════════════════════ *)
  mode === "barrier",

    model = BarrierModel[cfg];
    PrintBarrierSummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportBarrierCSV[model, FileNameJoin[{$outDir, "barrier_data.csv"}]];
    Print[""];

    Print["[2/4] Synthesising audio with spoken intro/outro..."];
    STEMSay["Sonifying the tunnelling event"];
    introText = BuildBarrierIntroText[model];
    outroText = BuildBarrierOutroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildBarrierAudio[model, audioFreqMin, audioFreqMax, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseBuf = ConstantArray[0.0, Round[sr * 0.4]];
    finalLeft  = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainL,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    finalRight = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainR,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    outWAV = FileNameJoin[{$outDir, "barrier_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[3/4] Rendering barrier diagram..."];
    STEMSay["Rendering the barrier diagram"];
    (* targetDuration = mainL's own length -- the narrated tunnelling
       event's audio, built above -- deliberately excluding the spoken
       intro/outro just added to finalLeft/finalRight (no visual
       counterpart, TTS-length dependent; see animate.wl's file header). *)
    barrierTargetDuration = N[Length[mainL]] / sr;
    {nFrames, gifFps} = AnimateBarrier[model, FileNameJoin[{$outDir, "barrier.gif"}],
                             FileNameJoin[{$outDir, "barrier.png"}], barrierTargetDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "barrier.gif"}], nFrames, gifFps];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* ══════════════════════════════════════════════════════
     SWEEP MODE
     ══════════════════════════════════════════════════════ *)
  mode === "sweep",

    sweepDuration = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "sweep_duration"}, 6.0];

    model = SweepModel[cfg];
    PrintSweepSummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportSweepCSV[model, FileNameJoin[{$outDir, "sweep_data.csv"}]];
    Print[""];

    Print["[2/4] Rendering sweep animation and static plot..."];
    STEMSay["Rendering the tunnelling probability animation"];
    (* targetDuration = sweepDuration -- the same value passed to
       BuildSweepAudio below for the sonified glissando's own length,
       deliberately excluding main.wl's spoken intro (see animate.wl's
       file header). *)
    {nFrames, gifFps} = AnimateSweep[model, FileNameJoin[{$outDir, "sweep.gif"}],
                           FileNameJoin[{$outDir, "sweep.png"}], sweepDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "sweep.gif"}], nFrames, gifFps];
    Print[""];

    Print["[3/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the barrier width sweep"];
    introText = BuildSweepIntroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildSweepAudio[model, audioFreqMin, audioFreqMax, sweepDuration, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, mainL];
    finalRight = Join[introBuffer, pauseBuf, mainR];
    outWAV = FileNameJoin[{$outDir, "sweep_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* ══════════════════════════════════════════════════════
     ENERGY MODE
     ══════════════════════════════════════════════════════ *)
  mode === "energy",

    energyDuration = N @ GetCfg[cfg, {"simulation", "quantum_tunnelling", "energy_duration"}, 8.0];

    model = EnergyModel[cfg];
    PrintEnergySummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportEnergyCSV[model, FileNameJoin[{$outDir, "energy_data.csv"}]];
    Print[""];

    Print["[2/4] Rendering energy sweep animation and static plot..."];
    STEMSay["Rendering the transmission versus energy animation"];
    (* targetDuration = energyDuration -- the same value passed to
       BuildEnergyAudio below, deliberately excluding main.wl's spoken
       intro (see animate.wl's file header). *)
    {nFrames, gifFps} = AnimateEnergy[model, FileNameJoin[{$outDir, "energy.gif"}],
                            FileNameJoin[{$outDir, "energy.png"}], energyDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "energy.gif"}], nFrames, gifFps];
    Print[""];

    Print["[3/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the energy sweep"];
    introText = BuildEnergyIntroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildEnergyAudio[model, audioFreqMin, audioFreqMax, energyDuration, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, mainL];
    finalRight = Join[introBuffer, pauseBuf, mainR];
    outWAV = FileNameJoin[{$outDir, "energy_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"barrier\", \"sweep\", or \"energy\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Quantum tunnelling sonification complete. Play audio: " <>
        STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

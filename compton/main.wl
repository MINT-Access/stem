#!/usr/bin/env wolframscript

(* ========================================================
   Compton Scattering — Entry Point

   Sonifies Compton scattering: a photon losing energy to a recoiling
   electron and shifting to a longer wavelength -- the 1923 measurement
   (Arthur Compton, Nobel Prize 1927) that settled the wave/particle
   debate in favour of the photon picture.

   Usage:
     wolframscript -file main.wl                                        # scatter, Compton's own 1923 values
     wolframscript -file main.wl -- --simulation.compton.angle_deg=180  # backscatter
     wolframscript -file main.wl -- --simulation.mode=sweep             # angle glissando, 0-180 deg
     wolframscript -file main.wl -- --simulation.mode=energy            # incident-energy sweep, 1 keV-5 MeV
     wolframscript -file main.wl -- --simulation.mode=discovery         # Thomson vs Compton, binaural
     wolframscript -file main.wl -- --simulation.compton.wavelength_pm=10
     wolframscript -file main.wl -- --config-dump

   Modes:
     scatter (default) -- single event at a configured wavelength/angle;
                            narrated incoming/collision/outgoing/recoil sequence
     sweep                -- continuous angle glissando at fixed incident wavelength
     energy                -- incident-photon-energy sweep at fixed angle,
                            crossing the electron rest energy (511 keV)
     discovery               -- binaural: left=classical Thomson (flat),
                            right=real Compton (pitch drops with angle)

   Outputs (compton/output/):
     scatter_audio.wav / scatter.gif / scatter.png / scatter_data.csv
     sweep_audio.wav / sweep.gif / sweep.png / sweep_data.csv
     energy_audio.wav / energy.gif / energy.png / energy_data.csv
     discovery_audio.wav / discovery.png / discovery_data.csv
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

cfg  = LoadConfig["compton", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "scatter"];

sr           = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
audioFreqMin = N @ GetCfg[cfg, {"simulation", "compton", "audio_freq_min"}, 200];
audioFreqMax = N @ GetCfg[cfg, {"simulation", "compton", "audio_freq_max"}, 3000];
EMinKevGlobal = N @ GetCfg[cfg, {"simulation", "compton", "energy_min_kev"}, 1.0];
EMaxKevGlobal = N @ GetCfg[cfg, {"simulation", "compton", "energy_max_kev"}, 5000.0];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Compton Scattering: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

Print["Correctness checks..."];
PrintComptonChecks[];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     SCATTER MODE
     ══════════════════════════════════════════════════════ *)
  mode === "scatter",

    model = ScatterModel[cfg];
    PrintScatterSummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportScatterCSV[model, FileNameJoin[{$outDir, "scatter_data.csv"}]];
    Print[""];

    Print["[2/4] Synthesising audio with spoken intro/outro..."];
    STEMSay["Sonifying the collision"];
    introText = BuildScatterIntroText[model];
    outroText = BuildScatterOutroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildScatterAudio[model, audioFreqMin, audioFreqMax, EMinKevGlobal, EMaxKevGlobal, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseBuf = ConstantArray[0.0, Round[sr * 0.4]];
    finalLeft  = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainL,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    finalRight = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainR,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    outWAV = FileNameJoin[{$outDir, "scatter_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[3/4] Rendering collision diagram..."];
    STEMSay["Rendering the collision diagram"];
    {$gifFrames, $gifFps} = AnimateScatter[model, FileNameJoin[{$outDir, "scatter.gif"}],
                             FileNameJoin[{$outDir, "scatter.png"}], wavDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "scatter.gif"}], $gifFrames, $gifFps];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* ══════════════════════════════════════════════════════
     SWEEP MODE
     ══════════════════════════════════════════════════════ *)
  mode === "sweep",

    sweepDuration = N @ GetCfg[cfg, {"simulation", "compton", "sweep_duration"}, 6.0];

    model = SweepModel[cfg];
    PrintSweepSummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportSweepCSV[model, FileNameJoin[{$outDir, "sweep_data.csv"}]];
    Print[""];

    Print["[2/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the angle sweep"];
    introText = BuildSweepIntroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildSweepAudio[model, audioFreqMin, audioFreqMax, EMinKevGlobal, EMaxKevGlobal,
                                     sweepDuration, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, mainL];
    finalRight = Join[introBuffer, pauseBuf, mainR];
    outWAV = FileNameJoin[{$outDir, "sweep_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[3/4] Rendering sweep animation and static plot..."];
    STEMSay["Rendering the wavelength shift animation"];
    {$gifFrames, $gifFps} = AnimateSweep[model, FileNameJoin[{$outDir, "sweep.gif"}],
                           FileNameJoin[{$outDir, "sweep.png"}], wavDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "sweep.gif"}], $gifFrames, $gifFps];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* ══════════════════════════════════════════════════════
     ENERGY MODE
     ══════════════════════════════════════════════════════ *)
  mode === "energy",

    frameDur = N @ GetCfg[cfg, {"simulation", "compton", "frame_duration"}, 0.1];

    model = EnergyModel[cfg];
    PrintEnergySummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportEnergyCSV[model, FileNameJoin[{$outDir, "energy_data.csv"}]];
    Print[""];

    Print["[2/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the incident energy sweep"];
    introText = BuildEnergyIntroText[model];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildEnergyAudio[model, audioFreqMin, audioFreqMax, frameDur, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, mainL];
    finalRight = Join[introBuffer, pauseBuf, mainR];
    outWAV = FileNameJoin[{$outDir, "energy_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[3/4] Rendering energy sweep animation and static plot..."];
    STEMSay["Rendering the fractional energy loss animation"];
    {$gifFrames, $gifFps} = AnimateEnergy[model, FileNameJoin[{$outDir, "energy.gif"}],
                            FileNameJoin[{$outDir, "energy.png"}], wavDuration];
    STEMDescribeGIF[FileNameJoin[{$outDir, "energy.gif"}], $gifFrames, $gifFps];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* ══════════════════════════════════════════════════════
     DISCOVERY MODE
     ══════════════════════════════════════════════════════ *)
  mode === "discovery",

    discoveryDuration = N @ GetCfg[cfg, {"simulation", "compton", "discovery_duration"}, 8.0];

    model = DiscoveryModel[cfg];
    PrintDiscoverySummary[model];
    Print[""];

    Print["[1/4] Exporting data table..."];
    ExportDiscoveryCSV[model, FileNameJoin[{$outDir, "discovery_data.csv"}]];
    Print[""];

    Print["[2/4] Rendering comparison plot..."];
    RenderDiscoveryStaticPNG[model, FileNameJoin[{$outDir, "discovery.png"}]];
    Print[""];

    Print["[3/4] Synthesising binaural audio with spoken intro/outro..."];
    STEMSay["Sonifying: Thomson prediction left channel, Compton prediction right channel"];
    introText = BuildDiscoveryIntroText[];
    outroText = BuildDiscoveryOutroText[];
    Print["  Spoken intro: ", introText];
    {mainL, mainR} = BuildDiscoveryAudio[model, audioFreqMin, audioFreqMax, EMinKevGlobal, EMaxKevGlobal,
                                         discoveryDuration, sr];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseBuf = ConstantArray[0.0, Round[sr * 0.4]];
    finalLeft  = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainL,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    finalRight = Join[introBuffer, If[Length[introBuffer] > 0, pauseBuf, {}], mainR,
                      If[Length[outroBuffer] > 0, pauseBuf, {}], outroBuffer];
    outWAV = FileNameJoin[{$outDir, "discovery_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""];

    Print["[4/4] Done."];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"scatter\", \"sweep\", \"energy\", or \"discovery\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Compton scattering sonification complete. Play audio: " <>
        STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

#!/usr/bin/env wolframscript

(* ========================================================
   Black Body Radiation — Entry Point

   Sonifies Planck's law, B(nu,T) = (2*h*nu^3/c^2) / (exp(h*nu/kT) - 1):
   the spectral radiance emitted by any object purely as a function of
   its temperature. The formula that ended the "ultraviolet
   catastrophe", founded quantum mechanics, and explains why hotter
   things glow bluer.

   Usage:
     wolframscript -file main.wl                                       # spectrum, solar T=5778K
     wolframscript -file main.wl -- --simulation.mode=temperature       # 2500K -> 40000K sweep
     wolframscript -file main.wl -- --simulation.mode=star              # star mode, default "sun"
     wolframscript -file main.wl -- --simulation.mode=star \
                                     --simulation.blackbody.preset=rigel
     wolframscript -file main.wl -- --simulation.mode=star \
                                     --simulation.blackbody.preset=all  # tour, red dwarf -> white dwarf
     wolframscript -file main.wl -- --simulation.blackbody.temperature=3500
     wolframscript -file main.wl -- --config-dump

   Modes:
     spectrum (default)  -- fixed T, sweep frequency radio -> X-ray;
                             chord (full curve as spectral envelope),
                             then a sequential sweep; visible-light
                             window (400-700nm) marked with accent taps
     temperature          -- sweep T itself (2500K red dwarf to 40000K
                             blue giant); Wien's law -> pitch (peak
                             marker), Stefan-Boltzmann -> loudness
                             (log-compressed T^4)
     star                  -- named real star/remnant presets; a single
                             preset reuses spectrum mode's chord+sweep;
                             preset=all is a sequential tour, coolest
                             to hottest

   Outputs (blackbody/output/):
     spectrum_audio.wav / spectrum.gif / spectrum.png / spectrum_data.csv
     temperature_audio.wav / temperature.gif / temperature.png / temperature_data.csv
     star_audio.wav / star.gif / star.png / star_data.csv
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

cfg  = LoadConfig["blackbody", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "spectrum"];

sr           = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
freqMin      = N @ GetCfg[cfg, {"simulation", "blackbody", "freq_min"}, 1.0*^6];
freqMax      = N @ GetCfg[cfg, {"simulation", "blackbody", "freq_max"}, 1.0*^19];
nBins        =     GetCfg[cfg, {"simulation", "blackbody", "n_bins"}, 64];
audioFreqMin = N @ GetCfg[cfg, {"simulation", "blackbody", "audio_freq_min"}, 100];
audioFreqMax = N @ GetCfg[cfg, {"simulation", "blackbody", "audio_freq_max"}, 4000];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Black Body Radiation: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     SPECTRUM MODE
     ══════════════════════════════════════════════════════ *)
  mode === "spectrum",

    T           = N @ GetCfg[cfg, {"simulation", "blackbody", "temperature"}, 5778];
    chordDur    = N @ GetCfg[cfg, {"simulation", "blackbody", "chord_duration"}, 4.0];
    noteDurCfg  = N @ GetCfg[cfg, {"simulation", "blackbody", "note_duration"}, 0.08];

    Print["  Temperature: ", T, " K"];
    Print["  Physical sweep: ", FmtN[freqMin, 4], " Hz -> ", FmtN[freqMax, 4], " Hz  (",
          nBins, " bins, radio to X-ray)"];
    Print[""];

    Print["[1/5] Correctness checks..."];
    STEMSay["Running correctness checks"];
    PrintBlackbodyChecks[T];
    Print[""];

    Print["[2/5] Building Planck spectrum (chord + sweep)..."];
    spectrumResult = BuildSpectrumAudio[T, nBins, freqMin, freqMax, audioFreqMin, audioFreqMax,
                                        chordDur, noteDurCfg, sr];
    PrintSpectrumSummary[spectrumResult, T];
    Print[""];

    Print["[3/5] Synthesising audio with spoken intro/outro..."];
    STEMSay["Sonifying the black body spectrum"];
    introText   = BuildSpectrumIntroText[T, nBins];
    outroText   = BuildSpectrumOutroText[];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseShort  = ConstantArray[0.0, Round[sr * 0.4]];
    finalLeft   = Join[
      introBuffer, If[Length[introBuffer] > 0, pauseShort, {}],
      spectrumResult["chordL"], pauseShort, spectrumResult["sweepL"],
      If[Length[outroBuffer] > 0, pauseShort, {}], outroBuffer
    ];
    finalRight  = Join[
      introBuffer, If[Length[introBuffer] > 0, pauseShort, {}],
      spectrumResult["chordR"], pauseShort, spectrumResult["sweepR"],
      If[Length[outroBuffer] > 0, pauseShort, {}], outroBuffer
    ];
    outWAV = FileNameJoin[{$outDir, "spectrum_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[4/5] Rendering sweep animation and static plot..."];
    STEMSay["Rendering the spectrum animation"];
    outGIF = FileNameJoin[{$outDir, "spectrum.gif"}];
    outPNG = FileNameJoin[{$outDir, "spectrum.png"}];
    {$gifFrames, $gifFps} = AnimateSpectrum[T, spectrumResult["spec"], freqMin, freqMax, outGIF, outPNG, wavDuration];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportSpectrumCSV[spectrumResult, FileNameJoin[{$outDir, "spectrum_data.csv"}]];
    Print[""],


  (* ══════════════════════════════════════════════════════
     TEMPERATURE MODE
     ══════════════════════════════════════════════════════ *)
  mode === "temperature",

    Tmin       = N @ GetCfg[cfg, {"simulation", "blackbody", "temp_min"}, 2500];
    Tmax       = N @ GetCfg[cfg, {"simulation", "blackbody", "temp_max"}, 40000];
    nSteps     =     GetCfg[cfg, {"simulation", "blackbody", "n_steps"}, 100];
    frameDur   = N @ GetCfg[cfg, {"simulation", "blackbody", "frame_duration"}, 0.12];

    Print["  T range: ", Tmin, " K -> ", Tmax, " K  (", nSteps, " steps)"];
    Print[""];

    Print["[1/5] Correctness checks..."];
    STEMSay["Running correctness checks"];
    PrintBlackbodyChecks[Tmin];
    Print[""];

    Print["[2/5] Building temperature sweep (Wien's law + Stefan-Boltzmann)..."];
    tempResult = BuildTemperatureAudio[Tmin, Tmax, nSteps, nBins, freqMin, freqMax,
                                       audioFreqMin, audioFreqMax, frameDur, sr];
    PrintTemperatureSummary[tempResult];
    Print[""];

    Print["[3/5] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the temperature sweep"];
    introText   = BuildTemperatureIntroText[Tmin, Tmax];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, tempResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, tempResult["right"]];
    outWAV = FileNameJoin[{$outDir, "temperature_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[4/5] Rendering animation and static plot..."];
    STEMSay["Rendering the temperature sweep animation"];
    outGIF = FileNameJoin[{$outDir, "temperature.gif"}];
    outPNG = FileNameJoin[{$outDir, "temperature.png"}];
    {$gifFrames, $gifFps} = AnimateTemperature[tempResult, freqMin, freqMax, outGIF, wavDuration];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    RenderTemperatureStaticPNG[Tmin, Tmax, freqMin, freqMax, outPNG];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportTemperatureCSV[tempResult, FileNameJoin[{$outDir, "temperature_data.csv"}]];
    Print[""],


  (* ══════════════════════════════════════════════════════
     STAR MODE
     ══════════════════════════════════════════════════════ *)
  mode === "star",

    presetCfg = GetCfg[cfg, {"simulation", "blackbody", "preset"}, "sun"];
    chordDur    = N @ GetCfg[cfg, {"simulation", "blackbody", "chord_duration"}, 4.0];
    noteDurCfg  = N @ GetCfg[cfg, {"simulation", "blackbody", "note_duration"}, 0.08];
    tourDur     = N @ GetCfg[cfg, {"simulation", "blackbody", "tour_segment_duration"}, 2.5];

    If[presetCfg === "all",

      (* ── "all": sequential tour, coolest to hottest ────────── *)
      order = StarOrder[];
      Print["  Preset: all (tour, ", Length[order], " stars, coolest to hottest)"];
      Print[""];

      Print["[1/5] Correctness checks..."];
      STEMSay["Running correctness checks"];
      PrintBlackbodyChecks[$StarPresets["sun"]];
      Print[""];

      Print["[2/5] Building star tour segments..."];
      tourResult = BuildStarTourSegments[order, $StarPresets, nBins, freqMin, freqMax,
                                         audioFreqMin, audioFreqMax, tourDur, sr];
      PrintStarSummary[order, $StarPresets];
      Print[""];

      Print["[3/5] Synthesising audio with spoken star names..."];
      STEMSay["Sonifying the star tour"];
      overviewText = BuildStarTourIntroText[];
      Print["  Spoken overview: ", overviewText];
      overviewBuffer = BuildIntroBuffer[overviewText, sr];
      overviewBuffer = If[Length[overviewBuffer] > 0, NormalizeBuffer[overviewBuffer, 0.95], overviewBuffer];
      pauseBuffer    = ConstantArray[0.0, Round[sr * 0.35]];
      segmentBuffers = MapThread[
        Function[{key, seg},
          Module[{nameText, nameBuffer},
            nameText   = BuildStarIntroText[StarDisplayName[key], seg["T"]];
            nameBuffer = BuildIntroBuffer[nameText, sr];
            nameBuffer = If[Length[nameBuffer] > 0, NormalizeBuffer[nameBuffer, 0.95], nameBuffer];
            <| "left" -> Join[nameBuffer, pauseBuffer, seg["left"]],
               "right" -> Join[nameBuffer, pauseBuffer, seg["right"]] |>
          ]
        ],
        {order, tourResult["segments"]}
      ];
      finalLeft  = Join[overviewBuffer, If[Length[overviewBuffer] > 0, pauseBuffer, {}],
                        Sequence @@ Map[#["left"] &, segmentBuffers]];
      finalRight = Join[overviewBuffer, If[Length[overviewBuffer] > 0, pauseBuffer, {}],
                        Sequence @@ Map[#["right"] &, segmentBuffers]];
      outWAV = FileNameJoin[{$outDir, "star_audio.wav"}];
      EnsureDir[outWAV];
      ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
      wavDuration = N[Length[finalLeft]] / sr;
      STEMDescribeWAV[outWAV, wavDuration];
      Print[""];

      Print["[4/5] Rendering tour animation and static plot..."];
      STEMSay["Rendering the star tour animation"];
      outGIF = FileNameJoin[{$outDir, "star.gif"}];
      outPNG = FileNameJoin[{$outDir, "star.png"}];
      {$gifFrames, $gifFps} = AnimateStarTour[order, $StarPresets, freqMin, freqMax, outGIF, wavDuration];
      STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
      RenderStarTourStaticPNG[order, $StarPresets, freqMin, freqMax, outPNG];
      Print[""];

      Print["[5/5] Exporting data table..."];
      ExportStarCSV[order, $StarPresets, nBins, freqMin, freqMax, audioFreqMin, audioFreqMax,
                    FileNameJoin[{$outDir, "star_data.csv"}]];
      Print[""],

      (* ── single preset: reuse spectrum mode's chord+sweep ───── *)
      preset = If[KeyExistsQ[$StarPresets, presetCfg], presetCfg, "sun"];
      T      = $StarPresets[preset];
      Print["  Preset: ", preset, "  (", StarDisplayName[preset], ", ", Round[T], " K)"];
      Print[""];

      Print["[1/5] Correctness checks..."];
      STEMSay["Running correctness checks"];
      PrintBlackbodyChecks[T];
      Print[""];

      Print["[2/5] Building Planck spectrum (chord + sweep)..."];
      spectrumResult = BuildSpectrumAudio[T, nBins, freqMin, freqMax, audioFreqMin, audioFreqMax,
                                          chordDur, noteDurCfg, sr];
      PrintSpectrumSummary[spectrumResult, T];
      Print[""];

      Print["[3/5] Synthesising audio with spoken intro..."];
      STEMSay["Sonifying " <> StarDisplayName[preset]];
      introText   = BuildStarIntroText[StarDisplayName[preset], T];
      Print["  Spoken intro: ", introText];
      introBuffer = BuildIntroBuffer[introText, sr];
      introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
      pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
      finalLeft   = Join[introBuffer, pauseBuffer, spectrumResult["chordL"], pauseBuffer, spectrumResult["sweepL"]];
      finalRight  = Join[introBuffer, pauseBuffer, spectrumResult["chordR"], pauseBuffer, spectrumResult["sweepR"]];
      outWAV = FileNameJoin[{$outDir, "star_audio.wav"}];
      EnsureDir[outWAV];
      ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
      wavDuration = N[Length[finalLeft]] / sr;
      STEMDescribeWAV[outWAV, wavDuration];
      Print[""];

      Print["[4/5] Rendering sweep animation and static plot..."];
      STEMSay["Rendering the " <> preset <> " animation"];
      outGIF = FileNameJoin[{$outDir, "star.gif"}];
      outPNG = FileNameJoin[{$outDir, "star.png"}];
      {$gifFrames, $gifFps} = AnimateSpectrum[T, spectrumResult["spec"], freqMin, freqMax, outGIF, outPNG, wavDuration];
      STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
      Print[""];

      Print["[5/5] Exporting data table..."];
      ExportSpectrumCSV[spectrumResult, FileNameJoin[{$outDir, "star_data.csv"}]];
      Print[""]
    ],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"spectrum\", \"temperature\", or \"star\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Black body radiation sonification complete. Play audio: " <>
        STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

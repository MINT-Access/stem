#!/usr/bin/env wolframscript

(* ========================================================
   Hydrogen Atom — Entry Point

   Sonifies the quantum mechanics of the hydrogen atom: its wave
   functions (orbitals), emission spectrum, and electron transitions.
   The only exactly-solvable atom, and the foundation of all atomic
   physics and spectroscopy.

   New to hydrogen sonification? Start with hydrogen/LISTENING_GUIDE.md.

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.hydrogen.orbital=100
     wolframscript -file main.wl -- --simulation.hydrogen.orbital=320
     wolframscript -file main.wl -- --simulation.mode=spectrum
     wolframscript -file main.wl -- --simulation.mode=transitions
     wolframscript -file main.wl -- --simulation.hydrogen.n_start=7
     wolframscript -file main.wl -- --simulation.hydrogen.n_realizations=5
     wolframscript -file main.wl -- --simulation.hydrogen.orbital=321

   Modes:
     orbitals (default) -- sonify |psi_nlm|^2 on a 2D xz cross-section
                            via Hilbert curve traversal (density -> pitch
                            and amplitude, log scale)
     spectrum            -- sonify the full n=2..n_max emission spectrum
                            as a chord, then a UV-to-IR sweep
     transitions          -- simulate n_realizations random electron
                            cascades from an excited state to the ground
                            state, respecting Delta l = +-1 selection rules

   Outputs (hydrogen/output/):
     orbitals_audio.wav / orbitals.gif / orbitals.png / orbitals_data.csv
     spectrum_audio.wav / spectrum_chord.wav / spectrum_sweep.wav /
       spectrum.gif / spectrum_data.csv
     transitions_audio.wav / transitions.gif / transitions_data.csv
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

cfg  = LoadConfig["hydrogen", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "orbitals"];

sr      = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
freqMin = N @ GetCfg[cfg, {"simulation", "hydrogen", "freq_min"}, 100];
freqMax = N @ GetCfg[cfg, {"simulation", "hydrogen", "freq_max"}, 4000];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Hydrogen Atom: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

Print["Correctness checks..."];
PrintEnergyLevelCheck[];
PrintRydbergCheck[];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     ORBITALS MODE
     ══════════════════════════════════════════════════════ *)
  mode === "orbitals",

    (* ParseCliOverrides (stem-core/config.wl) coerces numeric-looking CLI
       values to actual numbers, so --simulation.hydrogen.orbital=100
       arrives as the Integer 100, not the String "100" -- ToString
       normalises both that case and config.json's native String. *)
    orbitalKeyCfg = ToString[GetCfg[cfg, {"simulation", "hydrogen", "orbital"}, "210"]];
    gridSizeCfg   = GetCfg[cfg, {"simulation", "hydrogen", "grid_size"}, 64];
    orbitalKey    = If[KeyExistsQ[$Orbitals, orbitalKeyCfg], orbitalKeyCfg, "210"];
    gridImgN      = Min[8, Round[Log2[N[gridSizeCfg]]]];
    gridSize      = 2^gridImgN;
    {nOrb, lOrb, mOrb} = $Orbitals[orbitalKey];

    Print["  Orbital: ", OrbitalDisplayName[orbitalKey],
          "  (n=", nOrb, ", l=", lOrb, ", m=", mOrb, ")"];
    Print["  Grid:    ", gridSize, " x ", gridSize, " pixels  (order ", gridImgN, ")"];
    Print[""];

    PrintWaveFunctionCheck[orbitalKey];
    Print[""];

    Print["[1/4] Computing orbital density grid and Hilbert traversal..."];
    STEMSay["Computing hydrogen orbital density"];
    orbitalModel = ComputeOrbitalTraversal[orbitalKey, gridSize];
    Print["  Pixels: ", orbitalModel["nPixels"], "  r_max: ", FmtN[orbitalModel["rMax"], 4], " a0"];
    Print[""];

    Print["[2/4] Sonifying (Hilbert traversal, log pitch and amplitude)..."];
    STEMSay["Sonifying the orbital"];
    sonifyResult = SonifyOrbitals[orbitalModel, freqMin, freqMax, 0.02, sr];
    Print[""];

    outWAV = FileNameJoin[{$outDir, "orbitals_audio.wav"}];
    introText   = BuildOrbitalsIntroText[orbitalKey, nOrb, lOrb, mOrb, gridSize];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalBuffer = Join[introBuffer, pauseBuffer, sonifyResult["buffer"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[finalBuffer, outWAV, sr];
    $audioDur = N[Length[finalBuffer]] / sr;
    STEMDescribeWAV[outWAV, $audioDur];
    Print[""];

    (* GIF duration synced to the WAV's actual total duration
       (including its spoken intro) — see hydrogen/AGENTS.md "GIF/WAV
       duration sync". *)
    Print["[3/4] Rendering Hilbert-sweep animation..."];
    STEMSay["Rendering orbital animation"];
    AnimateOrbital[orbitalModel, FileNameJoin[{$outDir, "orbitals.gif"}],
                                 FileNameJoin[{$outDir, "orbitals.png"}], $audioDur];
    Print[""];

    Print["[4/4] Exporting data table..."];
    ExportOrbitalsCSV[orbitalModel, sonifyResult["freqs"], sonifyResult["amps"],
                      FileNameJoin[{$outDir, "orbitals_data.csv"}]];
    Print[""],


  (* ══════════════════════════════════════════════════════
     SPECTRUM MODE
     ══════════════════════════════════════════════════════ *)
  mode === "spectrum",

    With[{
      nMax        = GetCfg[cfg, {"simulation", "hydrogen", "n_max"}, 8],
      chordDur    = N @ GetCfg[cfg, {"simulation", "hydrogen", "chord_duration"}, 3.0],
      noteDurCfg  = N @ GetCfg[cfg, {"simulation", "hydrogen", "note_duration"}, 0.3]
    },
    Print["  n_max: ", nMax, "  (transitions n=2.. ", nMax, " -> n=1..n_upper-1)"];
    Print["  Chord duration: ", chordDur, " s   Sweep note duration: ", noteDurCfg, " s"];
    Print[""];

    Print["[1/5] Building spectral lines..."];
    spectrumResult = BuildSpectrumAudio[nMax, freqMin, freqMax, chordDur, noteDurCfg, sr];
    nLines = Length[spectrumResult["lines"]];
    Print["  Lines: ", nLines, "  (photon freq range ",
          FmtN[spectrumResult["nuMin"] / 10^12, 4], " - ",
          FmtN[spectrumResult["nuMax"] / 10^12, 4], " THz)"];
    Print[""];

    Print["[2/5] Synthesising chord and sweep..."];
    STEMSay["Sonifying the hydrogen emission spectrum"];
    chordPath = FileNameJoin[{$outDir, "spectrum_chord.wav"}];
    sweepPath = FileNameJoin[{$outDir, "spectrum_sweep.wav"}];
    ExportAudioBuffer[spectrumResult["chordBuf"], chordPath, sr];
    ExportAudioBuffer[spectrumResult["sweepBuf"], sweepPath, sr];
    STEMDescribeWAV[chordPath, N[Length[spectrumResult["chordBuf"]]] / sr];
    STEMDescribeWAV[sweepPath, N[Length[spectrumResult["sweepBuf"]]] / sr];
    Print[""];

    Print["[3/5] Building full narrated file (intro + chord + sweep + outro)..."];
    introText = BuildSpectrumIntroText[nMax, nLines];
    outroText = BuildSpectrumOutroText[];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    outroBuffer = BuildIntroBuffer[outroText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    outroBuffer = If[Length[outroBuffer] > 0, NormalizeBuffer[outroBuffer, 0.95], outroBuffer];
    pauseShort = ConstantArray[0.0, Round[sr * 0.4]];
    fullBuffer = Join[
      introBuffer, If[Length[introBuffer] > 0, pauseShort, {}],
      spectrumResult["chordBuf"], pauseShort,
      spectrumResult["sweepBuf"], If[Length[outroBuffer] > 0, pauseShort, {}],
      outroBuffer
    ];
    outWAV = FileNameJoin[{$outDir, "spectrum_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[fullBuffer, outWAV, sr];
    $audioDur = N[Length[fullBuffer]] / sr;
    STEMDescribeWAV[outWAV, $audioDur];
    Print[""];

    Print["[4/5] Rendering sweep animation..."];
    STEMSay["Rendering spectrum animation"];
    {$gifFrames, $gifFps} = AnimateSpectrum[spectrumResult, FileNameJoin[{$outDir, "spectrum.gif"}], $audioDur];
    STEMDescribeGIF[FileNameJoin[{$outDir, "spectrum.gif"}], $gifFrames, $gifFps];
    Print[""];

    Print["[5/5] Exporting data table..."];
    ExportSpectrumCSV[spectrumResult, FileNameJoin[{$outDir, "spectrum_data.csv"}]];
    Print[""]],


  (* ══════════════════════════════════════════════════════
     TRANSITIONS MODE
     ══════════════════════════════════════════════════════ *)
  mode === "transitions",

    With[{
      nStart     = GetCfg[cfg, {"simulation", "hydrogen", "n_start"},        5],
      lStartCfg  = GetCfg[cfg, {"simulation", "hydrogen", "l_start"},        2],
      nRealCfg   = GetCfg[cfg, {"simulation", "hydrogen", "n_realizations"}, 20],
      maxSteps   = GetCfg[cfg, {"simulation", "hydrogen", "max_steps"},      50]
    },
    lStart = Min[lStartCfg, nStart - 1];
    nReal  = Min[nRealCfg, 100];
    Print["  Start state: n=", nStart, ", l=", lStart];
    Print["  Realisations: ", nReal, "   Max steps: ", maxSteps];
    Print[""];

    Print["[1/5] Simulating ", nReal, " cascades..."];
    STEMSay["Simulating electron cascades"];
    cascadesList = Table[SimulateCascade[nStart, lStart, maxSteps], {nReal}];
    Print["  Path lengths: min=", Min[Map[Length, cascadesList]],
          "  max=", Max[Map[Length, cascadesList]],
          "  mean=", FmtN[N[Mean[Map[Length, cascadesList]]], 4]];
    Print[""];

    PrintSelectionRuleCheck[Flatten[cascadesList]];
    Print[""];

    Print["[2/5] Sonifying cascades (pitch=photon freq, duration~1/A, ",
          "amplitude~A, pan=l of emitting state)..."];
    STEMSay["Sonifying the electron cascades"];
    sonifyResult = SonifyCascades[cascadesList, freqMin, freqMax, sr];
    Print[""];

    introText   = BuildTransitionsIntroText[nReal, nStart, lStart];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, sonifyResult["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, sonifyResult["right"]];
    outWAV = FileNameJoin[{$outDir, "transitions_audio.wav"}];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    $audioDur = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, $audioDur];
    Print[""];

    Print["[3/5] Rendering Grotrian diagram animation..."];
    STEMSay["Rendering the energy level diagram"];
    {$gifFrames, $gifFps} = AnimateTransitions[cascadesList, nStart, FileNameJoin[{$outDir, "transitions.gif"}], $audioDur];
    STEMDescribeGIF[FileNameJoin[{$outDir, "transitions.gif"}], $gifFrames, $gifFps];
    Print[""];

    Print["[4/5] Exporting data table..."];
    ExportTransitionsCSV[cascadesList, sonifyResult["panLists"], sonifyResult["durLists"],
                         sonifyResult["freqLists"], FileNameJoin[{$outDir, "transitions_data.csv"}]];
    Print[""];

    Print["[5/5] Done."];
    Print[""]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"orbitals\", \"spectrum\", or \"transitions\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

(* ========================================================
   signal/sonify.wl — Direct audio export

   This app is different from all others: the WAV output IS the
   phenomenon, not a sonification of something else.  The user
   literally hears what Fourier analysis does by listening to
   clean → noisy → recovered in sequence.

   Public API:
     SonifySignal[analysis, cfg, outDir]

   Outputs (mode-prefixed so multiple modes coexist):
     {mode}_clean.wav           — clean signal, normalised to 0.95
     {mode}_noisy.wav           — noisy signal, normalised to 0.95
     {mode}_recovered.wav       — recovered signal, normalised to 0.95
     {mode}_narrative_full.wav  — speech + signals concatenated (best effort)
   ======================================================== *)



(* SpeakToBuffer
   Synthesises speech and returns a mono PCM list at the target sample rate.
   Falls back to a short silence on any error or if TTS is unavailable.

   Platform support:
     macOS   — `say -o file.aiff` then `afconvert` to linear PCM WAV
     Linux   — `espeak-ng -w file.wav` (preferred) or `espeak -w file.wav`
     Windows — PowerShell System.Speech.Synthesis.SpeechSynthesizer to WAV

   Upsamples to targetSr by linear interpolation when the TTS engine
   outputs at a lower sample rate (e.g. 22050 → 44100 Hz). *)

SpeakToBuffer[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr, upsampled,
          silence = ConstantArray[0.0, Round[targetSr * 0.5]]},

    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      (* ── macOS: say → AIFF-C → afconvert → WAV ── *)
      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".aiff"}];
          result = Quiet[RunProcess[{"say", "-o", aiffPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 ||
             !FileExistsQ[aiffPath],
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]];
            Return[silence]];
          conv = Quiet[RunProcess[{"afconvert", aiffPath, wavPath,
                                    "-d", "LEI16", "-f", "WAVE"}]];
          Quiet[DeleteFile[aiffPath]];
          If[!AssociationQ[conv] || conv["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[silence]]],

      (* ── Linux: espeak-ng or espeak → WAV directly ── *)
      "Unix",
        Module[{result},
          result = Quiet[RunProcess[{"espeak-ng", "-w", wavPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            result = Quiet[RunProcess[{"espeak", "-w", wavPath, text}]]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[silence]]],

      (* ── Windows: PowerShell SpeechSynthesizer → WAV ── *)
      "Windows",
        Module[{psCmd, result},
          psCmd = "Add-Type -AssemblyName System.Speech; " <>
                  "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " <>
                  "$s.SetOutputToWaveFile('" <>
                  StringReplace[wavPath, "\\" -> "/"] <> "'); " <>
                  "$s.Speak('" <> StringReplace[text, "'" -> "''"] <> "'); " <>
                  "$s.SetOutputToDefaultAudioDevice()";
          result = Quiet[RunProcess[{"powershell", "-NoProfile", "-Command", psCmd}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[silence]]],

      (* ── Unknown platform: return silence ── *)
      _,
        Return[silence]
    ];

    (* Common path: import the WAV, extract samples, upsample if needed *)
    snd = Quiet[Import[wavPath]];
    If[!AudioQ[snd], Quiet[DeleteFile[wavPath]]; Return[silence]];
    data  = Quiet[Flatten[N[AudioData[snd]]]];
    rawSr = Quiet[QuantityMagnitude[AudioSampleRate[snd]]];
    Quiet[DeleteFile[wavPath]];
    If[!ListQ[data] || Length[data] === 0, Return[silence]];

    If[rawSr < targetSr,
      With[{ratio = Round[targetSr / rawSr]},
        If[ratio === 2,
          upsampled = Flatten[Transpose[{
            Most[data],
            (Most[data] + Rest[data]) / 2.0
          }]];
          Append[upsampled, Last[data]],
          data]],
      data]
  ]


(* CountCorrectPeaks
   Count how many known frequencies have a detected peak within toleranceHz. *)

CountCorrectPeaks[peaks_List, knownFreqs_List, toleranceHz_:30.0] :=
  If[Length[peaks] === 0 || Length[knownFreqs] === 0,
    0,
    Module[{detectedFreqs = peaks[[All, 1]]},
      Length[Select[knownFreqs,
        Min[Abs[detectedFreqs - #]] < toleranceHz &]]
    ]
  ]


(* NarrativeText
   Build spoken text segments for each stage of the narrative. *)

NarrativeText[analysis_Association, mode_String] :=
  Module[{freqs, amps, noiseLevel, snrBefore, snrAfter,
          nKnown, nDetected, improvement,
          freqStr, introText, noisyText, recovText, summaryText},

    freqs     = analysis["known_frequencies"];
    amps      = analysis["amplitudes"];   (* may be absent for sweep *)
    noiseLevel = analysis["noise_level"];
    snrBefore = analysis["snr_before"];
    snrAfter  = analysis["snr_after"];
    nKnown    = Length[freqs];
    nDetected = CountCorrectPeaks[
                  analysis["recovered_frequencies"], freqs];
    improvement = snrAfter - snrBefore;

    freqStr = StringRiffle[
      Map[ToString[Round[#]] <> " hertz" &, freqs], ", "];

    introText = Switch[mode,
      "chord",
        "C major chord. Frequencies: " <> freqStr <> ".",
      "sweep",
        "Frequency sweep from " <> ToString[Round[freqs[[1]]]] <>
        " to " <> ToString[Round[freqs[[2]]]] <> " hertz.",
      "am",
        "Amplitude modulation. Carrier: " <> ToString[Round[freqs[[2]]]] <>
        " hertz. Sidebands at " <> ToString[Round[freqs[[1]]]] <>
        " and " <> ToString[Round[freqs[[3]]]] <> " hertz.",
      _,
        "Signal frequencies: " <> freqStr <> "."
    ];

    noisyText = "Adding gaussian noise at level " <>
                ToString[NumberForm[noiseLevel, {3, 2}]] <> ".";

    recovText = "Before filtering, signal to noise ratio: " <>
                ToString[Round[snrBefore, 0.1]] <>
                " decibels. After Fourier filtering: " <>
                ToString[Round[snrAfter, 0.1]] <> " decibels.";

    summaryText = "Signal recovered. Noise reduced by " <>
                  ToString[Round[improvement, 0.1]] <>
                  " decibels. " <>
                  ToString[nDetected] <> " of " <> ToString[nKnown] <>
                  " frequency components correctly identified.";

    <| "intro"   -> introText,
       "noisy"   -> noisyText,
       "recov"   -> recovText,
       "summary" -> summaryText |>
  ]


SonifySignal[analysis_Association, cfg_Association, outDir_String] :=
  Module[{mode, clean, noisy, recovered, sr, dur,
          cleanPath, noisyPath, recovPath, narrativePath,
          silence, texts,
          spIntro, spNoisy, spRecov, spSummary,
          fullNarrative},

    mode      = analysis["mode"];
    clean     = analysis["clean"];
    noisy     = analysis["noisy"];
    recovered = analysis["recovered"];
    sr        = analysis["sample_rate"];
    dur       = analysis["duration"];

    cleanPath     = FileNameJoin[{outDir, mode <> "_clean.wav"}];
    noisyPath     = FileNameJoin[{outDir, mode <> "_noisy.wav"}];
    recovPath     = FileNameJoin[{outDir, mode <> "_recovered.wav"}];
    narrativePath = FileNameJoin[{outDir, mode <> "_narrative_full.wav"}];

    (* ── Primary outputs: the three signal stages ── *)
    ExportAudioBuffer[NormalizeBuffer[clean,     0.95], cleanPath,  sr];
    STEMDescribeWAV[cleanPath, dur];

    ExportAudioBuffer[NormalizeBuffer[noisy,     0.95], noisyPath,  sr];
    STEMDescribeWAV[noisyPath, dur];

    ExportAudioBuffer[NormalizeBuffer[recovered, 0.95], recovPath,  sr];
    STEMDescribeWAV[recovPath, dur];

    (* ── Narrative WAV: speech + signals concatenated ── *)
    Print["  Building narrative WAV (TTS: say / espeak-ng / PowerShell)..."];
    texts   = NarrativeText[analysis, mode];
    silence = ConstantArray[0.0, Round[sr * 0.4]];   (* 0.4 s pause *)

    spIntro  = SpeakToBuffer[texts["intro"],   sr];
    spNoisy  = SpeakToBuffer[texts["noisy"],   sr];
    spRecov  = SpeakToBuffer[texts["recov"],   sr];
    spSummary = SpeakToBuffer[texts["summary"], sr];

    (* Concatenate: intro → clean → transition → noisy → transition → recovered → summary *)
    fullNarrative = Join[
      spIntro,  silence,
      NormalizeBuffer[clean,     0.8], silence,
      spNoisy,  silence,
      NormalizeBuffer[noisy,     0.8], silence,
      spRecov,  silence,
      NormalizeBuffer[recovered, 0.8], silence,
      spSummary
    ];

    ExportAudioBuffer[NormalizeBuffer[fullNarrative, 0.95], narrativePath, sr];
    STEMDescribeWAV[narrativePath, N[Length[fullNarrative]] / sr]
  ]

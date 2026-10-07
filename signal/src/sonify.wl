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

   Speech: stem-core's STEMSpeakToBuffer (SpeechSynthesize[] ->
   platform-native TTS), shared by every narrated app. If both TTS
   tiers fail, the narrative WAV is still built with silence standing
   in for the missing speech segment, so the intro -> clean -> noisy
   -> recovered -> summary structure stays intact either way.
   ======================================================== *)



(* SpeakToBuffer
   stem-core's STEMSpeakToBuffer (SpeechSynthesize[] -> platform TTS),
   with 0.5 s of silence standing in when neither tier produces audio.
   Sets the module-level $SignalSpeechFailed flag in that case, so
   SonifySignal can say once that silence was substituted. *)

$SignalSpeechFailed = False;

SpeakToBuffer[text_String, targetSr_Integer] :=
  Module[{buf = STEMSpeakToBuffer[text, targetSr]},
    If[Length[buf] > 0, Return[buf]];
    $SignalSpeechFailed = True;
    ConstantArray[0.0, Round[targetSr * 0.5]]
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
    ExportAudioBuffer[NormalizeToLoudness[clean, -17.0, 0.97, sr], cleanPath, sr];
    STEMDescribeWAV[cleanPath, dur];

    ExportAudioBuffer[NormalizeToLoudness[noisy, -17.0, 0.97, sr], noisyPath, sr];
    STEMDescribeWAV[noisyPath, dur];

    ExportAudioBuffer[NormalizeToLoudness[recovered, -17.0, 0.97, sr], recovPath, sr];
    STEMDescribeWAV[recovPath, dur];

    (* ── Narrative WAV: speech + signals concatenated ── *)
    Print["  Building narrative WAV (TTS: SpeechSynthesize -> platform TTS -> silence)..."];
    texts   = NarrativeText[analysis, mode];
    silence = ConstantArray[0.0, Round[sr * 0.4]];   (* 0.4 s pause between segments *)

    $SignalSpeechFailed = False;
    spIntro   = SpeakToBuffer[texts["intro"],   sr];
    spNoisy   = SpeakToBuffer[texts["noisy"],   sr];
    spRecov   = SpeakToBuffer[texts["recov"],   sr];
    spSummary = SpeakToBuffer[texts["summary"], sr];

    If[$SignalSpeechFailed,
      Print["[WARNING] signal: the narrative WAV uses 0.5 s of silence in place of " <>
            "each spoken segment that could not be synthesised; the signal audio is unaffected."]
    ];

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

    ExportAudioBuffer[NormalizeToLoudness[fullNarrative, -17.0, 0.97, sr], narrativePath, sr];
    STEMDescribeWAV[narrativePath, N[Length[fullNarrative]] / sr]
  ]

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


(* ExportMonoWAV
   Normalise buffer to peakAmp and write a mono WAV file. *)

ExportMonoWAV[buffer_List, filePath_String, sr_Integer, peakAmp_:0.95] :=
  Module[{normalised, snd},
    normalised = NormalizeBuffer[buffer, peakAmp];
    EnsureDir[filePath];
    snd = Sound[SampledSoundList[normalised, sr]];
    Export[filePath, snd, "WAV"];
    filePath
  ]


(* SpeakToBuffer
   Calls macOS `say` to synthesise speech and returns a mono PCM list
   at the target sample rate.  Falls back to a short silence on any error.

   `say` produces AIFF at ~22050 Hz by default.  We upsample 2x to 44100
   by linear interpolation between adjacent samples. *)

SpeakToBuffer[text_String, targetSr_Integer] :=
  Module[{tmpPath, result, snd, data, silence, rawSr, upsampled},
    silence = ConstantArray[0.0, Round[targetSr * 0.5]];   (* 0.5 s fallback *)
    tmpPath = FileNameJoin[{$TemporaryDirectory,
                "stem_say_" <> ToString[RandomInteger[999999]] <> ".aiff"}];

    result = Quiet[RunProcess[{"say", "-o", tmpPath, text}]];
    If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[tmpPath],
      Return[silence]];

    snd = Quiet[Import[tmpPath]];
    Quiet[DeleteFile[tmpPath]];

    If[Head[snd] =!= Sound || Length[snd] < 1 ||
       Head[snd[[1]]] =!= SampledSoundList,
      Return[silence]];

    data  = Flatten[N[snd[[1, 1]]]];
    rawSr = snd[[1, 2]];

    If[!ListQ[data] || Length[data] === 0, Return[silence]];

    (* Upsample if say produced 22050 Hz and we want 44100 Hz *)
    If[rawSr < targetSr,
      (* Linear interpolation: interleave interpolated midpoints *)
      With[{ratio = Round[targetSr / rawSr]},
        If[ratio === 2,
          upsampled = Flatten[Transpose[{
            Most[data],
            (Most[data] + Rest[data]) / 2.0
          }]];
          Append[upsampled, Last[data]],
          data   (* unsupported ratio — return as-is *)
        ]
      ],
      data   (* already at target rate *)
    ]
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
    ExportMonoWAV[clean,     cleanPath,  sr];
    STEMDescribeWAV[cleanPath, dur];

    ExportMonoWAV[noisy,     noisyPath,  sr];
    STEMDescribeWAV[noisyPath, dur];

    ExportMonoWAV[recovered, recovPath,  sr];
    STEMDescribeWAV[recovPath, dur];

    (* ── Narrative WAV: speech + signals concatenated ── *)
    Print["  Building narrative WAV (requires macOS say)..."];
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

    ExportMonoWAV[fullNarrative, narrativePath, sr];
    STEMDescribeWAV[narrativePath, N[Length[fullNarrative]] / sr]
  ]

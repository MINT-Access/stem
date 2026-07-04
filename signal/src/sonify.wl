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

   Speech: SpeechSynthesize[] -> platform-native TTS -> silence.
   Same three-tier fallback as images/, thermo/, montecarlo/, dynamical/,
   and magnetic/'s src/speech.wl (or, for magnetic, sonify.wl) files —
   this app previously skipped straight to shell `say`/espeak/PowerShell
   calls with no SpeechSynthesize[] attempt at all, which was the one
   remaining inconsistency addressed by the v1.3.0 speech-mechanism
   consolidation pass. If both TTS tiers fail, the narrative WAV is
   still built with silence standing in for the missing speech segment,
   so the intro -> clean -> noisy -> recovered -> summary structure and
   overall duration stay intact either way.
   ======================================================== *)



(* ResampleLinear — general linear-interpolation resampler, any ratio.
   Replaces the old "only handles exactly a 2x ratio" upsample hack:
   SpeechSynthesize[] and the platform TTS engines can each return audio
   at a variety of native sample rates (e.g. 22050, 24000 Hz), not just
   half of targetSr. *)
ResampleLinear[data_List, rawSr_?NumericQ, targetSr_?NumericQ] :=
  Module[{n = Length[data], newN, ratio, oldPos, lo, frac},
    If[n < 2 || Abs[N[rawSr] - N[targetSr]] < 1.0, Return[data]];
    ratio = N[targetSr] / N[rawSr];
    newN  = Max[1, Round[n * ratio]];
    Table[
      oldPos = (i - 1) * (n - 1.0) / Max[newN - 1, 1];
      lo     = Clip[Floor[oldPos], {0, n - 2}];
      frac   = oldPos - lo;
      (1 - frac) * data[[lo + 1]] + frac * data[[lo + 2]],
      {i, newN}
    ]
  ]


(* SpeakToBufferPlatform — OS-native TTS -> mono PCM at targetSr.
   Second-tier fallback, used only when SpeechSynthesize[] is
   unavailable or fails.

   Platform support:
     macOS   — `say -o file.aiff` then `afconvert` to linear PCM WAV
     Linux   — `espeak-ng -w file.wav` (preferred) or `espeak -w file.wav`
     Windows — PowerShell System.Speech.Synthesis.SpeechSynthesizer to WAV *)

SpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},

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
            Return[{}]];
          conv = Quiet[RunProcess[{"afconvert", aiffPath, wavPath,
                                    "-d", "LEI16", "-f", "WAVE"}]];
          Quiet[DeleteFile[aiffPath]];
          If[!AssociationQ[conv] || conv["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      (* ── Linux: espeak-ng or espeak → WAV directly ── *)
      "Unix",
        Module[{result},
          result = Quiet[RunProcess[{"espeak-ng", "-w", wavPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            result = Quiet[RunProcess[{"espeak", "-w", wavPath, text}]]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

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
            Return[{}]]],

      (* ── Unknown platform ── *)
      _,
        Return[{}]
    ];

    (* Common path: import the WAV, extract samples, resample if needed *)
    snd = Quiet[Import[wavPath]];
    If[!AudioQ[snd], Quiet[DeleteFile[wavPath]]; Return[{}]];
    data  = Quiet[Flatten[N[AudioData[snd]]]];
    rawSr = Quiet[QuantityMagnitude[AudioSampleRate[snd]]];
    Quiet[DeleteFile[wavPath]];
    If[!ListQ[data] || Length[data] === 0 || !NumericQ[rawSr], Return[{}]];

    ResampleLinear[data, rawSr, targetSr]
  ]


(* SpeakToBuffer
   Synthesises speech and returns a mono PCM list at the target sample
   rate: SpeechSynthesize[] first, platform-native TTS second, silence
   (of the same nominal duration the fallback would have produced) if
   both fail. Sets the module-level $SignalSpeechFailed flag the first
   time both tiers fail, so SonifySignal can print a single warning
   rather than one per segment. *)

$SignalSpeechFailed = False;

SpeakToBuffer[text_String, targetSr_Integer] :=
  Module[{buf, result, data, rawSr, silence},
    silence = ConstantArray[0.0, Round[targetSr * 0.5]];

    buf = Quiet[Check[
      result = SpeechSynthesize[text];
      If[AudioQ[result],
        data  = Quiet[Flatten[N[AudioData[result]]]];
        rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
        If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
          ResampleLinear[data, rawSr, targetSr],
          {}
        ],
        {}
      ],
      {}
    ]];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    buf = SpeakToBufferPlatform[text, targetSr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    $SignalSpeechFailed = True;
    silence
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
    Print["  Building narrative WAV (TTS: SpeechSynthesize -> platform TTS -> silence)..."];
    texts   = NarrativeText[analysis, mode];
    silence = ConstantArray[0.0, Round[sr * 0.4]];   (* 0.4 s pause between segments *)

    $SignalSpeechFailed = False;
    spIntro   = SpeakToBuffer[texts["intro"],   sr];
    spNoisy   = SpeakToBuffer[texts["noisy"],   sr];
    spRecov   = SpeakToBuffer[texts["recov"],   sr];
    spSummary = SpeakToBuffer[texts["summary"], sr];

    If[$SignalSpeechFailed,
      Print["[WARNING] Speech synthesis unavailable (SpeechSynthesize[] and " <>
            "platform TTS both failed) -- narrative WAV will use silence in place " <>
            "of the affected spoken segment(s); signal audio and timing are unaffected."]
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

    ExportAudioBuffer[NormalizeBuffer[fullNarrative, 0.95], narrativePath, sr];
    STEMDescribeWAV[narrativePath, N[Length[fullNarrative]] / sr]
  ]

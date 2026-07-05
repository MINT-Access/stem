(* ========================================================
   resonance/src/sonify.wl — Audio synthesis for all three modes

   galilean mode:
     Two mixed layers, bespoke (not SonifyTrajectory): a primary
     event-based rhythmic canon (StemSynthNote per orbit-completion,
     manually placed and panned -- the same discrete-note idiom
     scattering/src/sonify.wl's distribution mode and bayes/src/
     sonify.wl's secondary layer use, since an orbit-completion stream
     is a set of discrete one-shot events, not one continuously-
     varying trajectory) plus a secondary continuous three-tone drone
     (constant-frequency sines in the same 4:2:1 ratio, one octave
     below the event pitches) mixed 12 dB under it. SonifyTrajectory
     itself is not used: its SpatialLayer would spline-interpolate
     pitch *between* orbit-completion events into a glide, which is
     the wrong audio shape for a rhythmic canon of discrete notes.

   kirkwood / saturn modes:
     Additive spectral synthesis, the same SynthesizeAdditiveFrame/
     FrameWindow primitive thermo/src/sonify.wl and bayes/src/
     sonify.wl use for their posterior/MB spectra -- here the
     "spectrum" is asteroid-belt or ring density vs semi-major
     axis/radius rather than a probability or speed density, but the
     technique (nBins simultaneous sine partials, amplitude-weighted
     by the density at each bin) is identical. A second pass re-plays
     the same bins sequentially (a "sweep") rather than simultaneously,
     with a short per-step fade (FrameWindow) to avoid clicks between
     steps -- silences in the sweep are audible exactly where the
     density is a gap.
   ======================================================== *)


(* ── Speech: SpeechSynthesize[] -> platform TTS -> text-only STEMSay.
   Duplicated from scattering/src/sonify.wl's identical three-tier
   pattern (apps do not import each other's src/ files). *)

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

ResonanceSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_resonance_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_resonance_say_" <> id <> ".aiff"}];
          result = Quiet[RunProcess[{"say", "-o", aiffPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[aiffPath],
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]];
            Return[{}]];
          conv = Quiet[RunProcess[{"afconvert", aiffPath, wavPath, "-d", "LEI16", "-f", "WAVE"}]];
          Quiet[DeleteFile[aiffPath]];
          If[!AssociationQ[conv] || conv["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

      "Unix",
        Module[{result},
          result = Quiet[RunProcess[{"espeak-ng", "-w", wavPath, text}]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            result = Quiet[RunProcess[{"espeak", "-w", wavPath, text}]]];
          If[!AssociationQ[result] || result["ExitCode"] =!= 0 || !FileExistsQ[wavPath],
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
            Return[{}]]],

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

      _,
        Return[{}]
    ];

    snd = Quiet[Import[wavPath]];
    If[!AudioQ[snd], Quiet[DeleteFile[wavPath]]; Return[{}]];
    data  = Quiet[Flatten[N[AudioData[snd]]]];
    rawSr = Quiet[QuantityMagnitude[AudioSampleRate[snd]]];
    Quiet[DeleteFile[wavPath]];
    If[!ListQ[data] || Length[data] === 0 || !NumericQ[rawSr], Return[{}]];

    ResampleLinear[data, rawSr, targetSr]
  ]

BuildIntroBuffer[text_String, sr_Integer] :=
  Module[{buf, result, data, rawSr},
    buf = Quiet[Check[
      result = SpeechSynthesize[text];
      If[AudioQ[result],
        data  = Quiet[Flatten[N[AudioData[result]]]];
        rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
        If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
          ResampleLinear[data, rawSr, sr],
          {}
        ],
        {}
      ],
      {}
    ]];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    buf = ResonanceSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable -- spoken text will be skipped. Text:"];
    STEMSay[text];
    {}
  ]

PrependIntroAndExport[introText_String, leftMain_List, rightMain_List,
                      sr_Integer, outWav_String] :=
  Module[{introBuffer, pauseBuffer, finalLeft, finalRight},
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, leftMain];
    finalRight  = Join[introBuffer, pauseBuffer, rightMain];
    EnsureDir[outWav];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWav, sr];
    STEMDescribeWAV[outWav, N[Length[finalLeft]] / sr]
  ]


(* ── Shared additive-frame primitive (kirkwood/saturn spectral layer).
   Identical in structure to thermo/src/sonify.wl's FrameWindow /
   SynthesizeAdditiveFrame. *)

FrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ]

SynthesizeAdditiveFrame[freqs_List, amps_List, pans_List,
                        frameDuration_?NumericQ, sr_Integer] :=
  Module[{n = Length[freqs], nSamples, t, leftBuf, rightBuf, fadeSamples, envelope, mono},
    nSamples = Max[1, Round[frameDuration * sr]];
    t        = N[Range[0, nSamples - 1]] / sr;
    leftBuf  = ConstantArray[0.0, nSamples];
    rightBuf = ConstantArray[0.0, nSamples];
    Do[
      mono = amps[[i]] * Sin[2.0 * Pi * freqs[[i]] * t];
      leftBuf  += Sqrt[(1.0 - pans[[i]]) / 2.0] * mono;
      rightBuf += Sqrt[(1.0 + pans[[i]]) / 2.0] * mono,
      {i, n}
    ];
    fadeSamples = Min[Round[0.005 * sr], Floor[nSamples / 4]];
    envelope    = FrameWindow[nSamples, fadeSamples];
    {leftBuf * envelope, rightBuf * envelope}
  ]

ResonanceAccentBurst[freq_?NumericQ, dur_?NumericQ, amp_?NumericQ, sr_Integer] :=
  Module[{burstLen = Max[1, Round[dur * sr]]},
    amp * Table[Sin[2.0 Pi * freq * k / sr] * Exp[-6.0 * k / burstLen], {k, 0, burstLen - 1}]
  ]

OverlayBurst[leftBuf_List, rightBuf_List, freq_?NumericQ, dur_?NumericQ,
            amp_?NumericQ, startTimeSec_?NumericQ, sr_Integer] :=
  Module[{burst, start, len, n = Length[leftBuf], lb = leftBuf, rb = rightBuf},
    burst = ResonanceAccentBurst[freq, dur, amp, sr];
    start = Clip[Round[startTimeSec * sr] + 1, {1, n}];
    len   = Min[Length[burst], n - start + 1];
    If[len > 0,
      lb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]];
      rb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]]
    ];
    {lb, rb}
  ]


(* ========================================================
   GALILEAN MODE

   1 simulation time unit (1 Io period) = 1 second of audio -- an
   internal tempo constant, not exposed via config (the build spec
   gives event durations and n_periods but no seconds-per-period
   value, so a fixed, documented pace is chosen here: at the default
   n_periods=8, this produces a 32-second main body, long enough to
   hear several repetitions of the 4:2:1 canon without the file
   becoming unwieldy at n_periods=16).
   ======================================================== *)

$ResonanceIoPeriodSeconds = 1.0;

(* Continuous drone: constant frequency, one octave below each moon's
   event pitch -- preserves the exact 4:2:1 ratio (see model.wl's
   $Pitch*Hz) while remaining audibly distinct from the event layer. *)
$GalileanDroneGanymedeHz = $PitchGanymedeHz / 2.0;
$GalileanDroneEuropaHz   = $PitchEuropaHz   / 2.0;
$GalileanDroneIoHz       = $PitchIoHz       / 2.0;

BuildGalileanAudio[model_Association, cfg_Association, sr_Integer] :=
  Module[{
    tEnd, mainDurSec, nSamplesMain, nSamplesTotal, tVec,
    droneGain, contIo, contEu, contGa,
    leftBuf, rightBuf,
    ioEventTimes, euEventTimes, gaEventTimes
  },
    tEnd = model["tEnd"];
    mainDurSec = tEnd * $ResonanceIoPeriodSeconds;
    nSamplesMain  = Round[mainDurSec * sr];
    nSamplesTotal = nSamplesMain + Round[1.0 * sr];  (* padding for release tails *)

    droneGain = 10.0^(N @ GetCfg[cfg, {"sonification", "resonance", "trajectory_layer_gain"}, -12] / 20.0);

    tVec = N[Range[0, nSamplesMain - 1]] / sr;
    contIo = 0.5 * Sin[2.0 Pi $GalileanDroneIoHz tVec];
    contEu = 0.5 * Sin[2.0 Pi $GalileanDroneEuropaHz tVec];
    contGa = 0.5 * Sin[2.0 Pi $GalileanDroneGanymedeHz tVec];

    leftBuf  = ConstantArray[0.0, nSamplesTotal];
    rightBuf = ConstantArray[0.0, nSamplesTotal];

    (* Continuous trajectory layer -- Io hard left (-1), Europa centre
       (0), Ganymede hard right (+1), mixed at droneGain (-12dB default). *)
    leftBuf[[1 ;; nSamplesMain]]  += droneGain * Sqrt[(1.0 - (-1.0)) / 2.0] * contIo;
    rightBuf[[1 ;; nSamplesMain]] += droneGain * Sqrt[(1.0 + (-1.0)) / 2.0] * contIo;
    leftBuf[[1 ;; nSamplesMain]]  += droneGain * Sqrt[(1.0 - 0.0) / 2.0] * contEu;
    rightBuf[[1 ;; nSamplesMain]] += droneGain * Sqrt[(1.0 + 0.0) / 2.0] * contEu;
    leftBuf[[1 ;; nSamplesMain]]  += droneGain * Sqrt[(1.0 - 1.0) / 2.0] * contGa;
    rightBuf[[1 ;; nSamplesMain]] += droneGain * Sqrt[(1.0 + 1.0) / 2.0] * contGa;

    ioEventTimes = model["ioEventTimes"]; euEventTimes = model["euEventTimes"];
    gaEventTimes = model["gaEventTimes"];

    (* Event layer: one StemSynthNote per orbit completion, hard-panned
       per moon. Io: bright (sine+2nd+3rd), Europa: medium (sine+2nd),
       Ganymede: soft (pure sine). *)
    Do[
      Module[{mono, start, len},
        mono  = StemSynthNote[$PitchIoHz, 0.15, 0.5, {1.0, 0.3, 0.15}, 0.35, sr];
        start = Round[t * $ResonanceIoPeriodSeconds * sr] + 1;
        len   = Min[Length[mono], nSamplesTotal - start + 1];
        If[len > 0, leftBuf[[start ;; start + len - 1]] += mono[[1 ;; len]]]  (* pan -1: left only *)
      ],
      {t, ioEventTimes}
    ];
    Do[
      Module[{mono, start, len},
        mono  = StemSynthNote[$PitchEuropaHz, 0.3, 0.55, {1.0, 0.3}, 0.45, sr];
        start = Round[t * $ResonanceIoPeriodSeconds * sr] + 1;
        len   = Min[Length[mono], nSamplesTotal - start + 1];
        If[len > 0,
          leftBuf[[start ;; start + len - 1]]  += Sqrt[0.5] * mono[[1 ;; len]];
          rightBuf[[start ;; start + len - 1]] += Sqrt[0.5] * mono[[1 ;; len]]
        ]  (* pan 0: centre *)
      ],
      {t, euEventTimes}
    ];
    Do[
      Module[{mono, start, len},
        mono  = StemSynthNote[$PitchGanymedeHz, 0.6, 0.6, {1.0}, 0.5, sr];
        start = Round[t * $ResonanceIoPeriodSeconds * sr] + 1;
        len   = Min[Length[mono], nSamplesTotal - start + 1];
        If[len > 0, rightBuf[[start ;; start + len - 1]] += mono[[1 ;; len]]]  (* pan +1: right only *)
      ],
      {t, gaEventTimes}
    ];

    <| "left" -> leftBuf, "right" -> rightBuf, "sr" -> sr |>
  ]

SonifyGalilean[model_Association, cfg_Association, outWav_String] :=
  Module[{sr, audio, introText},
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    audio = BuildGalileanAudio[model, cfg, sr];

    introText =
      "Io, Europa, and Ganymede in 4 to 2 to 1 Laplace resonance. For every orbit Ganymede " <>
      "completes, Europa completes exactly 2 and Io completes exactly 4. Ganymede plays C3, " <>
      "Europa plays C4, Io plays C5 -- two octaves locked in place by gravity for billions of " <>
      "years. You will hear " <> ToString[model["nPeriods"]] <>
      " complete Ganymede orbits, each containing 2 Europa notes and 4 Io notes.";

    PrependIntroAndExport[introText, audio["left"], audio["right"], sr, outWav]
  ]


(* ========================================================
   KIRKWOOD MODE

   freq_min/freq_max are fixed at 200/2000 Hz per the build spec's own
   mode description -- distinct from the shared
   simulation.resonance.freq_min/freq_max config keys, which the
   config schema's own defaults (150/3000) match the SATURN mode's
   description instead. See AGENTS.md.
   ======================================================== *)

$KirkwoodFreqMinHz = 200.0;
$KirkwoodFreqMaxHz = 2000.0;

BuildKirkwoodAudio[model_Association, cfg_Association, sr_Integer] :=
  Module[{
    aVals, rhoVals, nBins, resonances,
    chordDur, stepDur, freqs, ampsChord,
    chordL, chordR, pauseSamples, pauseL, pauseR,
    sweepL, sweepR, stepSamples, fadeSamples,
    idx, resIndices
  },
    aVals   = model["aVals"]; rhoVals = model["rhoVals"];
    nBins   = model["nSteps"]; resonances = model["resonances"];
    chordDur = N @ GetCfg[cfg, {"simulation", "resonance", "chord_duration"},     4.0];
    stepDur  = N @ GetCfg[cfg, {"simulation", "resonance", "duration_per_step"}, 0.05];

    freqs = $KirkwoodFreqMinHz * ($KirkwoodFreqMaxHz / $KirkwoodFreqMinHz)^
      Rescale[aVals, {model["aMin"], model["aMax"]}, {0.0, 1.0}];

    (* ── Chord: all semi-major axes simultaneously ── *)
    ampsChord = rhoVals / Sqrt[N[nBins]];
    {chordL, chordR} = SynthesizeAdditiveFrame[freqs, ampsChord, ConstantArray[0.0, nBins], chordDur, sr];

    pauseSamples = Round[0.4 * sr];
    pauseL = ConstantArray[0.0, pauseSamples]; pauseR = pauseL;

    (* ── Sweep: same bins, played sequentially, inner to outer ── *)
    stepSamples = Max[1, Round[stepDur * sr]];
    fadeSamples = Min[Round[0.01 * sr], Floor[stepSamples / 4]];
    sweepL = ConstantArray[0.0, stepSamples * nBins];
    sweepR = sweepL;
    Do[
      Module[{t, mono, env, start},
        t     = N[Range[0, stepSamples - 1]] / sr;
        mono  = rhoVals[[k]] * Sin[2.0 Pi freqs[[k]] t];
        env   = FrameWindow[stepSamples, fadeSamples];
        start = (k - 1) * stepSamples + 1;
        sweepL[[start ;; start + stepSamples - 1]] = mono * env;
        sweepR[[start ;; start + stepSamples - 1]] = mono * env
      ],
      {k, nBins}
    ];

    (* ── Accent + spoken announcement at each resonance crossing ── *)
    Scan[
      Function[res,
        idx = First[Ordering[Abs[aVals - res["a"]], 1]];
        STEMSay["Crossing the " <> res["label"] <> " resonance"];
        {sweepL, sweepR} = OverlayBurst[sweepL, sweepR, 220.0, 0.12, 0.6,
          (idx - 1) * stepDur, sr]
      ],
      SortBy[resonances, #["a"] &]
    ];

    <|
      "left"  -> Join[chordL, pauseL, sweepL],
      "right" -> Join[chordR, pauseR, sweepR],
      "sr" -> sr
    |>
  ]

SonifyKirkwood[model_Association, cfg_Association, outWav_String] :=
  Module[{sr, audio, introText},
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    audio = BuildKirkwoodAudio[model, cfg, sr];

    introText =
      "Kirkwood gaps in the asteroid belt: orbital resonances with Jupiter at 4 to 1, 3 to 1, " <>
      "5 to 2, 7 to 3, and 2 to 1 period ratios. First you hear all orbital radii simultaneously " <>
      "as a chord, then a sweep from inner to outer belt. The silences in the sweep are the " <>
      "Kirkwood gaps -- regions cleared by Jupiter's gravity over billions of years.";

    PrependIntroAndExport[introText, audio["left"], audio["right"], sr, outWav]
  ]


(* ========================================================
   SATURN MODE

   Same chord+sweep structure as kirkwood; freq_min/freq_max come from
   the shared simulation.resonance.freq_min/freq_max config keys
   (default 150/3000 Hz), which match this mode's build-spec text
   exactly -- see AGENTS.md.
   ======================================================== *)

BuildSaturnAudio[model_Association, cfg_Association, sr_Integer] :=
  Module[{
    rVals, rhoVals, nBins, freqMin, freqMax,
    chordDur, stepDur, freqs, ampsChord,
    chordL, chordR, pauseSamples, pauseL, pauseR,
    sweepL, sweepR, stepSamples, fadeSamples,
    cassiniIdx
  },
    rVals = model["rVals"]; rhoVals = model["rhoVals"]; nBins = model["nSteps"];
    freqMin = N @ GetCfg[cfg, {"simulation", "resonance", "freq_min"}, 150];
    freqMax = N @ GetCfg[cfg, {"simulation", "resonance", "freq_max"}, 3000];
    chordDur = N @ GetCfg[cfg, {"simulation", "resonance", "chord_duration"},     4.0];
    stepDur  = N @ GetCfg[cfg, {"simulation", "resonance", "duration_per_step"}, 0.05];

    freqs = freqMin * (freqMax / freqMin)^Rescale[rVals, {model["rMin"], model["rMax"]}, {0.0, 1.0}];

    (* ── Chord: all orbital radii simultaneously ── *)
    ampsChord = rhoVals / Sqrt[N[nBins]];
    {chordL, chordR} = SynthesizeAdditiveFrame[freqs, ampsChord, ConstantArray[0.0, nBins], chordDur, sr];

    pauseSamples = Round[0.4 * sr];
    pauseL = ConstantArray[0.0, pauseSamples]; pauseR = pauseL;

    (* ── Sweep: inner edge to outer edge ── *)
    stepSamples = Max[1, Round[stepDur * sr]];
    fadeSamples = Min[Round[0.01 * sr], Floor[stepSamples / 4]];
    sweepL = ConstantArray[0.0, stepSamples * nBins];
    sweepR = sweepL;
    Do[
      Module[{t, mono, env, start},
        t     = N[Range[0, stepSamples - 1]] / sr;
        mono  = rhoVals[[k]] * Sin[2.0 Pi freqs[[k]] t];
        env   = FrameWindow[stepSamples, fadeSamples];
        start = (k - 1) * stepSamples + 1;
        sweepL[[start ;; start + stepSamples - 1]] = mono * env;
        sweepR[[start ;; start + stepSamples - 1]] = mono * env
      ],
      {k, nBins}
    ];

    (* ── Accent + announcement at the Cassini Division ── *)
    cassiniIdx = First[Ordering[Abs[rVals - $SaturnCassiniCenterKm], 1]];
    STEMSay["Cassini Division -- 2:1 resonance with Mimas"];
    {sweepL, sweepR} = OverlayBurst[sweepL, sweepR, 220.0, 0.15, 0.7, (cassiniIdx - 1) * stepDur, sr];

    <|
      "left"  -> Join[chordL, pauseL, sweepL],
      "right" -> Join[chordR, pauseR, sweepR],
      "sr" -> sr
    |>
  ]

SonifySaturn[model_Association, cfg_Association, outWav_String] :=
  Module[{sr, audio, introText},
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    audio = BuildSaturnAudio[model, cfg, sr];

    introText =
      "Saturn's ring structure, from the C ring at 74,000 kilometers to the outer A ring at " <>
      "137,000 kilometers. The loudest section is the dense B ring. Then silence: the Cassini " <>
      "Division, cleared by a 2 to 1 resonance with the moon Mimas. Then the A ring resumes, " <>
      "with a briefer gap from the Encke resonance with Pan.";

    PrependIntroAndExport[introText, audio["left"], audio["right"], sr, outWav]
  ]

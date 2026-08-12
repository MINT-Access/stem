(* ========================================================
   fluid/src/sonify.wl — Audio synthesis for karman/strouhal/flag

   Design decision: manual carrier synthesis, not stem-core's
   SonifyTrajectory wrapper (SpatialLayer/MotionLayer/EventLayer/
   MixLayers). Every mode needs a tone at an exact CALIBRATED
   physical frequency (the Strouhal or flutter frequency scaled to
   audio_freq_target -- a fixed target, not something re-derived
   from MinMax[value] the way SpatialLayer's Rescale works) plus
   ScaleLookup-quantised pitch (explicitly requested by the app
   spec for both karman and flag modes -- SpatialLayer only does a
   continuous linear Rescale to Hz, never scale quantisation) plus
   event bursts timed by real vortex-shedding/zero-crossing physics
   (not EventLayer's built-in apex/crossing detectors). This is the
   same situation, and the same resolution, as magnetic/src/sonify.wl
   (see its header comment and AGENTS.md design decision 1): manual
   carriers built directly from stem-core's lower-level primitives
   (ScaleLookup, SemitoneToHz, StemSynthNote, NormalizeBuffer,
   ExportAudioBuffer, SpeechSynthesize) rather than SonifyTrajectory.
   ======================================================== *)

$FluidAudioSecPerUnit = 0.6;  (* simulation-time-unit -> audio-second stretch *)


(* ── Vectorised ScaleLookup — VALS a list, not a scalar.
   Same mapping as stem-core's ScaleLookup (nearest scale degree,
   clamped to the scale's range) but computed for a whole array at
   once via Part-with-list-of-indices rather than Map, which matters
   at audio sample counts (10^5-10^6 elements).

   Deliberately does NOT call stem-core's SemitoneToHz here:
   SemitoneToHz[semitones_?NumericQ, ...] is pattern-matched for a
   scalar, so calling it with a list argument (scale[[idx]], a whole
   array) fails to match, returns *unevaluated*, and that unevaluated
   symbolic expression then silently poisons every downstream
   Accumulate/Sin -- turning a sub-second vectorised pipeline into a
   many-minutes-long symbolic one with no error message. Inlining the
   same formula (rootHz * 2^(semitones/12)) works directly on arrays. *)
VectorScaleLookup[vals_List, lo_?NumericQ, hi_?NumericQ, scale_List, rootHz_?NumericQ] :=
  Module[{n = Length[scale], idx},
    idx = Clip[Round[Rescale[vals, {lo, hi}, {1, n}]], {1, n}];
    Developer`ToPackedArray @ N[rootHz * 2.0^(scale[[idx]] / 12.0)]
  ];

(* SafeInterpToAudioGrid — spline-interpolate a (tSim, valSim) series
   onto tAudio; falls back to a constant when valSim is degenerate
   (fewer than 2 points, or all-equal) since Interpolation requires
   at least 2 distinct abscissas.

   InterpolatingFunction evaluated on a list argument does not
   reliably return a packed array (observed here: it silently comes
   back unpacked), which then cascades into every downstream
   elementwise operation running in Mathematica's much slower
   general/unpacked numeric path -- at audio sample counts
   (10^5-10^6) this alone turned a sub-second pipeline into a
   multi-minute one. Developer`ToPackedArray forces repacking right
   at the boundary so everything built from it downstream (carriers,
   pan, volume) stays packed. *)
SafeInterpToAudioGrid[tSim_List, valSim_List, tAudio_List] :=
  Developer`ToPackedArray @ N @
  If[Length[tSim] < 2,
    ConstantArray[If[Length[valSim] > 0, First[valSim], 0.0], Length[tAudio]],
    Interpolation[Transpose[{tSim, valSim}], Method -> "Spline"][tAudio]
  ];

(* SafeRescaleArr — like SafeRescale in model.wl but always returns a
   list the same length as val (model.wl's version already handles
   this via Rescale's own listability; duplicated here with the name
   spelled out for clarity at call sites in this file). *)
SafeRescaleArr[val_List, {lo_, hi_}, {a_, b_}] :=
  If[hi - lo < 1.0*^-9, ConstantArray[(a + b) / 2.0, Length[val]],
    Clip[Rescale[val, {lo, hi}, {a, b}], {a, b}]];


(* ── Event bursts — one frequency/intensity per event, so karman's
   alternating top(330Hz)/bottom(220Hz) shed clicks and strouhal's
   distinct onset/transition accents can all use one function. *)
BuildEventBurstArrayVar[times_List, freqs_List, intensities_List,
                        sr_Integer, nSamples_Integer, audioDur_?NumericQ] :=
  Module[{arr, burstLen},
    arr      = ConstantArray[0.0, nSamples];
    burstLen = Round[0.04 * sr];
    Do[
      With[{s = Clip[Round[times[[k]] / audioDur * (nSamples - 1)] + 1, {1, nSamples}],
            freq = freqs[[k]], inten = intensities[[k]]},
        With[{burst = inten * 0.5 *
                Table[Sin[2.0 Pi * freq * i / sr] * Exp[-8.0 i / burstLen], {i, 0, burstLen - 1}]},
          arr[[s ;; Min[s + burstLen - 1, nSamples]]] +=
            burst[[;; Min[burstLen, nSamples - s + 1]]]
        ]
      ],
      {k, Length[times]}
    ];
    arr
  ];

(* Clip to [-1,1] defensively: cubic-spline interpolation (used by
   SafeInterpToAudioGrid) can overshoot slightly past the source
   data's range between sample points -- harmless for a pan value
   already sitting well inside [-1,1] (karman's centroid pan is
   rescaled to [-0.8,0.8]) but fatal here if a caller's pan touches
   the endpoints exactly (flag mode's y_tip pan spans the full
   [-1,1]): Sqrt of the resulting tiny negative number silently goes
   complex, and every downstream real-only operation (MinMax,
   Export's WAV writer) then either poisons the whole array or fails
   outright with no useful error. *)
PanAndCarrierToStereo[monoPlusEvents_List, panArr_] :=
  Module[{panList = Clip[If[ListQ[panArr], panArr, ConstantArray[panArr, Length[monoPlusEvents]]],
                         {-1.0, 1.0}],
          leftCh, rightCh},
    leftCh  = monoPlusEvents * Sqrt[(1.0 - panList) / 2.0];
    rightCh = monoPlusEvents * Sqrt[(1.0 + panList) / 2.0];
    Transpose[{leftCh, rightCh}]
  ];


(* ── Speech: SpeechSynthesize[] -> platform TTS -> text-only STEMSay.
   Same three-tier fallback pattern as magnetic/dynamical/thermo. *)

FluidResampleLinear[data_List, rawSr_?NumericQ, targetSr_?NumericQ] :=
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
  ];

FluidSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_fluid_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_fluid_say_" <> id <> ".aiff"}];
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

    FluidResampleLinear[data, rawSr, targetSr]
  ];

FluidBuildIntroBuffer[text_String, sr_Integer] :=
  Module[{buf, result, data, rawSr},
    buf = Quiet[Check[
      result = SpeechSynthesize[text];
      If[AudioQ[result],
        data  = Quiet[Flatten[N[AudioData[result]]]];
        rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
        If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
          FluidResampleLinear[data, rawSr, sr],
          {}
        ],
        {}
      ],
      {}
    ]];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    buf = FluidSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable -- spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ];

(* Returns the ACTUAL total WAV duration (intro speech + pause + main
   audio, in seconds) rather than Null, so callers can pass it straight
   to Animate* as targetDuration -- the spoken intro's length depends on
   the platform TTS engine and isn't known until it's synthesised, so
   exact GIF/WAV sync requires sonifying before animating (main.wl and
   experiments.wl call Sonify* before Animate* for this reason). *)
FluidPrependIntroAndExport[introText_String, leftMain_List, rightMain_List,
                           sr_Integer, outWav_String] :=
  Module[{introBuffer, pauseBuffer, finalLeft, finalRight, totalDur},
    Print["  Spoken intro: ", introText];
    introBuffer = FluidBuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, leftMain];
    finalRight  = Join[introBuffer, pauseBuffer, rightMain];
    EnsureDir[outWav];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWav, sr];
    totalDur = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWav, totalDur];
    totalDur
  ];


(* ════════════════════════════════════════════════════════
   KARMAN MODE
   ════════════════════════════════════════════════════════ *)
SonifyKarman[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, audioDur, nSamples, tAudio, tSimAtAudio,
    lNormAudio, panAudio, freqArr1, carrier1, tone2, ampArr, mixMono,
    shedTimesAudio, shedFreqs, shedIntens, eventArr,
    total, stereo, introText
  },
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    audioDur = $FluidAudioSecPerUnit * model["duration"];
    nSamples = Max[2, Round[sr * audioDur]];
    tAudio = N @ Subdivide[0.0, audioDur, nSamples - 1];
    tSimAtAudio = N @ Rescale[tAudio, {0.0, audioDur}, {0.0, model["duration"]}];

    lNormAudio = SafeInterpToAudioGrid[model["tData"], model["lNorm"], tSimAtAudio];
    panAudio   = SafeInterpToAudioGrid[model["tData"], model["panData"], tSimAtAudio];

    freqArr1 = VectorScaleLookup[lNormAudio, -1.0, 1.0, $StemScales["MinorPentatonic"], $FluidRootHz];
    carrier1 = Sin[2.0 Pi * Accumulate[freqArr1] / sr];
    tone2    = Sin[2.0 Pi * model["audioFreq"] * tAudio];

    ampArr  = SafeRescaleArr[Abs[lNormAudio], {0.0, 1.0}, {0.20, 0.95}];
    mixMono = ampArr * carrier1 * 0.55 + 0.35 * tone2;

    (* Shed events: alternate 330 Hz (top/positive) and 220 Hz
       (bottom/negative), mapped onto the same simulation-time ->
       audio-time stretch as everything else. *)
    shedTimesAudio = model["sim"]["shedTimes"] * (audioDur / model["duration"]);
    shedFreqs  = If[# > 0, 330.0, 220.0] & /@ model["sim"]["shedSigns"];
    shedIntens = ConstantArray[0.55, Length[shedTimesAudio]];
    eventArr = BuildEventBurstArrayVar[shedTimesAudio, shedFreqs, shedIntens, sr, nSamples, audioDur];

    total  = mixMono + eventArr;
    stereo = PanAndCarrierToStereo[total, panAudio];

    introText =
      "Karman vortex street at Reynolds number " <> ToString[NumberForm[model["Re"], {5,1}]] <>
      ". Vortex shedding frequency " <> ToString[NumberForm[model["sim"]["fShed"], {5,4}]] <>
      " simulation units, mapped to " <> ToString[NumberForm[model["audioFreq"], {5,1}]] <>
      " hertz. The cylinder sheds alternating vortices from its top and bottom -- each shed " <>
      "marked by a click. The tone you hear is the Strouhal frequency: the same pitch a " <>
      "flag pole sings in the wind.";

    FluidPrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ];


(* ════════════════════════════════════════════════════════
   STROUHAL MODE
   ════════════════════════════════════════════════════════ *)
SonifyStrouhal[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, segDur, nSampSeg, tSeg, steps, nSteps,
    segBuffers, transitionAnnounced, i, step, lRaw, lCentered, lNorm,
    freqArr1, carrier1, audioFreqStep, tone2, ampArr, mono,
    fullMono, fullPan, segStartTimes,
    onsetIdx, transitionIdx, eventTimes, eventFreqs, eventIntens, eventArr,
    total, stereo, introText
  },
    sr     = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    segDur = $StrouhalAudioSecPerStep;
    nSampSeg = Max[2, Round[sr * segDur]];
    tSeg   = N @ Subdivide[0.0, segDur, nSampSeg - 1];
    steps  = model["steps"];
    nSteps = Length[steps];

    segBuffers = Table[
      step = steps[[i]];
      If[!step["shedding"],
        ConstantArray[0.0, nSampSeg],
        (
          lRaw = SafeInterpToAudioGrid[step["tLocal"], step["lRaw"], tSeg * (model["durationPerRe"] / segDur)];
          lCentered = lRaw - Mean[lRaw];
          lNorm = lCentered / (Max[Abs[lCentered]] + 1.0*^-6);
          freqArr1 = VectorScaleLookup[lNorm, -1.0, 1.0, $StemScales["MinorPentatonic"], $FluidRootHz];
          carrier1 = Sin[2.0 Pi * Accumulate[freqArr1] / sr];
          audioFreqStep = AudioFreqFromShed[step["fShedPredicted"], model["audioFreqTarget"]];
          tone2 = Sin[2.0 Pi * audioFreqStep * tSeg];
          ampArr = SafeRescaleArr[Abs[lNorm], {0.0, 1.0}, {0.25, 0.9}];
          ampArr * carrier1 * 0.55 + 0.35 * tone2
        )
      ],
      {i, nSteps}
    ];

    fullMono = Flatten[segBuffers];
    segStartTimes = Table[(i - 1) * segDur, {i, nSteps}];
    fullPan = Flatten[Table[
      ConstantArray[Rescale[i, {1, nSteps}, {-0.5, 0.5}], nSampSeg],
      {i, nSteps}
    ]];

    onsetIdx = FirstPosition[steps, _?(#["onsetFlag"] === True &)];
    transitionIdx = FirstPosition[model["reValues"], x_ /; x >= $ReTurbulentTransition];

    eventTimes = {}; eventFreqs = {}; eventIntens = {};
    If[onsetIdx =!= Missing["NotFound"],
      AppendTo[eventTimes, segStartTimes[[onsetIdx[[1]]]]];
      AppendTo[eventFreqs, 880.0]; AppendTo[eventIntens, 0.8]
    ];
    If[transitionIdx =!= Missing["NotFound"],
      AppendTo[eventTimes, segStartTimes[[transitionIdx[[1]]]]];
      AppendTo[eventFreqs, 200.0]; AppendTo[eventIntens, 0.8]
    ];
    eventArr = If[Length[eventTimes] > 0,
      BuildEventBurstArrayVar[eventTimes, eventFreqs, eventIntens, sr, Length[fullMono], nSteps * segDur],
      ConstantArray[0.0, Length[fullMono]]
    ];

    total  = fullMono + eventArr;
    stereo = PanAndCarrierToStereo[total, fullPan];

    introText =
      "Reynolds number sweep from " <> ToString[NumberForm[model["reStart"], {5,1}]] <> " to " <>
      ToString[NumberForm[model["reEnd"], {5,1}]] <> ". Below Reynolds number 47, the flow is " <>
      "steady -- silence. At onset, a pure tone appears. Listen for the tone emerging from " <>
      "silence and gradually complexifying as Reynolds number increases toward turbulence.";

    If[onsetIdx =!= Missing["NotFound"],
      STEMPrintN["Onset of vortex shedding at Re", model["reValues"][[onsetIdx[[1]]]], "", 4];
      STEMSay["Onset of vortex shedding."]
    ];
    If[transitionIdx =!= Missing["NotFound"],
      STEMPrintN["Transition toward turbulent wake near Re", model["reValues"][[transitionIdx[[1]]]], "", 4];
      STEMSay["Transition to turbulent wake."]
    ];

    FluidPrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ];


(* ════════════════════════════════════════════════════════
   FLAG MODE
   ════════════════════════════════════════════════════════ *)
SonifyFlag[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, audioDur, nSamples, tAudio, tSimAtAudio,
    panAudio, volAudio, freqArr1, carrier1, tone2, ampArr, mixMono,
    crossTimesSim, crossTimesAudio, eventFreqs, eventIntens, eventArr,
    total, stereo, introText
  },
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    audioDur = $FluidAudioSecPerUnit * model["duration"];
    nSamples = Max[2, Round[sr * audioDur]];
    tAudio = N @ Subdivide[0.0, audioDur, nSamples - 1];
    tSimAtAudio = N @ Rescale[tAudio, {0.0, audioDur}, {0.0, model["duration"]}];

    panAudio = SafeInterpToAudioGrid[model["model"]["tArr"], model["panData"], tSimAtAudio];
    volAudio = SafeInterpToAudioGrid[model["model"]["tArr"], model["volumeData"], tSimAtAudio];

    freqArr1 = VectorScaleLookup[panAudio, -1.0, 1.0, $StemScales["MinorPentatonic"], $FluidRootHz];
    carrier1 = Sin[2.0 Pi * Accumulate[freqArr1] / sr];
    tone2    = Sin[2.0 Pi * model["audioFreq"] * tAudio];

    ampArr  = SafeRescaleArr[volAudio, {0.0, 1.0}, {0.20, 0.95}];
    mixMono = ampArr * carrier1 * 0.6 + 0.30 * tone2;

    crossTimesSim = Select[Range[2, Length[model["model"]["tArr"]]],
      model["model"]["yArr"][[# - 1]] * model["model"]["yArr"][[#]] < 0 &];
    crossTimesSim = model["model"]["tArr"][[crossTimesSim]];
    crossTimesAudio = crossTimesSim * (audioDur / model["duration"]);
    eventFreqs  = ConstantArray[440.0, Length[crossTimesAudio]];
    eventIntens = ConstantArray[0.5, Length[crossTimesAudio]];
    eventArr = BuildEventBurstArrayVar[crossTimesAudio, eventFreqs, eventIntens, sr, nSamples, audioDur];

    total  = mixMono + eventArr;
    stereo = PanAndCarrierToStereo[total, panAudio];

    introText =
      "Flag flutter in flow. Flag length " <> ToString[NumberForm[model["flagLength"], {4,2}]] <>
      ", freestream velocity " <> ToString[NumberForm[model["U"], {4,2}]] <> ", flutter frequency " <>
      ToString[NumberForm[model["model"]["fFlag"], {5,4}]] <> " mapped to " <>
      ToString[NumberForm[model["audioFreq"], {5,1}]] <> " hertz. The tone pans left and right " <>
      "as the flag tip sweeps through each flap. This is the same physics that makes flags " <>
      "flap, power lines hum, and Aeolian harps sing.";

    FluidPrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ];

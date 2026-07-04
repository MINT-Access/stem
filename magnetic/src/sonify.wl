(* ========================================================
   magnetic/src/sonify.wl — Audio synthesis for all four modes

   Public API:
     SonifyCyclotron[model, cfg, outWav]
     SonifyDrift[model, cfg, outWav]
     SonifyMirror[model, cfg, outWav]
     SonifyMulti[model, cfg, outWav]

   Design decision: manual carrier synthesis, not SonifyTrajectory.
   Every mode needs the tone's OWN frequency to literally equal a
   physical quantity (e.g. cyclotron mode's tone must sit at exactly
   omega_c, a constant) rather than a value that is itself linearly
   rescaled into a pitch range (which is what stem-core's SpatialLayer
   does).  A constant-source signal fed through SpatialLayer's
   Rescale[val, MinMax[val], range] is degenerate (MinMax collapses to
   a point), and the accent-tone timing needed here (orbit completions,
   cycloid minima, mirror reflections) isn't among EventLayer's built-in
   apex/crossing detectors.  This mirrors the precedent already set by
   relativity/src/sonify.wl's SonifyGeodesic, which manually builds a
   frequency array and phase-accumulates a carrier for the same reason.
   See AGENTS.md design decision 1 for the full rationale.
   ======================================================== *)


(* ── SafeRescale — like Rescale, but returns the range midpoint
   instead of Indeterminate when the source is (numerically) constant.
   Needed because cyclotron mode's speed is exactly conserved, so a
   plain Rescale[speed, MinMax[speed], ampRange] would divide by zero. *)
SafeRescale[val_, {lo_, hi_}, {a_, b_}] :=
  If[hi - lo < 1.0*^-9, (a + b) / 2.0, Rescale[val, {lo, hi}, {a, b}]]


(* ── BuildEventBurstArray — short decaying sine "ping" at each listed
   time.  Same construction as stem-core's EventLayer, duplicated here
   (rather than calling EventLayer) because the event TIMES are computed
   from mode-specific physics (orbit completions, cycloid minima, mirror
   reflections), not EventLayer's built-in apex/crossing detectors. *)
BuildEventBurstArray[times_List, freq_?NumericQ, intensity_?NumericQ,
                     sr_Integer, nSamples_Integer, tMax_?NumericQ] :=
  Module[{arr, burstLen},
    arr      = ConstantArray[0.0, nSamples];
    burstLen = Round[0.04 * sr];
    Do[
      With[{s = Clip[Round[t / tMax * (nSamples - 1)] + 1, {1, nSamples}]},
        With[{burst = intensity * 0.5 *
                Table[Sin[2.0 Pi * freq * i / sr] * Exp[-8.0 i / burstLen],
                      {i, 0, burstLen - 1}]},
          arr[[s ;; Min[s + burstLen - 1, nSamples]]] +=
            burst[[;; Min[burstLen, nSamples - s + 1]]]
        ]
      ],
      {t, times}
    ];
    arr
  ]


(* ── LocalMinimaTimes — interior local minima of a sampled array. *)
LocalMinimaTimes[tArr_List, vArr_List] :=
  Pick[tArr[[2 ;; -2]],
    Table[vArr[[i]] < vArr[[i - 1]] && vArr[[i]] < vArr[[i + 1]],
          {i, 2, Length[vArr] - 1}],
    True]


(* ── PanAndCarrierToStereo — apply per-sample pan to (carrier+events). *)
PanAndCarrierToStereo[monoPlusEvents_List, panArr_List] :=
  Module[{leftCh, rightCh},
    leftCh  = monoPlusEvents * Sqrt[(1.0 - panArr) / 2.0];
    rightCh = monoPlusEvents * Sqrt[(1.0 + panArr) / 2.0];
    Transpose[{leftCh, rightCh}]
  ]


(* ── Speech: SpeechSynthesize[] -> platform TTS -> text-only STEMSay.
   Same three-tier fallback pattern as thermo/src/speech.wl and
   dynamical/src/speech.wl; folded into sonify.wl here because this
   app's file list has no separate speech.wl. *)

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

MagneticSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_magnetic_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_magnetic_say_" <> id <> ".aiff"}];
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

    buf = MagneticSpeakToBufferPlatform[text, sr];
    If[ListQ[buf] && Length[buf] > 0, Return[buf]];

    Print["[WARNING] Speech synthesis unavailable -- spoken intro will be skipped. Text:"];
    STEMSay[text];
    {}
  ]


(* ── PrependIntro — build spoken intro, silence gap, join with the
   main stereo buffer, normalise, and export. *)
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


(* ========================================================
   CYCLOTRON MODE
   ======================================================== *)

SonifyCyclotron[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, baseFreqHz, tMax, omegaC, xFn, zFn, isHelix,
    nSamples, times, xAudio, zAudio, zRange,
    freqArr, ampArr, panArr, carrier, evtTimes, evtFreq, eventArr,
    total, stereo, introText
  },
    sr         = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    baseFreqHz = N @ GetCfg[cfg, {"simulation", "magnetic", "base_freq_hz"}, 110.0];
    tMax       = model["tMax"]; omegaC = model["omegaC"];
    xFn        = model["xFn"];  zFn = model["zFn"]; isHelix = model["isHelix"];

    nSamples = Max[2, Round[sr * tMax]];
    times    = N @ Subdivide[0.0, tMax, nSamples - 1];
    xAudio   = xFn /@ times;

    (* Pitch: constant tone AT the cyclotron frequency (after app-wide
       scaling base_freq_hz per unit omega_c).  Helix mode adds a slow
       modulation from the axial drift -- z increases steadily, so the
       modulation is a gentle one-way glide, not an oscillation. *)
    If[isHelix,
      zAudio  = zFn /@ times;
      zRange  = Max[Abs[zAudio]];
      freqArr = If[zRange > 1.0*^-9,
        baseFreqHz * Abs[omegaC] * (1.0 + 0.15 * zAudio / zRange),
        ConstantArray[baseFreqHz * Abs[omegaC], nSamples]],
      freqArr = ConstantArray[baseFreqHz * Abs[omegaC], nSamples]
    ];
    freqArr = Clip[freqArr, {20.0, 8000.0}];

    (* Volume: constant -- the magnetic force does no work, so |v| (and
       hence loudness) is exactly conserved regardless of v_parallel. *)
    ampArr = SafeRescale[model["speed"], MinMax[model["speed"]], {0.5, 0.7}];
    ampArr = Mean[ampArr];   (* scalar: speed is constant to numerical precision *)

    panArr = SafeRescale[xAudio, MinMax[xAudio], {-1.0, 1.0}];

    carrier = ampArr * Sin[2.0 Pi * Accumulate[freqArr] / sr];

    evtTimes = Table[n * model["Tc"], {n, 1, model["nPeriods"]}];
    evtFreq  = baseFreqHz * Abs[omegaC] * 2.0;
    eventArr = BuildEventBurstArray[evtTimes, evtFreq, 0.5, sr, nSamples, tMax];

    total  = carrier + eventArr;
    stereo = PanAndCarrierToStereo[total, panArr];

    introText =
      "Charged particle in a uniform magnetic field. Charge-to-mass ratio " <>
      ToString[NumberForm[model["k"], {5, 3}]] <> ", field strength " <>
      ToString[NumberForm[model["Bz"], {5, 3}]] <> ". Cyclotron frequency " <>
      ToString[NumberForm[omegaC, {5, 3}]] <> " radians per unit time, period " <>
      ToString[NumberForm[model["Tc"], {5, 3}]] <> " time units. " <>
      If[isHelix,
        "The particle also drifts along the field line, adding a slow pitch glide. ",
        ""] <>
      "Listen for the steady tone at the cyclotron frequency and the panning that marks each orbit.";

    PrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ]


(* ========================================================
   DRIFT MODE
   ======================================================== *)

SonifyDrift[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, tMax, xFn, yFn,
    nSamples, times, xAudio, yAudio, speedFn, speedAudio,
    pitchMin, pitchMax, freqArr, panArr, ampArr, carrier,
    evtTimes, eventArr, total, stereo, introText
  },
    sr   = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    tMax = model["tMax"];
    xFn  = model["xFn"]; yFn = model["yFn"];

    nSamples = Max[2, Round[sr * tMax]];
    times    = N @ Subdivide[0.0, tMax, nSamples - 1];
    xAudio   = xFn /@ times;
    yAudio   = yFn /@ times;

    (* Pitch: maps from x-position, which oscillates (circular motion)
       superimposed on the steady y-drift. *)
    pitchMin = N @ GetCfg[cfg, {"sonification", "pitch", "min_hz"}, 110.0];
    pitchMax = N @ GetCfg[cfg, {"sonification", "pitch", "max_hz"}, 880.0];
    freqArr  = Clip[SafeRescale[xAudio, MinMax[xAudio], {pitchMin, pitchMax}], {20.0, 8000.0}];

    (* Pan: y-position -- drifts steadily across the stereo field. *)
    panArr = SafeRescale[yAudio, MinMax[yAudio], {-1.0, 1.0}];

    (* Volume: actual speed -- varies through the cycloid. *)
    speedAudio = Sqrt[(xFn'[#])^2 + (yFn'[#])^2] & /@ times;
    ampArr     = SafeRescale[speedAudio, MinMax[speedAudio], {0.35, 0.85}];

    carrier = ampArr * Sin[2.0 Pi * Accumulate[freqArr] / sr];

    (* Event bursts at cycloid minimum-speed points (bottom of the arc). *)
    evtTimes = LocalMinimaTimes[model["t"], model["speed"]];
    eventArr = BuildEventBurstArray[evtTimes, 440.0, 0.5, sr, nSamples, tMax];

    total  = carrier + eventArr;
    stereo = PanAndCarrierToStereo[total, panArr];

    introText =
      "Charged particle in crossed electric and magnetic fields. E cross B drift velocity " <>
      ToString[NumberForm[model["vDrift"], {5, 3}]] <>
      " in the y direction. Listen for the stereo pan drifting steadily in one direction " <>
      "while the pitch oscillates -- that is the cycloid: circular motion carried along by the drift.";

    PrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ]


(* ========================================================
   MIRROR MODE
   ======================================================== *)

SonifyMirror[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, baseFreqHz, duration, xFn, zFn, vzFn, zScale,
    nSamples, times, xAudio, zAudio, vzAudio,
    freqArr, panArr, ampArr, carrier,
    evtTimes, eventArr, total, stereo, introText
  },
    sr         = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    baseFreqHz = N @ GetCfg[cfg, {"simulation", "magnetic", "base_freq_hz"}, 110.0];
    duration   = model["duration"];
    xFn = model["xFn"]; zFn = model["zFn"]; vzFn = model["vzFn"];
    zScale = model["zScale"];

    nSamples = Max[2, Round[sr * duration]];
    times    = N @ Subdivide[0.0, duration, nSamples - 1];
    xAudio   = xFn /@ times;
    zAudio   = zFn /@ times;
    vzAudio  = vzFn /@ times;

    (* Pitch: |z| -- low at the field minimum (midplane), rising toward
       the mirror point, falling back as the particle returns. *)
    freqArr = Clip[baseFreqHz * (1.0 + 2.0 * Abs[zAudio] / zScale), {20.0, 8000.0}];

    (* Pan: x-position -- the fast cyclotron oscillation in the
       perpendicular plane, superimposed on the slow mirror bounce. *)
    panArr = SafeRescale[xAudio, MinMax[xAudio], {-1.0, 1.0}];

    (* Volume: |v_parallel| -- loud moving fast along the field line,
       quiet near the mirror point where parallel motion halts. *)
    ampArr = SafeRescale[Abs[vzAudio], MinMax[Abs[vzAudio]], {0.15, 0.85}];

    carrier = ampArr * Sin[2.0 Pi * Accumulate[freqArr] / sr];

    (* Event bursts at each mirror reflection (v_parallel changes sign). *)
    evtTimes = model["bounceTimes"];
    eventArr = BuildEventBurstArray[evtTimes, baseFreqHz * 3.0, 0.6, sr, nSamples, duration];

    total  = carrier + eventArr;
    stereo = PanAndCarrierToStereo[total, panArr];

    introText =
      "Magnetic mirror simulation. Particle " <>
      If[model["analyticTrapped"], "is trapped", "escapes"] <> " -- sine squared theta zero of " <>
      ToString[NumberForm[model["sin2Theta0"], {5, 3}]] <>
      If[model["analyticTrapped"], " exceeds", " does not exceed"] <>
      " the trapping threshold of " <> ToString[NumberForm[model["B0"] / model["Bmax"], {5, 3}]] <>
      ". Listen for the pitch rising and falling as the particle approaches and retreats from " <>
      "the mirror points. Accent tones mark each reflection.";

    PrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ]


(* ========================================================
   MULTI MODE — proton / alpha / electron chord
   ======================================================== *)

SonifyMulti[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, tMax, nSamples, times,
    proton, alphaP, electron,
    panProton, panAlpha, panElectron,
    carrierProton, carrierAlpha, carrierElectron,
    leftCh, rightCh, introText
  },
    sr   = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    tMax = model["tMax"];
    proton = model["proton"]; alphaP = model["alpha"]; electron = model["electron"];

    nSamples = Max[2, Round[sr * tMax]];
    times    = N @ Subdivide[0.0, tMax, nSamples - 1];

    (* Each voice pans within its own lane, oscillating at its own
       particle's cyclotron rate (closed-form: x/r = Sin[omega t]). *)
    panProton   = -0.8 + 0.15 * Sin[proton["omega"] * times];
    panAlpha    =  0.0 + 0.30 * Sin[alphaP["omega"] * times];
    panElectron =  0.8 - 0.15 * Sin[electron["omega"] * times];

    (* Proton: warm sine.  Alpha: fundamental + 2nd harmonic (richer).
       Electron: pure sine (bright/thin simply by virtue of high pitch). *)
    carrierProton   = 0.30 * Sin[2.0 Pi * model["fProton"] * times];
    carrierAlpha    = 0.30 * (Sin[2.0 Pi * model["fAlpha"] * times] +
                               0.35 * Sin[2.0 Pi * 2.0 * model["fAlpha"] * times]) / 1.35;
    carrierElectron = 0.30 * Sin[2.0 Pi * model["fElectronScaled"] * times];

    leftCh  = carrierProton * Sqrt[(1.0 - panProton) / 2.0] +
              carrierAlpha  * Sqrt[(1.0 - panAlpha) / 2.0] +
              carrierElectron * Sqrt[(1.0 - panElectron) / 2.0];
    rightCh = carrierProton * Sqrt[(1.0 + panProton) / 2.0] +
              carrierAlpha  * Sqrt[(1.0 + panAlpha) / 2.0] +
              carrierElectron * Sqrt[(1.0 + panElectron) / 2.0];

    introText =
      "Three particles in the same magnetic field: proton, left channel, " <>
      ToString[NumberForm[model["fProton"], {5, 1}]] <> " hertz; alpha particle, centre, " <>
      ToString[NumberForm[model["fAlpha"], {5, 1}]] <> " hertz; and electron, right channel, " <>
      "scaled to " <> ToString[NumberForm[model["fElectronScaled"], {5, 1}]] <>
      " hertz. The actual electron cyclotron frequency would be " <>
      ToString[NumberForm[model["fElectronActual"], {8, 1}]] <> " hertz, " <>
      ToString[NumberForm[model["electronRatio"], {6, 1}]] <>
      " times higher than audio range. Listen for the three simultaneous cyclotron tones " <>
      "and their different panning rates.";

    PrependIntroAndExport[introText, leftCh, rightCh, sr, outWav]
  ]

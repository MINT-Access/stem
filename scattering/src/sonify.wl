(* ========================================================
   scattering/src/sonify.wl — Audio synthesis for all three modes

   scatter mode:
     Uses stem-core's SpatialLayer/MotionLayer/EventLayer/MixLayers
     directly (not the SonifyTrajectory convenience wrapper, since
     that wrapper has no hook for a prepended spoken intro -- every
     app in this codebase that speaks its intro into the WAV file
     builds that prepend step by hand; see BuildIntroBuffer/
     PrependIntroAndExport below, duplicated from magnetic/src/
     sonify.wl's identical pattern).

     The pitch column is Log[1/r] rather than real y position -- the
     same "put whatever physically-meaningful quantity you want into
     the y slot" idiom lagrange/src/sonify.wl uses (its y slot holds
     angular velocity, not real y). This makes the built-in EventLayer
     "apex" detector (a local maximum of the y column) fire exactly at
     periapsis (minimum r = maximum 1/r), giving the accent tone the
     spec asks for at the moment of closest approach without needing a
     bespoke detector. Real x is left in the x column so pan (default
     axis "x") continues to track true position.

   distribution / discovery modes:
     Fully bespoke discrete-note synthesis (StemSynthNote per particle,
     manual stereo placement), not SonifyTrajectory. The 200-particle
     distribution and paired 100-particle discovery comparison are
     each a stream of discrete one-shot events, not a single smoothly-
     varying trajectory -- SonifyTrajectory's SpatialLayer would spline-
     interpolate pitch/pan *between* particles into one continuous
     glide, which is the wrong audio shape for "a dense stream of
     individual events punctuated by rare loud ones." This is the same
     reasoning bayes/src/sonify.wl gives for its own discrete-note
     secondary layer, and discovery mode additionally needs two
     genuinely independent stereo channels (Thomson-only left,
     Rutherford-only right), not a single shared pan value -- closer to
     magnetic/src/sonify.wl's SonifyMulti (separate carriers, separate
     channel placement) than to any single-pan trajectory.
   ======================================================== *)


(* ── Speech: SpeechSynthesize[] -> platform TTS -> text-only STEMSay.
   Duplicated from magnetic/src/sonify.wl's identical three-tier
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

ScatteringSpeakToBufferPlatform[text_String, targetSr_Integer] :=
  Module[{id, wavPath, snd, data, rawSr},
    id      = ToString[RandomInteger[999999]];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_scattering_say_" <> id <> ".wav"}];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{aiffPath, result, conv},
          aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_scattering_say_" <> id <> ".aiff"}];
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

    buf = ScatteringSpeakToBufferPlatform[text, sr];
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


(* ── Short decaying-sine accent burst (backscatter marker). ────────
   Same construction as stem-core's EventLayer bursts and magnetic's
   BuildEventBurstArray, sized to a single {left,right}-ready mono
   array rather than pre-mixed into a full-length buffer. *)
ScatteringAccentBurst[freq_?NumericQ, dur_?NumericQ, amp_?NumericQ, sr_Integer] :=
  Module[{burstLen = Max[1, Round[dur * sr]]},
    amp * Table[Sin[2.0 Pi * freq * k / sr] * Exp[-6.0 * k / burstLen], {k, 0, burstLen - 1}]
  ]


(* ========================================================
   SCATTER MODE
   ======================================================== *)

SonifyScatter[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, tArr, xArr, rArr, speedArr, nPts, yPitchCol, traj, cfgSon,
    sp, mo, ev, stereo, introText
  },
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    tArr = model["t"]; xArr = model["x"]; rArr = model["r"];
    speedArr = model["speed"]; nPts = model["nPts"];

    (* Pitch column: Log[1/r] -- monotonically peaks exactly at
       periapsis, giving both the "logarithmic 1/r pitch mapping" the
       spec asks for AND a clean, single EventLayer "apex" trigger. *)
    yPitchCol = Log[1.0 / rArr];

    traj = N @ Transpose[{tArr, xArr, yPitchCol, ConstantArray[0.0, nPts], speedArr}];

    cfgSon = DeepMerge[cfg, <|"sonification" -> <|
      "duration" -> Clip[0.6 * model["tActual"], {4.0, 20.0}],
      "pitch"    -> <| "min_hz" -> 220.0, "max_hz" -> 1760.0 |>,
      "volume"   -> <| "min_db" -> -24.0, "max_db" -> -3.0 |>
    |>|>];

    sp     = SpatialLayer[traj, cfgSon];
    mo     = MotionLayer[traj, cfgSon];
    ev     = EventLayer[traj, cfgSon, {"apex"}];   (* periapsis only -- no "crossing" *)
    stereo = MixLayers[sp, mo, ev, cfgSon];

    introText =
      "Rutherford scattering: single alpha particle, impact parameter b equals " <>
      ToString[NumberForm[model["b"], {5, 3}]] <> " in scaled units. Predicted scattering angle: " <>
      ToString[NumberForm[model["thetaAnalyticDeg"], {5, 1}]] <>
      " degrees. Listen for the rising pitch and volume as the particle approaches the nucleus, " <>
      "the accent tone at closest approach, then the departure at " <>
      ToString[NumberForm[model["thetaAnalyticDeg"], {5, 1}]] <> " degrees.";

    PrependIntroAndExport[introText, stereo[[All, 1]], stereo[[All, 2]], sr, outWav]
  ]


(* ========================================================
   DISTRIBUTION MODE
   ======================================================== *)

BuildDistributionAudio[model_Association, noteDuration_?NumericQ, sr_Integer] :=
  Module[{n, thetaDeg, pitchHz, pan, ampNorm, nSamplesTotal, leftBuf, rightBuf},
    n = model["n"]; thetaDeg = model["thetaDeg"];
    pitchHz = model["pitchHz"]; pan = model["pan"]; ampNorm = model["ampNorm"];

    nSamplesTotal = Round[n * noteDuration * sr] + Round[0.3 * sr];
    leftBuf  = ConstantArray[0.0, nSamplesTotal];
    rightBuf = ConstantArray[0.0, nSamplesTotal];

    Do[
      Module[{mono, startSample, len, burst, burstLen},
        mono = StemSynthNote[pitchHz[[i]], 0.9 * noteDuration, ampNorm[[i]], {1.0, 0.25}, 0.4, sr];
        startSample = Round[(i - 1) * noteDuration * sr] + 1;
        len = Min[Length[mono], nSamplesTotal - startSample + 1];
        If[len > 0,
          leftBuf[[startSample ;; startSample + len - 1]]  += Sqrt[(1.0 - pan[[i]]) / 2.0] * mono[[1 ;; len]];
          rightBuf[[startSample ;; startSample + len - 1]] += Sqrt[(1.0 + pan[[i]]) / 2.0] * mono[[1 ;; len]]
        ];
        (* Backscatter accent: theta > 90 deg -- "the events that shocked
           Geiger and Marsden." Bespoke 660 Hz burst (not EventLayer's
           built-in apex/crossing detectors -- see file header). *)
        If[thetaDeg[[i]] > 90.0,
          burst = ScatteringAccentBurst[660.0, 0.08, 0.7, sr];
          burstLen = Length[burst];
          With[{len2 = Min[burstLen, nSamplesTotal - startSample + 1]},
            leftBuf[[startSample ;; startSample + len2 - 1]]  += Sqrt[0.5] * burst[[1 ;; len2]];
            rightBuf[[startSample ;; startSample + len2 - 1]] += Sqrt[0.5] * burst[[1 ;; len2]]
          ]
        ]
      ],
      {i, n}
    ];

    {leftBuf, rightBuf}
  ]

SonifyDistribution[model_Association, cfg_Association, outWav_String] :=
  Module[{sr, noteDuration, leftBuf, rightBuf, introText},
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    noteDuration = N @ GetCfg[cfg, {"simulation", "scattering", "note_duration"}, 0.08];

    {leftBuf, rightBuf} = BuildDistributionAudio[model, noteDuration, sr];

    introText =
      "Rutherford scattering distribution: " <> ToString[model["n"]] <>
      " alpha particles with random impact parameters. Listen for the dense background of quiet " <>
      "small-angle events, punctuated by loud high-pitched large-angle scattering. Events with " <>
      "deflection greater than 90 degrees are marked by accent tones -- these are the backscatter " <>
      "events that discovered the nucleus.";

    PrependIntroAndExport[introText, leftBuf, rightBuf, sr, outWav]
  ]


(* ========================================================
   DISCOVERY MODE — binaural Thomson (left) vs Rutherford (right)
   ======================================================== *)

BuildDiscoveryAudio[model_Association, nSeconds_?NumericQ, sr_Integer] :=
  Module[{
    n, thomsonThetaDeg, rutherfordThetaDeg, stepDur, noteDur,
    nSamplesTotal, leftBuf, rightBuf, pitchMinHz, pitchMaxHz
  },
    n = model["n"];
    thomsonThetaDeg    = model["thomsonThetaDeg"];
    rutherfordThetaDeg = model["rutherfordThetaDeg"];

    stepDur = nSeconds / n;
    noteDur = 0.9 * stepDur;
    nSamplesTotal = Round[nSeconds * sr];
    leftBuf  = ConstantArray[0.0, nSamplesTotal];
    rightBuf = ConstantArray[0.0, nSamplesTotal];
    pitchMinHz = 220.0; pitchMaxHz = 1760.0;

    (* LEFT: Thomson only -- quiet, uniform, no large-angle events ever. *)
    Do[
      Module[{freq, mono, startSample, len},
        freq = Rescale[thomsonThetaDeg[[i]], {0.0, 180.0}, {pitchMinHz, pitchMaxHz}];
        mono = StemSynthNote[freq, noteDur, 0.25, {1.0, 0.2}, 0.4, sr];
        startSample = Round[(i - 1) * stepDur * sr] + 1;
        len = Min[Length[mono], nSamplesTotal - startSample + 1];
        If[len > 0, leftBuf[[startSample ;; startSample + len - 1]] += mono[[1 ;; len]]]
      ],
      {i, n}
    ];

    (* RIGHT: Rutherford -- same quiet background, plus rare loud
       backscatter accents wherever theta > 90 deg. *)
    Do[
      Module[{freq, amp, mono, startSample, len, burst, burstLen, len2},
        freq = Rescale[rutherfordThetaDeg[[i]], {0.0, 180.0}, {pitchMinHz, pitchMaxHz}];
        amp  = If[rutherfordThetaDeg[[i]] > 90.0, 0.8, 0.25];
        mono = StemSynthNote[freq, noteDur, amp, {1.0, 0.2}, 0.4, sr];
        startSample = Round[(i - 1) * stepDur * sr] + 1;
        len = Min[Length[mono], nSamplesTotal - startSample + 1];
        If[len > 0, rightBuf[[startSample ;; startSample + len - 1]] += mono[[1 ;; len]]];
        If[rutherfordThetaDeg[[i]] > 90.0,
          burst = ScatteringAccentBurst[660.0, 0.08, 0.7, sr];
          burstLen = Length[burst];
          len2 = Min[burstLen, nSamplesTotal - startSample + 1];
          rightBuf[[startSample ;; startSample + len2 - 1]] += burst[[1 ;; len2]]
        ]
      ],
      {i, n}
    ];

    {leftBuf, rightBuf}
  ]

SonifyDiscovery[model_Association, cfg_Association, outWav_String] :=
  Module[{
    sr, nSeconds, leftMain, rightMain, introText, outroText,
    introBuf, outroBuf, pauseBuf, finalLeft, finalRight
  },
    sr = Round @ GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    nSeconds = N @ GetCfg[cfg, {"simulation", "scattering", "n_seconds"}, 8.0];

    {leftMain, rightMain} = BuildDiscoveryAudio[model, nSeconds, sr];

    introText =
      "The Geiger-Marsden experiment, 1909. Left channel: Thomson plum-pudding model " <>
      "prediction -- all particles deflect by less than one degree. Right channel: actual " <>
      "Rutherford nuclear model -- same beam, same geometry, but with a point nucleus. Listen " <>
      "for the large-angle events in the right channel that are completely absent in the left. " <>
      "These events led Rutherford to say it was as if artillery shells had bounced back from " <>
      "tissue paper.";

    outroText =
      "The large-angle events in the right channel -- impossible under the Thomson model -- " <>
      "led Rutherford to propose the atomic nucleus in 1911.";

    Print["  Spoken intro: ", introText];
    introBuf = BuildIntroBuffer[introText, sr];
    introBuf = If[Length[introBuf] > 0, NormalizeBuffer[introBuf, 0.95], introBuf];

    Print["  Spoken outro: ", outroText];
    outroBuf = BuildIntroBuffer[outroText, sr];
    outroBuf = If[Length[outroBuf] > 0, NormalizeBuffer[outroBuf, 0.95], outroBuf];

    pauseBuf = ConstantArray[0.0, Round[sr * 0.4]];

    finalLeft = Join[
      If[Length[introBuf] > 0, Join[introBuf, pauseBuf], {}],
      leftMain,
      If[Length[outroBuf] > 0, Join[pauseBuf, outroBuf], {}]
    ];
    finalRight = Join[
      If[Length[introBuf] > 0, Join[introBuf, pauseBuf], {}],
      rightMain,
      If[Length[outroBuf] > 0, Join[pauseBuf, outroBuf], {}]
    ];

    EnsureDir[outWav];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWav, sr];
    STEMDescribeWAV[outWav, N[Length[finalLeft]] / sr]
  ]

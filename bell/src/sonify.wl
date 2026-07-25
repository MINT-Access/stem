(* ========================================================
   bell/src/sonify.wl — Three modes, three techniques, all built on the
   same "classical vs quantum, side by side" binaural idiom
   compton/discovery and scattering/discovery already establish in
   this codebase — bell/ is a natural third member of that family,
   since Bell's own historical argument IS a classical-vs-quantum
   comparison at its core.

   `correlations`: a continuous binaural sweep of the angle difference,
     phase-accumulated exactly like compton/sweep, relativity's chirp,
     and qubit/rabi (Sin[2 Pi Accumulate[f]*dt]) — LEFT channel plays
     the classical (local hidden-variable) triangular prediction,
     RIGHT channel plays the real quantum Cos[delta] curve, matching
     compton/discovery's own left=classical/right=quantum convention
     exactly.

   `chsh`: a short narrated build-up (compton/scatter's discrete-note
     idiom) of the four individual correlation measurements, followed
     by a sustained binaural "verdict" chord — LEFT holds the fixed
     classical-bound reference pitch, RIGHT holds the actual S value's
     pitch — so the AUDIBLE GAP between the two held tones is exactly
     how far the measured S exceeds what any local theory permits.

   `measurement`: discrete per-trial outcome clicks, Alice on LEFT and
     Bob on RIGHT (StemSynthNote bursts, compton/scatter-style), for a
     short audible sample of trials, followed by a continuous
     glissando (the same BuildGlissandoBuffer technique qubit/rabi and
     qubit/measurement use) tracking the running correlation estimate
     over the FULL trial count converging toward the true E(a,b).
   ======================================================== *)


BellFrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ========================================================
   MODE 1: correlations — binaural sweep, classical (left) vs quantum (right)
   ======================================================== *)

BuildCorrelationsAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                       duration_?NumericQ, sr_Integer] :=
  Module[{nSamples, dt, tFrac, deltaDegAudio, deltaRadAudio,
          EQuantumAudio, EClassicalAudio, freqQuantum, freqClassical,
          phaseQuantum, phaseClassical, envelope, fadeSamples, leftAll, rightAll},
    nSamples = Round[duration * sr];
    dt       = 1.0 / sr;
    tFrac    = N[Range[0, nSamples - 1]] / (nSamples - 1);

    (* Recomputed at full audio-sample resolution (not interpolated from
       the model's coarse nSteps grid) -- both E formulas are cheap
       closed forms, so a smooth glissando costs nothing extra, same
       reasoning compton/sweep's BuildSweepAudio gives for its own
       full-resolution recompute. *)
    deltaDegAudio = -180.0 + 360.0 * tFrac;
    deltaRadAudio = deltaDegAudio * Pi / 180.0;

    EQuantumAudio   = Cos[deltaRadAudio];
    EClassicalAudio = ClassicalTriangularCorrelation /@ deltaRadAudio;

    freqQuantum   = Rescale[EQuantumAudio,   {-1.0, 1.0}, {freqMin, freqMax}];
    freqClassical = Rescale[EClassicalAudio, {-1.0, 1.0}, {freqMin, freqMax}];

    phaseQuantum   = N[2.0 Pi * Accumulate[freqQuantum]   * dt];
    phaseClassical = N[2.0 Pi * Accumulate[freqClassical] * dt];

    fadeSamples = Round[0.05 * sr];
    envelope    = BellFrameWindow[nSamples, fadeSamples];

    (* LEFT = classical (local hidden-variable) prediction, RIGHT =
       real quantum correlation -- matches compton/discovery's and
       scattering/discovery's own left=classical/right=quantum
       convention exactly. *)
    leftAll  = 0.7 * Sin[phaseClassical] * envelope;
    rightAll = 0.7 * Sin[phaseQuantum]   * envelope;

    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 2: chsh — narrated build-up, then a binaural "verdict" gauge
   ======================================================== *)

(* ChshBuildupNote — one short note per E(.,.) term, pitch mapped from
   the term's value in [-1,1], panned toward Alice's or Bob's "side"
   (a/a' -> pan -0.4, b/b' -> not used here, all four notes centred on
   a single shared pan since the term itself already mixes both
   settings; deliberately simple, this is a narrated arithmetic
   build-up, not a spatial trajectory). *)
ChshBuildupNote[value_?NumericQ, freqMin_?NumericQ, freqMax_?NumericQ,
                dur_?NumericQ, sr_Integer] :=
  StemSynthNote[Rescale[value, {-1.0, 1.0}, {freqMin, freqMax}], dur, 0.55, {1.0, 0.25}, 0.4, sr];

BuildChshAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
              verdictDuration_?NumericQ, sr_Integer] :=
  Module[{terms, noteDur, gapDur, gap, notes, buildupMono, buildupLR,
          classicalBoundFreq, sVerdictFreq, tVerdict, verdictClassical,
          verdictQuantum, fadeSamples, envVerdict, pauseBuf,
          leftBuild, rightBuild, leftVerdict, rightVerdict},
    terms = {model["Eab"], -model["Eabp"], model["Eapb"], model["Eapbp"]};  (* signs as they enter S *)
    noteDur = 0.35; gapDur = 0.12;
    gap = ConstantArray[0.0, Round[gapDur * sr]];

    notes = ChshBuildupNote[#, freqMin, freqMax, noteDur, sr] & /@ terms;
    buildupMono = Riffle[notes, ConstantArray[gap, Length[notes]]] // Flatten;
    {leftBuild, rightBuild} = {buildupMono, buildupMono};  (* centred, narrated build-up *)

    (* Verdict: LEFT sustains the fixed classical-bound reference pitch,
       RIGHT sustains the actual S value's pitch -- both held together
       so the GAP between the two pitches is directly how far quantum
       correlations exceed the classical ceiling. Both mapped over
       [0, quantumBound] (not [-quantumBound,quantumBound]) since S is
       positive at any sensible CHSH-violating configuration and a
       one-sided range gives more resolvable pitch separation. *)
    classicalBoundFreq = Rescale[model["classicalBound"], {0.0, model["quantumBound"]}, {freqMin, freqMax}];
    sVerdictFreq        = Rescale[Clip[model["S"], {0.0, model["quantumBound"]}],
                                  {0.0, model["quantumBound"]}, {freqMin, freqMax}];

    tVerdict = N[Range[0, Round[verdictDuration * sr] - 1]] / sr;
    verdictClassical = 0.6 * Sin[2.0 Pi * classicalBoundFreq * tVerdict];
    verdictQuantum   = 0.6 * Sin[2.0 Pi * sVerdictFreq * tVerdict];

    fadeSamples = Round[0.08 * sr];
    envVerdict  = BellFrameWindow[Length[tVerdict], fadeSamples];
    leftVerdict  = verdictClassical * envVerdict;
    rightVerdict = verdictQuantum   * envVerdict;

    pauseBuf = ConstantArray[0.0, Round[0.3 * sr]];

    {
      Join[leftBuild,  pauseBuf, leftVerdict],
      Join[rightBuild, pauseBuf, rightVerdict]
    }
  ];


(* ========================================================
   MODE 3: measurement — discrete Alice/Bob clicks, then a running-
   correlation glissando over the full trial count
   ======================================================== *)

(* Only the first $bellAudibleTrials trials are rendered as individual
   clicks -- with nTrials in the thousands (for good CSV/PNG
   statistics), playing every single trial audibly would make the WAV
   impractically long; the same "readable sample of a much larger
   dataset" convention bayes/model's FlipSequenceText caps at
   $bayesMeterMaxChars characters for the same reason. The running-
   correlation GLISSANDO, unlike the discrete clicks, still covers the
   FULL nTrials run. *)
$bellAudibleTrials = 40;

BuildMeasurementClicks[aOut_List, bOut_List, sr_Integer] :=
  Module[{n, noteDur, gapDur, plusFreq, minusFreq, leftAll, rightAll,
          leftNote, rightNote, gap},
    n = Min[Length[aOut], $bellAudibleTrials];
    noteDur = 0.12; gapDur = 0.04;
    plusFreq = 660.0; minusFreq = 330.0;  (* an octave apart -- clearly distinguishable +-1 outcomes *)
    gap = ConstantArray[0.0, Round[gapDur * sr]];

    leftAll = Flatten[Table[
      leftNote = StemSynthNote[If[aOut[[k]] === 1, plusFreq, minusFreq], noteDur, 0.5, {1.0}, 0.35, sr];
      Join[leftNote, gap],
      {k, n}
    ]];
    rightAll = Flatten[Table[
      rightNote = StemSynthNote[If[bOut[[k]] === 1, plusFreq, minusFreq], noteDur, 0.5, {1.0}, 0.35, sr];
      Join[rightNote, gap],
      {k, n}
    ]];
    {leftAll, rightAll}
  ];

(* BuildGlissandoBuffer — duplicated from qubit/src/sonify.wl's own
   shared rabi/measurement helper (per this codebase's no-shared-src/
   convention, only stem-core is shared between apps). *)
BuildGlissandoBuffer[tVals_List, yVals_List, freqMin_?NumericQ, freqMax_?NumericQ,
                     duration_?NumericQ, sr_Integer] :=
  Module[{yInterp, nSamples, dt, tAudio, yAudio, fAudio, phaseArr, fadeSamples, envelope, mono},
    yInterp = Interpolation[Transpose[{tVals, yVals}], InterpolationOrder -> 1];
    nSamples = Round[duration * sr];
    dt = 1.0 / sr;
    tAudio = Rescale[N[Range[0, nSamples - 1]], {0, nSamples - 1}, {First[tVals], Last[tVals]}];
    yAudio = Clip[yInterp /@ tAudio, {-1.0, 1.0}];
    fAudio = Rescale[yAudio, {-1.0, 1.0}, {freqMin, freqMax}];

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];
    fadeSamples = Round[0.05 * sr];
    envelope = BellFrameWindow[nSamples, fadeSamples];
    mono = 0.7 * Sin[phaseArr] * envelope;
    {mono, mono}
  ];

BuildMeasurementAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                     glissandoDuration_?NumericQ, sr_Integer] :=
  Module[{leftClicks, rightClicks, pauseBuf, n, tVals, yVals, leftGliss, rightGliss},
    {leftClicks, rightClicks} = BuildMeasurementClicks[model["aOutcomes"], model["bOutcomes"], sr];
    pauseBuf = ConstantArray[0.0, Round[0.4 * sr]];

    n = model["nTrials"];
    tVals = N[Range[1, n]];
    yVals = model["runningCorr"];
    {leftGliss, rightGliss} = BuildGlissandoBuffer[tVals, yVals, freqMin, freqMax, glissandoDuration, sr];

    {
      Join[leftClicks,  pauseBuf, leftGliss],
      Join[rightClicks, pauseBuf, rightGliss]
    }
  ];

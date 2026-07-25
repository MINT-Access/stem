(* ========================================================
   grover/src/sonify.wl — Three modes, three techniques

   `search` uses discrete per-iteration notes (compton/energy's
   per-step-frame idiom) rather than a continuous glissando — each
   Grover iteration IS a discrete oracle+diffusion query, unlike
   qubit/rabi's genuinely continuous physical oscillation, so a
   discrete note per iteration is the honest representation. Pitch
   tracks P(marked)(k) directly; a bright accent marks the true
   optimal iteration, audible against the notes continuing (and
   falling in pitch) past it.

   `compare` is a binaural "race": LEFT channel ticks through an
   average-case classical linear search (N/2 ticks), RIGHT channel
   ticks through Grover's optimal iteration count — both start
   together, so the literal DURATION difference between the two
   channels' final "found" chimes is the speedup, made audible. The
   same classical-vs-quantum binaural lineage as compton/discovery,
   scattering/discovery, and bell/correlations.

   `geometry` sonifies the literal 2D rotation as a continuous
   phase-accumulated tone (compton/sweep's technique): PAN traces
   Sin[angle] (the signed amplitude on the marked axis, oscillating
   through the full rotation), PITCH is driven by P(marked)=Sin[angle]^2
   via continuous phase accumulation — the same "P(marked) drives
   pitch" relationship search mode and qubit/rabi both use, so
   geometry mode sounds like search mode's mechanism made continuous.
   ======================================================== *)


GroverFrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ========================================================
   MODE 1: search — discrete per-iteration notes, accent at the optimum
   ======================================================== *)

BuildSearchAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                 noteDuration_?NumericQ, sr_Integer] :=
  Module[{kArr, probArr, optimalK, notes, gap, foundAccent, leftAll, rightAll},
    kArr = model["kArr"]; probArr = model["probArr"]; optimalK = model["optimalK"];
    gap = ConstantArray[0.0, Round[0.03 * sr]];

    notes = Table[
      Module[{freq, note, isOptimum, accent},
        freq = Rescale[probArr[[i]], {0.0, 1.0}, {freqMin, freqMax}];
        note = StemSynthNote[freq, noteDuration, 0.6, {1.0, 0.2}, 0.4, sr];
        isOptimum = (kArr[[i]] === optimalK);
        If[isOptimum,
          accent = StemSynthNote[freq * 2.0, noteDuration * 0.8, 0.35, {1.0, 0.4, 0.2}, 0.3, sr];
          note = PadRight[note, Max[Length[note], Length[accent]]] +
                 PadRight[accent, Max[Length[note], Length[accent]]]
        ];
        Join[note, gap]
      ],
      {i, Length[kArr]}
    ];

    leftAll = rightAll = Flatten[notes];
    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 2: compare — binaural race, classical (left) vs quantum (right)
   ======================================================== *)

CompareRaceTick[freq_?NumericQ, dur_?NumericQ, amp_?NumericQ, sr_Integer] :=
  StemSynthNote[freq, dur, amp, {1.0}, 0.5, sr];

CompareFoundChime[freq_?NumericQ, dur_?NumericQ, sr_Integer] :=
  StemSynthNote[freq, dur, 0.7, {1.0, 0.4, 0.25, 0.15}, 0.35, sr];

(* tickInterval is auto-scaled from targetClassicalDuration (not a fixed
   constant): at small N (few classical ticks) it sits at a comfortable,
   clearly-discrete spacing; at large N (many classical ticks) it
   shrinks toward a floor rather than letting the WAV grow unboundedly
   long — the classical channel becomes a denser buzz instead, itself
   an honest illustration of "so many queries needed." Without this,
   a config with a large n_items (e.g. compare_large_n's N=4096, 2048
   classical ticks) produces multi-minute audio at a fixed tick rate. *)
BuildCompareAudio[model_Association, tickFreq_?NumericQ, targetClassicalDuration_?NumericQ, sr_Integer] :=
  Module[{nClassical, nQuantum, tickInterval, tickDur, gapLen, tick, gap, unit, classicalTicks,
          quantumTicks, classicalChime, quantumChime, leftAll, rightAll, maxLen},
    nClassical = Round[model["classicalAtN"]];
    nQuantum   = model["quantumAtN"];
    tickInterval = Clip[targetClassicalDuration / Max[nClassical, 1], {0.02, 0.15}];
    tickDur = tickInterval * 0.6;
    gapLen  = Round[(tickInterval - tickDur) * sr];
    gap = ConstantArray[0.0, Max[gapLen, 0]];

    tick = CompareRaceTick[tickFreq, tickDur, 0.5, sr];
    unit = Join[tick, gap];

    classicalTicks = Flatten[ConstantArray[unit, Max[nClassical, 1]]];
    quantumTicks   = Flatten[ConstantArray[unit, Max[nQuantum, 1]]];

    classicalChime = CompareFoundChime[tickFreq * 1.5, 0.6, sr];
    quantumChime   = CompareFoundChime[tickFreq * 1.5, 0.6, sr];

    leftAll  = Join[classicalTicks, classicalChime];
    rightAll = Join[quantumTicks, quantumChime];

    (* RIGHT (quantum) finishes far sooner than LEFT (classical) — pad
       the shorter channel with silence so both channels are the same
       length, rather than truncating; the silence itself IS the
       audible speedup. *)
    maxLen = Max[Length[leftAll], Length[rightAll]];
    leftAll  = PadRight[leftAll,  maxLen];
    rightAll = PadRight[rightAll, maxLen];

    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 3: geometry — continuous rotation, phase-accumulated
   ======================================================== *)

BuildGeometryAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                   duration_?NumericQ, sr_Integer] :=
  Module[{theta, nIterations, nSamples, dt, tFrac, uAudio, angleAudio,
          ampMarkedAudio, panAudio, fAudio, phaseArr, envelope, fadeSamples,
          mono, leftAll, rightAll},
    theta = model["theta"]; nIterations = model["nIterations"];
    nSamples = Round[duration * sr];
    dt = 1.0 / sr;
    tFrac = N[Range[0, nSamples - 1]] / (nSamples - 1);

    (* Continuous extension of the discrete iteration index k -- the
       same "sonify a discrete step sequence as a smooth continuous
       rotation" choice qubit/gates makes for its own gate-to-gate
       Bloch rotations (GateRotationPath), since the underlying
       mechanism genuinely IS a constant-rate rotation. *)
    uAudio = nIterations * tFrac;
    angleAudio = (2.0 * uAudio + 1.0) * theta;
    ampMarkedAudio = Sin[angleAudio];

    panAudio = ampMarkedAudio;  (* signed -1..1: literally the rotating vector's marked-axis component *)
    fAudio   = Rescale[ampMarkedAudio^2, {0.0, 1.0}, {freqMin, freqMax}];

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];
    fadeSamples = Round[0.05 * sr];
    envelope = GroverFrameWindow[nSamples, fadeSamples];
    mono = 0.75 * Sin[phaseArr] * envelope;

    leftAll  = Sqrt[(1.0 - panAudio) / 2.0] * mono;
    rightAll = Sqrt[(1.0 + panAudio) / 2.0] * mono;

    {leftAll, rightAll}
  ];

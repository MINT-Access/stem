(* ========================================================
   quantum_tunnelling/src/sonify.wl — Audio synthesis for all three modes

   barrier: a short narrated sequence of discrete sounds, reusing
     compton/scatter's idiom directly (incoming tone, event marker,
     then the outcome) -- except the outcome SPLITS here: reflected
     and transmitted tones play SIMULTANEOUSLY (not one-or-the-other),
     since both genuinely occur in the same measurement statistics --
     this is not a coin flip on any one run, it is the same wave
     splitting into two amplitude-weighted outcomes. Both tones sound
     at the SAME pitch as the incoming tone (the particle's energy E
     is unchanged by reflection or transmission -- only which channel
     it appears in, and with what probability, differs), loudness
     scaled by Sqrt[R] and Sqrt[T] respectively (amplitude, not raw
     probability, governs perceived loudness).

   sweep / energy: continuous tones via phase accumulation --
     compton/'s BuildSweepAudio/BuildDiscoveryAudio technique
     (phaseArr = 2*Pi*Accumulate[fAudio]*dt), itself relativity/'s
     chirp technique. sweep mode's loudness is LOG-compressed
     (blackbody/'s StefanBoltzmannLoudness precedent, cited there for
     the same reason: T falls off exponentially with L, so a linear
     or even Sqrt[T] mapping would go silent almost immediately rather
     than fading gradually across the whole sweep); energy mode's
     loudness is a plain Sqrt[T] (T stays order-1 throughout most of
     that sweep, including the resonance wobble above V0, so no extra
     compression is needed there).
   ======================================================== *)


(* ── Shared: event/accent burst, pan split, fade envelope ─────────── *)

TunnellingAccentBurst[freq_?NumericQ, dur_?NumericQ, amp_?NumericQ, sr_Integer] :=
  Module[{burstLen = Max[1, Round[dur * sr]]},
    amp * Table[Sin[2.0 Pi * freq * k / sr] * Exp[-6.0 * k / burstLen], {k, 0, burstLen - 1}]
  ];

PanBuffer[mono_List, pan_?NumericQ] :=
  {Sqrt[(1.0 - pan) / 2.0] * mono, Sqrt[(1.0 + pan) / 2.0] * mono};

FrameWindowTunnelling[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ========================================================
   MODE 1: barrier — narrated single-event sequence
   ======================================================== *)

BuildBarrierAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ, sr_Integer] :=
  Module[{
    freq, noteDur, clickDur, gapDur,
    inMono, inL, inR, click, clickL, clickR,
    reflMono, reflL, reflR, transMono, transL, transR,
    outcomeLen, outcomeL, outcomeR, gap, leftAll, rightAll
  },
    freq = TunnellingPitchHz[model["E"], audioFreqMin, audioFreqMax];
    noteDur = 1.1; clickDur = 0.05; gapDur = 0.15;

    inMono = StemSynthNote[freq, noteDur, 0.7, {1.0, 0.3}, 0.35, sr];
    {inL, inR} = PanBuffer[inMono, 0.0];   (* incoming: centred, the reference tone *)

    click = TunnellingAccentBurst[1500.0, clickDur, 0.9, sr];
    {clickL, clickR} = PanBuffer[click, 0.0];

    (* Reflected: same pitch, panned back toward the incoming side
       (hard left -- "bounced back"), loudness Sqrt[R]. Transmitted:
       same pitch, panned through and beyond the barrier (hard right),
       loudness Sqrt[T]. Both are synthesised over the SAME duration
       and summed into the same stereo buffer, not sequenced, so they
       are heard as one simultaneous outcome. *)
    reflMono  = StemSynthNote[freq, noteDur, Sqrt[model["R"]], {1.0, 0.3}, 0.35, sr];
    transMono = StemSynthNote[freq, noteDur, Sqrt[model["T"]], {1.0, 0.3}, 0.35, sr];
    {reflL, reflR}   = PanBuffer[reflMono, -1.0];
    {transL, transR} = PanBuffer[transMono, 1.0];

    outcomeLen = Max[Length[reflL], Length[transL]];
    outcomeL = PadRight[reflL, outcomeLen] + PadRight[transL, outcomeLen];
    outcomeR = PadRight[reflR, outcomeLen] + PadRight[transR, outcomeLen];

    gap = ConstantArray[0.0, Round[gapDur * sr]];

    leftAll  = Join[inL, gap, clickL, gap, outcomeL];
    rightAll = Join[inR, gap, clickR, gap, outcomeR];

    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 2: sweep — continuous glissando, barrier width 0..max
   ======================================================== *)

BuildSweepAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
               duration_?NumericQ, sr_Integer] :=
  Module[{nSamples, dt, tFrac, LAudio, TAudio, fAudio, phaseArr,
          logTMax, logTMin, loudness, envelope, fadeSamples, mono, leftAll, rightAll},
    nSamples = Round[duration * sr];
    dt       = 1.0 / sr;
    tFrac    = N[Range[0, nSamples - 1]] / (nSamples - 1);

    (* Recompute T at full audio-sample resolution (not just the
       model's nSteps grid) -- a smooth fade needs a continuous
       instantaneous amplitude, not an interpolation of a coarse grid. *)
    LAudio = model["widthMin"] + (model["widthMax"] - model["widthMin"]) * tFrac;
    TAudio = TransmissionCoefficient[model["E"], model["V0"], #, model["mc2"]] & /@ LAudio;
    fAudio = audioFreqMin + (audioFreqMax - audioFreqMin) * tFrac;   (* pitch tracks L linearly *)

    (* Loudness: log(T) normalised between this sweep's own endpoint
       values (loudest at widthMin, quietest at widthMax) onto
       [floor,1] -- blackbody/'s StefanBoltzmannLoudness technique,
       reused here because T's exponential falloff with L is the same
       kind of "many-orders-of-magnitude range that needs log
       compression to stay perceptible across a whole sweep" problem
       blackbody's own Stefan-Boltzmann T^4 growth posed. *)
    logTMax = Log[First[TAudio]]; logTMin = Log[Last[TAudio]];
    loudness = 0.05 + 0.95 * Clip[(Log[TAudio] - logTMin) / (logTMax - logTMin), {0.0, 1.0}];

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];
    fadeSamples = Round[0.05 * sr];
    envelope    = FrameWindowTunnelling[nSamples, fadeSamples];
    mono        = 0.8 * loudness * Sin[phaseArr] * envelope;

    leftAll  = mono;
    rightAll = mono;
    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 3: energy — continuous glissando, particle energy sweep
   ======================================================== *)

BuildEnergyAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                 duration_?NumericQ, sr_Integer] :=
  Module[{nSamples, dt, tFrac, EAudio, TAudio, fAudio, phaseArr,
          loudness, envelope, fadeSamples, mono, barrierFrac, barrierSample,
          accent, accentLen, leftAll, rightAll},
    nSamples = Round[duration * sr];
    dt       = 1.0 / sr;
    tFrac    = N[Range[0, nSamples - 1]] / (nSamples - 1);

    EAudio = model["EMin"] + (model["EMax"] - model["EMin"]) * tFrac;
    TAudio = TransmissionCoefficient[#, model["V0"], model["L"], model["mc2"]] & /@ EAudio;
    fAudio = audioFreqMin + (audioFreqMax - audioFreqMin) * tFrac;   (* pitch tracks E linearly *)

    (* Loudness: plain Sqrt[T] -- T stays order-1 through most of this
       sweep (including the above-barrier resonance wobble), so no
       additional log compression is needed here the way sweep mode's
       exponentially-collapsing T needs it. *)
    loudness = Sqrt[TAudio];

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];
    fadeSamples = Round[0.05 * sr];
    envelope    = FrameWindowTunnelling[nSamples, fadeSamples];
    mono        = 0.8 * loudness * Sin[phaseArr] * envelope;

    (* Accent burst at the sweep step nearest E=V0, placed at the
       corresponding fraction of total duration. *)
    barrierFrac   = (model["barrierIdx"] - 1.0) / (model["nSteps"] - 1.0);
    barrierSample = Max[1, Round[barrierFrac * nSamples]];
    accent    = TunnellingAccentBurst[1800.0, 0.08, 0.6, sr];
    accentLen = Min[Length[accent], nSamples - barrierSample + 1];
    If[accentLen > 0,
      mono[[barrierSample ;; barrierSample + accentLen - 1]] += accent[[1 ;; accentLen]]
    ];

    leftAll  = mono;
    rightAll = mono;
    {leftAll, rightAll}
  ];

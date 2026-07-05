(* ========================================================
   bayes/src/sonify.wl — Sonifying Bayesian updating

   coin/gaussian modes: two mixed layers, matching the build spec's
   "spectral posterior" + "summary trajectory" description:

     1. Primary — additive spectral synthesis of the posterior density
        itself (one frame per flip/observation, nBins simultaneous sine
        partials weighted by the posterior density at each bin's
        parameter value). This is the same SynthesizeAdditiveFrame/
        MBSpectrumBins-style primitive thermo/src/sonify.wl uses for
        the Maxwell-Boltzmann distribution — duplicated rather than
        shared, since apps do not import each other's src/ files (only
        stem-core is shared).

     2. Secondary — a discrete pentatonic note per flip/observation,
        mixed 12 dB below the primary layer (summary_layer_gain in
        config.json). The build spec asks for this layer to use
        stem-core's SonifyTrajectory pipeline; it is instead built with
        the discrete-note/ScaleLookup primitives dynamical/src/sonify.wl
        established (StemSynthNote + ScaleLookup), because
        SonifyTrajectory's SpatialLayer always linearly *rescales* pan
        and pitch to the trajectory's own observed min/max — it cannot
        express "pitch quantised to a pentatonic scale" (ScaleLookup)
        or "pan mapped to an absolute [0,1] domain regardless of how
        far the run's mode/mean actually wandered", both of which the
        spec explicitly calls for. See AGENTS.md for the full rationale
        (same category of deviation dynamical/AGENTS.md documents for
        its own sonify.wl).

   model mode has no spectral layer (there is no distribution to
   render — theta1/theta2 are two point hypotheses, not a density) so
   its single continuous layer is built directly: a phase-accumulated
   carrier (the same Sin[2 Pi Accumulate[pitch]/sr] formula stem-core's
   MixLayers uses) driven by absolute (non-autoscaled) pan/pitch/volume
   curves derived from log10(K). Built bespoke for the same
   fixed-domain-mapping reason as above.
   ======================================================== *)


(* ── Shared additive-frame primitive (coin/gaussian spectral layer) ──
   Identical in structure to thermo/src/sonify.wl's FrameWindow /
   SynthesizeAdditiveFrame — see that file's header for the rationale
   (short linear fade prevents clicks at frame boundaries when phase
   resets to zero between independently-synthesised frames). *)

FrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];

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
  ];

(* OverlayBurst — mixes a centred short accent tone into leftBuf/
   rightBuf at startTimeSec. Same pattern as thermo's
   AddEquilibriumAccent / dynamical's OverlayEvent. *)
OverlayBurst[leftBuf_List, rightBuf_List, freq_?NumericQ, dur_?NumericQ,
            amp_?NumericQ, startTimeSec_?NumericQ, sr_Integer] :=
  Module[{burst, start, len, n = Length[leftBuf], lb = leftBuf, rb = rightBuf, burstLen},
    burstLen = Round[dur * sr];
    burst = amp * Table[Sin[2.0 Pi freq k / sr] * Exp[-4.0 k / burstLen], {k, 0, burstLen - 1}];
    start = Clip[Round[startTimeSec * sr] + 1, {1, n}];
    len   = Min[Length[burst], n - start + 1];
    If[len > 0,
      lb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]];
      rb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]]
    ];
    {lb, rb}
  ];

$bayesRootHz = 130.81; (* C3 — consistent with dynamical's pentatonic root *)

(* SecondaryNote — one pentatonic note for the summary-trajectory
   layer. valueFrac/panFrac in [0,1] (already normalised by the
   caller against the mode's fixed parameter domain); amp in [0,1]
   before the -12dB (or configured) layer gain is applied by the
   caller. *)
SecondaryNote[valueFrac_?NumericQ, panFrac_?NumericQ, amp_?NumericQ,
             noteDuration_?NumericQ, sr_Integer] :=
  Module[{scale = $StemScales["MinorPentatonic"], freq, pan, mono},
    freq = ScaleLookup[Clip[valueFrac, {0.0, 1.0}], 0.0, 1.0, scale, $bayesRootHz];
    pan  = Clip[Rescale[panFrac, {0.0, 1.0}, {-1.0, 1.0}], {-1.0, 1.0}];
    mono = StemSynthNote[freq, noteDuration, amp, {1.0, 0.3}, 0.4, sr];
    <| "freq" -> freq, "pan" -> pan, "mono" -> mono |>
  ];

(* MixSecondaryNotes — places one SecondaryNote per step into
   pre-allocated stereo buffers of length nSamplesTotal, scaled by
   layerGain (e.g. 10^(-12/20) for the spec's -12dB secondary layer). *)
MixSecondaryNotes[valueFracs_List, panFracs_List, amps_List, stepStartTimes_List,
                  noteDuration_?NumericQ, layerGain_?NumericQ, nSamplesTotal_Integer,
                  sr_Integer] :=
  Module[{leftBuf, rightBuf, n = Length[valueFracs], note, start, len},
    leftBuf  = ConstantArray[0.0, nSamplesTotal];
    rightBuf = ConstantArray[0.0, nSamplesTotal];
    Do[
      note  = SecondaryNote[valueFracs[[k]], panFracs[[k]], amps[[k]], noteDuration, sr];
      start = Clip[Round[stepStartTimes[[k]] * sr] + 1, {1, nSamplesTotal}];
      len   = Min[Length[note["mono"]], nSamplesTotal - start + 1];
      If[len > 0,
        leftBuf[[start ;; start + len - 1]]  +=
          layerGain * Sqrt[(1.0 - note["pan"]) / 2.0] * note["mono"][[1 ;; len]];
        rightBuf[[start ;; start + len - 1]] +=
          layerGain * Sqrt[(1.0 + note["pan"]) / 2.0] * note["mono"][[1 ;; len]]
      ],
      {k, n}
    ];
    {leftBuf, rightBuf}
  ];


(* ── Coin mode ────────────────────────────────────────────────────── *)

(* ThetaSpectrumBins
   Discretises Beta(alpha,beta) over nBins points strictly inside
   (0,1) (never exactly 0 or 1, so the density is always finite even
   at alpha=beta=1) mapped logarithmically onto [freqMin,freqMax] —
   same log-frequency convention as thermo's MBSpectrumBins. *)
ThetaSpectrumBins[alpha_?NumericQ, beta_?NumericQ, nBins_Integer,
                  freqMin_?NumericQ, freqMax_?NumericQ] :=
  Module[{thetaBins, densities, maxDensity, freqs, amps},
    thetaBins  = N[Range[1, nBins]] / (nBins + 1.0);
    densities  = BetaDensity[#, alpha, beta] & /@ thetaBins;
    maxDensity = Max[densities];
    If[maxDensity <= 0.0, maxDensity = 1.0];
    freqs = freqMin * (freqMax / freqMin)^thetaBins;
    amps  = densities / maxDensity;
    <| "thetaBins" -> thetaBins, "freqs" -> freqs, "amps" -> amps |>
  ];

BuildCoinAudio[seq_List, nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
              frameDuration_?NumericQ, summaryGainDb_?NumericQ, sr_Integer] :=
  Module[{n = Length[seq], frames, leftAll, rightAll, priorVariance,
          valueFracs, panFracs, amps, stepStartTimes, secLeft, secRight,
          layerGain, convergenceFlipIdx},

    (* ── Primary: spectral posterior, one frame per flip ── *)
    frames = Table[
      Module[{spec, ampsBins, pans, l, r},
        spec     = ThetaSpectrumBins[seq[[k]]["alpha"], seq[[k]]["beta"], nBins, freqMin, freqMax];
        ampsBins = spec["amps"] / Sqrt[N[nBins]];
        pans     = ConstantArray[0.0, nBins];
        {l, r} = SynthesizeAdditiveFrame[spec["freqs"], ampsBins, pans, frameDuration, sr]
      ],
      {k, n}
    ];
    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    (* ── EventLayer markers ──
       flip 10: "first meaningful update" (440 Hz)
       first flip where posterior variance < 0.01: "convergence milestone" (528 Hz)
       final flip: "inference complete" (660 Hz) *)
    If[n >= 10,
      {leftAll, rightAll} = OverlayBurst[leftAll, rightAll, 440.0, 0.15, 0.6,
        (10 - 1) * frameDuration, sr]
    ];
    convergenceFlipIdx = SelectFirst[Range[n], seq[[#]]["variance"] < 0.01 &, Missing["NotFound"]];
    If[IntegerQ[convergenceFlipIdx],
      {leftAll, rightAll} = OverlayBurst[leftAll, rightAll, 528.0, 0.15, 0.6,
        (convergenceFlipIdx - 1) * frameDuration, sr]
    ];
    {leftAll, rightAll} = OverlayBurst[leftAll, rightAll, 660.0, 0.2, 0.7,
      (n - 1) * frameDuration, sr];

    (* ── Secondary: pentatonic summary-trajectory layer, -12dB ── *)
    priorVariance  = BetaVariance[1.0, 1.0];
    valueFracs     = seq[[All, "mean"]];                      (* pitch <- posterior mean *)
    panFracs       = seq[[All, "mode"]];                      (* pan   <- posterior mode *)
    amps           = Clip[0.15 + 0.75 * (seq[[All, "variance"]] / priorVariance),
                          {0.15, 0.9}];                        (* volume <- variance *)
    stepStartTimes = Table[(k - 1) * frameDuration, {k, n}];
    layerGain      = 10.0^(summaryGainDb / 20.0);
    {secLeft, secRight} = MixSecondaryNotes[valueFracs, panFracs, amps, stepStartTimes,
      0.6 * frameDuration, layerGain, Length[leftAll], sr];

    <|
      "left" -> leftAll + secLeft, "right" -> rightAll + secRight, "sr" -> sr,
      "convergenceFlipIdx" -> convergenceFlipIdx, "n" -> n, "frameDuration" -> frameDuration
    |>
  ];


(* ── Gaussian mode ────────────────────────────────────────────────── *)

(* MuSpectrumBins
   Discretises N(postMean,postVar) density over nBins points spanning
   the fixed display range [muLo,muHi] (fixed, not re-derived from the
   current posterior, so the frequency->mu mapping stays consistent
   across the whole run and a pitch shift is actually audible as
   belief moves within that fixed range). *)
MuSpectrumBins[postMean_?NumericQ, postVar_?NumericQ, muLo_?NumericQ, muHi_?NumericQ,
              nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ] :=
  Module[{muBins, fracs, densities, maxDensity, freqs, amps},
    muBins     = N[Subdivide[muLo, muHi, nBins - 1]];
    fracs      = Clip[(muBins - muLo) / (muHi - muLo), {0.0, 1.0}];
    (* Quiet: far-tail density at a wide, fixed muLo/muHi range underflows
       to (correctly) 0 once the posterior narrows — General::munfl is
       expected here, not a sign of a computation error. *)
    densities  = Quiet[PDF[NormalDistribution[postMean, Sqrt[postVar]], #] & /@ muBins,
      General::munfl];
    maxDensity = Max[densities];
    If[maxDensity <= 0.0, maxDensity = 1.0];
    freqs = freqMin * (freqMax / freqMin)^fracs;
    amps  = densities / maxDensity;
    <| "muBins" -> muBins, "freqs" -> freqs, "amps" -> amps |>
  ];

BuildGaussianAudio[seq_List, muLo_?NumericQ, muHi_?NumericQ, muTrue_?NumericQ,
                   priorVariance_?NumericQ, nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                   frameDuration_?NumericQ, summaryGainDb_?NumericQ, sr_Integer] :=
  Module[{n = Length[seq], frames, leftAll, rightAll,
          valueFracs, panFracs, amps, stepStartTimes, secLeft, secRight,
          layerGain, convergenceObsIdx},

    (* ── Primary: spectral posterior, one frame per observation ──
       Quiet[..., General::munfl]: as the posterior narrows in later
       observations, far-tail density values over the fixed [muLo,muHi]
       display range legitimately underflow toward 0 — expected
       behaviour (that bin simply gets ~0 amplitude), not an error. *)
    frames = Quiet[Table[
      Module[{spec, ampsBins, pans, l, r},
        spec     = MuSpectrumBins[seq[[k]]["mean"], seq[[k]]["variance"], muLo, muHi,
                                  nBins, freqMin, freqMax];
        ampsBins = spec["amps"] / Sqrt[N[nBins]];
        pans     = ConstantArray[0.0, nBins];
        {l, r} = SynthesizeAdditiveFrame[spec["freqs"], ampsBins, pans, frameDuration, sr]
      ],
      {k, n}],
      General::munfl];
    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    (* ── EventLayer marker: posterior mean within 0.1 of muTrue ── *)
    convergenceObsIdx = SelectFirst[Range[n], Abs[seq[[#]]["mean"] - muTrue] < 0.1 &,
      Missing["NotFound"]];
    If[IntegerQ[convergenceObsIdx],
      {leftAll, rightAll} = OverlayBurst[leftAll, rightAll, 528.0, 0.15, 0.6,
        (convergenceObsIdx - 1) * frameDuration, sr]
    ];

    (* ── Secondary: pentatonic summary-trajectory layer, -12dB ── *)
    valueFracs     = Clip[(seq[[All, "mean"]] - muLo) / (muHi - muLo), {0.0, 1.0}];
    panFracs       = valueFracs;
    amps           = Clip[0.15 + 0.75 * (seq[[All, "variance"]] / priorVariance),
                          {0.15, 0.9}];
    stepStartTimes = Table[(k - 1) * frameDuration, {k, n}];
    layerGain      = 10.0^(summaryGainDb / 20.0);
    {secLeft, secRight} = MixSecondaryNotes[valueFracs, panFracs, amps, stepStartTimes,
      0.6 * frameDuration, layerGain, Length[leftAll], sr];

    <|
      "left" -> leftAll + secLeft, "right" -> rightAll + secRight, "sr" -> sr,
      "convergenceObsIdx" -> convergenceObsIdx, "n" -> n, "frameDuration" -> frameDuration
    |>
  ];


(* ── Model mode ───────────────────────────────────────────────────── *)

(* BuildModelAudio
   Single continuous layer: pan = tanh(log10 K) (K>>1 -> H1 -> left,
   K<<1 -> H2 -> right); pitch = |log10 K| mapped to [freqMin,freqMax]
   (saturating at |log10K|=3, well past the "very strong evidence"
   band); volume = |change in log10 K| this flip, so informative flips
   are louder than uninformative ones. Built as a phase-accumulated
   carrier (Sin[2 Pi Accumulate[pitch]/sr], the same formula stem-core's
   MixLayers uses) over spline-interpolated per-sample control curves —
   see file header for why this is bespoke rather than a literal
   SonifyTrajectory/SpatialLayer call. *)
BuildModelAudio[modelSeq_List, theta1_?NumericQ, theta2_?NumericQ,
                frameDuration_?NumericQ, freqMin_?NumericQ, freqMax_?NumericQ,
                sr_Integer] :=
  Module[{n = Length[modelSeq], logK, times, pan, pitchFrac, pitchHz,
          deltaLogK, deltaMax, ampRaw, nSamplesTotal, sampleTimes,
          panInterp, pitchInterp, ampInterp, carrier, mono, leftBuf, rightBuf,
          crossOneIdx, crossTwoIdx},

    logK  = Prepend[modelSeq[[All, "log_bayes_factor"]], 0.0];  (* index 0: no data, K=1 *)
    times = N[Range[0, n]] * frameDuration;

    (* pan sign: stem-core's stereo convention is -1=left, +1=right (see
       sonification.wl's SpatialLayer). The spec's convention is
       K>>1/H1(fair) -> hard LEFT, K<<1/H2(biased) -> hard RIGHT, i.e.
       positive logK -> left (negative pan) and negative logK -> right
       (positive pan) -- the negation here is required to match that,
       not a sign typo. *)
    pan       = -Tanh[logK];
    pitchFrac = Clip[Abs[logK] / 3.0, {0.0, 1.0}];
    pitchHz   = freqMin + (freqMax - freqMin) * pitchFrac;

    deltaLogK = Prepend[Abs[Differences[logK]], 0.0];
    deltaMax  = Max[deltaLogK];
    If[deltaMax <= 0.0, deltaMax = 1.0];
    ampRaw    = Clip[0.2 + 0.8 * (deltaLogK / deltaMax), {0.2, 1.0}];

    nSamplesTotal = Round[Last[times] * sr] + 1;
    sampleTimes   = N[Range[0, nSamplesTotal - 1]] / sr;

    panInterp   = Clip[Interpolation[Transpose[{times, pan}],       Method -> "Spline"][sampleTimes],
                        {-1.0, 1.0}];
    pitchInterp = Clip[Interpolation[Transpose[{times, pitchHz}],   Method -> "Spline"][sampleTimes],
                        {freqMin, freqMax}];
    ampInterp   = Clip[Interpolation[Transpose[{times, ampRaw}],    Method -> "Spline"][sampleTimes],
                        {0.2, 1.0}];

    carrier = Sin[2.0 Pi Accumulate[pitchInterp] / sr];
    mono    = ampInterp * carrier;
    leftBuf  = mono * Sqrt[(1.0 - panInterp) / 2.0];
    rightBuf = mono * Sqrt[(1.0 + panInterp) / 2.0];

    (* ── EventLayer markers: |log10K| crossing 1 (K=10) and 2 (K=100) ── *)
    crossOneIdx = SelectFirst[Range[n], Abs[modelSeq[[#]]["log_bayes_factor"]] > 1.0 &,
      Missing["NotFound"]];
    crossTwoIdx = SelectFirst[Range[n], Abs[modelSeq[[#]]["log_bayes_factor"]] > 2.0 &,
      Missing["NotFound"]];
    If[IntegerQ[crossOneIdx],
      {leftBuf, rightBuf} = OverlayBurst[leftBuf, rightBuf, 440.0, 0.12, 0.5,
        crossOneIdx * frameDuration, sr]
    ];
    If[IntegerQ[crossTwoIdx],
      {leftBuf, rightBuf} = OverlayBurst[leftBuf, rightBuf, 660.0, 0.15, 0.6,
        crossTwoIdx * frameDuration, sr]
    ];

    <|
      "left" -> leftBuf, "right" -> rightBuf, "sr" -> sr,
      "logK" -> Rest[logK], "pan" -> Rest[pan], "pitchHz" -> Rest[pitchHz],
      "crossOneIdx" -> crossOneIdx, "crossTwoIdx" -> crossTwoIdx, "n" -> n
    |>
  ];

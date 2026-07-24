(* ========================================================
   clt/src/sonify.wl — Additive spectral synthesis for the CLT

   All three modes reuse the same additive-synthesis primitive
   thermo/src/sonify.wl's Maxwell-Boltzmann sweep and bayes/src/
   sonify.wl's posterior narrowing both use: discretise a density over
   nBins points on a FIXED domain, weight nBins simultaneous sine
   partials by that density, so the frame's spectral envelope literally
   IS the distribution at that step -- one frame per N, concatenated
   into a sweep. Duplicated here (not shared) since apps do not import
   each other's src/ files.

   sweep: one frame per N, RAW (unstandardized) mean, domain fixed at
     N=1's spread (RawMeanDisplayDomain) -- narrows AND symmetrises.
   compare: TWO simultaneous per-N frames, one per channel/source,
     STANDARDIZED mean, domain fixed at +/-4 sigma (StandardizedDisplayDomain,
     source-independent) -- symmetrises only, by construction; see the
     explicit channel-assignment comment on BuildCompareAudio below,
     the same convention bayes/'s pan-sign comments follow.
   dice: one frame per N, raw SUM (not mean), domain fixed at the
     WIDEST case N=n_max (DiceDisplayDomain) since the sum's spread
     GROWS with N -- the opposite asymmetry from sweep mode.
   ======================================================== *)


(* ── Shared additive-frame primitive (identical in structure to
   thermo/bayes's FrameWindow/SynthesizeAdditiveFrame) ────────────── *)

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


(* ── Histogram-based spectrum bins, the shared "one distribution ->
   nBins simultaneous partials" primitive all three modes use ──────
   Bin centres are used (not edges), matching bayes/'s ThetaSpectrumBins
   convention of sampling strictly-interior representative points.
   Amplitudes are peak-normalised (loudest bin = 1.0 before the
   1/Sqrt[nBins] additive-synthesis scaling), matching thermo/bayes. *)
HistogramSpectrumBins[samples_List, domainLo_?NumericQ, domainHi_?NumericQ, nBins_Integer,
                      audioFreqMin_?NumericQ, audioFreqMax_?NumericQ] :=
  Module[{binWidth, clippedSamples, counts, densities, maxDensity, amps, fracs, freqs, binCenters},
    binWidth   = (domainHi - domainLo) / N[nBins];
    (* BinCounts[data, {lo,hi,dx}] bins are HALF-OPEN even for the very
       last bin -- a sample exactly AT domainHi is silently dropped,
       not counted in the final bin as its visual position would
       suggest (verified directly: BinCounts[{1.0},{0.,1.,0.025}] is
       all zeros). This matters in practice, not just in principle: the
       "bernoulli" source's N=1 sample mean is EXACTLY 0.0 or 1.0 (a
       coin flip), so roughly p*nSamples worth of "heads" samples --
       the entire right-hand spike of the N=1 distribution -- were
       silently discarded before this fix, undercounting the total by
       exactly that fraction (caught by rendering sweep mode's
       bernoulli-source PNG and noticing the N=1 panel showed ONLY a
       spike at 0, with no second spike at 1 at all, rather than
       reading the code). Any value at or above domainHi is nudged a
       negligible amount inside the range before binning -- well below
       binWidth, so it still lands in the intended last bin, not a
       fabricated new one. *)
    clippedSamples = Map[If[# >= domainHi, domainHi - binWidth * 0.0001, #] &, samples];
    counts     = BinCounts[clippedSamples, {domainLo, domainHi, binWidth}];
    (* Defensive: pad/clip to exactly nBins regardless, in case of any
       other edge-count mismatch downstream Transpose/MapThread assume. *)
    counts     = PadRight[counts[[1 ;; Min[Length[counts], nBins]]], nBins, 0];
    densities  = N[counts] / Length[samples] / binWidth;
    maxDensity = Max[densities];
    If[maxDensity <= 0.0, maxDensity = 1.0];
    amps       = densities / maxDensity;
    binCenters = Table[domainLo + (i - 0.5) * binWidth, {i, nBins}];
    fracs      = Clip[(binCenters - domainLo) / (domainHi - domainLo), {0.0, 1.0}];
    freqs      = audioFreqMin * (audioFreqMax / audioFreqMin)^fracs;
    <| "binCenters" -> binCenters, "densities" -> densities, "amps" -> amps, "freqs" -> freqs |>
  ];


(* ========================================================
   MODE 1: sweep — raw sample mean, N=1..nMax
   ======================================================== *)

BuildSweepAudio[sourceName_String, p_?NumericQ, nMax_Integer, nSamples_Integer,
               nBins_Integer, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
               frameDuration_?NumericQ, seed_Integer, sr_Integer] :=
  Module[{domain, domainLo, domainHi, frames, leftAll, rightAll,
          empMeans, empVars},
    domain = RawMeanDisplayDomain[sourceName, p];
    {domainLo, domainHi} = domain;

    frames = Table[
      Module[{samples, spec, ampsBins, pans, l, r},
        samples  = SampleXbarN[sourceName, p, nStep, nSamples, seed + nStep];
        spec     = HistogramSpectrumBins[samples, domainLo, domainHi, nBins, audioFreqMin, audioFreqMax];
        ampsBins = spec["amps"] / Sqrt[N[nBins]];
        pans     = ConstantArray[0.0, nBins];
        {l, r}   = SynthesizeAdditiveFrame[spec["freqs"], ampsBins, pans, frameDuration, sr];
        {l, r, Mean[samples], Variance[samples]}
      ],
      {nStep, 1, nMax}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    empMeans = frames[[All, 3]];
    empVars  = frames[[All, 4]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "nMax" -> nMax, "domainLo" -> domainLo, "domainHi" -> domainHi,
      "empMeans" -> empMeans, "empVars" -> empVars, "frameDuration" -> frameDuration
    |>
  ];


(* ========================================================
   MODE 2: compare — standardized mean, two sources binaurally
   ======================================================== *)

(* BuildCompareAudio — CHANNEL ASSIGNMENT (read this before touching
   sonify.wl/animate.wl/output.wl for this mode): sourceLeft's
   standardized-mean spectrum is panned HARD LEFT (pan=-1) and
   sourceRight's is panned HARD RIGHT (pan=+1) -- a literal, fixed
   pan constant per source, not a computed/derived value, so there is
   no sign-convention ambiguity for a formula error to hide in (the
   same "fixed literal, not a derived quantity" reasoning
   quantum_tunnelling/AGENTS.md design decision 7 gives for its own
   reflected/transmitted pan assignment). animate.wl's two-panel
   layout and output.wl's CSV column order both independently use
   this SAME left=sourceLeft/right=sourceRight assignment -- verified
   by inspection to agree across all three files, not assumed
   (compton/AGENTS.md design decision 8 is the cautionary tale for
   why this needs saying explicitly and checking, not just saying). *)
BuildCompareAudio[sourceLeft_String, pLeft_?NumericQ, sourceRight_String, pRight_?NumericQ,
                  nMax_Integer, nSamples_Integer, nBins_Integer,
                  audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                  frameDuration_?NumericQ, seed_Integer, sr_Integer] :=
  Module[{domainLo, domainHi, frames, leftAll, rightAll,
          kurtLeft, kurtRight},
    {domainLo, domainHi} = StandardizedDisplayDomain[];

    frames = Table[
      Module[{
        samplesL, muL, sigL, stdL, specL, ampsL, panL, lL, rL,
        samplesR, muR, sigR, stdR, specR, ampsR, panR, lR, rR
      },
        muL  = SourceMean[sourceLeft, pLeft];   sigL = Sqrt[SourceVariance[sourceLeft, pLeft]];
        muR  = SourceMean[sourceRight, pRight]; sigR = Sqrt[SourceVariance[sourceRight, pRight]];

        samplesL = SampleXbarN[sourceLeft, pLeft, nStep, nSamples, seed + nStep];
        stdL     = (samplesL - muL) / (sigL / Sqrt[N[nStep]]);
        specL    = HistogramSpectrumBins[stdL, domainLo, domainHi, nBins, audioFreqMin, audioFreqMax];
        ampsL    = specL["amps"] / Sqrt[N[nBins]];
        panL     = ConstantArray[-1.0, nBins];   (* sourceLeft: hard left, see file header *)
        {lL, rL} = SynthesizeAdditiveFrame[specL["freqs"], ampsL, panL, frameDuration, sr];

        samplesR = SampleXbarN[sourceRight, pRight, nStep, nSamples, seed + 10000 + nStep];
        stdR     = (samplesR - muR) / (sigR / Sqrt[N[nStep]]);
        specR    = HistogramSpectrumBins[stdR, domainLo, domainHi, nBins, audioFreqMin, audioFreqMax];
        ampsR    = specR["amps"] / Sqrt[N[nBins]];
        panR     = ConstantArray[1.0, nBins];    (* sourceRight: hard right, see file header *)
        {lR, rR} = SynthesizeAdditiveFrame[specR["freqs"], ampsR, panR, frameDuration, sr];

        {lL + lR, rL + rR, Kurtosis[stdL] - 3.0, Kurtosis[stdR] - 3.0}
      ],
      {nStep, 1, nMax}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    kurtLeft  = frames[[All, 3]];
    kurtRight = frames[[All, 4]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "nMax" -> nMax, "domainLo" -> domainLo, "domainHi" -> domainHi,
      "kurtLeft" -> kurtLeft, "kurtRight" -> kurtRight, "frameDuration" -> frameDuration
    |>
  ];


(* ========================================================
   MODE 3: dice — raw sum, N=1..nMax (shape smoothing, not narrowing)
   ======================================================== *)

BuildDiceAudio[nMax_Integer, nSamples_Integer, nBins_Integer,
              audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
              frameDuration_?NumericQ, seed_Integer, sr_Integer] :=
  Module[{domainLo, domainHi, frames, leftAll, rightAll, empMeans, empVars},
    {domainLo, domainHi} = DiceDisplayDomain[nMax];

    frames = Table[
      Module[{sums, spec, ampsBins, pans, l, r},
        sums     = SampleDiceSumN[nStep, nSamples, seed + nStep];
        spec     = HistogramSpectrumBins[sums, domainLo, domainHi, nBins, audioFreqMin, audioFreqMax];
        ampsBins = spec["amps"] / Sqrt[N[nBins]];
        pans     = ConstantArray[0.0, nBins];
        {l, r}   = SynthesizeAdditiveFrame[spec["freqs"], ampsBins, pans, frameDuration, sr];
        {l, r, Mean[sums], Variance[sums]}
      ],
      {nStep, 1, nMax}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    empMeans = frames[[All, 3]];
    empVars  = frames[[All, 4]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "nMax" -> nMax, "domainLo" -> domainLo, "domainHi" -> domainHi,
      "empMeans" -> empMeans, "empVars" -> empVars, "frameDuration" -> frameDuration
    |>
  ];

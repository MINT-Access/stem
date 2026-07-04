(* ========================================================
   montecarlo/src/sonify.wl — Two-layer Ising sonification

   Layer 1 — Global observables, via stem-core's actual SpatialLayer/
   MotionLayer continuous-carrier machinery (the "SonifyTrajectory
   pipeline", minus its generic EventLayer — see below):
     t     — sweep index, rescaled to the overall audio duration
     x     — energy per spin e(t)              [pan axis, default]
     y     — |M(t)|                             [pitch axis, default]
     z     — 0 (unused)
     speed — |M(t) - M(t-1)|                    [volume]
   Custom domain events (T_c crossing, magnetisation sign flip,
   susceptibility peak) need frequencies/durations/detection rules
   that don't match stem-core's generic EventLayer (fixed at 880 Hz
   "apex" / 440 Hz "crossing", detected on hardcoded columns) — so,
   following the precedent set in cellular/'s original design, this
   file calls SpatialLayer + MotionLayer directly and mixes in a
   custom event buffer via MixLayers, rather than calling
   SonifyTrajectory (which would force the generic EventLayer).

   Layer 2 — Spatial Hilbert scan, one snapshot per sonified sweep.
   0.001 s/pixel (the spec default) is far shorter than one wave cycle
   even at the low pitch (C3 = 130.8 Hz has a ~7.6 ms period) — a
   literal one-tone-per-pixel synthesis would just be an inaudible
   click train regardless of the underlying spin pattern. Instead,
   consecutive equal-spin pixels in Hilbert order are grouped into a
   single held tone (exactly cellular/'s run-length technique): a
   50-pixel aligned domain becomes one 50 ms tone; a checkerboard-like
   disordered region becomes a rapid alternation of ~1 ms blips. This
   is also the only way "long runs = large domains" is actually
   audible as anything.

   Both layers are subsampled to at most $maxSpatialSnapshots sweeps
   (same reasoning as dynamical/'s $sweepNotesPerStep: a literal
   one-snapshot-per-sweep mapping at defaults would run into
   thousands of seconds; see AGENTS.md).
   ======================================================== *)


$maxSpatialSnapshots = 60;

$hilbertC3 = 130.8128;   (* spin -1 *)
$hilbertC5 = 523.2511;   (* spin +1 *)


(* ── Layer 1: global-observable trajectory ───────────────────────── *)

(* BuildObservableTrajectory
   sweepIdx/M/E are parallel lists (one entry per recorded sweep).
   Returns the standard {t, x, y, z, speed} matrix, t rescaled to
   [0, totalDuration]. *)
BuildObservableTrajectory[sweepIdx_List, MVals_List, EVals_List, totalDuration_?NumericQ] :=
  Module[{n = Length[sweepIdx], tVals, xVals, yVals, zVals, speedVals},
    tVals    = N[Rescale[sweepIdx, {First[sweepIdx], Last[sweepIdx]}, {0.0, totalDuration}]];
    xVals    = N[EVals];
    yVals    = N[Abs[MVals]];
    zVals    = ConstantArray[0.0, n];
    speedVals = Prepend[Abs[Differences[MVals]], 0.0];
    Transpose[{tVals, xVals, yVals, zVals, speedVals}]
  ];

(* ── Custom domain events (Layer 1 accents) ──────────────────────── *)

(* DetectTcCrossing — sweep mode only: the sweep-index position where
   T first crosses T_c (sign change of T - T_c between consecutive
   recorded sweeps). Returns {} if the sweep never spans T_c. *)
DetectTcCrossing[TVals_List, Tc_?NumericQ] :=
  Module[{diffs},
    diffs = (TVals[[#]] - Tc) * (TVals[[# + 1]] - Tc) & /@ Range[Length[TVals] - 1];
    With[{idx = FirstPosition[diffs, d_ /; d < 0, {}]},
      If[idx === {}, {}, {idx[[1]] + 1}]
    ]
  ];

(* DetectSignFlips — every sweep index where M changes sign relative
   to the previous recorded sweep (a domain-reversal event). *)
DetectSignFlips[MVals_List] :=
  Select[Range[2, Length[MVals]], MVals[[# - 1]] * MVals[[#]] < 0 &];

(* DetectSusceptibilityPeaks — local maxima of |dM/dt| exceeding
   thresholdFrac of the global maximum (same "local max above a
   fraction of the global max" pattern cosmology/'s acoustic-peak
   detector uses). *)
DetectSusceptibilityPeaks[dMVals_List, Optional[thresholdFrac_?NumericQ, 0.5]] :=
  Module[{thresh = thresholdFrac * Max[dMVals]},
    Select[Range[2, Length[dMVals] - 1],
      dMVals[[#]] > dMVals[[# - 1]] && dMVals[[#]] > dMVals[[# + 1]] && dMVals[[#]] > thresh &]
  ];

(* SynthBurst — short exponentially-decaying sine burst, same style as
   cellular/'s accent tones. *)
SynthBurst[freq_?NumericQ, sr_Integer, burstLen_Integer, amp_:0.5] :=
  amp * Table[Sin[2.0 Pi freq i / sr] * Exp[-6.0 i / burstLen], {i, 0, burstLen - 1}];

(* BuildEventAudio
   sweepIdx/MVals/TVals (TVals may be a constant list, or Missing[] to
   skip T_c-crossing detection for critical/quench modes) drive three
   accent types, each placed at the sample position corresponding to
   its sweep index (via the same t-rescaling BuildObservableTrajectory
   uses) and panned centrally. Returns {leftBuf, rightBuf, articulated}
   where articulated is a 0/1 list (length = sweepIdx) flagging any
   sweep at which an event fired, for CSV export. *)
BuildEventAudio[sweepIdx_List, MVals_List, TVals_, Tc_?NumericQ, nSamples_Integer, sr_Integer] :=
  Module[{n = Length[sweepIdx], dMVals, tcIdx, flipIdx, peakIdx, leftBuf, rightBuf,
          articulated, genToSample},
    dMVals = Prepend[Abs[Differences[MVals]], 0.0];

    tcIdx = If[ListQ[TVals], DetectTcCrossing[TVals, Tc], {}];
    flipIdx = DetectSignFlips[MVals];
    peakIdx = DetectSusceptibilityPeaks[dMVals];

    leftBuf  = ConstantArray[0.0, nSamples];
    rightBuf = ConstantArray[0.0, nSamples];
    articulated = ConstantArray[0, n];

    genToSample[idx_Integer] :=
      Clip[Round[Rescale[idx, {1, n}, {1, nSamples}]], {1, nSamples}];

    PlaceBurst[idx_Integer, freq_?NumericQ, durSec_?NumericQ, amp_?NumericQ] :=
      Module[{burstLen, burst, start, endS},
        burstLen = Round[durSec * sr];
        burst    = SynthBurst[freq, sr, burstLen, amp];
        start    = genToSample[idx];
        endS     = Min[start + burstLen - 1, nSamples];
        If[endS >= start,
          leftBuf[[start ;; endS]]  += Sqrt[0.5] * burst[[1 ;; endS - start + 1]];
          rightBuf[[start ;; endS]] += Sqrt[0.5] * burst[[1 ;; endS - start + 1]]
        ];
        articulated[[idx]] = 1
      ];

    Scan[PlaceBurst[#, 440.0, 0.150, 0.7] &, tcIdx];
    Scan[PlaceBurst[#, 220.0, 0.050, 0.4] &, flipIdx];
    Scan[PlaceBurst[#, 660.0, 0.100, 0.6] &, peakIdx];

    <| "left" -> leftBuf, "right" -> rightBuf, "articulated" -> articulated,
       "tcCrossingIdx" -> tcIdx, "signFlipIdx" -> flipIdx, "susceptibilityPeakIdx" -> peakIdx |>
  ];


(* ── Layer 2: run-length Hilbert spatial scan ─────────────────────── *)

(* HilbertRunLengthTones
   spinSeq is the grid's values visited in Hilbert order (length
   nPixels). Groups consecutive equal values into runs and returns
   {leftBuf, rightBuf} of exactly nPixels*pixelDuration*sr samples
   (run lengths always sum to nPixels, so the segment duration is
   exact regardless of run structure — same invariant as cellular/'s
   run-length note articulation). *)
HilbertRunLengthTones[spinSeq_List, pixelDuration_?NumericQ, sr_Integer] :=
  Module[{n = Length[spinSeq], boundaries, runs, nSamples, leftBuf, rightBuf,
          gensSoFar, harmonics = {1.0, 0.2}, decayFrac = 0.4},
    boundaries = Prepend[Select[Range[2, n], spinSeq[[#]] != spinSeq[[# - 1]] &], 1];
    runs = Table[
      Module[{s = boundaries[[i]], e = If[i < Length[boundaries], boundaries[[i + 1]] - 1, n]},
        <| "start" -> s, "length" -> (e - s + 1), "value" -> spinSeq[[s]] |>
      ],
      {i, Length[boundaries]}
    ];

    nSamples = Round[n * pixelDuration * sr];
    leftBuf  = ConstantArray[0.0, nSamples];
    rightBuf = ConstantArray[0.0, nSamples];

    gensSoFar = 0;
    Do[
      Module[{run, startSample, endSample, dur, freq, note},
        run = runs[[i]];
        startSample = Round[gensSoFar * pixelDuration * sr] + 1;
        gensSoFar  += run["length"];
        endSample   = Round[gensSoFar * pixelDuration * sr];
        dur = N[Max[endSample - startSample + 1, 1] / sr];
        freq = If[run["value"] > 0, $hilbertC5, $hilbertC3];
        note = StemSynthNote[freq, dur, 0.6, harmonics, decayFrac, sr];
        With[{placeEnd = Min[startSample + Length[note] - 1, nSamples]},
          If[placeEnd >= startSample,
            leftBuf[[startSample ;; placeEnd]]  += note[[1 ;; placeEnd - startSample + 1]];
            rightBuf[[startSample ;; placeEnd]] += note[[1 ;; placeEnd - startSample + 1]]
          ]
        ]
      ],
      {i, Length[runs]}
    ];

    {leftBuf, rightBuf}
  ];

(* BuildSpatialLayerAudio
   grids is the full list of recorded grid snapshots; only
   Min[$maxSpatialSnapshots, Length[grids]] of them (evenly spaced)
   actually get sonified, each occupying its own contiguous slot
   within totalDuration (matching Layer 1's own duration exactly, so
   the two layers can be summed sample-for-sample). *)
BuildSpatialLayerAudio[grids_List, hilbertN_Integer, pixelDuration_?NumericQ,
                       totalDuration_?NumericQ, sr_Integer] :=
  Module[{nGrids = Length[grids], nSnapshots, indices, traversal, nPixels,
          slotDuration, totalSamples, leftAll, rightAll, cursor},
    nSnapshots = Min[$maxSpatialSnapshots, nGrids];
    indices    = DeleteDuplicates[Round[Subdivide[1, nGrids, nSnapshots - 1]]];
    traversal  = HilbertTraversalOrder[hilbertN];
    nPixels    = Length[traversal];
    slotDuration = nPixels * pixelDuration;
    totalSamples = Round[totalDuration * sr];

    leftAll  = ConstantArray[0.0, totalSamples];
    rightAll = ConstantArray[0.0, totalSamples];

    Do[
      Module[{gridIdx, grid, spinSeq, lr, startSample, endSample},
        gridIdx = indices[[k]];
        grid    = grids[[gridIdx]];
        spinSeq = Table[grid[[traversal[[p, 2]], traversal[[p, 1]]]], {p, nPixels}];
        lr = HilbertRunLengthTones[spinSeq, pixelDuration, sr];

        startSample = Round[(gridIdx - 1) / Max[nGrids - 1, 1] * (totalSamples - Length[lr[[1]]])] + 1;
        endSample   = Min[startSample + Length[lr[[1]]] - 1, totalSamples];
        If[endSample >= startSample,
          leftAll[[startSample ;; endSample]]  += lr[[1]][[1 ;; endSample - startSample + 1]];
          rightAll[[startSample ;; endSample]] += lr[[2]][[1 ;; endSample - startSample + 1]]
        ]
      ],
      {k, Length[indices]}
    ];

    {leftAll, rightAll}
  ];


(* ── Full two-layer mix ──────────────────────────────────────────── *)

(* SonifyIsingRun
   Common entry point for all three modes. modelResult must have keys
   "sweepIdx", "M", "E", "grids"; TVals is a list (sweep mode) — pass
   Missing[] to skip T_c-crossing detection for critical/quench.
   Returns buffers rather than exporting directly (same pattern as
   thermo/dynamical), so main.wl can prepend the spoken intro before a
   single final export. *)
SonifyIsingRun[modelResult_Association, TValsOrMissing_, Tc_?NumericQ, cfg_Association] :=
  Module[{sweepIdx, MVals, EVals, grids, nSize, hilbertN, pixelDuration, spatialGainDb,
          spatialGainLin, sr, secondsPerSweep, totalDuration, trajectory, cfgDur, sp, mo,
          eventResult, spatial, mixLeft, mixRight, stereo, traversalCache},

    sweepIdx = modelResult["sweepIdx"];
    MVals    = modelResult["M"];
    EVals    = modelResult["E"];
    grids    = modelResult["grids"];
    nSize    = modelResult["nSize"];

    hilbertN      = Round[Log2[N[nSize]]];
    pixelDuration = GetCfg[cfg, {"simulation", "montecarlo", "pixel_duration"}, 0.001];
    spatialGainDb = GetCfg[cfg, {"sonification", "montecarlo", "spatial_layer_gain"}, -12];
    spatialGainLin = 10.0^(spatialGainDb / 20.0);
    sr = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

    (* Total duration is driven by the spatial layer's own natural
       length (see $maxSpatialSnapshots/AGENTS.md) and reused for
       Layer 1 so both layers span exactly the same buffer. *)
    secondsPerSweep = Length[traversalCache = HilbertTraversalOrder[hilbertN]] * pixelDuration;
    totalDuration   = Min[$maxSpatialSnapshots, Length[sweepIdx]] * secondsPerSweep;

    trajectory = BuildObservableTrajectory[sweepIdx, MVals, EVals, totalDuration];
    (* $HardcodedDefaults always supplies sonification.duration (10.0),
       which would otherwise silently override totalDuration here —
       same pitfall documented in cellular/AGENTS.md and dynamical/. *)
    cfgDur = DeepMerge[cfg, <| "sonification" -> <| "duration" -> totalDuration |> |>];
    sp = SpatialLayer[trajectory, cfgDur];
    mo = MotionLayer[trajectory, cfgDur];

    eventResult = BuildEventAudio[sweepIdx, MVals, TValsOrMissing, Tc,
                                  Length[sp["times"]], sr];

    spatial = BuildSpatialLayerAudio[grids, hilbertN, pixelDuration, totalDuration, sr];

    (* MixLayers expects an "events" Association shaped like EventLayer's
       output ({"audio"->buffer,"events"->{},"sr"->sr}); the event
       buffer here is mono (centred), so feed it in as-is — MixLayers
       adds it identically to both channels before panning is applied
       to the spatial/motion carrier only, matching cellular/'s
       original pattern of pre-mixing custom events this way. *)
    With[{ev = <| "audio" -> eventResult["left"], "events" -> {}, "sr" -> sr |>},
      stereo = MixLayers[sp, mo, ev, cfgDur]
    ];

    mixLeft  = stereo[[All, 1]] + spatialGainLin * spatial[[1]];
    mixRight = stereo[[All, 2]] + spatialGainLin * spatial[[2]];

    <|
      "left" -> mixLeft, "right" -> mixRight, "sr" -> sr,
      "totalDuration" -> totalDuration, "articulated" -> eventResult["articulated"],
      "tcCrossingIdx" -> eventResult["tcCrossingIdx"],
      "signFlipIdx" -> eventResult["signFlipIdx"],
      "susceptibilityPeakIdx" -> eventResult["susceptibilityPeakIdx"],
      "nSpatialSnapshots" -> Min[$maxSpatialSnapshots, Length[grids]]
    |>
  ];

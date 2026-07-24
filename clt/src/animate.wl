(* ========================================================
   clt/src/animate.wl — GIF/PNG rendering for all three modes

   Samples are RE-DRAWN here with the identical
   SampleXbarN[...,seed+nStep]/SampleDiceSumN[...,seed+nStep] calls
   sonify.wl uses, not passed through some shared struct -- WL's
   SeedRandom-based RNG makes this exactly reproducible (same seed,
   same arguments -> byte-identical samples), the simplest way to
   guarantee the animation matches what the audio actually sonified,
   without threading large raw-sample arrays through every Association.

   compare mode's two-panel layout uses the SAME left=sourceLeft/
   right=sourceRight assignment as sonify.wl's BuildCompareAudio and
   output.wl's CSV columns -- see sonify.wl's file header for the full
   channel-assignment note (compton/AGENTS.md design decision 8 is the
   reason this is called out explicitly here rather than assumed).
   ======================================================== *)


(* ClampToDomain — Histogram[data,{lo,hi,dx}] bins are half-open even
   for the last bin, so a value exactly AT hi is silently dropped, not
   binned -- see sonify.wl's HistogramSpectrumBins for the full note
   (the same issue, first caught there, when the "bernoulli" source's
   exact 0.0/1.0 sample means at N=1 lost their entire right-hand
   spike). Every Histogram[...,{domainLo,domainHi,binWidth},...] call
   below applies this first for the same reason. *)
ClampToDomain[samples_List, domainHi_?NumericQ, binWidth_?NumericQ] :=
  Map[If[# >= domainHi, domainHi - binWidth * 0.0001, #] &, samples];


(* ── Mode 1: sweep — raw mean histogram narrowing and smoothing ────── *)

RenderSweepFrame[sourceName_String, p_?NumericQ, nStep_Integer, nSamples_Integer,
                 domainLo_?NumericQ, domainHi_?NumericQ, nMax_Integer, seed_Integer] :=
  Module[{samples, colorFrac, curveColor, binWidth},
    samples   = SampleXbarN[sourceName, p, nStep, nSamples, seed + nStep];
    colorFrac = N[nStep - 1] / Max[nMax - 1, 1];
    curveColor = Blend[{RGBColor[0.85, 0.25, 0.15], RGBColor[0.2, 0.45, 0.9]}, colorFrac];
    binWidth  = (domainHi - domainLo) / 40.0;
    samples   = ClampToDomain[samples, domainHi, binWidth];

    Histogram[samples, {domainLo, domainHi, binWidth}, "PDF",
      ChartStyle -> curveColor,
      PlotRange  -> {{domainLo, domainHi}, {0, Automatic}},
      Background -> Black,
      ImageSize  -> {600, 380},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["sample mean value", White, 11], Style["density", White, 11]},
      PlotLabel  -> Style["N = " <> ToString[nStep] <> "   mean = " <>
                          ToString[NumberForm[Mean[samples], {4, 3}]] <> "   var = " <>
                          ToString[NumberForm[Variance[samples], {4, 4}]], White, 12]
    ]
  ];

AnimateSweep[sourceName_String, p_?NumericQ, nMax_Integer, nSamples_Integer,
            domainLo_?NumericQ, domainHi_?NumericQ, seed_Integer, outGif_String] :=
  Module[{frames},
    Print["  Rendering ", nMax, " sweep frames..."];
    frames = Table[RenderSweepFrame[sourceName, p, k, nSamples, domainLo, domainHi, nMax, seed],
                   {k, nMax}];
    ExportGIF[frames, outGif, 8];
    nMax
  ];

(* RenderSweepSmallMultiple — a few representative N values side by
   side (N=1, a middle value, and n_max), echoing the classic textbook
   "watch it converge" figure -- matches thermo/'s and bayes/'s own
   preference for a single representative composite PNG over a bare
   re-render of the last GIF frame. *)
RenderSweepSmallMultiple[sourceName_String, p_?NumericQ, nMax_Integer, nSamples_Integer,
                         domainLo_?NumericQ, domainHi_?NumericQ, seed_Integer, outPng_String] :=
  Module[{nMid, representativeNs, panels, binWidth},
    nMid = Max[2, Round[nMax / 2]];
    representativeNs = DeleteDuplicates[{1, nMid, nMax}];
    binWidth = (domainHi - domainLo) / 40.0;

    panels = Map[
      Function[nStep,
        Module[{samples},
          samples = SampleXbarN[sourceName, p, nStep, nSamples, seed + nStep];
          samples = ClampToDomain[samples, domainHi, binWidth];
          Histogram[samples, {domainLo, domainHi, binWidth}, "PDF",
            ChartStyle -> RGBColor[0.2, 0.45, 0.85],
            PlotRange  -> {{domainLo, domainHi}, {0, Automatic}},
            Background -> White,
            ImageSize  -> {320, 280},
            Frame      -> True,
            FrameLabel -> {"sample mean", "density"},
            PlotLabel  -> "N = " <> ToString[nStep]
          ]
        ]
      ],
      representativeNs
    ];

    Export[outPng, GraphicsRow[panels, ImageSize -> 320 * Length[panels]], "PNG"];
    Print["  PNG: ", outPng]
  ];


(* ── Mode 2: compare — two standardized densities converging ──────── *)

RenderCompareFrame[sourceLeft_String, pLeft_?NumericQ, sourceRight_String, pRight_?NumericQ,
                   nStep_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
                   seed_Integer] :=
  Module[{muL, sigL, samplesL, stdL, muR, sigR, samplesR, stdR, binWidth},
    muL = SourceMean[sourceLeft, pLeft];   sigL = Sqrt[SourceVariance[sourceLeft, pLeft]];
    muR = SourceMean[sourceRight, pRight]; sigR = Sqrt[SourceVariance[sourceRight, pRight]];

    samplesL = SampleXbarN[sourceLeft, pLeft, nStep, nSamples, seed + nStep];
    stdL     = (samplesL - muL) / (sigL / Sqrt[N[nStep]]);
    samplesR = SampleXbarN[sourceRight, pRight, nStep, nSamples, seed + 10000 + nStep];
    stdR     = (samplesR - muR) / (sigR / Sqrt[N[nStep]]);

    binWidth = (domainHi - domainLo) / 40.0;
    stdL     = ClampToDomain[stdL, domainHi, binWidth];
    stdR     = ClampToDomain[stdR, domainHi, binWidth];

    Show[
      Histogram[stdL, {domainLo, domainHi, binWidth}, "PDF",
        ChartStyle -> Directive[Opacity[0.55], RGBColor[0.25, 0.55, 0.95]],
        PlotRange  -> {{domainLo, domainHi}, {0, Automatic}},
        Background -> Black, ImageSize -> {600, 380},
        Frame -> True, FrameStyle -> Directive[White, Thin],
        FrameLabel -> {Style["standardized sample mean", White, 11], Style["density", White, 11]},
        PlotLabel -> Style["N = " <> ToString[nStep] <> "   left=" <> sourceLeft <>
                           "   right=" <> sourceRight, White, 12]
      ],
      Histogram[stdR, {domainLo, domainHi, binWidth}, "PDF",
        ChartStyle -> Directive[Opacity[0.55], RGBColor[0.95, 0.45, 0.15]]
      ]
    ]
  ];

AnimateCompare[sourceLeft_String, pLeft_?NumericQ, sourceRight_String, pRight_?NumericQ,
              nMax_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
              seed_Integer, outGif_String] :=
  Module[{frames},
    Print["  Rendering ", nMax, " compare frames..."];
    frames = Table[
      RenderCompareFrame[sourceLeft, pLeft, sourceRight, pRight, k, nSamples, domainLo, domainHi, seed],
      {k, nMax}
    ];
    ExportGIF[frames, outGif, 8];
    nMax
  ];

(* Built directly with White/Black swapped throughout, not via a
   post-hoc /. substitution on RenderCompareFrame's black-background
   result -- an earlier version tried exactly that substitution and it
   silently failed to recolour the rendered Graphics (Histogram's
   internal option structure does not expose Background/ChartStyle as
   bare replaceable symbols the way a naive /. expects), producing a
   PNG that LOOKED like it exported successfully but was still
   black-on-black. Caught by actually viewing the exported PNG, not by
   reading the code -- the same "render and look" discipline
   quantum_tunnelling/AGENTS.md pitfall 4/5 and compton/AGENTS.md
   pitfall 4 both document. *)
RenderCompareStaticPNG[sourceLeft_String, pLeft_?NumericQ, sourceRight_String, pRight_?NumericQ,
                       nMax_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
                       seed_Integer, outPng_String] :=
  Module[{muL, sigL, samplesL, stdL, muR, sigR, samplesR, stdR, binWidth, plt},
    muL = SourceMean[sourceLeft, pLeft];   sigL = Sqrt[SourceVariance[sourceLeft, pLeft]];
    muR = SourceMean[sourceRight, pRight]; sigR = Sqrt[SourceVariance[sourceRight, pRight]];

    samplesL = SampleXbarN[sourceLeft, pLeft, nMax, nSamples, seed + nMax];
    stdL     = (samplesL - muL) / (sigL / Sqrt[N[nMax]]);
    samplesR = SampleXbarN[sourceRight, pRight, nMax, nSamples, seed + 10000 + nMax];
    stdR     = (samplesR - muR) / (sigR / Sqrt[N[nMax]]);

    binWidth = (domainHi - domainLo) / 40.0;
    stdL     = ClampToDomain[stdL, domainHi, binWidth];
    stdR     = ClampToDomain[stdR, domainHi, binWidth];

    plt = Show[
      Histogram[stdL, {domainLo, domainHi, binWidth}, "PDF",
        ChartStyle -> Directive[Opacity[0.55], RGBColor[0.15, 0.35, 0.75]],
        PlotRange  -> {{domainLo, domainHi}, {0, Automatic}},
        Background -> White, ImageSize -> {600, 380},
        Frame -> True, FrameLabel -> {"standardized sample mean", "density"},
        PlotLabel  -> "N = " <> ToString[nMax] <> " (left=" <> sourceLeft <> ", right=" <>
                      sourceRight <> ") \[LongDash] Standardized Shapes Converge"
      ],
      Histogram[stdR, {domainLo, domainHi, binWidth}, "PDF",
        ChartStyle -> Directive[Opacity[0.55], RGBColor[0.85, 0.35, 0.1]]
      ]
    ];
    Export[outPng, plt, "PNG"];
    Print["  PNG: ", outPng]
  ];


(* ── Mode 3: dice — discrete bar chart of the sum's distribution ──── *)

RenderDiceFrame[nStep_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
               nMax_Integer, seed_Integer] :=
  Module[{sums, possibleValues, empProbs, colorFrac, barColor},
    sums = SampleDiceSumN[nStep, nSamples, seed + nStep];
    possibleValues = Range[nStep, 6 * nStep];
    empProbs = N[Count[sums, N[#]] & /@ possibleValues] / nSamples;
    colorFrac = N[nStep - 1] / Max[nMax - 1, 1];
    barColor  = Blend[{RGBColor[0.85, 0.25, 0.15], RGBColor[0.2, 0.45, 0.9]}, colorFrac];

    BarChart[empProbs,
      ChartLabels -> None,
      ChartStyle  -> barColor,
      PlotRange   -> {{0, domainHi - domainLo + 2}, {0, Automatic}},
      Background  -> Black,
      ImageSize   -> {600, 380},
      Frame       -> True,
      FrameStyle  -> Directive[White, Thin],
      FrameTicks  -> {{Automatic, None}, {Table[{i - possibleValues[[1]] + 1, possibleValues[[i]]},
                                              {i, 1, Length[possibleValues], Max[1, Round[Length[possibleValues]/10]]}], None}},
      FrameLabel  -> {Style["sum of " <> ToString[nStep] <> " dice", White, 11], Style["probability", White, 11]},
      PlotLabel   -> Style["N = " <> ToString[nStep] <> " dice", White, 12]
    ]
  ];

AnimateDice[nMax_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
           seed_Integer, outGif_String] :=
  Module[{frames},
    Print["  Rendering ", nMax, " dice frames..."];
    frames = Table[RenderDiceFrame[k, nSamples, domainLo, domainHi, nMax, seed], {k, nMax}];
    ExportGIF[frames, outGif, 4];
    nMax
  ];

RenderDiceSmallMultiple[nMax_Integer, nSamples_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
                        seed_Integer, outPng_String] :=
  Module[{representativeNs, panels},
    representativeNs = DeleteDuplicates[{1, 2, nMax}];
    panels = Map[
      Function[nStep,
        Module[{sums, possibleValues, empProbs},
          sums = SampleDiceSumN[nStep, nSamples, seed + nStep];
          possibleValues = Range[nStep, 6 * nStep];
          empProbs = N[Count[sums, N[#]] & /@ possibleValues] / nSamples;
          BarChart[empProbs,
            ChartStyle -> RGBColor[0.2, 0.45, 0.85],
            Background -> White, ImageSize -> {320, 280},
            Frame -> True, FrameLabel -> {"sum", "probability"},
            PlotLabel -> "N = " <> ToString[nStep] <> " dice"
          ]
        ]
      ],
      representativeNs
    ];
    Export[outPng, GraphicsRow[panels, ImageSize -> 320 * Length[panels]], "PNG"];
    Print["  PNG: ", outPng]
  ];

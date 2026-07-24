(* ========================================================
   clt/src/output.wl — CSV export and console summaries

   All three Export*CSV functions re-derive samples with the same
   seed+nStep convention sonify.wl/animate.wl use (see animate.wl's
   file header for why this is exact and safe, not an approximation).
   ======================================================== *)


(* ── Mode 1: sweep ────────────────────────────────────────────────── *)

(* Long format: one row per (N, bin) -- N/mean/variance repeat down
   the N's block of rows, bin_center/density vary -- enough to
   reconstruct both the summary (N vs mean/variance) and the full
   per-N density curve, per the build spec's own framing. *)
ExportSweepCSV[sourceName_String, p_?NumericQ, nMax_Integer, nSamples_Integer,
              domainLo_?NumericQ, domainHi_?NumericQ, nBins_Integer, seed_Integer,
              outCSV_String] :=
  Module[{header, rows},
    header = {{"N", "empirical_mean", "empirical_variance", "bin_center", "density"}};
    rows = Flatten[
      Table[
        Module[{samples, mu, var, spec},
          samples = SampleXbarN[sourceName, p, nStep, nSamples, seed + nStep];
          mu  = Mean[samples]; var = Variance[samples];
          spec = HistogramSpectrumBins[samples, domainLo, domainHi, nBins, 100.0, 4000.0];
          Table[{nStep, mu, var, spec["binCenters"][[i]], spec["densities"][[i]]}, {i, nBins}]
        ],
        {nStep, 1, nMax}
      ],
      1
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 5]
  ];

PrintSweepSummary[sourceName_String, nMax_Integer, domainLo_?NumericQ, domainHi_?NumericQ,
                  firstMean_?NumericQ, firstVar_?NumericQ, lastMean_?NumericQ, lastVar_?NumericQ] :=
  Module[{},
    STEMSection["Sweep Summary"];
    Print["  Source: ", sourceName, "  (display domain [", FmtN[domainLo, 4], ", ", FmtN[domainHi, 4], "])"];
    STEMPrintN["N range", 1, "-> " <> ToString[nMax], 1];
    Print["  Mean:     ", FmtN[firstMean, 5], " (N=1) -> ", FmtN[lastMean, 5], " (N=", nMax, ")"];
    Print["  Variance: ", FmtN[firstVar, 6], " (N=1) -> ", FmtN[lastVar, 6], " (N=", nMax, ")"]
  ];


(* ── Mode 2: compare ──────────────────────────────────────────────── *)

ExportCompareCSV[sourceLeft_String, pLeft_?NumericQ, sourceRight_String, pRight_?NumericQ,
                 nMax_Integer, nSamples_Integer, seed_Integer, outCSV_String] :=
  Module[{header, rows},
    header = {{"N", "left_source", "left_mean", "left_variance", "left_excess_kurtosis",
                "right_source", "right_mean", "right_variance", "right_excess_kurtosis"}};
    rows = Table[
      Module[{muL, sigL, samplesL, stdL, muR, sigR, samplesR, stdR},
        muL = SourceMean[sourceLeft, pLeft];   sigL = Sqrt[SourceVariance[sourceLeft, pLeft]];
        muR = SourceMean[sourceRight, pRight]; sigR = Sqrt[SourceVariance[sourceRight, pRight]];
        samplesL = SampleXbarN[sourceLeft, pLeft, nStep, nSamples, seed + nStep];
        stdL     = (samplesL - muL) / (sigL / Sqrt[N[nStep]]);
        samplesR = SampleXbarN[sourceRight, pRight, nStep, nSamples, seed + 10000 + nStep];
        stdR     = (samplesR - muR) / (sigR / Sqrt[N[nStep]]);
        {nStep, sourceLeft, Mean[stdL], Variance[stdL], Kurtosis[stdL] - 3.0,
         sourceRight, Mean[stdR], Variance[stdR], Kurtosis[stdR] - 3.0}
      ],
      {nStep, 1, nMax}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 9]
  ];

PrintCompareSummary[sourceLeft_String, sourceRight_String, nMax_Integer,
                    firstKurtL_?NumericQ, firstKurtR_?NumericQ,
                    lastKurtL_?NumericQ, lastKurtR_?NumericQ] :=
  Module[{},
    STEMSection["Compare Summary"];
    Print["  Left channel:  ", sourceLeft, " (standardized)"];
    Print["  Right channel: ", sourceRight, " (standardized)"];
    Print["  Excess kurtosis at N=1:      left=", FmtN[firstKurtL, 4], "   right=", FmtN[firstKurtR, 4]];
    Print["  Excess kurtosis at N=", nMax, ":     left=", FmtN[lastKurtL, 4], "   right=", FmtN[lastKurtR, 4]]
  ];


(* ── Mode 3: dice ─────────────────────────────────────────────────── *)

(* ExactDiceProbability — brute-force enumeration over all 6^N equally
   likely outcomes, feasible only for small N (N=1,2 per the build
   spec's own suggestion); returns Missing[] for larger N rather than
   attempting an expensive or approximate combinatorial shortcut. *)
ExactDiceProbability[nStep_Integer, sumValue_Integer] :=
  If[nStep > 2,
    Missing["NotAvailable"],
    Module[{allOutcomes, allSums, matching},
      allOutcomes = Tuples[Range[1, 6], nStep];
      allSums     = Total /@ allOutcomes;
      matching    = Count[allSums, sumValue];
      N[matching] / 6.0^nStep
    ]
  ];

ExportDiceCSV[nMax_Integer, nSamples_Integer, seed_Integer, outCSV_String] :=
  Module[{header, rows},
    header = {{"N", "sum_value", "empirical_probability", "exact_probability"}};
    rows = Flatten[
      Table[
        Module[{sums, possibleValues, empProbs},
          sums = SampleDiceSumN[nStep, nSamples, seed + nStep];
          possibleValues = Range[nStep, 6 * nStep];
          empProbs = N[Count[sums, N[#]] & /@ possibleValues] / nSamples;
          Table[
            {nStep, possibleValues[[i]], empProbs[[i]],
             With[{ex = ExactDiceProbability[nStep, possibleValues[[i]]]},
               If[MissingQ[ex], "", ex]
             ]},
            {i, Length[possibleValues]}
          ]
        ],
        {nStep, 1, nMax}
      ],
      1
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 4]
  ];

PrintDiceSummary[nMax_Integer, firstMean_?NumericQ, firstVar_?NumericQ,
                 lastMean_?NumericQ, lastVar_?NumericQ] :=
  Module[{},
    STEMSection["Dice Summary"];
    STEMPrintN["N range", 1, "-> " <> ToString[nMax], 1];
    Print["  Mean sum: ", FmtN[firstMean, 4], " (N=1) -> ", FmtN[lastMean, 4], " (N=", nMax, ")"];
    Print["  Variance: ", FmtN[firstVar, 4], " (N=1) -> ", FmtN[lastVar, 4], " (N=", nMax,
          ")  -- grows with N, unlike the mean's variance"]
  ];

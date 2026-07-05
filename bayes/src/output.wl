(* ========================================================
   bayes/src/output.wl — CSV export, correctness-check
   printing, and console summaries
   ======================================================== *)


(* ── Correctness checks (PASS/FAIL, printed every run) ───────────── *)

(* PrintCoreChecks — checks 1-3, relevant to every mode since they test
   the conjugate-update formulas themselves, independent of which mode
   is currently running. *)
PrintCoreChecks[] :=
  Module[{betaCheck, gaussCheck, bfCheck},
    betaCheck  = BetaPosteriorCheck[];
    gaussCheck = GaussianPosteriorCheck[];
    bfCheck    = BayesFactorCheck[];
    Print["  [", If[betaCheck["pass"], "PASS", "FAIL"], "] Beta posterior (h=7,t=3): mean = ",
          FmtN[betaCheck["mean"], 6], " (expected 0.6667), mode = ", FmtN[betaCheck["mode"], 6],
          " (expected 0.7)"];
    Print["  [", If[gaussCheck["pass"], "PASS", "FAIL"], "] Gaussian posterior (prior N(0,4), x=3): mean = ",
          FmtN[gaussCheck["mean"], 6], " (expected 2.4), variance = ",
          FmtN[gaussCheck["variance"], 6], " (expected 0.8)"];
    Print["  [", If[bfCheck["pass"], "PASS", "FAIL"], "] Bayes factor (h=7,t=3, H1:0.5 vs H2:0.7): log10K = ",
          FmtN[bfCheck["logK"], 6], " (expected -0.35735)"];
    {betaCheck, gaussCheck, bfCheck}
  ];

(* PrintConvergenceCheck — check 4, coin mode only (statistical, run
   against the mode's actual thetaTrue/nFlips configuration). *)
PrintConvergenceCheck[thetaTrue_?NumericQ, nFlips_Integer] :=
  Module[{check},
    check = ConvergenceCheck[thetaTrue, nFlips];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Convergence: ", check["nConverged"], "/",
          check["nRealizations"], " independent ", nFlips, "-flip realisations converged to ",
          "within 0.1 of theta_true = ", FmtN[thetaTrue, 4]];
    check
  ];


(* ── CSV export ───────────────────────────────────────────────────── *)

ExportCoinCSV[seq_List, outCSV_String] :=
  Module[{header, rows},
    header = {{"flip", "outcome", "alpha", "beta", "posterior_mean",
               "posterior_variance", "posterior_mode"}};
    rows = Table[
      {s["flip"], s["outcome"], s["alpha"], s["beta"], s["mean"], s["variance"], s["mode"]},
      {s, seq}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 7]
  ];

ExportGaussianCSV[seq_List, outCSV_String] :=
  Module[{header, rows},
    header = {{"observation", "x_obs", "posterior_mean", "posterior_variance",
               "posterior_credible_interval_low", "posterior_credible_interval_high"}};
    rows = Table[
      {s["observation"], s["x_obs"], s["mean"], s["variance"], s["ci_low"], s["ci_high"]},
      {s, seq}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 6]
  ];

ExportModelCSV[modelSeq_List, modelAudio_Association, outCSV_String] :=
  Module[{n = Length[modelSeq], header, rows},
    header = {{"flip", "outcome", "log_bayes_factor", "pan", "pitch_hz", "evidence_level"}};
    rows = Table[
      {modelSeq[[k]]["flip"], modelSeq[[k]]["outcome"], modelSeq[[k]]["log_bayes_factor"],
       modelAudio["pan"][[k]], modelAudio["pitchHz"][[k]],
       EvidenceLevel[modelSeq[[k]]["log_bayes_factor"]]},
      {k, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 6]
  ];


(* ── Console summaries ───────────────────────────────────────────── *)

PrintCoinSummary[seq_List, thetaTrue_?NumericQ, convergenceFlipIdx_] :=
  Module[{final},
    final = Last[seq];
    STEMSection["Coin Summary"];
    STEMPrintN["True bias theta", thetaTrue];
    STEMPrintN["Flips", Length[seq]];
    Print["  Final posterior: Beta(", final["alpha"], ", ", final["beta"], ")"];
    STEMPrintN["Final posterior mean", final["mean"], "", 5];
    STEMPrintN["Final posterior variance", final["variance"], "", 5];
    STEMPrintN["Final posterior mode", final["mode"], "", 5];
    If[IntegerQ[convergenceFlipIdx],
      Print["  Convergence milestone (variance < 0.01) reached at flip ", convergenceFlipIdx],
      Print["  Convergence milestone (variance < 0.01) not reached within this run"]
    ]
  ];

PrintGaussianSummary[seq_List, muTrue_?NumericQ, mu0_?NumericQ, convergenceObsIdx_] :=
  Module[{final},
    final = Last[seq];
    STEMSection["Gaussian Summary"];
    STEMPrintN["True mean mu", muTrue];
    STEMPrintN["Prior mean mu_0", mu0];
    STEMPrintN["Observations", Length[seq]];
    STEMPrintN["Final posterior mean", final["mean"], "", 5];
    STEMPrintN["Final posterior variance", final["variance"], "", 5];
    Print["  Final 95% credible interval: [", FmtN[final["ci_low"], 5], ", ",
          FmtN[final["ci_high"], 5], "]"];
    If[IntegerQ[convergenceObsIdx],
      Print["  Converged to within 0.1 of mu_true at observation ", convergenceObsIdx],
      Print["  Did not converge to within 0.1 of mu_true within this run"]
    ]
  ];

PrintModelSummary[modelSeq_List, thetaAlt_?NumericQ, thetaTrue_?NumericQ, crossOneIdx_, crossTwoIdx_] :=
  Module[{finalLogK},
    finalLogK = Last[modelSeq]["log_bayes_factor"];
    STEMSection["Model Comparison Summary"];
    STEMPrintN["H1 theta (fair)", 0.5];
    STEMPrintN["H2 theta (biased)", thetaAlt];
    STEMPrintN["True theta", thetaTrue];
    STEMPrintN["Final log10(Bayes factor)", finalLogK, "", 6];
    Print["  Final evidence: ", EvidenceLevel[finalLogK], " for ",
          If[finalLogK >= 0, "H1 (fair coin)", "H2 (biased coin)"]];
    If[IntegerQ[crossOneIdx], Print["  |log10K| crossed 1 (K=10) at flip ", crossOneIdx]];
    If[IntegerQ[crossTwoIdx], Print["  |log10K| crossed 2 (K=100) at flip ", crossTwoIdx]]
  ];

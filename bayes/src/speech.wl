(* ========================================================
   bayes/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildCoinIntroText[thetaTrue_?NumericQ, nFlips_Integer, audioFreqThetaTrue_?NumericQ] :=
  "Bayesian coin inference. True bias " <> ToString[NumberForm[N[thetaTrue], {3, 2}]] <>
  ", uniform prior, " <> ToString[nFlips] <> " flips. The sound begins broad -- all bias " <>
  "values are equally plausible. Listen for it narrowing to a focused tone near pitch " <>
  ToString[Round[audioFreqThetaTrue]] <> " Hertz as the data accumulates. Convergence " <>
  "milestone and completion are marked by accent tones.";

BuildGaussianIntroText[muTrue_?NumericQ, mu0_?NumericQ, sigma0_?NumericQ, sigma_?NumericQ,
                       nObs_Integer, audioFreqMu0_?NumericQ, audioFreqMuTrue_?NumericQ] :=
  "Bayesian Gaussian mean estimation. True mean " <> ToString[NumberForm[N[muTrue], {3, 2}]] <>
  ", prior centred at " <> ToString[NumberForm[N[mu0], {3, 2}]] <> " with standard deviation " <>
  ToString[NumberForm[N[sigma0], {3, 2}]] <> ", observation noise " <>
  ToString[NumberForm[N[sigma], {3, 2}]] <> ", " <> ToString[nObs] <> " observations. Listen " <>
  "for the pitch shifting from " <> ToString[Round[audioFreqMu0]] <> " Hertz toward " <>
  ToString[Round[audioFreqMuTrue]] <> " Hertz as the posterior mean moves toward the true " <>
  "value, and the sound narrowing as uncertainty shrinks.";

(* The expected drift direction depends on how thetaTrue relates to the
   two hypotheses (theta1=0.5 vs theta2=thetaAlt) — spelled out
   explicitly here (rather than hardcoding "toward the right", which is
   only true for the default thetaTrue=thetaAlt=0.7 configuration) so
   the spoken intro stays accurate if a listener overrides thetaTrue to
   favour hypothesis 1 instead. *)
BuildModelIntroText[nFlips_Integer, thetaAlt_?NumericQ, thetaTrue_?NumericQ] :=
  Module[{expectedLogKPerFlip, sideWord, sideDesc},
    expectedLogKPerFlip = thetaTrue * Log10[0.5 / thetaAlt] +
                          (1.0 - thetaTrue) * Log10[0.5 / (1.0 - thetaAlt)];
    {sideWord, sideDesc} = If[expectedLogKPerFlip >= 0,
      {"left", "the fair coin hypothesis"},
      {"right", "the biased coin hypothesis"}
    ];
    "Bayesian model comparison. " <> ToString[nFlips] <> " coin flips. Hypothesis 1: fair coin, " <>
    "theta equals 0.5. Hypothesis 2: biased coin, theta equals " <>
    ToString[NumberForm[N[thetaAlt], {3, 2}]] <> ". True data from theta equals " <>
    ToString[NumberForm[N[thetaTrue], {3, 2}]] <> ". Listen for the stereo position drifting " <>
    "toward the " <> sideWord <> " as evidence accumulates for " <> sideDesc <>
    ". Strong evidence is marked by accent tones."
  ];

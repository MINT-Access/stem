#!/usr/bin/env wolframscript

(* ========================================================
   Bayesian Inference — Entry Point

   Sonifies Bayesian updating: probability distributions narrowing as
   evidence accumulates. The most conceptually distinct app in the
   project — no differential equations, no orbital mechanics, no wave
   functions, just probability updating made directly audible.

   Usage:
     wolframscript -file main.wl                                       # coin, theta_true=0.7, 100 flips
     wolframscript -file main.wl -- --simulation.mode=gaussian         # Gaussian mean estimation
     wolframscript -file main.wl -- --simulation.mode=model            # Bayes factor comparison
     wolframscript -file main.wl -- --simulation.bayes.theta_true=0.5  # fair coin (slow convergence)
     wolframscript -file main.wl -- --simulation.bayes.theta_true=0.9  # strongly biased coin
     wolframscript -file main.wl -- --simulation.bayes.n_flips=200     # more data
     wolframscript -file main.wl -- --simulation.bayes.random_seed=123 # different random data
     wolframscript -file main.wl -- --simulation.bayes.mu_true=0.5     # near-prior mean (slow shift)
     wolframscript -file main.wl -- --config-dump

   New to this app? Start with bayes/LISTENING_GUIDE.md.

   Modes:
     coin     (default) -- unknown coin bias theta, Beta-Binomial
                           conjugate update; spectral posterior narrows
                           from a broad hum to a focused tone
     gaussian            -- unknown Gaussian mean mu, Normal-Normal
                           conjugate update; posterior shifts in pitch
                           toward the true mean while narrowing
     model               -- Bayes factor comparison of two coin
                           hypotheses; stereo position drifts toward
                           whichever hypothesis the data favours

   Outputs (bayes/output/):
     coin_audio.wav     / coin.gif     / coin_data.csv
     gaussian_audio.wav / gaussian.gif / gaussian_data.csv
     model_audio.wav    / model.gif    / model_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

(* ── CLI preprocessing ──────────────────────────────────────────── *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["bayes", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "coin"];

thetaTrue     = N @ GetCfg[cfg, {"simulation", "bayes", "theta_true"},     0.7];
thetaAlt      = N @ GetCfg[cfg, {"simulation", "bayes", "theta_alt"},      0.7];
muTrue        = N @ GetCfg[cfg, {"simulation", "bayes", "mu_true"},        2.5];
mu0           = N @ GetCfg[cfg, {"simulation", "bayes", "mu_0"},           0.0];
sigma0        = N @ GetCfg[cfg, {"simulation", "bayes", "sigma_0"},        2.0];
sigmaObs      = N @ GetCfg[cfg, {"simulation", "bayes", "sigma"},          1.0];
nFlips        =     GetCfg[cfg, {"simulation", "bayes", "n_flips"},        100];
nObs          =     GetCfg[cfg, {"simulation", "bayes", "n_obs"},          80];
randomSeed    =     GetCfg[cfg, {"simulation", "bayes", "random_seed"},    42];
frameDuration = N @ GetCfg[cfg, {"simulation", "bayes", "frame_duration"}, 0.15];
freqMin       = N @ GetCfg[cfg, {"simulation", "bayes", "freq_min"},       100];
freqMax       = N @ GetCfg[cfg, {"simulation", "bayes", "freq_max"},       4000];
nBins         =     GetCfg[cfg, {"simulation", "bayes", "n_bins"},         128];
summaryGainDb = N @ GetCfg[cfg, {"sonification", "bayes", "summary_layer_gain"}, -12];
sr            =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Bayesian Inference: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

STEMSay["Starting Bayesian inference sonification: " <> mode];

$nSteps5 = 5;
outWAV = FileNameJoin[{$outDir, mode <> "_audio.wav"}];
outGIF = FileNameJoin[{$outDir, mode <> ".gif"}];
outCSV = FileNameJoin[{$outDir, mode <> "_data.csv"}];

Print["[1/", $nSteps5, "] Correctness checks..."];
PrintCoreChecks[];
PrintConvergenceCheck[thetaTrue, nFlips];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     COIN MODE
     ══════════════════════════════════════════════════════ *)
  mode === "coin",

    Print["  True bias theta: ", thetaTrue, "   Flips: ", nFlips];
    Print[""];

    Print["[2/", $nSteps5, "] Generating flips and updating the Beta posterior..."];
    flips = GenerateCoinFlips[nFlips, thetaTrue, randomSeed];
    coinSeq = CoinPosteriorSequence[flips];
    Print["  Observed ", Total[flips], " heads, ", nFlips - Total[flips], " tails."];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the coin bias posterior"];
    coinAudio = BuildCoinAudio[coinSeq, nBins, freqMin, freqMax, frameDuration, summaryGainDb, sr];
    audioFreqThetaTrue = freqMin * (freqMax / freqMin)^thetaTrue;
    introText   = BuildCoinIntroText[thetaTrue, nFlips, audioFreqThetaTrue];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, coinAudio["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, coinAudio["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    PrintCoinSummary[coinSeq, thetaTrue, coinAudio["convergenceFlipIdx"]];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the Beta posterior animation"];
    nFramesRendered = AnimateCoin[coinSeq, thetaTrue, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 12];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportCoinCSV[coinSeq, outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     GAUSSIAN MODE
     ══════════════════════════════════════════════════════ *)
  mode === "gaussian",

    Print["  True mean mu: ", muTrue, "   Prior: N(", mu0, ", ", sigma0^2, ")   ",
          "Obs noise sigma: ", sigmaObs, "   Observations: ", nObs];
    Print[""];

    Print["[2/", $nSteps5, "] Generating observations and updating the Gaussian posterior..."];
    gaussObs = GenerateGaussianObservations[nObs, muTrue, sigmaObs, randomSeed];
    gaussSeq = GaussianPosteriorSequence[gaussObs, mu0, sigma0, sigmaObs];
    muLo = Min[mu0, muTrue] - 3.0 * sigma0;
    muHi = Max[mu0, muTrue] + 3.0 * sigma0;
    Print["  Sample mean: ", FmtN[Mean[gaussObs], 5]];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the Gaussian mean posterior"];
    gaussAudio = BuildGaussianAudio[gaussSeq, muLo, muHi, muTrue, sigma0^2, nBins, freqMin, freqMax,
      frameDuration, summaryGainDb, sr];
    audioFreqMu0    = freqMin * (freqMax / freqMin)^Clip[(mu0 - muLo) / (muHi - muLo), {0.0, 1.0}];
    audioFreqMuTrue = freqMin * (freqMax / freqMin)^Clip[(muTrue - muLo) / (muHi - muLo), {0.0, 1.0}];
    introText   = BuildGaussianIntroText[muTrue, mu0, sigma0, sigmaObs, nObs, audioFreqMu0, audioFreqMuTrue];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, gaussAudio["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, gaussAudio["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    PrintGaussianSummary[gaussSeq, muTrue, mu0, gaussAudio["convergenceObsIdx"]];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the Gaussian posterior animation"];
    nFramesRendered = AnimateGaussian[gaussSeq, muLo, muHi, muTrue, mu0, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 12];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportGaussianCSV[gaussSeq, outCSV];
    Print[""],


  (* ══════════════════════════════════════════════════════
     MODEL MODE
     ══════════════════════════════════════════════════════ *)
  mode === "model",

    Print["  H1 theta (fair): 0.5   H2 theta (biased): ", thetaAlt, "   True theta: ", thetaTrue,
          "   Flips: ", nFlips];
    Print[""];

    Print["[2/", $nSteps5, "] Generating flips and accumulating the Bayes factor..."];
    modelFlips = GenerateCoinFlips[nFlips, thetaTrue, randomSeed];
    modelSeq   = ModelPosteriorSequence[modelFlips, 0.5, thetaAlt];
    Print["  Observed ", Total[modelFlips], " heads, ", nFlips - Total[modelFlips], " tails."];
    Print[""];

    Print["[3/", $nSteps5, "] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the Bayes factor"];
    modelAudio = BuildModelAudio[modelSeq, 0.5, thetaAlt, frameDuration, freqMin, freqMax, sr];
    introText   = BuildModelIntroText[nFlips, thetaAlt, thetaTrue];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft   = Join[introBuffer, pauseBuffer, modelAudio["left"]];
    finalRight  = Join[introBuffer, pauseBuffer, modelAudio["right"]];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    PrintModelSummary[modelSeq, thetaAlt, thetaTrue, modelAudio["crossOneIdx"], modelAudio["crossTwoIdx"]];
    Print[""];

    Print["[4/", $nSteps5, "] Rendering animation..."];
    STEMSay["Rendering the Bayes factor meter"];
    nFramesRendered = AnimateModel[modelFlips, modelSeq, outGIF, 60];
    STEMDescribeGIF[outGIF, nFramesRendered, 10];
    Print[""];

    Print["[5/", $nSteps5, "] Exporting data table..."];
    ExportModelCSV[modelSeq, modelAudio, outCSV];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"coin\", \"gaussian\", or \"model\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Bayesian inference sonification complete. Play audio: " <> STEMPlayCmd[outWAV]]

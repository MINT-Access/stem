#!/usr/bin/env wolframscript

(* bayes/experiments.wl — Curated preset runs for Bayesian inference.
   Each experiment calls the same pipeline as main.wl and writes its
   outputs to bayes/output/, including the prepended spoken intro. *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, thetaTrue, thetaAlt, muTrue, mu0, sigma0, sigmaObs, nFlips, nObs,
          randomSeed, frameDuration, freqMin, freqMax, nBins, summaryGainDb, sr,
          outWAV, outGIF, outCSV,
          flips, coinSeq, coinAudio, gaussObs, gaussSeq, gaussAudio, muLo, muHi,
          modelFlips, modelSeq, modelAudio,
          introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec,
          audioFreqThetaTrue, audioFreqMu0, audioFreqMuTrue},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["bayes", {}], overrides];

    mode          = GetCfg[cfg, {"simulation", "mode"},                        "coin"];
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

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "coin",
        flips   = GenerateCoinFlips[nFlips, thetaTrue, randomSeed];
        coinSeq = CoinPosteriorSequence[flips];
        coinAudio = BuildCoinAudio[coinSeq, nBins, freqMin, freqMax, frameDuration, summaryGainDb, sr];
        audioFreqThetaTrue = freqMin * (freqMax / freqMin)^thetaTrue;
        introText   = BuildCoinIntroText[thetaTrue, nFlips, audioFreqThetaTrue];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, coinAudio["left"]];
        finalRight  = Join[introBuffer, pauseBuffer, coinAudio["right"]];
        EnsureDir[outWAV];
        ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];
        AnimateCoin[coinSeq, thetaTrue, outGIF, totalDurSec];
        ExportCoinCSV[coinSeq, outCSV],

      mode === "gaussian",
        gaussObs = GenerateGaussianObservations[nObs, muTrue, sigmaObs, randomSeed];
        gaussSeq = GaussianPosteriorSequence[gaussObs, mu0, sigma0, sigmaObs];
        muLo = Min[mu0, muTrue] - 3.0 * sigma0;
        muHi = Max[mu0, muTrue] + 3.0 * sigma0;
        gaussAudio = BuildGaussianAudio[gaussSeq, muLo, muHi, muTrue, sigma0^2, nBins, freqMin, freqMax,
          frameDuration, summaryGainDb, sr];
        audioFreqMu0    = freqMin * (freqMax / freqMin)^Clip[(mu0 - muLo) / (muHi - muLo), {0.0, 1.0}];
        audioFreqMuTrue = freqMin * (freqMax / freqMin)^Clip[(muTrue - muLo) / (muHi - muLo), {0.0, 1.0}];
        introText   = BuildGaussianIntroText[muTrue, mu0, sigma0, sigmaObs, nObs, audioFreqMu0, audioFreqMuTrue];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, gaussAudio["left"]];
        finalRight  = Join[introBuffer, pauseBuffer, gaussAudio["right"]];
        EnsureDir[outWAV];
        ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];
        AnimateGaussian[gaussSeq, muLo, muHi, muTrue, mu0, outGIF, totalDurSec];
        ExportGaussianCSV[gaussSeq, outCSV],

      mode === "model",
        modelFlips = GenerateCoinFlips[nFlips, thetaTrue, randomSeed];
        modelSeq   = ModelPosteriorSequence[modelFlips, 0.5, thetaAlt];
        modelAudio = BuildModelAudio[modelSeq, 0.5, thetaAlt, frameDuration, freqMin, freqMax, sr];
        introText   = BuildModelIntroText[nFlips, thetaAlt, thetaTrue];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, modelAudio["left"]];
        finalRight  = Join[introBuffer, pauseBuffer, modelAudio["right"]];
        EnsureDir[outWAV];
        ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];
        AnimateModel[modelFlips, modelSeq, outGIF, totalDurSec];
        ExportModelCSV[modelSeq, modelAudio, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-4: the recommended listening sequence (LISTENING_GUIDE.md). *)

RunExperiment["coin_biased", <|
  "simulation" -> <| "mode" -> "coin", "bayes" -> <| "theta_true" -> 0.7 |> |>
|>];

RunExperiment["coin_fair", <|
  "simulation" -> <| "mode" -> "coin", "bayes" -> <| "theta_true" -> 0.5 |> |>
|>];

RunExperiment["coin_extreme", <|
  "simulation" -> <| "mode" -> "coin", "bayes" -> <| "theta_true" -> 0.9 |> |>
|>];

RunExperiment["gaussian_default", <|
  "simulation" -> <| "mode" -> "gaussian" |>
|>];

RunExperiment["model_default", <|
  "simulation" -> <| "mode" -> "model" |>
|>];

(* 6. Model mode with a fair true coin -- evidence should drift toward
   H1 instead of H2, a useful contrast against the default. *)
RunExperiment["model_fair_truth", <|
  "simulation" -> <| "mode" -> "model", "bayes" -> <| "theta_true" -> 0.5, "theta_alt" -> 0.7 |> |>
|>];

(* 7. Gaussian mode with mu_true near the prior mean -- a much slower,
   subtler pitch shift than the default mu_true=2.5. *)
RunExperiment["gaussian_near_prior", <|
  "simulation" -> <| "mode" -> "gaussian", "bayes" -> <| "mu_true" -> 0.5 |> |>
|>];

(* 8. Longer coin run -- more flips make the final narrow tone even
   more pronounced. *)
RunExperiment["coin_long_run", <|
  "simulation" -> <| "mode" -> "coin", "bayes" -> <| "theta_true" -> 0.7, "n_flips" -> 200 |> |>
|>];

(* 9. Different random seed -- same theta_true, different flip
   sequence, for comparing run-to-run variability. *)
RunExperiment["coin_alt_seed", <|
  "simulation" -> <| "mode" -> "coin", "bayes" -> <| "theta_true" -> 0.7, "random_seed" -> 123 |> |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

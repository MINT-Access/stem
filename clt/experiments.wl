#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Central Limit Theorem parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own GIF/PNG, WAV, and CSV to output/
   so the results can be compared side by side.
   ======================================================== *)

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

$sr = 44100;
$audioFreqMin = 100.0; $audioFreqMax = 4000.0;
$nSamples = 5000; $nBins = 48; $frameDur = 0.2;

RunToFile[name_String, left_List, right_List] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{left, right}, 0.92], outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];


(* --- sweep_uniform: flat source narrows and smooths --- *)
Print[""];
Print[">>> Experiment: sweep_uniform"];
{domainLo1, domainHi1} = RawMeanDisplayDomain["uniform"];
sweep1 = BuildSweepAudio["uniform", 0.5, 30, $nSamples, $nBins, $audioFreqMin, $audioFreqMax, $frameDur, 42, $sr];
RunToFile["sweep_uniform", sweep1["left"], sweep1["right"]];
AnimateSweep["uniform", 0.5, 30, $nSamples, domainLo1, domainHi1, 42,
             FileNameJoin[{$outDir, "sweep_uniform_animation.gif"}], 30 * $frameDur];
RenderSweepSmallMultiple["uniform", 0.5, 30, $nSamples, domainLo1, domainHi1, 42,
                         FileNameJoin[{$outDir, "sweep_uniform_plot.png"}]];
ExportSweepCSV["uniform", 0.5, 30, $nSamples, domainLo1, domainHi1, $nBins, 42,
               FileNameJoin[{$outDir, "sweep_uniform_stats.csv"}]];

(* --- sweep_exponential: one-sided source, most visibly lopsided at N=1 --- *)
Print[""];
Print[">>> Experiment: sweep_exponential"];
{domainLo2, domainHi2} = RawMeanDisplayDomain["exponential"];
sweep2 = BuildSweepAudio["exponential", 0.5, 30, $nSamples, $nBins, $audioFreqMin, $audioFreqMax, $frameDur, 42, $sr];
RunToFile["sweep_exponential", sweep2["left"], sweep2["right"]];
AnimateSweep["exponential", 0.5, 30, $nSamples, domainLo2, domainHi2, 42,
             FileNameJoin[{$outDir, "sweep_exponential_animation.gif"}], 30 * $frameDur];
RenderSweepSmallMultiple["exponential", 0.5, 30, $nSamples, domainLo2, domainHi2, 42,
                         FileNameJoin[{$outDir, "sweep_exponential_plot.png"}]];
ExportSweepCSV["exponential", 0.5, 30, $nSamples, domainLo2, domainHi2, $nBins, 42,
               FileNameJoin[{$outDir, "sweep_exponential_stats.csv"}]];

(* --- sweep_bernoulli: a biased coin, discrete source at N=1 --- *)
Print[""];
Print[">>> Experiment: sweep_bernoulli"];
{domainLo3, domainHi3} = RawMeanDisplayDomain["bernoulli"];
sweep3 = BuildSweepAudio["bernoulli", 0.3, 30, $nSamples, $nBins, $audioFreqMin, $audioFreqMax, $frameDur, 42, $sr];
RunToFile["sweep_bernoulli", sweep3["left"], sweep3["right"]];
AnimateSweep["bernoulli", 0.3, 30, $nSamples, domainLo3, domainHi3, 42,
             FileNameJoin[{$outDir, "sweep_bernoulli_animation.gif"}], 30 * $frameDur];
RenderSweepSmallMultiple["bernoulli", 0.3, 30, $nSamples, domainLo3, domainHi3, 42,
                         FileNameJoin[{$outDir, "sweep_bernoulli_plot.png"}]];
ExportSweepCSV["bernoulli", 0.3, 30, $nSamples, domainLo3, domainHi3, $nBins, 42,
               FileNameJoin[{$outDir, "sweep_bernoulli_stats.csv"}]];

(* --- compare_default: uniform vs exponential, standardized --- *)
Print[""];
Print[">>> Experiment: compare_default"];
{domainLoC, domainHiC} = StandardizedDisplayDomain[];
compare1 = BuildCompareAudio["uniform", 0.5, "exponential", 0.5, 30, $nSamples, $nBins,
                             $audioFreqMin, $audioFreqMax, $frameDur, 42, $sr];
RunToFile["compare_default", compare1["left"], compare1["right"]];
AnimateCompare["uniform", 0.5, "exponential", 0.5, 30, $nSamples, domainLoC, domainHiC, 42,
               FileNameJoin[{$outDir, "compare_default_animation.gif"}], 30 * $frameDur];
RenderCompareStaticPNG["uniform", 0.5, "exponential", 0.5, 30, $nSamples, domainLoC, domainHiC, 42,
                       FileNameJoin[{$outDir, "compare_default_plot.png"}]];
ExportCompareCSV["uniform", 0.5, "exponential", 0.5, 30, $nSamples, 42,
                 FileNameJoin[{$outDir, "compare_default_stats.csv"}]];

(* --- dice_default: sum of up to 10 fair dice --- *)
Print[""];
Print[">>> Experiment: dice_default"];
{domainLoD, domainHiD} = DiceDisplayDomain[10];
dice1 = BuildDiceAudio[10, $nSamples, $nBins, $audioFreqMin, $audioFreqMax, $frameDur, 42, $sr];
RunToFile["dice_default", dice1["left"], dice1["right"]];
AnimateDice[10, $nSamples, domainLoD, domainHiD, 42,
            FileNameJoin[{$outDir, "dice_default_animation.gif"}], 10 * $frameDur];
RenderDiceSmallMultiple[10, $nSamples, domainLoD, domainHiD, 42, FileNameJoin[{$outDir, "dice_default_plot.png"}]];
ExportDiceCSV[10, $nSamples, 42, FileNameJoin[{$outDir, "dice_default_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

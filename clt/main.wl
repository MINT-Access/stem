#!/usr/bin/env wolframscript

(* ========================================================
   Central Limit Theorem — Entry Point

   Sonifies the Central Limit Theorem: sums/means of independent random
   variables become approximately Gaussian, regardless of the source
   distribution's own shape. The most accessible statistics app in
   this batch -- no physics background needed.

   Usage:
     wolframscript -file main.wl                                          # sweep, uniform source
     wolframscript -file main.wl -- --simulation.clt.source=exponential
     wolframscript -file main.wl -- --simulation.clt.source=bernoulli \
                                     --simulation.clt.bernoulli_p=0.3
     wolframscript -file main.wl -- --simulation.mode=compare              # uniform vs exponential, binaural
     wolframscript -file main.wl -- --simulation.mode=dice                 # sum of N fair dice
     wolframscript -file main.wl -- --config-dump

   Modes:
     sweep (default) -- raw sample mean of N draws from one source,
                        N=1..n_max; narrows AND smooths into a bell shape
     compare           -- binaural: two sources' STANDARDIZED sample
                        means sweep simultaneously, converging to the
                        same shape despite starting completely different
     dice               -- sum (not mean) of N fair six-sided dice;
                        shape smooths even though spread GROWS with N

   Outputs (clt/output/):
     sweep_audio.wav / sweep.gif / sweep.png / sweep_data.csv
     compare_audio.wav / compare.gif / compare.png / compare_data.csv
     dice_audio.wav / dice.gif / dice.png / dice_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =). *)
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

cfg  = LoadConfig["clt", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "sweep"];

sr           = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
nSamples     = GetCfg[cfg, {"simulation", "clt", "n_samples"},     5000];
nBins        = GetCfg[cfg, {"simulation", "clt", "n_bins"},        48];
audioFreqMin = N @ GetCfg[cfg, {"simulation", "clt", "audio_freq_min"}, 100];
audioFreqMax = N @ GetCfg[cfg, {"simulation", "clt", "audio_freq_max"}, 4000];
frameDur     = N @ GetCfg[cfg, {"simulation", "clt", "frame_duration"}, 0.2];
randomSeed   = GetCfg[cfg, {"simulation", "clt", "random_seed"},   42];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

STEMHeading["Central Limit Theorem: " <> Capitalize[mode]];
Print["  Mode: ", mode];
Print[""];

Print["Correctness checks..."];
PrintCltChecks[];
Print[""];

Which[

  (* ══════════════════════════════════════════════════════
     SWEEP MODE
     ══════════════════════════════════════════════════════ *)
  mode === "sweep",

    source   = GetCfg[cfg, {"simulation", "clt", "source"}, "uniform"];
    bernP    = N @ GetCfg[cfg, {"simulation", "clt", "bernoulli_p"}, 0.5];
    nMax     = GetCfg[cfg, {"simulation", "clt", "n_max"}, 30];
    {domainLo, domainHi} = RawMeanDisplayDomain[source, bernP];

    Print["  Source: ", source, "  N: 1 -> ", nMax, "  Monte Carlo samples/step: ", nSamples];
    Print[""];

    Print["[1/4] Building spectral sweep (Monte Carlo)..."];
    sweepAudio = BuildSweepAudio[source, bernP, nMax, nSamples, nBins, audioFreqMin, audioFreqMax,
                                 frameDur, randomSeed, sr];
    PrintSweepSummary[source, nMax, domainLo, domainHi,
                      First[sweepAudio["empMeans"]], First[sweepAudio["empVars"]],
                      Last[sweepAudio["empMeans"]], Last[sweepAudio["empVars"]]];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportSweepCSV[source, bernP, nMax, nSamples, domainLo, domainHi, nBins, randomSeed,
                   FileNameJoin[{$outDir, "sweep_data.csv"}]];
    Print[""];

    Print["[3/4] Rendering animation and static plot..."];
    STEMSay["Rendering the sample mean animation"];
    (* targetDuration = nMax*frameDur, the sonified content's own length --
       matches sweepAudio's actual "left"/"right" duration, deliberately
       excluding the spoken intro/pause main.wl prepends below (see
       animate.wl's file header and AGENTS.md's duration-sync note). *)
    {nFrames, gifFps} = AnimateSweep[source, bernP, nMax, nSamples, domainLo, domainHi, randomSeed,
                                     FileNameJoin[{$outDir, "sweep.gif"}], nMax * frameDur];
    STEMDescribeGIF[FileNameJoin[{$outDir, "sweep.gif"}], nFrames, gifFps];
    RenderSweepSmallMultiple[source, bernP, nMax, nSamples, domainLo, domainHi, randomSeed,
                             FileNameJoin[{$outDir, "sweep.png"}]];
    Print[""];

    Print["[4/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the Central Limit Theorem"];
    introText = BuildSweepIntroText[source, nMax];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, sweepAudio["left"]];
    finalRight = Join[introBuffer, pauseBuf, sweepAudio["right"]];
    outWAV = FileNameJoin[{$outDir, "sweep_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],


  (* ══════════════════════════════════════════════════════
     COMPARE MODE
     ══════════════════════════════════════════════════════ *)
  mode === "compare",

    sourceLeft  = GetCfg[cfg, {"simulation", "clt", "source_left"},  "uniform"];
    sourceRight = GetCfg[cfg, {"simulation", "clt", "source_right"}, "exponential"];
    bernP       = N @ GetCfg[cfg, {"simulation", "clt", "bernoulli_p"}, 0.5];
    nMax        = GetCfg[cfg, {"simulation", "clt", "n_max"}, 30];
    {domainLo, domainHi} = StandardizedDisplayDomain[];

    Print["  Left: ", sourceLeft, "   Right: ", sourceRight, "   N: 1 -> ", nMax];
    Print[""];

    Print["[1/4] Building binaural standardized spectral sweep (Monte Carlo)..."];
    compareAudio = BuildCompareAudio[sourceLeft, bernP, sourceRight, bernP, nMax, nSamples, nBins,
                                     audioFreqMin, audioFreqMax, frameDur, randomSeed, sr];
    PrintCompareSummary[sourceLeft, sourceRight, nMax,
                        First[compareAudio["kurtLeft"]], First[compareAudio["kurtRight"]],
                        Last[compareAudio["kurtLeft"]], Last[compareAudio["kurtRight"]]];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportCompareCSV[sourceLeft, bernP, sourceRight, bernP, nMax, nSamples, randomSeed,
                     FileNameJoin[{$outDir, "compare_data.csv"}]];
    Print[""];

    Print["[3/4] Rendering animation and static plot..."];
    STEMSay["Rendering the shape-convergence animation"];
    {nFrames, gifFps} = AnimateCompare[sourceLeft, bernP, sourceRight, bernP, nMax, nSamples,
                                       domainLo, domainHi, randomSeed,
                                       FileNameJoin[{$outDir, "compare.gif"}], nMax * frameDur];
    STEMDescribeGIF[FileNameJoin[{$outDir, "compare.gif"}], nFrames, gifFps];
    RenderCompareStaticPNG[sourceLeft, bernP, sourceRight, bernP, nMax, nSamples, domainLo, domainHi,
                           randomSeed, FileNameJoin[{$outDir, "compare.png"}]];
    Print[""];

    Print["[4/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the shape convergence, binaural"];
    introText = BuildCompareIntroText[sourceLeft, sourceRight, nMax];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, compareAudio["left"]];
    finalRight = Join[introBuffer, pauseBuf, compareAudio["right"]];
    outWAV = FileNameJoin[{$outDir, "compare_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],


  (* ══════════════════════════════════════════════════════
     DICE MODE
     ══════════════════════════════════════════════════════ *)
  mode === "dice",

    (* Deliberately the SAME config key as sweep/compare's n_max, with
       a smaller inline default (10, not 30) -- dice sums are visibly
       bell-shaped much sooner than abstract sources. This only works
       because clt/config.json does NOT declare "n_max" at all: if it
       did, that value would win over every mode's own inline GetCfg
       default (config.json outranks the hardcoded fallback in the
       4-layer merge), silently making dice mode use 30 regardless of
       the default written here -- exactly the bug an earlier version
       of this app had, caught only by actually running dice mode and
       noticing n_max=30 in the printed summary instead of 10. *)
    nMax = GetCfg[cfg, {"simulation", "clt", "n_max"}, 10];
    {domainLo, domainHi} = DiceDisplayDomain[nMax];

    Print["  Fair six-sided dice, N: 1 -> ", nMax];
    Print[""];

    Print["[1/4] Building spectral sweep (Monte Carlo)..."];
    diceAudio = BuildDiceAudio[nMax, nSamples, nBins, audioFreqMin, audioFreqMax, frameDur,
                               randomSeed, sr];
    PrintDiceSummary[nMax, First[diceAudio["empMeans"]], First[diceAudio["empVars"]],
                     Last[diceAudio["empMeans"]], Last[diceAudio["empVars"]]];
    Print[""];

    Print["[2/4] Exporting data table..."];
    ExportDiceCSV[nMax, nSamples, randomSeed, FileNameJoin[{$outDir, "dice_data.csv"}]];
    Print[""];

    Print["[3/4] Rendering animation and static plot..."];
    STEMSay["Rendering the dice sum animation"];
    {nFrames, gifFps} = AnimateDice[nMax, nSamples, domainLo, domainHi, randomSeed,
                                    FileNameJoin[{$outDir, "dice.gif"}], nMax * frameDur];
    STEMDescribeGIF[FileNameJoin[{$outDir, "dice.gif"}], nFrames, gifFps];
    RenderDiceSmallMultiple[nMax, nSamples, domainLo, domainHi, randomSeed,
                            FileNameJoin[{$outDir, "dice.png"}]];
    Print[""];

    Print["[4/4] Synthesising audio with spoken intro..."];
    STEMSay["Sonifying the sum of fair dice"];
    introText = BuildDiceIntroText[nMax];
    Print["  Spoken intro: ", introText];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuf = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuf, diceAudio["left"]];
    finalRight = Join[introBuffer, pauseBuf, diceAudio["right"]];
    outWAV = FileNameJoin[{$outDir, "dice_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{finalLeft, finalRight}, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[Length[finalLeft]] / sr];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"sweep\", \"compare\", or \"dice\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Central Limit Theorem sonification complete. Play audio: " <>
        STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

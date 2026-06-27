#!/usr/bin/env wolframscript

(* ========================================================
   Signal Processing — Entry Point

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode=chord
     wolframscript -file main.wl -- --simulation.mode=sweep
     wolframscript -file main.wl -- --simulation.mode=am
     wolframscript -file main.wl -- --simulation.chord.noise_level=0.6

   Modes:
     chord  — sum of sinusoids; Fourier extracts individual tones
     sweep  — linear frequency chirp; Fourier shows the ramp
     am     — amplitude modulation; Fourier separates carrier + sidebands

   Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "analyze.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

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

cfg  = LoadConfig["signal", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "chord"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

Which[

  (* ══════════════════════════════════════════════════════
     CHORD MODE
     ══════════════════════════════════════════════════════ *)
  mode === "chord",

    With[{
      freqs  = GetCfg[cfg, {"simulation","chord","frequencies"}, {261.63, 329.63, 392.00}],
      amps   = GetCfg[cfg, {"simulation","chord","amplitudes"},  {1.0, 0.8, 0.6}],
      dur    = GetCfg[cfg, {"simulation","chord","duration"},    3.0],
      noise  = GetCfg[cfg, {"simulation","chord","noise_level"}, 0.4]
    },

    STEMHeading["Signal Processing: Chord (Fourier Analysis)"];
    Print["  Frequencies:  ", StringRiffle[Map[ToString[#] <> " Hz" &, freqs], ", "]];
    Print["  Amplitudes:   ", StringRiffle[Map[ToString, amps], ", "]];
    Print["  Duration:     ", dur, " s"];
    Print["  Noise level:  ", noise];
    Print[""]];

    STEMSay["Generating chord signal"];
    Print["[1/5] Generating signal..."];
    signal = ChordModel[cfg];
    Print["  Clean samples: ", Length[signal["clean"]]];
    Print[""];

    Print["[2/5] Fourier analysis and filtering..."];
    analysis = FourierAnalysis[signal, cfg];
    STEMPrintN["SNR before filtering", analysis["snr_before"], "dB", {5, 1}];
    STEMPrintN["SNR after filtering",  analysis["snr_after"],  "dB", {5, 1}];
    STEMPrintN["SNR improvement",
      analysis["snr_after"] - analysis["snr_before"], "dB", {5, 1}];
    Print["  Detected peaks: ", Length[analysis["recovered_frequencies"]]];
    If[Length[analysis["recovered_frequencies"]] > 0,
      Print["  Peak frequencies (Hz): ",
        StringRiffle[
          Map[ToString[Round[#[[1]], 0.1]] &,
              analysis["recovered_frequencies"]], ", "]]];
    Print[""];

    Print["[3/5] Exporting spectrum CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "chord_spectrum.csv"}],
      fa = analysis["freq_axis"],
      pc = analysis["spectrum_clean"],
      pn = analysis["spectrum_noisy"],
      pr = analysis["spectrum_recovered"]},
      ExportCSV[
        Join[{{"frequency_hz","power_clean","power_noisy","power_recovered"}},
          Table[{fa[[k]], pc[[k]], pn[[k]], pr[[k]]}, {k, Length[fa]}]],
        csvPath];
      STEMDescribeCSV[csvPath, Length[fa], 4]];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    AnimateSignal[analysis, cfg, $outDir];
    Print[""];

    Print["[5/5] Exporting audio..."];
    STEMSay["Exporting audio"];
    SonifySignal[analysis, cfg, $outDir];

    With[{
      snrImprovement = analysis["snr_after"] - analysis["snr_before"],
      nDetected = CountCorrectPeaks[
                    analysis["recovered_frequencies"],
                    N[GetCfg[cfg, {"simulation","chord","frequencies"}, {261.63, 329.63, 392.00}]]],
      nKnown = Length[GetCfg[cfg, {"simulation","chord","frequencies"}, {261.63, 329.63, 392.00}]]},
      Print[""];
      STEMHeading["Done"];
      STEMSay["Signal recovered. Noise reduced by " <>
        ToString[Round[snrImprovement, 0.1]] <>
        " decibels. " <> ToString[nDetected] <> " of " <> ToString[nKnown] <>
        " frequency components correctly identified."]],


  (* ══════════════════════════════════════════════════════
     SWEEP MODE
     ══════════════════════════════════════════════════════ *)
  mode === "sweep",

    With[{
      f0    = GetCfg[cfg, {"simulation","sweep","start_hz"},    100.0],
      f1    = GetCfg[cfg, {"simulation","sweep","end_hz"},      2000.0],
      dur   = GetCfg[cfg, {"simulation","sweep","duration"},    4.0],
      noise = GetCfg[cfg, {"simulation","sweep","noise_level"}, 0.3]
    },

    STEMHeading["Signal Processing: Frequency Sweep (Fourier Analysis)"];
    Print["  Sweep range:  ", f0, " — ", f1, " Hz"];
    Print["  Duration:     ", dur, " s"];
    Print["  Noise level:  ", noise];
    Print[""]];

    STEMSay["Generating frequency sweep"];
    Print["[1/5] Generating signal..."];
    signal = SweepModel[cfg];
    Print["  Clean samples: ", Length[signal["clean"]]];
    Print[""];

    Print["[2/5] Fourier analysis and filtering..."];
    analysis = FourierAnalysis[signal, cfg];
    STEMPrintN["SNR before filtering", analysis["snr_before"], "dB", {5, 1}];
    STEMPrintN["SNR after filtering",  analysis["snr_after"],  "dB", {5, 1}];
    STEMPrintN["SNR improvement",
      analysis["snr_after"] - analysis["snr_before"], "dB", {5, 1}];
    Print[""];

    Print["[3/5] Exporting spectrum CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "sweep_spectrum.csv"}],
      fa = analysis["freq_axis"],
      pc = analysis["spectrum_clean"],
      pn = analysis["spectrum_noisy"],
      pr = analysis["spectrum_recovered"]},
      ExportCSV[
        Join[{{"frequency_hz","power_clean","power_noisy","power_recovered"}},
          Table[{fa[[k]], pc[[k]], pn[[k]], pr[[k]]}, {k, Length[fa]}]],
        csvPath];
      STEMDescribeCSV[csvPath, Length[fa], 4]];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    AnimateSignal[analysis, cfg, $outDir];
    Print[""];

    Print["[5/5] Exporting audio..."];
    STEMSay["Exporting audio"];
    SonifySignal[analysis, cfg, $outDir];
    Print[""];
    STEMHeading["Done"];
    STEMSay["Sweep recovered. SNR improvement: " <>
      ToString[Round[analysis["snr_after"] - analysis["snr_before"], 0.1]] <>
      " decibels."],


  (* ══════════════════════════════════════════════════════
     AM MODE
     ══════════════════════════════════════════════════════ *)
  mode === "am",

    With[{
      fc    = GetCfg[cfg, {"simulation","am","carrier_hz"},       440.0],
      fm    = GetCfg[cfg, {"simulation","am","modulator_hz"},     4.0],
      m     = GetCfg[cfg, {"simulation","am","modulation_depth"}, 0.8],
      dur   = GetCfg[cfg, {"simulation","am","duration"},         3.0],
      noise = GetCfg[cfg, {"simulation","am","noise_level"},      0.35]
    },

    STEMHeading["Signal Processing: Amplitude Modulation (Fourier Analysis)"];
    Print["  Carrier:      ", fc, " Hz"];
    Print["  Modulator:    ", fm, " Hz  (sidebands at ", fc-fm, " and ", fc+fm, " Hz)"];
    Print["  Mod depth:    ", m];
    Print["  Duration:     ", dur, " s"];
    Print["  Noise level:  ", noise];
    Print[""]];

    STEMSay["Generating AM signal"];
    Print["[1/5] Generating signal..."];
    signal = AMModel[cfg];
    Print["  Clean samples: ", Length[signal["clean"]]];
    Print[""];

    Print["[2/5] Fourier analysis and filtering..."];
    analysis = FourierAnalysis[signal, cfg];
    STEMPrintN["SNR before filtering", analysis["snr_before"], "dB", {5, 1}];
    STEMPrintN["SNR after filtering",  analysis["snr_after"],  "dB", {5, 1}];
    STEMPrintN["SNR improvement",
      analysis["snr_after"] - analysis["snr_before"], "dB", {5, 1}];
    Print["  Detected peaks: ", Length[analysis["recovered_frequencies"]]];
    If[Length[analysis["recovered_frequencies"]] > 0,
      Print["  Peak frequencies (Hz): ",
        StringRiffle[
          Map[ToString[Round[#[[1]], 0.1]] &,
              analysis["recovered_frequencies"]], ", "]]];
    Print[""];

    Print["[3/5] Exporting spectrum CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "am_spectrum.csv"}],
      fa = analysis["freq_axis"],
      pc = analysis["spectrum_clean"],
      pn = analysis["spectrum_noisy"],
      pr = analysis["spectrum_recovered"]},
      ExportCSV[
        Join[{{"frequency_hz","power_clean","power_noisy","power_recovered"}},
          Table[{fa[[k]], pc[[k]], pn[[k]], pr[[k]]}, {k, Length[fa]}]],
        csvPath];
      STEMDescribeCSV[csvPath, Length[fa], 4]];
    Print[""];

    Print["[4/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    AnimateSignal[analysis, cfg, $outDir];
    Print[""];

    Print["[5/5] Exporting audio..."];
    STEMSay["Exporting audio"];
    SonifySignal[analysis, cfg, $outDir];

    With[{
      snrImprovement = analysis["snr_after"] - analysis["snr_before"],
      nDetected = CountCorrectPeaks[
                    analysis["recovered_frequencies"],
                    N[{GetCfg[cfg, {"simulation","am","carrier_hz"}, 440.0] -
                       GetCfg[cfg, {"simulation","am","modulator_hz"}, 4.0],
                       GetCfg[cfg, {"simulation","am","carrier_hz"}, 440.0],
                       GetCfg[cfg, {"simulation","am","carrier_hz"}, 440.0] +
                       GetCfg[cfg, {"simulation","am","modulator_hz"}, 4.0]}]],
      nKnown = 3},
      Print[""];
      STEMHeading["Done"];
      STEMSay["AM signal recovered. Noise reduced by " <>
        ToString[Round[snrImprovement, 0.1]] <>
        " decibels. " <> ToString[nDetected] <> " of " <> ToString[nKnown] <>
        " components correctly identified."]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"chord\", \"sweep\", or \"am\"."];
    Exit[1]
];

STEMSay["Complete. Play audio: afplay " <>
  FileNameJoin[{$outDir, mode <> "_narrative_full.wav"}]]

#!/usr/bin/env wolframscript

(* ========================================================
   Quantum Statistics — Entry Point
   Usage: wolframscript -file main.wl [-- [--key=value ...]]
          wolframscript -file main.wl -- --config-dump
          wolframscript -file main.wl -- --simulation.mode=temperature
          wolframscript -file main.wl -- --simulation.mode fermi_sea
          Note: --key value (space) also accepted in addition to --key=value.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

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
      i++
    ]
  ];
  result
];

cfg  = LoadConfig["quantum_statistics", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"}, "spectrum"];
sr   = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];

STEMHeading["Quantum Statistics"];
Print["  mode: ", mode];
Print[""];

(* ── Correctness checks — always at fixed canonical parameters,
   independent of the active mode's own configured parameters, the
   same convention every prior v1.5.0 app's checks section
   uses. ── *)
Print["[1/5] Correctness checks..."];
STEMSay["Running correctness checks"];
$classicalChk = ClassicalLimitCheck[];
$boundChk     = FermiDiracBoundCheck[];
$stepChk      = FermiDiracStepLimitCheck[];
$divergeChk   = BoseEinsteinDivergenceCheck[];
PrintCorrectnessChecks[$classicalChk, $boundChk, $stepChk, $divergeChk];
Print["    1. Classical limit at (eps-mu)=10*kT: relErr_BE=", FmtN[$classicalChk["relErrBE"], 3],
      "  relErr_FD=", FmtN[$classicalChk["relErrFD"], 3], "  (both < 1e-4)"];
Print["    2. Fermi-Dirac bound: max n_FD over wide sweep = ", FmtN[$boundChk["maxVal"], 8],
      "  n_FD(eps=mu) = ", FmtN[$boundChk["atMu"], 4], "  (exact, < 1 always)"];
Print["    3. T->0 step: n_FD(mu-5kT)=", FmtN[$stepChk["belowMu"], 6], "  n_FD(mu+5kT)=",
      FmtN[$stepChk["aboveMu"], 4], "  10-90 width/kT constant across T = ",
      FmtN[Mean[$stepChk["widthOverKT"]], 6], " (exact: 2*Log[9] = ", FmtN[$stepChk["exactWidthOverKT"], 6], ")"];
Print["    4. Bose-Einstein divergence: grows from ", FmtN[First[$divergeChk["vals"]], 4],
      " to ", FmtN[Last[$divergeChk["vals"]], {9, 1}], " as eps-mu shrinks; domain guard engaged at/below mu: ",
      $divergeChk["guardEngagedAtMu"] && $divergeChk["guardEngagedBelowMu"]];
Print[""];

Which[

  (* ===== spectrum (default) ===== *)
  mode === "spectrum",

    duration = N @ GetCfg[cfg, {"sonification", "duration"}, 8.0];

    spectrumModel = SpectrumModel[cfg];
    PrintSpectrumSummary[spectrumModel];
    Print[""];

    Print["[2/5] Computing occupation numbers..."];
    STEMSay["Computing occupation numbers"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_spectrum.csv"}];
    ExportSpectrumCSV[spectrumModel, outCSV];
    Print[""];

    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_spectrum.wav"}];
    {rawLeft, rawRight} = BuildSpectrumAudio[spectrumModel, 60, duration, sr];
    introText   = BuildSpectrumIntroText[spectrumModel["T"]];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "quantum_statistics_spectrum.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "quantum_statistics_spectrum.png"}];
    {$gifFrames, $gifFps} = AnimateSpectrum[spectrumModel, outGIF, outPNG, wavDuration];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== temperature ===== *)
  mode === "temperature",

    duration = N @ GetCfg[cfg, {"sonification", "duration"}, 8.0];

    temperatureModel = TemperatureModel[cfg];
    PrintTemperatureSummary[temperatureModel];
    Print[""];

    Print["[2/5] Sweeping temperature..."];
    STEMSay["Sweeping temperature"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_temperature.csv"}];
    ExportTemperatureCSV[temperatureModel, outCSV];
    Print[""];

    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_temperature.wav"}];
    {rawLeft, rawRight} = BuildTemperatureAudio[temperatureModel, duration, sr];
    introText   = BuildTemperatureIntroText[];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "quantum_statistics_temperature.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "quantum_statistics_temperature.png"}];
    {$gifFrames, $gifFps} = AnimateTemperature[temperatureModel, outGIF, outPNG, wavDuration];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== fermi_sea ===== *)
  mode === "fermi_sea",

    fermiSeaModel = FermiSeaModel[cfg];
    PrintFermiSeaSummary[fermiSeaModel];
    Print[""];

    Print["[2/5] Computing Fermi-Dirac step at each temperature..."];
    STEMSay["Computing the Fermi sea"];
    Print[""];

    Print["[3/5] Exporting data..."];
    outCSV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_fermi_sea.csv"}];
    ExportFermiSeaCSV[fermiSeaModel, outCSV];
    Print[""];

    Print["[4/5] Synthesising audio..."];
    STEMSay["Synthesising audio"];
    outWAV = FileNameJoin[{$projectRoot, "output", "quantum_statistics_fermi_sea.wav"}];
    {rawLeft, rawRight} = BuildFermiSeaAudio[fermiSeaModel, 220.0, 1400.0, 1.2, sr];
    introText   = BuildFermiSeaIntroText[];
    introBuffer = BuildIntroBuffer[introText, sr];
    introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
    pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
    finalLeft  = Join[introBuffer, pauseBuffer, rawLeft];
    finalRight = Join[introBuffer, pauseBuffer, rawRight];
    EnsureDir[outWAV];
    Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
    wavDuration = N[Length[finalLeft]] / sr;
    STEMDescribeWAV[outWAV, wavDuration];
    Print[""];

    Print["[5/5] Rendering visualisation..."];
    STEMSay["Rendering visualisation"];
    outGIF = FileNameJoin[{$projectRoot, "output", "quantum_statistics_fermi_sea.gif"}];
    outPNG = FileNameJoin[{$projectRoot, "output", "quantum_statistics_fermi_sea.png"}];
    {$gifFrames, $gifFps} = AnimateFermiSea[fermiSeaModel, outGIF, outPNG, wavDuration];
    STEMDescribeGIF[outGIF, $gifFrames, $gifFps];
    Print[""],

  (* ===== unknown mode ===== *)
  True,
    Print["Error: unknown simulation.mode \"", mode, "\" — expected \"spectrum\", \"temperature\", or \"fermi_sea\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: " <> STEMPlayCmd[outWAV]];

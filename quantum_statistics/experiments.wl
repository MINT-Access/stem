#!/usr/bin/env wolframscript

(* quantum_statistics/experiments.wl — Curated runs across all three
   quantum_statistics modes. Each experiment calls the same pipeline as
   main.wl and writes its outputs to quantum_statistics/output/,
   including the prepended spoken intro. *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, sr, duration,
          spectrumModel, temperatureModel, fermiSeaModel,
          outWAV, outGIF, outPNG, outCSV,
          rawLeft, rawRight, introText, introBuffer, pauseBuffer, finalLeft, finalRight, totalDurSec},

    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg = DeepMerge[LoadConfig["quantum_statistics", {}], overrides];

    mode     = GetCfg[cfg, {"simulation", "mode"}, "spectrum"];
    sr       =     GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    duration = N @ GetCfg[cfg, {"sonification", "duration"},     8.0];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];

    Which[

      mode === "spectrum",
        spectrumModel = SpectrumModel[cfg];
        PrintSpectrumSummary[spectrumModel];

        {rawLeft, rawRight} = BuildSpectrumAudio[spectrumModel, 60, duration, sr];
        introText   = BuildSpectrumIntroText[spectrumModel["T"]];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateSpectrum[spectrumModel, outGIF, outPNG];
        ExportSpectrumCSV[spectrumModel, outCSV],

      mode === "temperature",
        temperatureModel = TemperatureModel[cfg];
        PrintTemperatureSummary[temperatureModel];

        {rawLeft, rawRight} = BuildTemperatureAudio[temperatureModel, duration, sr];
        introText   = BuildTemperatureIntroText[];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateTemperature[temperatureModel, outGIF, outPNG];
        ExportTemperatureCSV[temperatureModel, outCSV],

      mode === "fermi_sea",
        fermiSeaModel = FermiSeaModel[cfg];
        PrintFermiSeaSummary[fermiSeaModel];

        {rawLeft, rawRight} = BuildFermiSeaAudio[fermiSeaModel, 220.0, 1400.0, 1.2, sr];
        introText   = BuildFermiSeaIntroText[];
        introBuffer = BuildIntroBuffer[introText, sr];
        introBuffer = If[Length[introBuffer] > 0, NormalizeBuffer[introBuffer, 0.95], introBuffer];
        pauseBuffer = If[Length[introBuffer] > 0, ConstantArray[0.0, Round[sr * 0.4]], {}];
        finalLeft   = Join[introBuffer, pauseBuffer, rawLeft];
        finalRight  = Join[introBuffer, pauseBuffer, rawRight];
        EnsureDir[outWAV];
        Export[outWAV, Sound[SampledSoundList[{finalLeft, finalRight}, sr]], "WAV"];
        totalDurSec = N[Length[finalLeft]] / sr;
        STEMDescribeWAV[outWAV, totalDurSec];

        AnimateFermiSea[fermiSeaModel, outGIF, outPNG];
        ExportFermiSeaCSV[fermiSeaModel, outCSV]
    ];

    Print["  Experiment done: ", name]
  ];


(* ── Experiments ──────────────────────────────────────────────────────
   1-3: the recommended listening sequence (LISTENING_GUIDE.md) — run
   in order to hear the quantum/classical bridge from three angles. *)

RunExperiment["spectrum_default", <|
  "simulation" -> <| "mode" -> "spectrum" |>
|>];

RunExperiment["temperature_default", <|
  "simulation" -> <| "mode" -> "temperature" |>
|>];

RunExperiment["fermi_sea_default", <|
  "simulation" -> <| "mode" -> "fermi_sea" |>
|>];

(* 4. spectrum at a much higher temperature (30000K) — pushes the
   whole default energy range (0.001-2.0 eV) into the moderate-x
   regime where BE's divergence near eps=0 is dramatically more
   pronounced than at the default 300K. *)
RunExperiment["spectrum_hot", <|
  "simulation" -> <|
    "mode" -> "spectrum",
    "quantum_statistics" -> <| "temperature" -> 30000.0 |>
  |>
|>];

(* 5. spectrum at a very low temperature (10K) — everything except the
   very lowest energies collapses toward zero; mostly silence except
   right at the start of the sweep. *)
RunExperiment["spectrum_cold", <|
  "simulation" -> <|
    "mode" -> "spectrum",
    "quantum_statistics" -> <| "temperature" -> 10.0 |>
  |>
|>];

(* 6. temperature mode at a smaller reference energy (0.1 eV instead
   of 1.0 eV) — the same convergence/divergence story, but shifted to
   a lower temperature range since a smaller eps needs less kT to
   reach the same dimensionless x. *)
RunExperiment["temperature_low_energy", <|
  "simulation" -> <|
    "mode" -> "temperature",
    "quantum_statistics" -> <| "reference_energy" -> 0.1 |>
  |>
|>];

(* 7. fermi_sea with a higher Fermi energy (3.0 eV, closer to a real
   metal's conduction-electron scale) and more temperature steps, for
   a smoother sharpen-to-blur sequence. *)
RunExperiment["fermi_sea_metal_scale", <|
  "simulation" -> <|
    "mode" -> "fermi_sea",
    "quantum_statistics" -> <| "reference_energy" -> 3.0, "energy_max" -> 6.0, "n_temp_steps" -> 8 |>
  |>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

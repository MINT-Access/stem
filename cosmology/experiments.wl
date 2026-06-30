#!/usr/bin/env wolframscript

(* cosmology/experiments.wl — Curated preset runs for CMB sonification *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, overrides_Association] :=
  Module[{cfg, mode, src, lMax, skyN, tStr, sr,
          lArr, dlArr, clArr, checks, outWAV, outCSV, outPNG, outGIF},
    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg  = DeepMerge[LoadConfig["cosmology", {}], overrides];
    mode = GetCfg[cfg, {"simulation", "mode"},                         "spectrum"];
    src  = GetCfg[cfg, {"simulation", "cosmology", "source"},          "simulated"];
    lMax = GetCfg[cfg, {"simulation", "cosmology", "l_max"},           2000];
    skyN = GetCfg[cfg, {"simulation", "cosmology", "sky_resolution"},  64];
    tStr = N @ GetCfg[cfg, {"simulation", "cosmology", "time_stretch"}, 1.0];
    sr   = GetCfg[cfg, {"sonification", "sample_rate"},                44100];

    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];
    outPNG = FileNameJoin[{$outDir, name <> ".png"}];
    outGIF = FileNameJoin[{$outDir, name <> ".gif"}];

    {lArr, dlArr, clArr} = LoadSpectrum[src, lMax];
    checks = CMBPhysicsChecks[lArr, dlArr];

    Which[
      mode === "spectrum",
        SonifySpectrum[lArr, dlArr, checks, cfg, outWAV];
        AnimateSpectrum[lArr, dlArr, checks, lMax, outPNG];
        ExportSpectrumData[lArr, dlArr, clArr, checks, outCSV],

      mode === "sky",
        With[{
          hilbertN = Min[8, Max[4, Round[Log2[N[skyN]]]]],
          patchDeg = 20.0, freqLo = 200.0, freqHi = 2000.0
        },
          skyModel = GenerateSkyMap[lArr, clArr, hilbertN,
                                    patchDeg, tStr * 0.008, freqLo, freqHi];
          SonifySkyMap[skyModel, cfg, outWAV];
          AnimateSky[skyModel, outGIF];
          ExportSkyData[skyModel, outCSV, outPNG]
        ]
    ];
    Print["  Experiment done: ", name]
  ];


(* ── Experiments ────────────────────────────────────────────────── *)

(* 1. Spectrum: simulated LCDM (default) — hear acoustic peaks clearly *)
RunExperiment["spectrum_simulated", <|
  "simulation" -> <|"mode" -> "spectrum",
                    "cosmology" -> <|"source" -> "simulated", "l_max" -> 2000|>|>
|>];

(* 2. Spectrum: low l_max (200) — only the first acoustic peak audible *)
RunExperiment["spectrum_first_peak_only", <|
  "simulation" -> <|"mode" -> "spectrum",
                    "cosmology" -> <|"source" -> "simulated", "l_max" -> 400|>|>
|>];

(* 3. Spectrum: slow tempo — 4x slower, better for detailed listening *)
RunExperiment["spectrum_slow", <|
  "simulation" -> <|"mode" -> "spectrum",
                    "cosmology" -> <|"source" -> "simulated",
                                     "l_max" -> 2000,
                                     "time_stretch" -> 4.0|>|>
|>];

(* 4. Sky: small 32x32 patch — fast, shows spatial texture *)
RunExperiment["sky_small", <|
  "simulation" -> <|"mode" -> "sky",
                    "cosmology" -> <|"source" -> "simulated",
                                     "sky_resolution" -> 32|>|>
|>];

(* 5. Sky: 64x64 patch (default resolution) *)
RunExperiment["sky_medium", <|
  "simulation" -> <|"mode" -> "sky",
                    "cosmology" -> <|"source" -> "simulated",
                                     "sky_resolution" -> 64|>|>
|>];

(* 6. Sky: 128x128 patch — longer traversal, more spatial detail *)
RunExperiment["sky_large", <|
  "simulation" -> <|"mode" -> "sky",
                    "cosmology" -> <|"source" -> "simulated",
                                     "sky_resolution" -> 128|>|>
|>];

(* 7. Spectrum: extended to l=3000 — Silk damping tail more pronounced *)
RunExperiment["spectrum_extended", <|
  "simulation" -> <|"mode" -> "spectrum",
                    "cosmology" -> <|"source" -> "simulated", "l_max" -> 3000|>|>
|>];

(* 8. Spectrum: Planck real data (requires network; falls back to simulated) *)
RunExperiment["spectrum_planck", <|
  "simulation" -> <|"mode" -> "spectrum",
                    "cosmology" -> <|"source" -> "planck", "l_max" -> 2000|>|>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

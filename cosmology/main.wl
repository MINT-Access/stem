#!/usr/bin/env wolframscript

(* ========================================================
   Cosmic Microwave Background Sonification — Entry Point

   Sonifies the CMB angular power spectrum C_l, making the
   acoustic peaks of the early universe audible.  The peaks
   arise from sound waves in the photon-baryon plasma before
   recombination (z ~ 1100); their positions and relative
   heights encode the universe's geometry, baryon density,
   and dark matter density.

   Usage:
     wolframscript -file main.wl
     wolframscript -file main.wl -- --simulation.mode=sky
     wolframscript -file main.wl -- --simulation.cosmology.source=planck
     wolframscript -file main.wl -- --simulation.cosmology.l_max=1500
     wolframscript -file main.wl -- --simulation.mode=sky \
       --simulation.cosmology.sky_resolution=128

   Modes:
     spectrum (default) -- traverse D_l = l(l+1)C_l/2pi from l=2
                           to l_max; each acoustic peak is audible
                           as a pitch+volume swell above the
                           Sachs-Wolfe plateau
     sky      -- sonify a simulated flat-sky CMB temperature
                 anisotropy map via Hilbert-curve traversal

   Data sources (--simulation.cosmology.source=):
     simulated (default) -- analytic LCDM approximation; five
                            Gaussian peaks at the correct multipole
                            positions with approximate Planck 2018
                            amplitudes
     planck              -- real Planck 2018 best-fit TT spectrum
                            from the Planck Legacy Archive; falls
                            back to simulated automatically if the
                            fetch fails

   Outputs (cosmology/output/):
     spectrum: cmb_spectrum_audio.wav
               cmb_spectrum.png
               cmb_spectrum_data.csv
     sky:      cmb_sky_audio.wav
               cmb_sky.gif
               cmb_sky.png
               cmb_sky_data.csv
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

Get[FileNameJoin[{$projectRoot, "src", "fetch.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
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

cfg   = LoadConfig["cosmology", $cliArgs];
mode  = GetCfg[cfg, {"simulation", "mode"},                         "spectrum"];
src   = GetCfg[cfg, {"simulation", "cosmology", "source"},          "simulated"];
lMax  = GetCfg[cfg, {"simulation", "cosmology", "l_max"},           2000];
skyN  = GetCfg[cfg, {"simulation", "cosmology", "sky_resolution"},  64];
tStr  = N @ GetCfg[cfg, {"simulation", "cosmology", "time_stretch"}, 1.0];
sr    = GetCfg[cfg, {"sonification", "sample_rate"},                44100];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

outWAV = FileNameJoin[{$outDir, "cmb_" <> mode <> "_audio.wav"}];
outCSV = FileNameJoin[{$outDir, "cmb_" <> mode <> "_data.csv"}];
outPNG = FileNameJoin[{$outDir, "cmb_" <> mode <> ".png"}];
outGIF = FileNameJoin[{$outDir, "cmb_sky.gif"}];

$nSteps = If[mode === "spectrum", 4, 5];

STEMHeading["CMB Power Spectrum Sonification"];
Print["  Mode:   ", mode];
Print["  Source: ", src,
      If[src === "planck", "  (falls back to simulated on failure)", ""]];
Print["  l_max:  ", lMax];
If[mode === "sky",
  Print["  Sky:    ", skyN, " x ", skyN, "  (",
        skyN^2, " pixels,  patch = 20 deg)"]
];
Print[""];

(* ── [1/N] Load power spectrum ──────────────────────────────────── *)
Print["[1/", $nSteps, "] Loading CMB power spectrum..."];
STEMSay["Loading CMB power spectrum"];
{lArr, dlArr, clArr} = LoadSpectrum[src, lMax];
Print[""];

(* ── Physical correctness checks 1-3 (run in both modes) ────────── *)
Print["-- Physical correctness checks --"];
checks = CMBPhysicsChecks[lArr, dlArr];
Print[""];
Do[
  With[{k = k0, li = checks["peakLVals"][[k0]], dli = checks["peakDlVals"][[k0]]},
    Print["  Peak ", k, ": l = ", li,
          "  (theta ~ ", FmtN[180.0/li, {4,1}], " deg)  D_l = ",
          FmtN[dli, 5], " uK^2"]
  ],
  {k0, Min[3, Length[checks["peakLVals"]]]}
];
Print[""];

(* ── Mode dispatch ──────────────────────────────────────────────── *)
Which[

  mode === "spectrum",
    Print["[2/4] Sonifying spectrum  (", Length[lArr], " notes  ",
          FmtN[N[Length[lArr] * tStr * 0.025], {6, 1}], " s)..."];
    STEMSay["Sonifying CMB power spectrum -- listen for the acoustic peaks"];
    SonifySpectrum[lArr, dlArr, checks, cfg, outWAV];

    Print["[3/4] Exporting spectrum plot (PNG)..."];
    AnimateSpectrum[lArr, dlArr, checks, lMax, outPNG];
    Print[""];

    Print["[4/4] Exporting data table (CSV)..."];
    ExportSpectrumData[lArr, dlArr, clArr, checks, outCSV];
    Print[""],

  mode === "sky",
    With[{
      hilbertN = Min[8, Max[4, Round[Log2[N[skyN]]]]],
      patchDeg = 20.0,
      freqLo   = 200.0,
      freqHi   = 2000.0
    },
      With[{actualN = 2^hilbertN},
        Print["[2/5] Generating flat-sky CMB map  (",
              actualN, " x ", actualN, " pixels)..."];
        STEMSay["Generating simulated CMB sky map"];
        skyModel = GenerateSkyMap[lArr, clArr, hilbertN,
                                  patchDeg, tStr * 0.008, freqLo, freqHi];

        Print["[3/5] Sonifying via Hilbert traversal  (",
              actualN^2, " pixels,  ",
              FmtN[N[actualN^2 * tStr * 0.008], {6, 1}], " s)..."];
        STEMSay["Sonifying CMB sky map via Hilbert curve traversal"];
        SonifySkyMap[skyModel, cfg, outWAV];
        Print[""];

        Print["[4/5] Rendering Hilbert traversal animation..."];
        STEMSay["Rendering sky traversal animation"];
        AnimateSky[skyModel, outGIF];
        Print[""];

        Print["[5/5] Exporting map image and data table..."];
        ExportSkyData[skyModel, outCSV, outPNG];
        Print[""]
      ]
    ],

  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" -- expected \"spectrum\" or \"sky\"."];
    Exit[1]
];

Print[""];
STEMHeading["Done"];
STEMSay["CMB sonification complete. Play audio: " <> STEMPlayCmd[outWAV]]

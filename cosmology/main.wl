#!/usr/bin/env wolframscript

(* ========================================================
   Cosmic Microwave Background Sonification — Entry Point

   Sonifies the CMB angular power spectrum C_l, making the
   acoustic peaks of the early universe audible.  The peaks
   arise from sound waves in the photon-baryon plasma before
   recombination (z ≈ 1100); their positions and relative
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
     spectrum (default) — traverse D_l = l(l+1)C_l/2π from l=2
                          to l_max; each acoustic peak is audible
                          as a pitch+volume swell above the
                          Sachs-Wolfe plateau
     sky      — sonify a simulated flat-sky CMB temperature
                anisotropy map via Hilbert-curve traversal

   Data sources (--simulation.cosmology.source=):
     simulated (default) — analytic LCDM approximation; five
                           Gaussian peaks at the correct multipole
                           positions with approximate Planck 2018
                           amplitudes (not a Boltzmann code output)
     planck              — real Planck 2018 best-fit TT spectrum
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

cfg  = LoadConfig["cosmology", $cliArgs];
mode = GetCfg[cfg, {"simulation", "mode"},                        "spectrum"];
src  = GetCfg[cfg, {"simulation", "cosmology", "source"},         "simulated"];
lMax = GetCfg[cfg, {"simulation", "cosmology", "l_max"},          2000];
skyN = GetCfg[cfg, {"simulation", "cosmology", "sky_resolution"}, 64];
tStr = N @ GetCfg[cfg, {"simulation", "cosmology", "time_stretch"}, 1.0];
sr   = GetCfg[cfg, {"sonification", "sample_rate"},               44100];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

(* ── Output file paths ──────────────────────────────────────────── *)
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
  Print["  Sky:    ", skyN, " × ", skyN, "  (",
        skyN^2, " pixels,  patch = 20°)"]
];
Print[""];

(* ================================================================
   ANALYTIC CMB POWER SPECTRUM APPROXIMATION

   D_l = l(l+1) C_l / (2π)  in  μK²

   Physical components:
     1. Sachs-Wolfe plateau (low l, large scales):
        Constant ~1100 μK² for l ≪ 100, decaying for higher l.
     2. Acoustic peaks (l ~ 200-1500):
        Gaussian bumps at the first five harmonic positions.
        Peak positions are set by the sound horizon at last
        scattering (θ_A ≈ 0.82°, l_1 ≈ 220).
        Peak amplitudes approximately match Planck 2018 best-fit.
        The 2nd peak is lower than the 1st due to baryon loading
        (baryons suppress compression peaks that reach maximum
        compression at recombination — the even harmonics).
     3. Silk damping (high l):
        Already encoded in the falling Gaussian tails above l~1000.

   This is NOT a Boltzmann code (CAMB/CLASS) output.  It is an
   analytic approximation for accessible demonstration.  Peak
   positions and relative heights are approximately correct for
   standard flat ΛCDM; fine structure (e.g. exact baryon loading
   asymmetry, reionisation bump) is not reproduced.
   ================================================================ *)

$cmbPeakSpecs = {
  (* {l_center, D_peak [μK²], sigma_l}  —  approximate Planck 2018 values *)
  {220.0,  5400.0,  88.0},   (* 1st peak: θ ≈ 0.82°, sound horizon scale *)
  {540.0,  2500.0, 100.0},   (* 2nd peak: even harmonic — baryon-suppressed *)
  {810.0,  2200.0, 108.0},   (* 3rd peak *)
  {1120.0, 1100.0, 115.0},   (* 4th peak — entering strong Silk damping *)
  {1430.0,  550.0, 122.0}    (* 5th peak — strongly Silk-damped *)
};

SimulatedDl[l_?NumericQ] :=
  With[{lN = N[l]},
    With[{
      sw  = 1100.0 / (1.0 + (lN / 50.0)^2.0),  (* Sachs-Wolfe plateau *)
      bg  = 200.0  * Exp[-(lN / 600.0)^2.0],    (* smooth inter-peak floor *)
      gau = Total @ Map[Function[pk,
              pk[[2]] * Exp[-((lN - pk[[1]])^2) / (2.0 * pk[[3]]^2)]
            ], $cmbPeakSpecs]
    },
      N @ Max[0.0, sw + bg + gau]
    ]
  ]

(* C_l = 2π D_l / (l(l+1)) *)
DlToCl[l_?NumericQ, dl_?NumericQ] :=
  If[N[l] <= 1.0, 0.0, N[2.0 Pi * dl / (N[l] * (N[l] + 1.0))]]

(* ── Planck Legacy Archive fetcher ─────────────────────────────── *)
(* Fetches COM_PowerSpect_CMB-TT-full_R3.01.txt from the PLA.
   Returns {lArr, dlArr} on success, {} on any failure. *)
FetchPlanckSpectrum[lMaxFetch_Integer] :=
  Module[{
    url = "https://pla.esac.esa.int/pla/aio/product-action" <>
          "?COSMOLOGY.FILE_ID=COM_PowerSpect_CMB-TT-full_R3.01.txt",
    raw, lines, dataLines, parsed, lVec, dlVec, keep
  },
    Print["  Fetching Planck 2018 TT spectrum from PLA..."];
    raw = Quiet[URLFetch[url, "Content"]];
    If[!StringQ[raw] || StringLength[raw] < 200,
      Return[{}]
    ];
    (* File format: comment lines start with #, then l  D_l  lower  upper *)
    lines     = StringSplit[raw, "\n"];
    dataLines = Select[lines,
      StringLength[StringTrim[#]] > 0 &&
      !StringStartsQ[StringTrim[#], "#"] &];
    If[Length[dataLines] < 5, Return[{}]];
    parsed = Quiet @ Map[
      Function[line, ToExpression /@ StringSplit[StringTrim[line]]],
      dataLines
    ];
    parsed = Select[parsed,
      ListQ[#] && Length[#] >= 2 &&
      NumericQ[#[[1]]] && NumericQ[#[[2]]] &];
    If[Length[parsed] < 10, Return[{}]];
    lVec  = Round /@ parsed[[All, 1]];   (* l values — should be integers *)
    dlVec = N   @ parsed[[All, 2]];      (* D_l = l(l+1)C_l/2π in μK² *)
    keep  = Select[Range[Length[lVec]], lVec[[#]] <= lMaxFetch &];
    If[Length[keep] < 5, Return[{}]];
    {lVec[[keep]], dlVec[[keep]]}
  ]

(* ================================================================
   [1/N] LOAD POWER SPECTRUM
   ================================================================ *)

Print["[1/", $nSteps, "] Loading CMB power spectrum..."];
STEMSay["Loading CMB power spectrum"];

$lArr = Range[2, lMax];
$nL   = Length[$lArr];

If[src === "planck",
  Module[{result, lPlanck, dlPlanck, clInterp},
    result = FetchPlanckSpectrum[lMax];
    If[Length[result] === 2 && Length[result[[1]]] > 50,
      lPlanck  = N @ result[[1]];
      dlPlanck = N @ result[[2]];
      clInterp = Interpolation[
        Transpose[{lPlanck, dlPlanck}], InterpolationOrder -> 1];
      $dlArr = N @ Map[
        Function[l,
          If[l >= Min[lPlanck] && l <= Max[lPlanck],
            Max[0.0, Quiet[clInterp[N[l]]]],
            SimulatedDl[l]   (* fill gaps outside Planck range *)
          ]
        ],
        N @ $lArr
      ];
      Print["  Planck 2018 data: l = ", Min[lPlanck], " to ", Max[lPlanck],
            "  (", Length[lPlanck], " points)"],
      (* Fetch failed *)
      Print["  [WARNING] Planck fetch failed — using simulated spectrum."];
      $dlArr = N @ Map[SimulatedDl, $lArr]
    ]
  ],
  $dlArr = N @ Map[SimulatedDl, $lArr];
  Print["  Analytic ΛCDM approximation (5-Gaussian-peak model)"]
];

$clArr = N @ MapThread[DlToCl, {$lArr, $dlArr}];

STEMPrintN["D_l range",
  N @ Min[$dlArr],
  "μK²  to  " <> FmtN[N @ Max[$dlArr], 5] <> " μK²", 5];
Print[""];

(* ================================================================
   PHYSICAL CORRECTNESS CHECKS 1–3  (run in both modes)
   ================================================================ *)

Print["-- Physical correctness checks --"];

(* Check 1: D_l ≥ 0 everywhere *)
With[{nNeg = Count[$dlArr, _?(# < 0.0 &)]},
  Print["  [", If[nNeg === 0, "PASS", "FAIL"], "] ",
        "D_l ≥ 0 for all l  (", nNeg, " negative values)"]
];

(* Detect acoustic peaks: local maxima with D_l > 30% of global max *)
$peakIdxs = Module[{thresh = 0.30 * Max[$dlArr]},
  Select[Range[2, $nL - 1], Function[i,
    $dlArr[[i]] > $dlArr[[i - 1]] &&
    $dlArr[[i]] > $dlArr[[i + 1]] &&
    $dlArr[[i]] > thresh
  ]]
];
$peakLVals  = $lArr[[$peakIdxs]];
$peakDlVals = $dlArr[[$peakIdxs]];

(* Check 2: First acoustic peak l ∈ [180, 260] *)
With[{
  lPk1  = If[Length[$peakLVals] > 0, First[$peakLVals], -1],
  found = Length[$peakLVals] > 0
},
  Print["  [", If[found && 180 <= lPk1 <= 260, "PASS", "FAIL"], "] ",
        "First acoustic peak at l = ",
        If[found, ToString[lPk1], "not found"],
        "  (expected 180 – 260)"]
];

(* Check 3: Peak amplitudes decreasing (overall Silk damping trend).
   In the physical spectrum, peak 3 can slightly exceed peak 2 due to
   baryon loading; we test peak1 > last-detected-peak as the robust criterion,
   and report the pairwise status as PASS/WARN rather than aborting. *)
With[{
  mono = Length[$peakDlVals] < 2 ||
         AllTrue[Differences[$peakDlVals], # <= 0.0 &]
},
  Print["  [", If[Length[$peakDlVals] < 2, "PASS",
                  If[First[$peakDlVals] > Last[$peakDlVals], "PASS", "FAIL"]], "] ",
        "Peak 1 amplitude > last detected peak (Silk damping)"];
  If[!mono && Length[$peakDlVals] >= 2,
    Print["  [WARN] Not strictly pairwise decreasing — peak 2 < peak 3 ",
          "is physically expected with baryon loading"]
  ]
];

Print[""];

(* Print first 3 peak positions *)
Do[
  With[{k = k0, li = $peakLVals[[k0]], dli = $peakDlVals[[k0]]},
    Print["  Peak ", k, ": l = ", li,
          "  (θ ≈ ", FmtN[180.0/li, {4,1}], "°)  D_l = ",
          FmtN[dli, 5], " μK²"]
  ],
  {k0, Min[3, Length[$peakLVals]]}
];
Print[""];

(* ================================================================
   MODE DISPATCH
   ================================================================ *)

Which[

  (* ════════════════════════════════════════════════════════════════
     SPECTRUM MODE
     Each multipole l is one note; pitch and volume follow D_l so
     the listener hears swells at each acoustic peak rising above
     the Sachs-Wolfe plateau, with progressive damping.
     ════════════════════════════════════════════════════════════════ *)
  mode === "spectrum",

  Module[{
    noteDur = tStr * 0.025,  (* seconds per multipole step *)
    freqLo  = 80.0,          (* Hz at D_l minimum *)
    freqHi  = 2000.0,        (* Hz at D_l maximum *)
    volLo   = 0.25,
    volHi   = 1.0,
    dlMin, dlMax, dlNorm, peakAccentSet, audioBuffer
  },

    dlMin  = N @ Min[$dlArr];
    dlMax  = N @ Max[$dlArr];
    dlNorm = N[($dlArr - dlMin) / (dlMax - dlMin)];

    (* First 3 peak indices for accent notes *)
    peakAccentSet = If[Length[$peakIdxs] >= 3,
      $peakIdxs[[1 ;; 3]],
      $peakIdxs
    ];

    Print["[2/4] Sonifying spectrum  (", $nL, " notes  ",
          FmtN[N[$nL * noteDur], {6, 1}], " s)..."];
    STEMSay["Sonifying CMB power spectrum — listen for the acoustic peaks"];

    audioBuffer = Flatten @ Table[
      With[{
        norm   = dlNorm[[i]],
        f      = N[freqLo * (freqHi / freqLo)^dlNorm[[i]]],
        v      = N[volLo + dlNorm[[i]] * (volHi - volLo)],
        isPeak = MemberQ[peakAccentSet, i]
      },
        If[isPeak,
          (* Accent at peak: brighter harmonics, louder *)
          StemSynthNote[f, noteDur, Min[1.0, v * 1.4],
                        {1.0, 0.6, 0.4, 0.2}, 0.55, sr],
          StemSynthNote[f, noteDur, v, {1.0, 0.3}, 0.30, sr]
        ]
      ],
      {i, $nL}
    ];

    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[$nL * noteDur]];
    Print["  Pitch: D_l min → ", FmtN[freqLo, 4], " Hz  |  ",
          "D_l max → ", FmtN[freqHi, 5], " Hz  (log-mapped)"];
    Print["  Peak accents at l ≈ ",
          StringRiffle[Map[ToString, Take[$peakLVals, Min[3, Length[$peakLVals]]]], ", "]];
    Print[""];

    (* STEMSay announcements for each acoustic peak *)
    Do[
      STEMSay["Acoustic peak " <> ToString[k] <> ": l equals " <>
        ToString[$peakLVals[[k]]] <> ", angular scale " <>
        FmtN[180.0 / $peakLVals[[k]], {4, 1}] <> " degrees. " <>
        "Power " <> FmtN[$peakDlVals[[k]], 5] <> " microkelvin squared."],
      {k, Min[3, Length[$peakLVals]]}
    ];

    Print["[3/4] Exporting spectrum plot (PNG)..."];
    Module[{logLArr, accentPts, plt},
      logLArr   = N @ Log10[$lArr];
      accentPts = Map[
        Function[i,
          {Directive[Red, PointSize[0.018]],
           Point[{Log10[$lArr[[i]]], $dlArr[[i]]}],
           Text[
             Style["Peak " <> ToString[Position[$peakIdxs, i][[1, 1]]], 8, Red],
             {Log10[$lArr[[i]]], $dlArr[[i]] + 200}
           ]}
        ],
        Take[$peakIdxs, Min[3, Length[$peakIdxs]]]
      ];

      plt = Show[
        ListLinePlot[
          Transpose[{logLArr, $dlArr}],
          PlotStyle  -> {Thickness[0.0018], RGBColor[0.18, 0.42, 0.78]},
          PlotRange  -> {{Log10[2], Log10[lMax]}, {0, Automatic}},
          Frame      -> True,
          FrameLabel -> {"log\[ThinSpace]\!\(\*SubscriptBox[\(10\), \(l\)]\)",
                         "\!\(\*SubscriptBox[\(D\), \(l\)]\)  [\[Mu]\!\(\*SuperscriptBox[\(K\), \(2\)]\)]"},
          PlotLabel  -> Style["CMB Temperature Power Spectrum", 14, Bold],
          GridLines  -> Automatic,
          Background -> White,
          ImageSize  -> {600, 360}
        ],
        Graphics[Flatten[accentPts]]
      ];
      Export[outPNG, plt, "PNG"];
      Print["  PNG: ", outPNG]
    ];
    Print[""];

    Print["[4/4] Exporting data table (CSV)..."];
    Module[{isPeakArr},
      isPeakArr = ConstantArray[0, $nL];
      (* Flag first 3 acoustic peaks *)
      Do[isPeakArr[[idx]] = 1,
         {idx, Take[$peakIdxs, Min[3, Length[$peakIdxs]]]}];
      ExportCSV[
        Join[
          {{"l", "Cl_uK2", "Dl_uK2", "is_peak"}},
          Table[
            {$lArr[[i]], $clArr[[i]], $dlArr[[i]], isPeakArr[[i]]},
            {i, $nL}
          ]
        ],
        outCSV
      ];
      STEMDescribeCSV[outCSV, $nL, 4]
    ];
    Print[""]
  ],

  (* ════════════════════════════════════════════════════════════════
     SKY MODE
     Generates a simulated CMB temperature anisotropy map as a
     Gaussian random field with power spectrum C_l, then sonifies
     it using a Hilbert-curve traversal so spatial proximity in
     the map corresponds to temporal proximity in the audio.
     ════════════════════════════════════════════════════════════════ *)
  mode === "sky",

  Module[{
    patchDeg  = 20.0,         (* flat-sky patch size in degrees *)
    noteDur   = tStr * 0.008, (* seconds per pixel *)
    freqLo    = 200.0,
    freqHi    = 2000.0,
    (* Round sky_resolution to power of 2; clamp to [16, 256] *)
    hilbertN  = Min[8, Max[4, Round[Log2[N[skyN]]]]],
    patchRad, lPerPix, kIdx, lGrid, clGrid, clInterp,
    sigmaGrid, coeffs, mapT,
    traversal, nPix, pixTemps, tNorm,
    audioBuffer,
    nGIFFrames, dispDataRGB, gCoords, frameUpTo, gifFrames
  },

    With[{actualN = 2^hilbertN},

    Print["[2/5] Generating flat-sky CMB map  (",
          actualN, " × ", actualN, " pixels)..."];
    STEMSay["Generating simulated CMB sky map"];

    (* ── Flat-sky Gaussian random field from C_l ──────────────
       A flat-sky patch of angular size θ_patch radians has
       2D Fourier modes at wavevector k (pixel units) corresponding
       to multipole l = |k| × (2π / θ_patch).

       We draw complex Gaussian coefficients a(k) with variance
         Var[a(k)] = C_l(|k|) × N² / θ_patch²  (per real/imag component)
       Then take InverseFourier to get the temperature map.

       With FourierParameters -> {1,-1}:
         T(x) = (1/N²) Σ_k a(k) exp(2πi k·x/N)
       By Parseval, the pixel variance is:
         Var(T) = Σ_k C_l(k) / (N² × θ_patch²)
       which is the expected value used in sanity check 4.
    ──────────────────────────────────────────────────────────── *)
    patchRad = N[patchDeg * Pi / 180.0];
    lPerPix  = N[2.0 Pi / patchRad];

    clInterp = Interpolation[
      Transpose[{N @ $lArr, N @ $clArr}], InterpolationOrder -> 1];

    (* Unshifted k-index arrays for Fourier convention used by WL *)
    kIdx  = N @ Join[Range[0, actualN/2 - 1], Range[-actualN/2, -1]];
    lGrid = Outer[(#1^2 + #2^2)^0.5 * lPerPix &, kIdx, kIdx];

    (* C_l interpolated at each 2D mode *)
    clGrid = Map[
      Function[l,
        If[l < 2.0 || l > Max[$lArr], 0.0,
          N @ Max[0.0, Quiet[clInterp[Min[N[l], N @ Max[$lArr]]]]]
        ]
      ],
      lGrid, {2}
    ];

    (* Gaussian random coefficients; factor N/sqrt(Ω) scales for DFT *)
    sigmaGrid = N @ Sqrt[clGrid / 2.0] * actualN / Sqrt[patchRad^2];
    SeedRandom[271828];
    coeffs = sigmaGrid *
      (RandomVariate[NormalDistribution[0, 1], {actualN, actualN}] +
       I * RandomVariate[NormalDistribution[0, 1], {actualN, actualN}]);

    mapT = N @ Re[InverseFourier[coeffs, FourierParameters -> {1, -1}]];

    STEMPrintN["Map std dev",
      N @ StandardDeviation[Flatten[mapT]], "μK", 5];
    STEMPrintN["Map range",
      N @ Min[Flatten[mapT]],
      "μK  to  " <> FmtN[N @ Max[Flatten[mapT]], 5] <> " μK", 5];
    Print[""];

    (* ── Sanity check 4: map pixel variance vs flat-sky expected ──
       The expected variance from the Fourier construction is exactly
         σ²_expected = Σ_k C_l(k) / (N² × patchRad²)
       where the sum runs over all N² modes in the 2D DFT grid.
       This is what the IFFT produces by Parseval's theorem; the
       check detects implementation bugs (wrong normalisation, etc.).
       The ratio should be close to 1 within ~10% statistical scatter.
    ──────────────────────────────────────────────────────────────── *)
    Print["-- Physical correctness check (4) --"];
    With[{
      varActual   = N @ Variance[Flatten[mapT]],
      varExpected = N @ Total[Flatten[clGrid]] / (actualN^2 * patchRad^2)
    },
      With[{ratio = If[varExpected > 0.0, varActual / varExpected, -1.0]},
        Print["  [", If[0.5 < ratio < 2.0, "PASS", "FAIL"], "] ",
              "Map variance: ", FmtN[varActual, 5], " μK²  ",
              "vs flat-sky Σ_k C_l(k)/(N²Ω) = ", FmtN[varExpected, 5], " μK²  ",
              "(ratio = ", FmtN[ratio, {4, 2}], ")"]
      ]
    ];
    Print[""];

    (* ── Hilbert traversal → audio ────────────────────────────── *)
    Print["[3/5] Sonifying via Hilbert traversal  (",
          actualN^2, " pixels,  ",
          FmtN[N[actualN^2 * noteDur], {6, 1}], " s)..."];
    STEMSay["Sonifying CMB sky map via Hilbert curve traversal"];

    traversal = HilbertTraversalOrder[hilbertN];
    nPix      = Length[traversal];

    pixTemps = Table[
      mapT[[ traversal[[i, 2]], traversal[[i, 1]] ]],
      {i, nPix}
    ];

    With[{tMin = N @ Min[pixTemps], tMax = N @ Max[pixTemps]},
      tNorm = N[(pixTemps - tMin) / Max[tMax - tMin, 1.0*^-10]]
    ];

    audioBuffer = Flatten @ Table[
      StemSynthNote[
        N[freqLo * (freqHi / freqLo)^tNorm[[i]]],
        noteDur, 0.75, {1.0, 0.25}, 0.15, sr],
      {i, nPix}
    ];

    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[nPix * noteDur]];
    Print["  Pitch: cold pixels → ", FmtN[freqLo, 4], " Hz  |  ",
          "hot pixels → ", FmtN[freqHi, 5], " Hz"];
    Print[""];

    (* ── GIF animation ─────────────────────────────────────────── *)
    Print["[4/5] Rendering Hilbert traversal animation..."];
    STEMSay["Rendering sky traversal animation"];

    nGIFFrames = 32;

    (* CMB false-colour: cold=blue, mean=white, hot=red *)
    dispDataRGB = Map[
      Function[row,
        Map[Function[t,
          With[{t1 = Clip[N[t], {0.0, 1.0}]},
            If[t1 < 0.5,
              {2.0*t1,       2.0*t1,       1.0},
              {1.0,    2.0*(1.0-t1), 2.0*(1.0-t1)}
            ]
          ]
        ], row]
      ],
      (* Normalise mapT to [0,1]; reverse rows so top of image = row 1 *)
      Reverse @ N[(mapT - Min[mapT]) / Max[Max[mapT] - Min[mapT], 1.0*^-10]]
    ];

    gCoords   = Map[{#[[1]] - 0.5, actualN - #[[2]] + 0.5} &, traversal];
    frameUpTo = Table[Max[1, Round[k * nPix / nGIFFrames]], {k, nGIFFrames}];

    gifFrames = Table[
      With[{upTo = frameUpTo[[k]]},
        Graphics[{
          Raster[dispDataRGB, {{0, 0}, {actualN, actualN}}],
          {Opacity[0.75], RGBColor[1.0, 0.85, 0.0], Thin, Line[gCoords[[1 ;; upTo]]]},
          {White, Disk[gCoords[[upTo]], 0.65]}
        },
        PlotRange    -> {{0, actualN}, {0, actualN}},
        ImagePadding -> None,
        AspectRatio  -> 1,
        ImageSize    -> 256]
      ],
      {k, nGIFFrames}
    ];

    ExportGIF[gifFrames, outGIF, 10];
    STEMDescribeGIF[outGIF, nGIFFrames, 10];
    Print[""];

    (* ── Static PNG + CSV ─────────────────────────────────────── *)
    Print["[5/5] Exporting map image and data table..."];

    Module[{skyImg},
      skyImg = Image[N[(mapT - Min[mapT]) / Max[Max[mapT] - Min[mapT], 1.0*^-10]]];
      Export[outPNG, skyImg, "PNG"];
      Print["  PNG: ", outPNG]
    ];

    ExportCSV[
      Join[
        {{"hilbert_index", "col", "row", "temperature_uK", "frequency_hz"}},
        Table[
          {i,
           traversal[[i, 1]], traversal[[i, 2]],
           pixTemps[[i]],
           N[freqLo * (freqHi / freqLo)^tNorm[[i]]]},
          {i, nPix}
        ]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nPix, 5];
    Print[""]

    ]  (* end With[{actualN}] *)
  ],  (* end sky Module *)

  (* Unknown mode *)
  True,
  Print["Error: unknown simulation.mode \"", mode,
        "\" — expected \"spectrum\" or \"sky\"."];
  Exit[1]
];

(* ── Done ──────────────────────────────────────────────────────── *)
Print[""];
STEMHeading["Done"];
STEMSay["CMB sonification complete. Play audio: " <> STEMPlayCmd[outWAV]]

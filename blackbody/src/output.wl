(* ========================================================
   blackbody/src/output.wl — CSV export, correctness-check
   printing, and console summaries
   ======================================================== *)


(* ── Correctness checks (PASS/FAIL, printed every run) ─────────────
   All four checks are properties of the Planck formula itself, not
   of any particular mode, so — unlike thermo (whose checks 3-4 are
   mode-specific) — all four run unconditionally on every invocation,
   following hydrogen's pattern (EnergyLevelCheck/RydbergCheck also
   run before the mode dispatch, independent of mode). *)
PrintBlackbodyChecks[T_?NumericQ] :=
  Module[{rj, wien, disp, sb},
    rj   = RayleighJeansCheck[T];
    wien = WienApproxCheck[T];
    disp = WienDisplacementCheck[];
    sb   = StefanBoltzmannCheck[];

    Print["  [", If[rj["pass"], "PASS", "FAIL"], "] Rayleigh-Jeans limit (nu -> 0, T=",
          Round[T], "K): B_exact = ", FmtN[rj["exact"], 5], "  B_RJ = ", FmtN[rj["approx"], 5],
          "  (", FmtN[rj["relError"] * 100, 4], "% error)"];

    Print["  [", If[wien["pass"], "PASS", "FAIL"], "] Wien approximation (h*nu/kT=",
          Round[wien["xTest"]], ", T=", Round[T], "K): B_exact = ", FmtN[wien["exact"], 5],
          "  B_Wien = ", FmtN[wien["approx"], 5], "  (", FmtN[wien["relError"] * 100, 6], "% error)"];

    Print["  [", If[disp["pass"], "PASS", "FAIL"], "] Wien's displacement law: lambda_peak*T ",
          "matches b=", FmtN[$WienB, 6], " m*K within ",
          FmtN[Max[disp["relErrors"]] * 100, 4], "% (checked at T = ",
          StringRiffle[Map[ToString[Round[#]] &, disp["Ts"]], ", "], " K)"];

    Print["  [", If[sb["pass"], "PASS", "FAIL"], "] Stefan-Boltzmann law: integral ratio at T1=",
          Round[sb["T1"]], "K/T2=", Round[sb["T2"]], "K = ", FmtN[sb["ratio"], 6],
          "  vs (T1/T2)^4 = ", FmtN[sb["expected"], 6],
          "  (", FmtN[sb["relError"] * 100, 4], "% error)"];

    {rj, wien, disp, sb}
  ];


(* ── CSV export ───────────────────────────────────────────────────── *)

(* ExportSpectrumCSV — columns: bin, nu_Hz, lambda_nm, B_relative,
   audio_freq_hz, is_visible_edge (1 for the two bins nearest the
   400/700nm band edges, else 0) *)
ExportSpectrumCSV[spectrumResult_Association, outCSV_String] :=
  Module[{spec, nBins, header, rows},
    spec   = spectrumResult["spec"];
    nBins  = spectrumResult["nBins"];
    header = {{"bin", "nu_Hz", "lambda_nm", "B_relative", "audio_freq_hz", "is_visible_edge"}};
    rows = Table[
      {i - 1, spec["nuBins"][[i]], ($SpeedC / spec["nuBins"][[i]]) * 1.0*^9,
       spec["amps"][[i]], spec["audioFreqs"][[i]],
       If[i === spectrumResult["visLoIdx"] || i === spectrumResult["visHiIdx"], 1, 0]},
      {i, nBins}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, nBins, 6]
  ];

(* ExportTemperatureCSV — columns: step, T_K, peak_freq_hz,
   peak_wavelength_nm, loudness_scale *)
ExportTemperatureCSV[tempResult_Association, outCSV_String] :=
  Module[{TVals, peakFreqs, loudness, n, header, rows},
    TVals     = tempResult["TVals"];
    peakFreqs = tempResult["peakFreqs"];
    loudness  = tempResult["loudness"];
    n = Length[TVals];
    header = {{"step", "T_K", "peak_freq_hz", "peak_wavelength_nm", "loudness_scale"}};
    rows = Table[
      {i - 1, TVals[[i]], peakFreqs[[i]], ($SpeedC / peakFreqs[[i]]) * 1.0*^9, loudness[[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];

(* ExportStarCSV — long format: preset, T_K, bin, nu_Hz, B_relative,
   one block of nBins rows per preset, in tour order. *)
ExportStarCSV[order_List, presets_Association, nBins_Integer,
             nuMin_?NumericQ, nuMax_?NumericQ, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
             outCSV_String] :=
  Module[{header, rows},
    header = {{"preset", "T_K", "bin", "nu_Hz", "B_relative"}};
    rows = Flatten[
      Table[
        Module[{T = presets[key], spec},
          spec = BlackbodySpectrumBins[T, nBins, nuMin, nuMax, audioFreqMin, audioFreqMax];
          Table[{key, T, i - 1, spec["nuBins"][[i]], spec["amps"][[i]]}, {i, nBins}]
        ],
        {key, order}
      ],
      1
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 5]
  ];


(* ── Console summaries ───────────────────────────────────────────── *)

PrintSpectrumSummary[spectrumResult_Association, T_?NumericQ] :=
  Module[{spec},
    spec = spectrumResult["spec"];
    STEMSection["Spectrum Summary"];
    STEMPrintN["Temperature", T, "K"];
    STEMPrintN["Peak (Wien's law)", spectrumResult["peakFreq"], "Hz (audio)", 4];
    Print["  Visible-band bins: ", spectrumResult["visLoIdx"] - 1, " (700nm) to ",
          spectrumResult["visHiIdx"] - 1, " (400nm) of ", spectrumResult["nBins"] - 1];
    Print["  Physical sweep: ", FmtN[spectrumResult["nuMin"], 4], " Hz -> ",
          FmtN[spectrumResult["nuMax"], 4], " Hz"]
  ];

PrintTemperatureSummary[tempResult_Association] :=
  Module[{TVals, peakFreqs},
    TVals     = tempResult["TVals"];
    peakFreqs = tempResult["peakFreqs"];
    STEMSection["Temperature Summary"];
    STEMPrintN["Temperature range", First[TVals], "K \[LongDash] " <> FmtN[Last[TVals], 5] <> " K", 5];
    STEMPrintN["Temperature steps", Length[TVals]];
    Print["  Peak wavelength: ", FmtN[($SpeedC / First[peakFreqs]) * 1.0*^9, 5], " nm -> ",
          FmtN[($SpeedC / Last[peakFreqs]) * 1.0*^9, 5], " nm"];
    Print["  Loudness scale:  ", FmtN[First[tempResult["loudness"]], 4], " -> ",
          FmtN[Last[tempResult["loudness"]], 4]]
  ];

PrintStarSummary[order_List, presets_Association] :=
  Module[{},
    STEMSection["Star Tour Summary"];
    Scan[
      Function[key,
        Print["  ", StarDisplayName[key], ": ", Round[presets[key]], " K  (peak ",
              FmtN[WienPeakWavelength[presets[key]] * 1.0*^9, 4], " nm)"]
      ],
      order
    ]
  ];

(* ========================================================
   hydrogen/src/output.wl — CSV export and correctness-check printing
   ======================================================== *)


(* ── Correctness checks (PASS/FAIL, printed every run) ───────────── *)

PrintEnergyLevelCheck[] :=
  Module[{check},
    check = EnergyLevelCheck[];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Energy levels: E_n = -13.6057/n^2 eV ",
          "for n=1..4, max error ", FmtN[Max[check["errors"]], 4], " eV"];
    check
  ];

PrintRydbergCheck[] :=
  Module[{check},
    check = RydbergCheck[0.001];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Rydberg check: H-alpha (n=3->2) wavelength = ",
          FmtN[check["lambda_nm"], {7, 3}], " nm  (reference ", check["expected_nm"],
          " nm, error ", FmtN[check["relError"] * 100, 4], "%)"];
    check
  ];

PrintWaveFunctionCheck[orbitalKey_String] :=
  Module[{check},
    check = WaveFunctionNormalizationCheck[orbitalKey];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Wave function normalisation (",
          orbitalKey, "): 3D integral = ", FmtN[check["threeDInt"], 6],
          " (expected 1.0, error ", FmtN[check["err3D"] * 100, 4], "%);  ",
          "grid-vs-continuum 2D cross-section agreement: ", FmtN[check["err2D"] * 100, 4], "%"];
    check
  ];

PrintSelectionRuleCheck[cascadeSteps_List] :=
  Module[{check},
    check = SelectionRuleCheck[cascadeSteps];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Selection rule: every cascade step has ",
          "|\[CapitalDelta]l| = 1  (", check["nSteps"], " steps checked, ",
          "observed \[CapitalDelta]l values: ", DeleteDuplicates[check["deltaLs"]], ")"];
    check
  ];


(* ── CSV export ────────────────────────────────────────────────────
   Columns match the spec exactly (see hydrogen/AGENTS.md). *)

ExportOrbitalsCSV[orbitalModel_Association, freqs_List, amps_List, outCSV_String] :=
  Module[{traversal, xVals, zVals, density, nPixels, header, rows},
    traversal = orbitalModel["traversal"];
    xVals     = orbitalModel["xVals"];
    zVals     = orbitalModel["zVals"];
    density   = orbitalModel["density"];
    nPixels   = orbitalModel["nPixels"];
    header = {{"hilbert_index", "x", "z", "r", "psi_squared", "pitch_hz", "amplitude"}};
    rows = Table[
      With[{col = traversal[[i, 1]], row = traversal[[i, 2]]},
        With[{x = xVals[[col]], z = zVals[[row]]},
          {i - 1, x, z, Sqrt[x^2 + z^2], density[[row, col]], freqs[[i]], amps[[i]]}
        ]
      ],
      {i, nPixels}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, nPixels, 7]
  ];

ExportSpectrumCSV[spectrumResult_Association, outCSV_String] :=
  Module[{lines, audioFreqs, amps, header, rows, n},
    lines      = spectrumResult["lines"];
    audioFreqs = spectrumResult["audioFreqs"];
    amps       = spectrumResult["amps"];
    n = Length[lines];
    header = {{"n_upper", "n_lower", "series_name", "lambda_nm", "nu_THz",
                "nu_audio_hz", "amplitude", "einstein_A"}};
    rows = Table[
      With[{ln = lines[[i]]},
        {ln["n_upper"], ln["n_lower"], ln["series"], ln["lambda_nm"], ln["nu_THz"],
         audioFreqs[[i]], amps[[i]], ln["einstein_A"]}
      ],
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 8]
  ];

ExportTransitionsCSV[cascadesList_List, panList_List, durationList_List, nuAudioList_List, outCSV_String] :=
  Module[{header, rows},
    header = {{"realization", "step", "n_upper", "l_upper", "n_lower", "l_lower",
                "series", "lambda_nm", "nu_audio_hz", "duration_s", "pan"}};
    rows = Flatten[
      Table[
        Module[{steps = cascadesList[[real]]},
          Table[
            With[{s = steps[[k]]},
              {real - 1, k - 1, s["n_upper"], s["l_upper"], s["n_lower"], s["l_lower"],
               s["series"], s["lambda_nm"],
               nuAudioList[[real, k]], durationList[[real, k]], panList[[real, k]]}
            ],
            {k, Length[steps]}
          ]
        ],
        {real, Length[cascadesList]}
      ],
      1
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 11]
  ];

(* ========================================================
   compton/src/output.wl — CSV export and console summaries
   ======================================================== *)


(* ── Mode 1: scatter ──────────────────────────────────────────────── *)

ExportScatterCSV[model_Association, outCSV_String] :=
  Module[{header, row},
    header = {{"lambda_pm", "lambda_prime_pm", "E_keV", "E_prime_keV",
                "delta_lambda_pm", "T_keV", "theta_deg", "recoil_angle_deg", "pan"}};
    row = {{model["lambdaPm"], model["lambdaPrimePm"], model["EKeV"], model["EPrimeKeV"],
            model["deltaLambdaPm"], model["TKeV"], model["thetaDeg"],
            model["recoilAngleDeg"], model["pan"]}};
    ExportCSV[Join[header, row], outCSV];
    STEMDescribeCSV[outCSV, 1, 9]
  ];

PrintScatterSummary[model_Association] :=
  Module[{},
    STEMSection["Scatter Summary"];
    STEMPrintN["Incident wavelength", model["lambdaPm"], "pm", 5];
    STEMPrintN["Incident energy",     model["EKeV"],     "keV", 5];
    STEMPrintN["Scattering angle",    model["thetaDeg"],  "deg", 4];
    STEMPrintN["Wavelength shift (Delta lambda)", model["deltaLambdaPm"], "pm", 5];
    STEMPrintN["Outgoing wavelength", model["lambdaPrimePm"], "pm", 5];
    STEMPrintN["Outgoing energy",     model["EPrimeKeV"], "keV", 5];
    STEMPrintN["Electron recoil KE",  model["TKeV"],      "keV", 5];
    STEMPrintN["Electron recoil angle", model["recoilAngleDeg"], "deg", 4]
  ];


(* ── Mode 2: sweep ────────────────────────────────────────────────── *)

ExportSweepCSV[model_Association, outCSV_String] :=
  Module[{header, n, rows},
    header = {{"step", "theta_deg", "delta_lambda_pm", "E_prime_keV", "pan"}};
    n = model["nSteps"];
    rows = Table[
      {i - 1, model["thetaDegArr"][[i]], model["deltaLambdaArr"][[i]],
       model["EPrimeArr"][[i]], model["panArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];

PrintSweepSummary[model_Association] :=
  Module[{},
    STEMSection["Sweep Summary"];
    STEMPrintN["Incident wavelength", model["lambdaPm"], "pm", 5];
    STEMPrintN["Angle range start", model["angleMin"], "deg", 4];
    STEMPrintN["Angle range end", model["angleMax"], "deg", 4];
    Print["  Delta_lambda range: ", FmtN[First[model["deltaLambdaArr"]], 5], " pm -> ",
          FmtN[Last[model["deltaLambdaArr"]], 5], " pm"]
  ];


(* ── Mode 3: energy ───────────────────────────────────────────────── *)

ExportEnergyCSV[model_Association, outCSV_String] :=
  Module[{header, n, rows},
    header = {{"step", "E_keV", "E_prime_keV", "frac_shift"}};
    n = model["nSteps"];
    rows = Table[
      {i - 1, model["EArr"][[i]], model["EPrimeArr"][[i]], model["fracShiftArr"][[i]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];

PrintEnergySummary[model_Association] :=
  Module[{},
    STEMSection["Energy Summary"];
    STEMPrintN["Energy range start", model["EMinKev"], "keV", 5];
    STEMPrintN["Energy range end", model["EMaxKev"], "keV", 6];
    STEMPrintN["Fixed scattering angle", model["angleDeg"], "deg", 4];
    Print["  Fractional shift: ", FmtN[First[model["fracShiftArr"]] * 100, 4], "% -> ",
          FmtN[Last[model["fracShiftArr"]] * 100, 4], "%"]
  ];


(* ── Mode 4: discovery ────────────────────────────────────────────── *)

ExportDiscoveryCSV[model_Association, outCSV_String] :=
  Module[{header, n, rows},
    header = {{"step", "theta_deg", "lambda_thomson_pm", "lambda_compton_pm"}};
    n = model["nSteps"];
    rows = Table[
      {i - 1, model["thetaDegArr"][[i]], PhotonWavelengthPm[model["EPrimeThomson"][[i]]],
       PhotonWavelengthPm[model["EPrimeCompton"][[i]]]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 4]
  ];

PrintDiscoverySummary[model_Association] :=
  Module[{},
    STEMSection["Discovery Summary"];
    STEMPrintN["Incident energy", model["EKeV"], "keV", 5];
    Print["  Thomson prediction: outgoing energy = incident energy at every angle (flat)"];
    Print["  Compton prediction: outgoing energy ", FmtN[First[model["EPrimeCompton"]], 5],
          " keV -> ", FmtN[Last[model["EPrimeCompton"]], 5], " keV"]
  ];

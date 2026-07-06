(* fluid/src/output.wl — CSV data export for karman/strouhal/flag modes *)

(* ExportKarmanCSV
   {t_s, L_proxy, n_vortices_pos, n_vortices_neg, f_shed_measured,
    pitch_hz, pan, volume} *)
ExportKarmanCSV[model_Association, outCSV_String] :=
  Module[{tData, lNorm, nPos, nNeg, pitchData, panData, volData, fShedMeasured, n, rows},
    tData     = model["tData"];
    lNorm     = model["lNorm"];
    nPos      = model["nPosData"];
    nNeg      = model["nNegData"];
    pitchData = model["pitchData"];
    panData   = model["panData"];
    volData   = Abs[lNorm];
    fShedMeasured = model["modeCheck"]["measuredFreq"];
    n = Length[tData];

    rows = Table[
      {tData[[i]], lNorm[[i]], nPos[[i]], nNeg[[i]], fShedMeasured, pitchData[[i]], panData[[i]], volData[[i]]},
      {i, n}
    ];
    Export[outCSV,
      Join[{{"t_s", "L_proxy", "n_vortices_pos", "n_vortices_neg", "f_shed_measured", "pitch_hz", "pan", "volume"}}, rows],
      "CSV"];
    STEMDescribeCSV[outCSV, n, 8]
  ];

(* ExportStrouhalCSV
   {Re, f_shed_measured, St_measured, St_predicted, onset_flag, pitch_hz} *)
ExportStrouhalCSV[model_Association, outCSV_String] :=
  Module[{reValues, steps, n, rows, pitchHz},
    reValues = model["reValues"];
    steps    = model["steps"];
    n = Length[reValues];

    rows = Table[
      pitchHz = If[steps[[i]]["shedding"],
        AudioFreqFromShed[steps[[i]]["fShedPredicted"], model["audioFreqTarget"]],
        0.0];
      {reValues[[i]], steps[[i]]["fShedMeasured"], steps[[i]]["stMeasured"],
       steps[[i]]["stPredicted"], If[steps[[i]]["onsetFlag"], 1, 0], pitchHz},
      {i, n}
    ];
    Export[outCSV,
      Join[{{"Re", "f_shed_measured", "St_measured", "St_predicted", "onset_flag", "pitch_hz"}}, rows],
      "CSV"];
    STEMDescribeCSV[outCSV, n, 6]
  ];

(* ExportFlagCSV
   {t, y_tip, dy_tip_dt, f_flag, pitch_hz, pan, volume} *)
ExportFlagCSV[model_Association, outCSV_String] :=
  Module[{tArr, yArr, vArr, fFlag, pitchData, panData, volData, n, rows},
    tArr      = model["model"]["tArr"];
    yArr      = model["model"]["yArr"];
    vArr      = model["model"]["vArr"];
    fFlag     = model["model"]["fFlag"];
    pitchData = model["pitchData"];
    panData   = model["panData"];
    volData   = model["volumeData"];
    n = Length[tArr];

    rows = Table[
      {tArr[[i]], yArr[[i]], vArr[[i]], fFlag, pitchData[[i]], panData[[i]], volData[[i]]},
      {i, n}
    ];
    Export[outCSV,
      Join[{{"t", "y_tip", "dy_tip_dt", "f_flag", "pitch_hz", "pan", "volume"}}, rows],
      "CSV"];
    STEMDescribeCSV[outCSV, n, 7]
  ];

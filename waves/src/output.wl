(* waves/src/output.wl — CSV data export for wave modes *)

(* Export ripple mode listening-point displacement time series. *)
ExportRippleData[model_Association, outCSV_String] :=
  Module[{tVals, lpDisp, nLP, nT, csvHeader, csvData},
    tVals  = model["tVals"];
    lpDisp = model["lpDisp"];
    nLP    = model["nLP"];
    nT     = model["nT"];
    csvHeader = Join[{"t_s"}, Map["disp_lp" <> ToString[#] <> "_units" &, Range[nLP]]];
    csvData   = Table[
      Join[{tVals[[i]]}, Map[lpDisp[[#, i]] &, Range[nLP]]],
      {i, nT}];
    Export[outCSV, Join[{csvHeader}, csvData], "CSV"];
    STEMDescribeCSV[outCSV, nT, nLP + 1]
  ];

(* Export interference mode moving-LP and fixed-LP displacement time series. *)
ExportInterferenceData[model_Association, outCSV_String] :=
  Module[{tVals, xMoving, dispMoving, dispFixed, nT, csvData},
    tVals      = model["tVals"];
    xMoving    = model["xMoving"];
    dispMoving = model["dispMoving"];
    dispFixed  = model["dispFixed"];
    nT         = model["nT"];
    csvData = Table[
      {tVals[[i]], xMoving[[i]], dispMoving[[i]], dispFixed[[i]]},
      {i, nT}];
    Export[outCSV,
      Join[{{"t_s", "lp_x_units", "displacement_units", "disp_fixed_units"}}, csvData],
      "CSV"];
    STEMDescribeCSV[outCSV, nT, 4]
  ];

(* ========================================================
   scattering/src/output.wl — CSV export for all three modes

   scatter mode's pitch_hz/pan/volume columns re-derive the same
   Rescale mapping law src/sonify.wl's SonifyScatter feeds through
   stem-core's SpatialLayer (Log[1/r] -> pitch, x -> pan, speed ->
   volume) so the CSV documents the physical-to-audio mapping without
   reproducing the full per-audio-sample render (tremolo/roughness/
   envelope from MotionLayer are audio-signal shaping, not properties
   of the underlying 500-row trajectory this CSV exports).
   ======================================================== *)

$ScatCsvMaxRows = 3000;

ScatSubsampleStep[n_Integer] := Max[1, Round[n / $ScatCsvMaxRows]]

RescaleOrConstant[arr_List, range_List] :=
  If[Max[arr] - Min[arr] < 1.0*^-9,
    ConstantArray[Mean[range], Length[arr]],
    Rescale[arr, MinMax[arr], range]
  ]


(* ========================================================
   SCATTER MODE
   ======================================================== *)

ExportScatterCSV[model_Association, outCSV_String] :=
  Module[{header, t, x, y, r, speed, phi, logInvR, pitchHz, pan, volDb, volume,
          step, idx, rows},
    header = {"t", "x", "y", "r", "speed", "phi", "pitch_hz", "pan", "volume"};
    t = model["t"]; x = model["x"]; y = model["y"];
    r = model["r"]; speed = model["speed"]; phi = model["phi"];

    logInvR = Log[1.0 / r];
    pitchHz = RescaleOrConstant[logInvR, {220.0, 1760.0}];
    pan     = RescaleOrConstant[x, {-1.0, 1.0}];
    volDb   = RescaleOrConstant[speed, {-24.0, -3.0}];
    volume  = 10.0^(volDb / 20.0);

    step = ScatSubsampleStep[Length[t]];
    idx  = Range[1, Length[t], step];
    rows = Transpose[{t[[idx]], x[[idx]], y[[idx]], r[[idx]], speed[[idx]], phi[[idx]],
                       pitchHz[[idx]], pan[[idx]], volume[[idx]]}];

    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ]


(* ========================================================
   DISTRIBUTION MODE
   ======================================================== *)

ExportDistributionCSV[model_Association, outCSV_String] :=
  Module[{header, rows},
    header = {"particle", "b", "theta_deg", "weight", "pitch_hz", "pan", "volume"};
    rows = Table[
      {i, model["b"][[i]], model["thetaDeg"][[i]], model["weight"][[i]],
       model["pitchHz"][[i]], model["pan"][[i]], model["ampNorm"][[i]]},
      {i, model["n"]}
    ];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ]


(* ========================================================
   DISCOVERY MODE
   ======================================================== *)

ExportDiscoveryCSV[model_Association, outCSV_String] :=
  Module[{header, rows},
    header = {"particle", "b_rutherford", "theta_thomson_deg", "theta_rutherford_deg"};
    rows = Table[
      {i, model["bRutherford"][[i]], model["thomsonThetaDeg"][[i]], model["rutherfordThetaDeg"][[i]]},
      {i, model["n"]}
    ];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ]

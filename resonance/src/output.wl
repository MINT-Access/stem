(* ========================================================
   resonance/src/output.wl — CSV export for all three modes
   ======================================================== *)


(* ========================================================
   GALILEAN MODE
   ======================================================== *)

ExportGalileanCSV[model_Association, outCSV_String] :=
  Module[{header, rows},
    header = {"t", "theta_io", "theta_eu", "theta_ga",
              "x_io", "y_io", "x_eu", "y_eu", "x_ga", "y_ga",
              "event_io", "event_eu", "event_ga"};
    rows = Transpose[{
      model["t"], model["thetaIo"], model["thetaEu"], model["thetaGa"],
      model["xIo"], model["yIo"], model["xEu"], model["yEu"], model["xGa"], model["yGa"],
      model["eventIoFlag"], model["euEventFlag"], model["gaEventFlag"]
    }];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ];


(* ========================================================
   KIRKWOOD MODE
   ======================================================== *)

(* Nearest-resonance label for a given semi-major axis -- blank unless
   within 2 gap-widths of a listed resonance (used purely to annotate
   the CSV; has no effect on the density model itself). *)
KirkwoodResonanceLabelAt[a_?NumericQ, resonances_List, gapWidth_?NumericQ] :=
  Module[{nearest},
    nearest = SelectFirst[resonances, Abs[#["a"] - a] < 2.0 * gapWidth &, Missing["None"]];
    If[MissingQ[nearest], "", nearest["label"]]
  ];

ExportKirkwoodCSV[model_Association, outCSV_String] :=
  Module[{header, aVals, rhoVals, resonances, gapWidth, aMin, aMax, pitchHz, rows},
    header = {"a_AU", "resonance_ratio", "density", "pitch_hz", "amplitude"};
    aVals = model["aVals"]; rhoVals = model["rhoVals"]; resonances = model["resonances"];
    gapWidth = model["gapWidth"]; aMin = model["aMin"]; aMax = model["aMax"];
    pitchHz = $KirkwoodFreqMinHz * ($KirkwoodFreqMaxHz / $KirkwoodFreqMinHz)^
      Rescale[aVals, {aMin, aMax}, {0.0, 1.0}];
    rows = Table[
      {aVals[[i]], KirkwoodResonanceLabelAt[aVals[[i]], resonances, gapWidth], rhoVals[[i]],
       pitchHz[[i]], rhoVals[[i]]},
      {i, Length[aVals]}
    ];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ];


(* ========================================================
   SATURN MODE
   ======================================================== *)

SaturnResonanceLabelAt[region_String] :=
  Which[
    region === "Cassini Division", "2:1 (Mimas)",
    region === "Encke gap",        "3:2 (Pan)",
    True,                          ""
  ];

ExportSaturnCSV[model_Association, cfg_Association, outCSV_String] :=
  Module[{header, rVals, rhoVals, regions, rMin, rMax, freqMin, freqMax, pitchHz, rows},
    header = {"r_km", "ring_region", "density", "resonance", "pitch_hz", "amplitude"};
    rVals = model["rVals"]; rhoVals = model["rhoVals"]; regions = model["regions"];
    rMin = model["rMin"]; rMax = model["rMax"];
    freqMin = N @ GetCfg[cfg, {"simulation", "resonance", "freq_min"}, 150];
    freqMax = N @ GetCfg[cfg, {"simulation", "resonance", "freq_max"}, 3000];
    pitchHz = freqMin * (freqMax / freqMin)^Rescale[rVals, {rMin, rMax}, {0.0, 1.0}];
    rows = Table[
      {rVals[[i]], regions[[i]], rhoVals[[i]], SaturnResonanceLabelAt[regions[[i]]],
       pitchHz[[i]], rhoVals[[i]]},
      {i, Length[rVals]}
    ];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ];

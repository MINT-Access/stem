(* ========================================================
   magnetic/src/output.wl — CSV export for all four modes

   Common column format: {t, x, y, z, vx, vy, vz, speed, kinetic_energy}
   Rows are subsampled to at most 3000 for CSV readability; the full
   arrays are still used for audio/GIF/correctness checks upstream.
   ======================================================== *)

$MagCsvMaxRows = 3000;

MagSubsampleStep[n_Integer] := Max[1, Round[n / $MagCsvMaxRows]]

MagTrajectoryRows[t_List, x_List, y_List, z_List,
                  vx_List, vy_List, vz_List, speed_List, ke_List] :=
  Module[{step = MagSubsampleStep[Length[t]], idx},
    idx = Range[1, Length[t], step];
    Transpose[{t[[idx]], x[[idx]], y[[idx]], z[[idx]],
               vx[[idx]], vy[[idx]], vz[[idx]], speed[[idx]], ke[[idx]]}]
  ]

$MagCsvHeader = {"t", "x", "y", "z", "vx", "vy", "vz", "speed", "kinetic_energy"};


ExportCyclotronCSV[model_Association, outCSV_String] :=
  Module[{rows},
    rows = MagTrajectoryRows[model["t"], model["x"], model["y"], model["z"],
                            model["vx"], model["vy"], model["vz"],
                            model["speed"], model["ke"]];
    ExportCSV[Join[{$MagCsvHeader}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[$MagCsvHeader]]
  ]

ExportDriftCSV[model_Association, outCSV_String] :=
  Module[{rows},
    rows = MagTrajectoryRows[model["t"], model["x"], model["y"], model["z"],
                            model["vx"], model["vy"], model["vz"],
                            model["speed"], model["ke"]];
    ExportCSV[Join[{$MagCsvHeader}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[$MagCsvHeader]]
  ]

ExportMirrorCSV[model_Association, outCSV_String] :=
  Module[{rows},
    rows = MagTrajectoryRows[model["t"], model["x"], model["y"], model["z"],
                            model["vx"], model["vy"], model["vz"],
                            model["speed"], model["ke"]];
    ExportCSV[Join[{$MagCsvHeader}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[$MagCsvHeader]]
  ]

(* Long format: one row per particle per timestep, with a "particle" label. *)
ExportMultiCSV[model_Association, outCSV_String] :=
  Module[{t, step, idx, header, rows, particles},
    t    = model["t"];
    step = MagSubsampleStep[Length[t]];
    idx  = Range[1, Length[t], step];
    header = {"t", "particle", "x", "y", "z", "vx", "vy", "vz", "speed", "kinetic_energy"};
    particles = {model["proton"], model["alpha"], model["electron"]};
    rows = Flatten[
      Table[
        Table[
          {t[[i]], p["label"], p["x"][[i]], p["y"][[i]], 0.0,
           p["vx"][[i]], p["vy"][[i]], 0.0, p["speed"][[i]], 0.5 * p["speed"][[i]]^2},
          {i, idx}],
        {p, particles}],
      1];
    ExportCSV[Join[{header}, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], Length[header]]
  ]

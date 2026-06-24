(* ========================================================
   src/output.wl — CSV export and console summary
   ======================================================== *)


(* ExportResults
   Writes trajectory data to a CSV file.
   Columns: time, x, y, z, speed (magnitude of velocity vector) *)

ExportResults[solution_List, params_Association, filePath_String] :=
  Module[{header, rows, allRows},

    header = {{"time_s", "x", "y", "z", "speed"}};

    rows = {
      #[[1]],                                          (* t   *)
      #[[2]],                                          (* x   *)
      #[[3]],                                          (* y   *)
      #[[4]],                                          (* z   *)
      Sqrt[                                            (* |v| *)
        (params["Sigma"] * (#[[3]] - #[[2]]))^2 +
        (#[[2]] * (params["Rho"] - #[[4]]) - #[[3]])^2 +
        (#[[2]] * #[[3]] - params["Beta"] * #[[4]])^2
      ]
    } & /@ solution;

    allRows = Join[header, rows];

    ExportCSV[allRows, filePath]
  ]


(* ExportDivergence
   Writes divergence data for the butterfly-effect experiment. *)

ExportDivergence[divergence_List, filePath_String] :=
  Module[{header, allRows},
    header  = {{"time_s", "distance"}};
    allRows = Join[header, divergence];
    ExportCSV[allRows, filePath]
  ]


(* PrintSummary — console statistics *)

PrintSummary[solution_List, params_Association] :=
  Module[{xs, ys, zs},
    xs = solution[[All, 2]];
    ys = solution[[All, 3]];
    zs = solution[[All, 4]];
    Print["--- Trajectory Summary ---"];
    Print["  Steps:   ", Length[solution]];
    Print["  x range: [", NumberForm[Min[xs],4],
                  ", ", NumberForm[Max[xs],4], "]"];
    Print["  y range: [", NumberForm[Min[ys],4],
                  ", ", NumberForm[Max[ys],4], "]"];
    Print["  z range: [", NumberForm[Min[zs],4],
                  ", ", NumberForm[Max[zs],4], "]"];
  ]

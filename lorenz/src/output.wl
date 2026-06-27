(* ========================================================
   src/output.wl — CSV export and console summary
   ======================================================== *)


(* ExportResults
   Writes trajectory data to a CSV file.
   Columns: time, x, y, z, speed (magnitude of velocity vector) *)

ExportResults[solution_List, params_Association, filePath_String] :=
  Module[{header, dt, vx, vy, vz, speeds, rows, allRows},

    header = {{"time_s", "x", "y", "z", "speed"}};

    (* Generic speed via finite differences — works for any 3D attractor *)
    dt     = solution[[2, 1]] - solution[[1, 1]];
    vx     = Differences[solution[[All, 2]]] / dt;
    vy     = Differences[solution[[All, 3]]] / dt;
    vz     = Differences[solution[[All, 4]]] / dt;
    speeds = Append[Sqrt[vx^2 + vy^2 + vz^2],
                    Last[Sqrt[vx^2 + vy^2 + vz^2]]];

    rows = MapThread[
      {#1[[1]], #1[[2]], #1[[3]], #1[[4]], #2} &,
      {solution, speeds}
    ];

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
    STEMSection["Trajectory Summary"];
    STEMPrintN["Steps", Length[solution]];
    Print["  x range: [", FmtN[Min[xs],4], ", ", FmtN[Max[xs],4], "]"];
    Print["  y range: [", FmtN[Min[ys],4], ", ", FmtN[Max[ys],4], "]"];
    Print["  z range: [", FmtN[Min[zs],4], ", ", FmtN[Max[zs],4], "]"];
  ]

(* ========================================================
   src/output.wl — Result formatting and file export
   ======================================================== *)

(* ExportResults
   Writes simulation output to a CSV file.
   Input:  solution — list of {t, angle, velocity} triples
           params   — the Association used for the simulation
           filePath — destination path for the CSV *)

ExportResults[solution_List, params_Association, filePath_String] := Module[
  {header, rows, allRows},

  (* Build CSV content *)
  header = {{"time_s", "angle_rad", "angle_deg", "angular_velocity_rad_s", "energy_J"}};

  rows = {
    #[[1]],                                        (* time *)
    #[[2]],                                        (* angle in radians *)
    #[[2]] * 180.0 / Pi,                           (* angle in degrees *)
    #[[3]],                                        (* angular velocity *)
    PendulumEnergy[#[[2]], #[[3]], params]         (* mechanical energy *)
  } & /@ solution;

  allRows = Join[header, rows];

  ExportCSV[allRows, filePath]
]


(* PrintSummary
   Prints a brief summary of key simulation results to stdout. *)

PrintSummary[solution_List, params_Association] := Module[
  {angles, maxAngle, minAngle, energies},

  angles   = solution[[All, 2]];
  energies = PendulumEnergy[#[[2]], #[[3]], params] & /@ solution;

  maxAngle = Max[angles] * 180.0 / Pi;
  minAngle = Min[angles] * 180.0 / Pi;

  Print["--- Simulation Summary ---"];
  Print["  Steps computed:  ", Length[solution]];
  Print["  Max angle:       ", FmtN[maxAngle, 4], " deg"];
  Print["  Min angle:       ", FmtN[minAngle, 4], " deg"];
  Print["  Initial energy:  ", FmtN[First[energies], 4], " J"];
  Print["  Final energy:    ", FmtN[Last[energies], 4], " J"];
  Print["  Energy drift:    ",
    FmtN[Abs[Last[energies] - First[energies]], 4], " J"];
]

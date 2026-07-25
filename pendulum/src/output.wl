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


(* ExportDoublePendulumResults
   Writes the double pendulum solution to a CSV file.
   Columns: time_s, theta1_rad, omega1_rad_s, theta2_rad, omega2_rad_s *)

ExportDoublePendulumResults[solution_List, filePath_String] :=
  Module[{header, rows},
    header = {{"time_s", "theta1_rad", "omega1_rad_s",
               "theta2_rad", "omega2_rad_s"}};
    rows   = {#[[1]], #[[2]], #[[3]], #[[4]], #[[5]]} & /@ solution;
    ExportCSV[Join[header, rows], filePath]
  ]


(* PrintSummary
   Prints a brief summary of key simulation results to stdout. *)

PrintSummary[solution_List, params_Association] := Module[
  {angles, maxAngle, minAngle, energies},

  angles   = solution[[All, 2]];
  energies = PendulumEnergy[#[[2]], #[[3]], params] & /@ solution;

  maxAngle = Max[angles] * 180.0 / Pi;
  minAngle = Min[angles] * 180.0 / Pi;

  STEMSection["Simulation Summary"];
  STEMPrintN["Steps computed",  Length[solution]];
  STEMPrintN["Max angle",       maxAngle,                             "deg", 4];
  STEMPrintN["Min angle",       minAngle,                             "deg", 4];
  STEMPrintN["Initial energy",  First[energies],                      "J",   4];
  STEMPrintN["Final energy",    Last[energies],                       "J",   4];
  STEMPrintN["Energy drift",    Abs[Last[energies] - First[energies]], "J",   4];
]


(* PrintCorrectnessChecks -- "Checks: N[PASS] M[FAIL] ..." line,
   consistent with the style used across the v1.5.0 apps. Simple and
   double pendulum are different systems (like magnetic/'s four
   modes), so each mode prints only ITS OWN two checks (global numbers
   1-2 for simple, 3-4 for double) rather than a forced four every
   run -- see AGENTS.md design decision on this split, the same
   deliberate-not-oversight reasoning magnetic/AGENTS.md documents for
   its own per-mode check structure. *)
PrintCorrectnessChecks[label1_String, chk1_Association, label2_String, chk2_Association] :=
  Print["  Checks: ",
    If[chk1["pass"], label1 <> "[PASS]", label1 <> "[FAIL]"], " ",
    If[chk2["pass"], label2 <> "[PASS]", label2 <> "[FAIL]"]
  ];

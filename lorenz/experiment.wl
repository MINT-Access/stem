#!/usr/bin/env wolframscript

(* ========================================================
   experiment.wl — Parameter experiments for the Lorenz system

   Edit the ACTIVE PRESET section and run:
     wolframscript -file experiment.wl

   Each preset saves output files with a unique label suffix
   so runs never overwrite each other.

   Interesting things to explore:
     - Change rho to leave the chaotic regime (rho < 24.74)
     - Nudge initial conditions to hear the butterfly effect
     - Try the dual-trajectory animation for a visual demo
       of sensitive dependence on initial conditions
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* -------------------------------------------------------
   PRESETS
   ------------------------------------------------------- *)

(* A: Classic chaotic attractor — baseline *)
(*
label     = "classic";
params    = <| "Sigma"->10.0, "Rho"->28.0, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->40.0, "TimeStep"->0.005 |>;
scaleName = "MinorPentatonic";
dualAnim  = False;
*)

(* B: Butterfly effect — two near-identical trajectories *)
(*
label     = "butterfly";
params    = <| "Sigma"->10.0, "Rho"->28.0, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->30.0, "TimeStep"->0.005 |>;
scaleName = "MajorPentatonic";
dualAnim  = True;   (* side-by-side divergence animation *)
*)

(* C: rho=24 — just below chaos, stable spiral to fixed point *)
(*
label     = "stable";
params    = <| "Sigma"->10.0, "Rho"->24.0, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->30.0, "TimeStep"->0.005 |>;
scaleName = "Major";
dualAnim  = False;
*)

(* D: rho=99.96 — different chaotic regime, wilder attractor *)
(*
label     = "wild";
params    = <| "Sigma"->10.0, "Rho"->99.96, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->20.0, "TimeStep"->0.005 |>;
scaleName = "WholeTone";
dualAnim  = False;
*)

(* E: Different sigma — slower mixing *)
(*
label     = "slow";
params    = <| "Sigma"->4.0, "Rho"->28.0, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->60.0, "TimeStep"->0.005 |>;
scaleName = "Minor";
dualAnim  = False;
*)

(* -------------------------------------------------------
   ACTIVE PRESET — change this block to switch experiments
   ------------------------------------------------------- *)
label     = "butterfly";
params    = <| "Sigma"->10.0, "Rho"->28.0, "Beta"->8/3,
               "InitX"->1.0, "InitY"->1.0, "InitZ"->1.0,
               "TimeEnd"->30.0, "TimeStep"->0.005 |>;
scaleName = "MajorPentatonic";
dualAnim  = True;

(* -------------------------------------------------------
   Run pipeline — no need to edit below here
   ------------------------------------------------------- *)

Print["=== Lorenz Experiment: ", label, " ==="];
Print["  sigma=", params["Sigma"],
      "  rho=",   params["Rho"],
      "  beta=",  N[params["Beta"], 4]];
Print["  Scale: ", scaleName];
Print["  Dual animation: ", dualAnim];
Print[""];

Print["[1/4] Solving..."];
solution = SolveLorenz[params];
Print["  Steps: ", Length[solution]];
PrintSummary[solution, params];
Print[""];

Print["[2/4] CSV..."];
outCSV = FileNameJoin[{$projectRoot, "output",
  "lorenz_trajectory_" <> label <> ".csv"}];
ExportResults[solution, params, outCSV];
Print["  ", outCSV];
Print[""];

Print["[3/4] Animation..."];
outGIF = FileNameJoin[{$projectRoot, "output",
  "lorenz_animation_" <> label <> ".gif"}];
If[dualAnim,
  Module[{sol2},
    Print["  Solving perturbed trajectory..."];
    {solution, sol2} = SolveLorenzPair[params, 0.001];
    ExportDualAnimation[solution, sol2, outGIF, 30, 150];
  ],
  ExportAnimation[solution, outGIF, 30, 150,
    "Lorenz rho=" <> FmtN[params["Rho"],4]];
];
Print["  ", outGIF];
Print[""];

Print["[4/4] Sonification..."];
outWAV = FileNameJoin[{$projectRoot, "output",
  "lorenz_audio_" <> label <> ".wav"}];
ExportSonification[solution, outWAV, "Scale" -> scaleName];
Print["  ", outWAV];
Print[""];

Print["=== Done ==="];
Print["Play:  afplay ", outWAV];

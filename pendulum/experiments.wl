#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Parameter experimentation script

   Run individual experiments or all of them:
     wolframscript -file experiments.wl

   Each experiment produces its own GIF and WAV in data/
   so you can compare them side by side.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];


(* --- Helper: run one named experiment --- *)

RunExperiment[name_String, params_Association] :=
  Module[{sol, gifFile, wavFile},
    Print[""];
    Print[">>> Experiment: ", name];
    Print["    Length=", params["Length"], " m  |  ",
          "InitAngle=", FmtN[params["InitAngle"] * 180/Pi, 3], " deg  |  ",
          "TimeEnd=", params["TimeEnd"], " s"];
    Print["    Small-angle period: ",
      FmtN[2 Pi Sqrt[params["Length"]/params["Gravity"]], 4], " s"];

    sol = SolvePendulum[params];

    gifFile = FileNameJoin[{$projectRoot, "data",
                name <> "_animation.gif"}];
    wavFile = FileNameJoin[{$projectRoot, "data",
                name <> "_audio.wav"}];

    ExportAnimation[sol, params, gifFile, 25, 1.0];
    Print["    GIF -> ", gifFile];

    ExportSonification[sol, params, wavFile];
    Print["    WAV -> ", wavFile];
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   Uncomment the ones you want to run, or run them all.
   ================================================================ *)

(* --- Baseline (same as main.wl) --- *)
RunExperiment["baseline", <|
  "Length"       -> 1.0,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 0.4,     (* ~23 deg *)
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 10.0,
  "TimeStep"     -> 0.01
|>];


(* --- Long pendulum (2 m): slower, deeper swing --- *)
(* Period is sqrt(2) longer than baseline ~ 2.84 s *)
RunExperiment["long_pendulum", <|
  "Length"       -> 2.0,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 0.4,
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 15.0,
  "TimeStep"     -> 0.01
|>];


(* --- Short pendulum (0.25 m): fast ticking, higher notes --- *)
(* Period ~ 1 s, twice the frequency of baseline *)
RunExperiment["short_pendulum", <|
  "Length"       -> 0.25,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 0.4,
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 8.0,
  "TimeStep"     -> 0.005
|>];


(* --- Large initial angle (1.2 rad ~ 69 deg): nonlinear regime --- *)
(* At this angle the small-angle approximation breaks down noticeably.
   The period is longer than the formula predicts, and the pitch
   range in the sonification will span the full two octaves. *)
RunExperiment["large_angle", <|
  "Length"       -> 1.0,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 1.2,     (* ~69 deg — strongly nonlinear *)
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 12.0,
  "TimeStep"     -> 0.01
|>];


(* --- Moon gravity (1.62 m/s^2): dreamlike slow swings --- *)
RunExperiment["moon_gravity", <|
  "Length"       -> 1.0,
  "Gravity"      -> 1.62,
  "InitAngle"    -> 0.4,
  "InitVelocity" -> 0.0,
  "TimeEnd"      -> 25.0,
  "TimeStep"     -> 0.01
|>];


(* --- Pushed pendulum (nonzero initial velocity) --- *)
(* Starts vertical but is given a push — asymmetric motion *)
RunExperiment["pushed", <|
  "Length"       -> 1.0,
  "Gravity"      -> 9.81,
  "InitAngle"    -> 0.0,     (* starts vertical *)
  "InitVelocity" -> 2.5,     (* rad/s push *)
  "TimeEnd"      -> 10.0,
  "TimeStep"     -> 0.01
|>];


Print[""];
Print["=== All experiments complete. Files are in data/ ==="];

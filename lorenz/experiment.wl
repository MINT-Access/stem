#!/usr/bin/env wolframscript

(* ========================================================
   experiment.wl — Parameter experiments for the Lorenz system

   Runs one named preset through main.wl. The presets live in
   src/model.wl ($lorenzPresets) and can be run directly, without
   editing this file:
     wolframscript -file main.wl -- --simulation.lorenz.preset=stable

   To run one from here, set the ACTIVE PRESET line below and run:
     wolframscript -file experiment.wl

   Presets (outputs lorenz_audio_<preset>.wav,
   lorenz_animation_<preset>.gif, lorenz_trajectory_<preset>.csv):
     classic    rho = 28, 40 s, the classic chaotic attractor
     butterfly  rho = 28, 30 s, two trajectories 0.001 apart side by side
                (the WAV sonifies the first trajectory)
     stable     rho = 20, 30 s, a spiral settling onto a fixed point
     wild       rho = 99.96, 20 s, a wilder chaotic regime
     slow       sigma = 4, 60 s, slower mixing
     rho9996    rho = 99.96, 120 s, the GIF frame-rate stress test

   Every preset starts from (1, 1, 1) and discards the first
   simulation.lorenz.transient_seconds (default 5) before its duration.
   ======================================================== *)

(* -------------------------------------------------------
   ACTIVE PRESET — change this line to switch experiments
   ------------------------------------------------------- *)
label = "butterfly";

(* Run main.wl with the preset, as if invoked as
   wolframscript -file main.wl -- --simulation.lorenz.preset=<label> *)
Block[{$ScriptCommandLine = {"main.wl", "--", "--simulation.lorenz.preset=" <> label}},
  Get[FileNameJoin[{DirectoryName[$InputFileName], "main.wl"}]]
];

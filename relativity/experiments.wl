#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Relativity parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each chirp preset writes a dedicated WAV alongside the default
   chirp.* output files. Each geodesic experiment overwrites the
   geodesic.* output files.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* --- Helper: run one chirp experiment --- *)

RunChirpExperiment[label_String, cfg_Association] :=
  Module[{model},
    Print[""];
    Print[">>> Experiment: chirp  — ", label];
    model = ChirpModel[cfg];
    STEMPrintN["Chirp mass",      model["chirp_mass_solar"],  "M\[SmallCircle]", {5,3}];
    STEMPrintN["Coalescence time",model["coalescence_time"],  "s",              {6,4}];
    STEMPrintN["Peak frequency",  model["peak_frequency"],    "Hz",             {5,1}];
    AnimateRelativity[model, cfg, $outDir];
    SonifyRelativity[model, cfg, $outDir];
    Print["    Output: output/chirp*"]
  ]


(* --- Helper: run one geodesic experiment --- *)

RunGeodesicExperiment[label_String, cfg_Association] :=
  Module[{model},
    Print[""];
    Print[">>> Experiment: geodesic  — ", label];
    model = GeodesicModel[cfg];
    STEMPrintN["r_min",       model["r_min"] / 2.0,    "r_s", {6,3}];
    STEMPrintN["r_max",       model["r_max"] / 2.0,    "r_s", {6,2}];
    STEMPrintN["Revolutions", model["n_revolutions"],   "",    {5,2}];
    AnimateRelativity[model, cfg, $outDir];
    SonifyRelativity[model, cfg, $outDir];
    Print["    Output: output/geodesic*"]
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- gw150914: first detected gravitational wave event (LIGO, 2015) --- *)
(* 36 + 29 solar masses at 410 Mpc. The classic "chirp" sound that
   proved gravitational waves exist. Coalescence time ~0.45 s;
   the frequency sweeps from 20 Hz to ~150 Hz at merger. *)
RunChirpExperiment["GW150914 — 36+29 M\[SmallCircle], 410 Mpc (first detection)",
  <| "simulation" -> <| "mode" -> "chirp",
    "chirp" -> <|
      "mass1_solar"       -> 36.0,
      "mass2_solar"       -> 29.0,
      "distance_mpc"      -> 410.0,
      "sample_rate"       -> 4096,
      "frequency_min_hz"  -> 20.0,
      "frequency_max_hz"  -> 500.0,
      "ringdown_duration" -> 0.05,
      "preset"            -> ""
    |>
  |>,
  "sonification" -> <| "chirp" -> <| "time_stretch" -> 4.0, "frequency_shift" -> 1.0 |> |> |>
];


(* --- gw170817: neutron-star binary merger (LIGO+Virgo, 2017) --- *)
(* Two 1.4 solar-mass neutron stars. Much lower chirp mass than GW150914;
   the inspiral lasts many seconds and the frequency rises more slowly.
   The PN approximation is least accurate near merger for NS, but the
   inspiral phase is well-modelled. *)
RunChirpExperiment["GW170817 — 1.4+1.4 M\[SmallCircle], 40 Mpc (neutron stars)",
  <| "simulation" -> <| "mode" -> "chirp",
    "chirp" -> <|
      "mass1_solar"       -> 1.4,
      "mass2_solar"       -> 1.4,
      "distance_mpc"      -> 40.0,
      "sample_rate"       -> 4096,
      "frequency_min_hz"  -> 20.0,
      "frequency_max_hz"  -> 1000.0,
      "ringdown_duration" -> 0.01,
      "preset"            -> ""
    |>
  |>,
  "sonification" -> <| "chirp" -> <| "time_stretch" -> 4.0, "frequency_shift" -> 1.0 |> |> |>
];


(* --- stellar_merger: equal-mass stellar-black-hole binary --- *)
(* 10 + 10 solar masses at 200 Mpc — a hypothetical stellar-mass merger.
   Intermediate chirp mass gives a coalescence time between GW150914 and GW170817.
   A good reference for comparing chirp rate vs. mass. *)
RunChirpExperiment["Stellar merger — 10+10 M\[SmallCircle], 200 Mpc",
  <| "simulation" -> <| "mode" -> "chirp",
    "chirp" -> <|
      "mass1_solar"       -> 10.0,
      "mass2_solar"       -> 10.0,
      "distance_mpc"      -> 200.0,
      "sample_rate"       -> 4096,
      "frequency_min_hz"  -> 20.0,
      "frequency_max_hz"  -> 500.0,
      "ringdown_duration" -> 0.05,
      "preset"            -> ""
    |>
  |>,
  "sonification" -> <| "chirp" -> <| "time_stretch" -> 4.0, "frequency_shift" -> 1.0 |> |> |>
];


(* --- geodesic_bound: elliptical GR orbit (rosette) --- *)
(* A test particle with angular momentum = 0.85 × circular value at r=10 r_s.
   GR periapsis precession produces a slowly rotating ellipse (rosette).
   Pitch oscillates fast at periapsis, slow at apoapsis — hear the
   Keplerian rhythm plus relativistic correction. *)
RunGeodesicExperiment["Bound orbit — ellipse with GR precession",
  <| "simulation" -> <| "mode" -> "geodesic",
    "geodesic" -> <|
      "mass_solar"   -> 10.0,
      "orbit_type"   -> "bound",
      "tau_max_m"    -> 3000.0,
      "n_steps"      -> 50000,
      "bound" -> <|
        "r_start_rs"              -> 10.0,
        "angular_momentum_factor" -> 0.85
      |>
    |>
  |>,
  "sonification" -> <| "geodesic" -> <| "pitch_base_hz" -> 220.0, "duration_s" -> 10.0 |> |> |>
];


(* --- geodesic_plunging: test particle spiralling into the black hole --- *)
(* Low angular momentum (factor 0.30) means L² < 12 and there is no
   potential barrier. The particle spirals inward monotonically and
   crosses the event horizon. Pitch rises continuously as the particle
   falls (gravitational blueshift); amplitude fades to silence at the horizon. *)
RunGeodesicExperiment["Plunging orbit — inspiral to event horizon",
  <| "simulation" -> <| "mode" -> "geodesic",
    "geodesic" -> <|
      "mass_solar"   -> 10.0,
      "orbit_type"   -> "plunging",
      "tau_max_m"    -> 500.0,
      "n_steps"      -> 20000,
      "plunging" -> <|
        "r_start_rs"              -> 10.0,
        "angular_momentum_factor" -> 0.30
      |>
    |>
  |>,
  "sonification" -> <| "geodesic" -> <| "pitch_base_hz" -> 220.0, "duration_s" -> 10.0 |> |> |>
];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

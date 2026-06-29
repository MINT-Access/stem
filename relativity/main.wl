#!/usr/bin/env wolframscript

(* ========================================================
   Relativity — Entry Point

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode chirp
     wolframscript -file main.wl -- --simulation.mode geodesic

   Modes:
     chirp    — gravitational wave chirp from binary inspiral (PN approximation)
     geodesic — Schwarzschild geodesic: bound orbit / plunging / photon lensing

   CLI flags — chirp mode:
     --simulation.chirp.mass1_solar
     --simulation.chirp.mass2_solar
     --simulation.chirp.distance_mpc
     --simulation.chirp.preset              (gw150914 | gw170817 | stellar)
     --sonification.chirp.time_stretch
     --sonification.chirp.frequency_shift

   CLI flags — geodesic mode:
     --simulation.geodesic.orbit_type       (bound | plunging | photon)
     --simulation.geodesic.mass_solar
     --simulation.geodesic.bound.r_start_rs
     --simulation.geodesic.bound.angular_momentum_factor
     --simulation.geodesic.plunging.r_start_rs
     --simulation.geodesic.plunging.angular_momentum_factor
     --simulation.geodesic.photon.r_start_rs
     --simulation.geodesic.photon.impact_parameter_factor
     --sonification.geodesic.pitch_base_hz
     --sonification.geodesic.duration_s
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both space and equals conventions work with ParseCliOverrides. *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["relativity", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "chirp"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

(* ── Preset resolution ─────────────────────────────────
   If --simulation.chirp.preset=<name> is given, merge the
   preset's mass1/mass2/distance into cfg before running.  *)
Module[{preset, presetData, ovr},
  preset = GetCfg[cfg, {"simulation","chirp","preset"}, ""];
  If[StringQ[preset] && preset =!= "",
    presetData = GetCfg[cfg, {"simulation","chirp","presets",preset}, <||>];
    If[AssociationQ[presetData] && Length[presetData] > 0,
      ovr = <||>;
      If[KeyExistsQ[presetData, "mass1"],        ovr["mass1_solar"]  = presetData["mass1"]];
      If[KeyExistsQ[presetData, "mass2"],        ovr["mass2_solar"]  = presetData["mass2"]];
      If[KeyExistsQ[presetData, "distance_mpc"], ovr["distance_mpc"] = presetData["distance_mpc"]];
      If[ovr =!= <||>,
        cfg = DeepMerge[cfg, <|"simulation" -> <|"chirp" -> ovr|>|>];
        Print["  Loaded preset: ", preset, " (m1=", presetData["mass1"],
              ", m2=", presetData["mass2"], ", d=", presetData["distance_mpc"], " Mpc)"]
      ],
      Print["  Warning: preset \"", preset, "\" not found in config — using defaults."]
    ]
  ]
];

Which[

  (* ══════════════════════════════════════════════════════
     CHIRP MODE — binary inspiral gravitational wave
     ══════════════════════════════════════════════════════ *)
  mode === "chirp",

    With[{
      m1      = GetCfg[cfg, {"simulation","chirp","mass1_solar"},       36.0],
      m2      = GetCfg[cfg, {"simulation","chirp","mass2_solar"},       29.0],
      distMpc = GetCfg[cfg, {"simulation","chirp","distance_mpc"},     410.0],
      fMin    = GetCfg[cfg, {"simulation","chirp","frequency_min_hz"},   20.0],
      ts      = GetCfg[cfg, {"sonification","chirp","time_stretch"},      4.0]
    },

    STEMHeading["General Relativity: Gravitational Wave Chirp (PN Inspiral)"];
    Print["  m1 = ", m1, " M☉   m2 = ", m2, " M☉   distance = ", distMpc, " Mpc"];
    Print["  Starting frequency: ", fMin, " Hz"];
    Print["  Time stretch: ", ts, "×"];
    Print[""]];

    STEMSay["Computing gravitational wave chirp"];
    Print["[1/4] Computing waveform..."];
    model = ChirpModel[cfg];
    Print[""];

    Print["[2/4] Exporting time-series CSV..."];
    With[{
      csvPath  = FileNameJoin[{$outDir, "chirp_timeseries.csv"}],
      tArr     = model["time"],
      hArr     = model["strain"],
      fArr     = model["frequency"],
      aArr     = model["amplitude"]},

      (* Subsample to every 10th row so the CSV stays manageable *)
      With[{
        step = 10,
        rows = Table[
          {tArr[[k]], hArr[[k]], fArr[[k]], aArr[[k]]},
          {k, 1, Length[tArr], 10}]},

        ExportCSV[
          Join[{{"time_s", "strain_h", "frequency_hz", "amplitude"}}, rows],
          csvPath];
        STEMDescribeCSV[csvPath, Length[rows], 4]
      ]
    ];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering gravitational wave animation"];
    AnimateRelativity[model, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    STEMSay["Sonifying gravitational wave"];
    SonifyRelativity[model, cfg, $outDir];
    Print[""],


  (* ══════════════════════════════════════════════════════
     GEODESIC MODE — Schwarzschild test-particle / photon orbit
     ══════════════════════════════════════════════════════ *)
  mode === "geodesic",

    With[{
      orbitType = GetCfg[cfg, {"simulation","geodesic","orbit_type"}, "bound"],
      mass      = GetCfg[cfg, {"simulation","geodesic","mass_solar"},  10.0]
    },

    STEMHeading["General Relativity: Schwarzschild Geodesic"];
    Print["  orbit_type = ", orbitType, "   mass = ", mass, " M\[SmallCircle]"];
    Print[""];

    STEMSay["Computing Schwarzschild geodesic"];
    Print["[1/4] Computing trajectory..."];
    model = GeodesicModel[cfg];
    Print[""];

    Print["[2/4] Exporting trajectory CSV..."];
    With[{
      csvPath = FileNameJoin[{$outDir, "geodesic_trajectory.csv"}],
      tArr    = model["tau"],
      rArr    = model["r"],
      phiArr  = model["phi"],
      xArr    = model["x"],
      yArr    = model["y"]
    },
      With[{
        step = Max[1, Round[Length[tArr] / 5000]],
        rows = Table[
          {tArr[[k]], N[rArr[[k]]/2.0], phiArr[[k]],
           N[xArr[[k]]/2.0], N[yArr[[k]]/2.0]},
          {k, 1, Length[tArr], Max[1, Round[Length[tArr]/5000]]}]},
        ExportCSV[
          Join[{{"tau_M", "r_rs", "phi_rad", "x_rs", "y_rs"}}, rows],
          csvPath];
        STEMDescribeCSV[csvPath, Length[rows], 5]
      ]
    ];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering geodesic animation"];
    AnimateRelativity[model, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    STEMSay["Sonifying geodesic"];
    SonifyRelativity[model, cfg, $outDir];
    Print[""]
    ],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"chirp\" or \"geodesic\"."];
    Exit[1]
];

Print[""];
STEMHeading["Done"];
If[mode === "chirp",
  STEMSay["Relativity complete. Chirp mass " <>
    ToString[NumberForm[N @ model["chirp_mass_solar"], {4,1}]] <>
    " solar masses. Frequency sweep " <>
    ToString[Round[N @ First[model["frequency"]]]] <>
    " to " <>
    ToString[Round[N @ model["peak_frequency"]]] <>
    " hertz. Merger at " <>
    ToString[NumberForm[N @ model["coalescence_time"], {5,3}]] <>
    " seconds. Play audio: " <>
    STEMPlayCmd[FileNameJoin[{$outDir, "chirp.wav"}]]],
  (* geodesic *)
  STEMSay["Geodesic complete. " <>
    ToString[model["orbit_type"]] <> " orbit around " <>
    ToString[NumberForm[N @ model["mass_solar"], {4,1}]] <>
    " M\[SmallCircle] black hole (r_s = " <>
    ToString[NumberForm[N @ model["r_s_km"], {5,2}]] <> " km). " <>
    "r_min = " <> ToString[NumberForm[N @ (model["r_min"]/2.0), {4,2}]] <> " r_s. " <>
    "Total \[Phi] = " <> ToString[NumberForm[N @ Last[model["phi"]], {5,2}]] <> " rad (" <>
    ToString[NumberForm[N @ model["n_revolutions"], {4,2}]] <> " revolutions). " <>
    "Play audio: " <>
    STEMPlayCmd[FileNameJoin[{$outDir, "geodesic.wav"}]]]
]

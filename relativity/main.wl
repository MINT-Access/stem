#!/usr/bin/env wolframscript

(* ========================================================
   Relativity — Entry Point

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode chirp
     wolframscript -file main.wl -- --simulation.chirp.preset gw170817
     wolframscript -file main.wl -- --simulation.chirp.mass1_solar 50
     wolframscript -file main.wl -- --sonification.chirp.time_stretch 8

   Modes:
     chirp — gravitational wave chirp from binary inspiral (PN approximation)
             models GW150914-class events; geodesic mode added in next session

   CLI flags accepted:
     --config-dump
     --simulation.mode
     --simulation.chirp.mass1_solar
     --simulation.chirp.mass2_solar
     --simulation.chirp.distance_mpc
     --simulation.chirp.preset        (gw150914 | gw170817 | stellar)
     --sonification.chirp.time_stretch
     --sonification.chirp.frequency_shift
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


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"chirp\"."];
    Exit[1]
];

Print[""];
STEMHeading["Done"];
STEMSay["Relativity complete. Chirp mass " <>
  ToString[NumberForm[N @ model["chirp_mass_solar"], {4,1}]] <>
  " solar masses. Frequency sweep " <>
  ToString[Round[N @ First[model["frequency"]]]] <>
  " to " <>
  ToString[Round[N @ model["peak_frequency"]]] <>
  " hertz. Merger at " <>
  ToString[NumberForm[N @ model["coalescence_time"], {5,3}]] <>
  " seconds. Play audio: afplay " <>
  FileNameJoin[{$outDir, "chirp.wav"}]]

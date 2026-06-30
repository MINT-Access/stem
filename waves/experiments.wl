#!/usr/bin/env wolframscript

(* waves/experiments.wl — Curated preset runs for wave propagation sonification *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

RunExperiment[name_String, mode_String, overrides_Association] :=
  Module[{cfg, model, outWAV, outCSV},
    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg    = DeepMerge[LoadConfig["waves", {}], overrides];
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];
    Which[
      mode === "ripple",
        model = RippleModel[cfg];
        SonifyRipple[model, cfg, outWAV];
        AnimateRipple[model, $outDir];
        ExportRippleData[model, outCSV],
      mode === "interference",
        model = InterferenceModel[cfg];
        SonifyInterference[model, cfg, outWAV];
        AnimateInterference[model, $outDir];
        ExportInterferenceData[model, outCSV]
    ];
    Print["  Experiment done: ", name]
  ];


(* ── Experiments ─────────────────────────────────────────────────── *)

(* 1. Ripple: default parameters — baseline wavefront propagation *)
RunExperiment["ripple_default", "ripple", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "membrane_radius" -> 1.0,
                                  "duration" -> 4.0, "listening_points" -> 4|>|>
|>];

(* 2. Ripple: faster wave — wavefront arrives sooner at each LP *)
RunExperiment["ripple_fast_wave", "ripple", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 2.0, "membrane_radius" -> 1.0,
                                  "duration" -> 4.0, "listening_points" -> 4|>|>
|>];

(* 3. Ripple: 6 listening points — sequential arrival clearer *)
RunExperiment["ripple_6_lp", "ripple", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "membrane_radius" -> 1.0,
                                  "duration" -> 4.0, "listening_points" -> 6|>|>
|>];

(* 4. Interference: default — 2 sources, sweeping LP *)
RunExperiment["interference_default", "interference", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "source_frequency" -> 2.0,
                                  "tank_width" -> 2.0, "tank_height" -> 1.0,
                                  "duration" -> 4.0|>|>
|>];

(* 5. Interference: higher frequency — more fringes, faster oscillation *)
RunExperiment["interference_high_freq", "interference", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "source_frequency" -> 4.0,
                                  "tank_width" -> 2.0, "tank_height" -> 1.0,
                                  "duration" -> 4.0|>|>
|>];

(* 6. Interference: slow wave speed — wider fringe spacing *)
RunExperiment["interference_slow_wave", "interference", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 0.5, "source_frequency" -> 2.0,
                                  "tank_width" -> 2.0, "tank_height" -> 1.0,
                                  "duration" -> 8.0|>|>
|>];

(* 7. Ripple: large membrane, longer duration — reverb-like reflections *)
RunExperiment["ripple_large_membrane", "ripple", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "membrane_radius" -> 2.0,
                                  "duration" -> 8.0, "listening_points" -> 4|>|>
|>];

(* 8. Interference: wide tank — sweep covers more fringe bands *)
RunExperiment["interference_wide_tank", "interference", <|
  "simulation" -> <|"waves" -> <|"wave_speed" -> 1.0, "source_frequency" -> 3.0,
                                  "tank_width" -> 4.0, "tank_height" -> 1.0,
                                  "duration" -> 4.0|>|>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

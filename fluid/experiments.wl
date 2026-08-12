#!/usr/bin/env wolframscript

(* fluid/experiments.wl — Curated preset runs for Karman vortex street sonification *)

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
  Module[{cfg, model, outWAV, outCSV, audioDur},
    Print[""];
    STEMHeading["Experiment: " <> name];
    cfg    = DeepMerge[LoadConfig["fluid", {}], overrides];
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    outCSV = FileNameJoin[{$outDir, name <> "_data.csv"}];
    (* Sonify before Animate: GIF duration is synced to the actual WAV
       duration returned by Sonify* (see fluid/AGENTS.md "GIF/WAV
       duration sync"), which isn't known until the intro speech has
       actually been synthesised. *)
    Which[
      mode === "karman",
        model = KarmanModel[cfg];
        audioDur = SonifyKarman[model, cfg, outWAV];
        AnimateKarman[model, $outDir, audioDur];
        ExportKarmanCSV[model, outCSV],
      mode === "strouhal",
        model = StrouhalSweepModel[cfg];
        audioDur = SonifyStrouhal[model, cfg, outWAV];
        AnimateStrouhal[model, $outDir, audioDur];
        ExportStrouhalCSV[model, outCSV],
      mode === "flag",
        model = FlagModel[cfg];
        audioDur = SonifyFlag[model, cfg, outWAV];
        AnimateFlag[model, $outDir, audioDur];
        ExportFlagCSV[model, outCSV]
    ];
    Print["  Experiment done: ", name]
  ];


(* ── Experiments ─────────────────────────────────────────────────── *)

(* 1. Karman: default parameters -- clean laminar Karman street, Re=150 *)
RunExperiment["karman_default", "karman", <|
  "simulation" -> <|"fluid" -> <|"Re" -> 150.0, "U" -> 1.0, "D" -> 1.0,
                                  "duration" -> 40.0, "n_vortices_max" -> 200,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 2. Karman: low Re -- cleaner, more regular shedding *)
RunExperiment["karman_low_re", "karman", <|
  "simulation" -> <|"fluid" -> <|"Re" -> 80.0, "U" -> 1.0, "D" -> 1.0,
                                  "duration" -> 40.0, "n_vortices_max" -> 200,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 3. Karman: high Re -- noisier, closer to the turbulent transition *)
RunExperiment["karman_high_re", "karman", <|
  "simulation" -> <|"fluid" -> <|"Re" -> 250.0, "U" -> 1.0, "D" -> 1.0,
                                  "duration" -> 40.0, "n_vortices_max" -> 200,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 4. Karman: higher reference pitch (A4 = 440 Hz instead of A3 = 220 Hz) *)
RunExperiment["karman_higher_pitch", "karman", <|
  "simulation" -> <|"fluid" -> <|"Re" -> 150.0, "U" -> 1.0, "D" -> 1.0,
                                  "duration" -> 40.0, "n_vortices_max" -> 200,
                                  "audio_freq_target" -> 440.0|>|>
|>];

(* 5. Karman: longer simulation -- more shed events, longer street *)
RunExperiment["karman_long", "karman", <|
  "simulation" -> <|"fluid" -> <|"Re" -> 150.0, "U" -> 1.0, "D" -> 1.0,
                                  "duration" -> 80.0, "n_vortices_max" -> 200,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 6. Strouhal: default full sweep -- silence, onset, laminar, transition *)
RunExperiment["strouhal_default", "strouhal", <|
  "simulation" -> <|"fluid" -> <|"Re_start" -> 20.0, "Re_end" -> 300.0, "Re_steps" -> 50,
                                  "U" -> 1.0, "D" -> 1.0, "duration_per_Re" -> 10.0,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 7. Strouhal: zoomed near onset -- the silence-to-tone transition, close up *)
RunExperiment["strouhal_onset_zoom", "strouhal", <|
  "simulation" -> <|"fluid" -> <|"Re_start" -> 30.0, "Re_end" -> 90.0, "Re_steps" -> 30,
                                  "U" -> 1.0, "D" -> 1.0, "duration_per_Re" -> 10.0,
                                  "audio_freq_target" -> 220.0|>|>
|>];

(* 8. Flag: default -- flag_length=5, moderate flutter rate *)
RunExperiment["flag_default", "flag", <|
  "simulation" -> <|"fluid" -> <|"U" -> 1.0, "flag_length" -> 5.0, "flag_stiffness" -> 0.1,
                                  "duration" -> 30.0, "audio_freq_target" -> 220.0|>|>
|>];

(* 9. Flag: longer flag -- lower flutter frequency (0.15 U / flagLength) *)
RunExperiment["flag_long", "flag", <|
  "simulation" -> <|"fluid" -> <|"U" -> 1.0, "flag_length" -> 10.0, "flag_stiffness" -> 0.1,
                                  "duration" -> 60.0, "audio_freq_target" -> 220.0|>|>
|>];

Print[""];
STEMHeading["All experiments complete"];
Print["  Output files written to: ", $outDir]

(* lagrange/src/sonify.wl — CR3BP trajectory audio synthesis *)

(* Target audio durations — single source of truth, shared with animate.wl
   so the GIF's playback length can be made to match the WAV exactly. *)
LibrationAudioDuration[model_Association] := N[Max[15.0, 0.5 * model["tEnd"]]];
EscapeAudioDuration[model_Association]     := N[Max[8.0, 0.6 * model["tActual"]]];

(* Sonify the l4/l5 libration trajectory.
   Pitch: angular velocity around barycentre; Pan: x-position; Volume: 1/min(r1,r2). *)
SonifyLibration[model_Association, mode_String, cfg_Association, outWAV_String] :=
  Module[{tSamp, xV, omV, invDV, nPts, lLabel,
          audioDur, traj, cfgSon},
    tSamp  = model["tSamp"];
    xV     = model["xV"];
    omV    = model["omV"];
    invDV  = model["invDV"];
    nPts   = model["nPts"];
    lLabel = model["lLabel"];

    audioDur = LibrationAudioDuration[model];
    traj = N @ Transpose[{tSamp, xV, omV, ConstantArray[0.0, nPts], invDV}];
    cfgSon = DeepMerge[cfg, <|"sonification" -> <|
      "duration" -> audioDur,
      "pitch"    -> <|"axis" -> "y", "min_hz" -> 110.0, "max_hz" -> 880.0|>,
      "volume"   -> <|"min_db" -> -28.0, "max_db" -> -3.0|>
    |>|>];
    SonifyTrajectory[traj, cfgSon, outWAV]
  ];

(* Sonify the L1 escape trajectory.
   Wider pitch range (55-1760 Hz) to make the escape dynamics more dramatic. *)
SonifyEscape[model_Association, cfg_Association, outWAV_String] :=
  Module[{tSamp, xV, omV, invDV, nPts, audioDur, traj, cfgSon},
    tSamp   = model["tSamp"];
    xV      = model["xV"];
    omV     = model["omV"];
    invDV   = model["invDV"];
    nPts    = model["nPts"];

    audioDur = EscapeAudioDuration[model];
    traj = N @ Transpose[{tSamp, xV, omV, ConstantArray[0.0, nPts], invDV}];
    cfgSon = DeepMerge[cfg, <|"sonification" -> <|
      "duration" -> audioDur,
      "pitch"    -> <|"axis" -> "y", "min_hz" -> 55.0, "max_hz" -> 1760.0|>,
      "volume"   -> <|"min_db" -> -30.0, "max_db" -> -3.0|>
    |>|>];
    SonifyTrajectory[traj, cfgSon, outWAV]
  ];

(* lagrange/src/sonify.wl — CR3BP trajectory audio synthesis *)

(* Sonify the l4/l5 libration trajectory.
   Pitch: angular velocity around barycentre; Pan: x-position; Volume: 1/min(r1,r2). *)
SonifyLibration[model_Association, mode_String, cfg_Association, outWAV_String] :=
  Module[{tSamp, xV, omV, invDV, nPts, tEnd, lLabel,
          audioDur, traj, cfgSon},
    tSamp  = model["tSamp"];
    xV     = model["xV"];
    omV    = model["omV"];
    invDV  = model["invDV"];
    nPts   = model["nPts"];
    tEnd   = model["tEnd"];
    lLabel = model["lLabel"];

    audioDur = N[Max[15.0, 0.5 * tEnd]];
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
  Module[{tSamp, xV, omV, invDV, nPts, tActual, audioDur, traj, cfgSon},
    tSamp   = model["tSamp"];
    xV      = model["xV"];
    omV     = model["omV"];
    invDV   = model["invDV"];
    nPts    = model["nPts"];
    tActual = model["tActual"];

    audioDur = N[Max[8.0, 0.6 * tActual]];
    traj = N @ Transpose[{tSamp, xV, omV, ConstantArray[0.0, nPts], invDV}];
    cfgSon = DeepMerge[cfg, <|"sonification" -> <|
      "duration" -> audioDur,
      "pitch"    -> <|"axis" -> "y", "min_hz" -> 55.0, "max_hz" -> 1760.0|>,
      "volume"   -> <|"min_db" -> -30.0, "max_db" -> -3.0|>
    |>|>];
    SonifyTrajectory[traj, cfgSon, outWAV]
  ];

(* waves/src/sonify.wl — Audio synthesis for wave propagation *)

(* Build mono signal from a trajectory using 3-layer pipeline.
   Bypasses MixLayers so the caller can apply per-LP stereo pan. *)
WavesMono[traj_?MatrixQ, cfgAudio_Association] :=
  Module[{sp, mo, ev, amp, carrier},
    sp      = SpatialLayer[traj, cfgAudio];
    mo      = MotionLayer[traj, cfgAudio];
    ev      = EventLayer[traj, cfgAudio, {}];
    amp     = 10.0^(sp["vol"] / 20.0);
    carrier = Sin[2.0 Pi * Accumulate[sp["pitch"]] / sp["sr"]];
    amp * mo["envelope"] * mo["tremolo"] * mo["roughness"] * carrier + ev["audio"]
  ];

(* Constant-power stereo pan: mono list -> {left, right} matrix *)
PanStereo[mono_List, panVal_?NumericQ] :=
  Transpose[{
    mono * Sqrt[N @ Max[0.0, (1.0 - panVal) / 2.0]],
    mono * Sqrt[N @ Max[0.0, (1.0 + panVal) / 2.0]]
  }];

(* Build LP trajectory for SpatialLayer: {t, disp, disp, 0, |d_disp/dt|}.
   Tiny jitter guards against zero-range displacement in Rescale. *)
MakeLPTraj[tAudio_List, disp_List] :=
  Module[{n, dt, speed, dRange, d2},
    n      = Length[tAudio];
    dt     = If[n > 1, tAudio[[2]] - tAudio[[1]], 1.0];
    speed  = Abs @ Differences[Append[N @ disp, 0.0]] / N[dt];
    dRange = Max[N @ disp] - Min[N @ disp];
    d2     = If[dRange < 1.0*^-8,
      N @ disp + 1.0*^-6 * Table[Sin[2.0 Pi * i / n], {i, n}],
      N @ disp];
    Transpose[{tAudio, d2, d2, ConstantArray[0.0, n], speed}]
  ];

(* Config with pitch axis and audio duration for LP trajectories *)
AudioCfg[cfgBase_Association, dur_?NumericQ] :=
  DeepMerge[cfgBase, <|"sonification" -> <|
    "duration" -> N[dur],
    "pitch"    -> <| "axis" -> "x", "min_hz" -> 110.0, "max_hz" -> 880.0 |>,
    "volume"   -> <| "min_db" -> -28.0, "max_db" -> -3.0 |>
  |>|>];

(* Sonify the ripple model: mix nLP panned mono signals into a stereo WAV. *)
SonifyRipple[model_Association, cfg_Association, outWAV_String] :=
  Module[{lpDisp, lpPans, nLP, nT, tVals, tEnd,
          stretchR, audioDurR, cfgR, tAudioR, allStereoR, combinedR},
    lpDisp  = model["lpDisp"];
    lpPans  = model["lpPans"];
    nLP     = model["nLP"];
    nT      = model["nT"];
    tVals   = model["tVals"];
    tEnd    = model["tEnd"];

    stretchR  = 5.0;
    audioDurR = N[tEnd * stretchR];
    cfgR      = AudioCfg[cfg, audioDurR];
    tAudioR   = N @ Rescale[Range[nT], {1, nT}, {0.0, audioDurR}];

    allStereoR = Table[
      PanStereo[
        WavesMono[MakeLPTraj[tAudioR, lpDisp[[k]]], cfgR],
        lpPans[[k]]
      ],
      {k, nLP}];

    combinedR = Total[allStereoR] / nLP;
    RenderAudio[combinedR, cfgR, outWAV];
    STEMDescribeWAV[outWAV, audioDurR];
    Print["  Listen for: wavefront arriving at LP1 (leftmost), then LP2, LP3, LP4 in sequence."];
    Print["  Pan: ", StringRiffle[Map[FmtN[#, {4,2}] &, lpPans], " -> "],
          "  (left to right)"]
  ];

(* Sonify the interference model: moving LP with x-position as pan. *)
SonifyInterference[model_Association, cfg_Association, outWAV_String] :=
  Module[{dispMoving, xMoving, nT, tVals, dt, tEnd,
          stretchI, audioDurI, speedI, tAudioI, cfgI, trajI},
    dispMoving = model["dispMoving"];
    xMoving    = model["xMoving"];
    nT         = model["nT"];
    tVals      = model["tVals"];
    dt         = model["dt"];
    tEnd       = model["tEnd"];

    stretchI  = 4.0;
    audioDurI = N[tEnd * stretchI];
    speedI    = Abs @ Differences[Append[N @ dispMoving, 0.0]] / dt;
    tAudioI   = N @ Rescale[Range[nT], {1, nT}, {0.0, audioDurI}];

    cfgI = DeepMerge[cfg, <|"sonification" -> <|
      "duration"  -> audioDurI,
      "pitch"     -> <| "axis" -> "y", "min_hz" -> 80.0, "max_hz" -> 1200.0 |>,
      "spatial"   -> <| "pan_axis" -> "x" |>,
      "volume"    -> <| "min_db" -> -28.0, "max_db" -> -3.0 |>
    |>|>];

    trajI = Transpose[{tAudioI, N @ xMoving, N @ dispMoving,
                       ConstantArray[0.0, nT], speedI}];
    SonifyTrajectory[trajI, cfgI, outWAV, {}];
    STEMDescribeWAV[outWAV, audioDurI];
    Print["  First half: LP stationary at centre (constructive) -- sustained tone."];
    Print["  Second half: LP sweeps left-to-right -- loud/quiet fringe bands audible."]
  ];

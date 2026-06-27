(* ========================================================
   src/sonify.wl — Cellular automata sonification

   Converts a 3D grid array into audio by:
   1. Building a {t, x, y, z, speed} trajectory matrix that
      encodes population dynamics as spatial/pitch/volume signals
   2. Detecting custom extinction and explosion events
   3. Synthesising marker tones for each event
   4. Mixing all layers into a stereo WAV via stem-core

   Trajectory column mapping:
     t     — generation number (time axis)
     x     — (left_pop − right_pop) / cols  [pan: left/right asymmetry]
     y     — total_pop / total_cells         [pitch: population density]
     z     — 0.0
     speed — |Δpopulation| + ε              [volume: rate of change]

   Events:
     extinction — population drops > 40% in one step → 150 Hz low burst
     explosion  — population rises > 40% in one step → 900 Hz high burst
   ======================================================== *)


(* GridToTrajectory
   Computes the {nGen, 5} trajectory matrix from the 3D grid.
   The ε on speed prevents MinMax degeneracy when population
   is stationary (which would cause Rescale to divide by zero). *)

GridToTrajectory[grid3D_List, cfg_Association] :=
  Module[{nGen, nRows, nCols, halfCols,
          populations, leftPop, rightPop,
          pan, density, delta, zeros, t},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    halfCols = Floor[nCols / 2];

    populations = N[Total[grid3D, {2, 3}]];
    leftPop     = N[Total[grid3D[[All, All, 1 ;; halfCols]], {2, 3}]];
    rightPop    = N[Total[grid3D[[All, All, halfCols + 1 ;; nCols]], {2, 3}]];

    pan     = (leftPop - rightPop) / N[nCols];
    density = populations / N[nRows * nCols];
    delta   = Append[Abs[Differences[populations]], 0.0] + 0.01;

    zeros = ConstantArray[0.0, nGen];
    t     = N[Range[0, nGen - 1]];

    Transpose[{t, pan, density, zeros, delta}]
  ]


(* SynthBurst
   Adds a short exponentially-decayed sine burst at sample index
   `startIdx` into the mutable `buffer` list.
   freq     — burst frequency in Hz
   startIdx — 1-indexed sample position
   sr       — sample rate
   nSamples — total buffer length (for clipping) *)

SynthBurst[buffer_List, freq_, startIdx_, sr_, nSamples_] :=
  Module[{burstLen, endIdx, burst},
    burstLen = Round[0.06 * sr];   (* 60 ms *)
    endIdx   = Min[startIdx + burstLen - 1, nSamples];
    burst    = 0.45 * Table[
      Sin[2 Pi * freq * i / sr] * Exp[-8 i / burstLen],
      {i, 0, endIdx - startIdx}
    ];
    ReplacePart[buffer,
      Table[startIdx + i -> buffer[[startIdx + i]] + burst[[i + 1]],
            {i, 0, endIdx - startIdx}]]
  ]


(* SonifyCellular
   Main entry point: produces a stereo WAV at outPath.
   Calls SpatialLayer, MotionLayer, and RenderAudio from
   stem-core/sonification.wl directly (bypassing SonifyTrajectory)
   so that the custom event audio can be mixed in before rendering. *)

SonifyCellular[grid3D_List, cfg_Association, outPath_String] :=
  Module[
    {nGen, nRows, nCols, populations, deltas,
     audioDuration, cfgDur, trajectory,
     sr, nSamples, burstLen,
     extinctions, explosions,
     eventAudio, idx, sp, mo, ev, stereo,
     extinctEnabled, explosEnabled},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    populations = N[Total[grid3D, {2, 3}]];

    audioDuration = N[nGen] * 0.1;   (* 0.1 s per generation *)
    cfgDur = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> audioDuration |> |>];

    trajectory = GridToTrajectory[grid3D, cfgDur];

    sr       = GetCfg[cfgDur, {"sonification","sample_rate"}, 44100];
    nSamples = Round[sr * audioDuration];
    burstLen = Round[0.06 * sr];

    (* ── Event detection ── *)
    extinctions = {};
    explosions  = {};
    extinctEnabled = GetCfg[cfgDur, {"sonification","events","extinction"}, True];
    explosEnabled  = GetCfg[cfgDur, {"sonification","events","explosion"},  True];

    Do[
      Module[{prev, cur, frac},
        prev = populations[[g]];
        cur  = populations[[g + 1]];
        If[prev > 0,
          frac = (cur - prev) / prev;
          If[extinctEnabled && frac < -0.4,
            AppendTo[extinctions, g - 1]];   (* 0-indexed generation *)
          If[explosEnabled  && frac >  0.4,
            AppendTo[explosions,  g - 1]]
        ]
      ],
      {g, 1, nGen - 1}
    ];

    (* ── Build event audio buffer ── *)
    eventAudio = ConstantArray[0.0, nSamples];

    genToSample[g0_] :=
      Clip[Round[g0 / Max[nGen - 1, 1] * nSamples], {1, nSamples}];

    (* Low burst (150 Hz) for each extinction *)
    Do[
      idx = genToSample[g];
      With[{end = Min[idx + burstLen - 1, nSamples]},
        eventAudio[[idx ;; end]] +=
          0.45 * Table[Sin[2 Pi * 150 * i / sr] * Exp[-8 i / burstLen],
                       {i, 0, end - idx}]
      ],
      {g, extinctions}
    ];

    (* High burst (900 Hz) for each explosion *)
    Do[
      idx = genToSample[g];
      With[{end = Min[idx + burstLen - 1, nSamples]},
        eventAudio[[idx ;; end]] +=
          0.45 * Table[Sin[2 Pi * 900 * i / sr] * Exp[-8 i / burstLen],
                       {i, 0, end - idx}]
      ],
      {g, explosions}
    ];

    Print["  Extinctions (>40% drop): ", Length[extinctions]];
    Print["  Explosions  (>40% rise): ", Length[explosions]];
    Print["  Trajectory: ", nGen, " generations, ", FmtN[audioDuration, 4], " s"];

    sp     = SpatialLayer[trajectory, cfgDur];
    mo     = MotionLayer[trajectory, cfgDur];
    ev     = <| "audio" -> eventAudio, "events" -> {}, "sr" -> sr |>;
    stereo = MixLayers[sp, mo, ev, cfgDur];

    EnsureDir[outPath];
    RenderAudio[stereo, cfgDur, outPath]
  ]

(* ========================================================
   quantum/src/sonify.wl — Sonification for quantum density

   Public API:
     DensityToTrajectory[solution]
       Converts |psi(x,t)|^2 density field to a {t,x,y,z,speed}
       trajectory matrix for SonifyTrajectory.
         x     -> <x>(t)    stereo pan
         y     -> Var(x)(t) pitch (apex detection at variance extremes)
         z     -> 0
         speed -> |d<x>/dt| volume dynamics

     SonifyQuantum[solution, cfg, outDir]
       Runs the full audio pipeline. Outputs:
         {mode}_audio.wav  — sonification via SonifyTrajectory
   ======================================================== *)


DensityToTrajectory[solution_Association] :=
  Module[{density, xVals, xVals2, tVals, nt, dx,
          meanX, meanX2, varX, speed, varRange},

    density = solution["density"];
    xVals   = solution["x"];
    xVals2  = xVals^2;
    tVals   = solution["t"];
    nt      = Length[tVals];
    dx      = solution["dx"];

    (* Expectation values via quadrature sum (density rows are nx-vectors) *)
    meanX  = density . xVals  * dx;   (* {nt} *)
    meanX2 = density . xVals2 * dx;   (* {nt} *)
    varX   = meanX2 - meanX^2;        (* {nt} *)

    (* Speed: |d<x>/dt| via central differences; boundary points set to 0 *)
    speed = Table[
      If[it === 1 || it === nt,
        0.0,
        Abs[(meanX[[it + 1]] - meanX[[it - 1]]) /
            (tVals[[it + 1]] - tVals[[it - 1]])]
      ],
      {it, nt}
    ];

    (* Guard: if variance is nearly flat (e.g. QHO coherent state), add a tiny
       sinusoidal component so SonifyTrajectory's pitch Rescale is non-degenerate *)
    varRange = Max[varX] - Min[varX];
    If[varRange < 1.0*^-4 * (Mean[Abs[varX]] + $MachineEpsilon),
      varX = varX +
        0.001 * Mean[Abs[varX]] * Table[Sin[2.0 * Pi * it / nt], {it, nt}]
    ];

    Transpose[{tVals, meanX, varX, ConstantArray[0.0, nt], speed}]
  ]


SonifyQuantum[solution_Association, cfg_Association, outDir_String] :=
  Module[{mode, traj, tEnd, cfgSon, audioPath},

    mode  = solution["mode"];
    traj  = DensityToTrajectory[solution];
    tEnd  = Last[solution["t"]];

    (* Override sonification duration to match simulation time span *)
    cfgSon = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> N[tEnd] |> |>];

    audioPath = FileNameJoin[{outDir, mode <> "_audio.wav"}];
    STEMSay["Sonifying " <> mode <> " density trajectory"];
    EnsureDir[audioPath];
    SonifyTrajectory[traj, cfgSon, audioPath, {"apex", "crossing"}];
    STEMDescribeWAV[audioPath, N[tEnd]]
  ]

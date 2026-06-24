(* ========================================================
   src/animate.wl — Pendulum animation export

   Reads simulation results and exports an animated GIF.
   Each frame shows the pendulum at one time step, with
   a small trail to convey motion.

   Usage (called from main.wl or standalone):
     Get["src/animate.wl"]
     ExportAnimation[solution, params, "data/pendulum_animation.gif"]
   ======================================================== *)


(* PendulumFrame
   Renders a single frame of the pendulum at angle theta.
   Also accepts a list of recent angles for the motion trail. *)

PendulumFrame[theta_?NumericQ, trailAngles_List, params_Association] :=
  Module[
    {L, pivotX, pivotY, bobX, bobY,
     trailPoints, trailLine, rod, pivot, bob,
     energyFrac},

    L      = params["Length"];
    pivotX = 0.0;
    pivotY = 0.0;

    (* Current bob position — y is downward in pendulum coords *)
    bobX =  L * Sin[theta];
    bobY = -L * Cos[theta];

    (* Trail: positions of recent frames, fading out *)
    trailPoints = {L * Sin[#], -L * Cos[#]} & /@ trailAngles;

    trailLine = If[Length[trailPoints] > 1,
      {Opacity[0.25], Thickness[0.008],
       RGBColor[0.4, 0.6, 1.0],
       Line[trailPoints]},
      {}
    ];

    (* Rod from pivot to bob *)
    rod = {
      Thickness[0.012],
      GrayLevel[0.35],
      Line[{{pivotX, pivotY}, {bobX, bobY}}]
    };

    (* Pivot point *)
    pivot = {
      GrayLevel[0.2],
      Disk[{pivotX, pivotY}, 0.04]
    };

    (* Bob — colour shifts with angle (potential energy proxy) *)
    energyFrac = Clip[Abs[theta] / (params["InitAngle"] + 0.001), {0, 1}];
    bob = {
      RGBColor[0.2 + 0.6 * energyFrac, 0.3, 1.0 - 0.5 * energyFrac],
      Disk[{bobX, bobY}, 0.07]
    };

    Graphics[
      {
        (* Ceiling line *)
        {GrayLevel[0.6], Thickness[0.006], Line[{{-1.3, 0}, {1.3, 0}}]},
        trailLine,
        rod,
        pivot,
        bob
      },
      PlotRange -> {{-1.4, 1.4}, {-1.4, 0.25}},
      Background -> RGBColor[0.97, 0.97, 1.0],
      ImageSize -> {480, 400}
    ]
  ]


(* ExportAnimation
   Builds all frames and exports to an animated GIF.

   Parameters:
     solution  — output of SolvePendulum (list of {t, angle, velocity})
     params    — the simulation parameters Association
     filePath  — destination path, e.g. "data/pendulum_animation.gif"
     frameRate — frames per second in the GIF (default 25)
     speedup   — playback speed multiplier (default 1.0, try 2.0 to go faster) *)

ExportAnimation[solution_List, params_Association, filePath_String,
                frameRate_:25, speedup_:1.0] :=
  Module[
    {dt, stride, sampledSol, trailLen, frames},

    dt = params["TimeStep"];

    (* Sub-sample so we get approximately frameRate fps of simulation time *)
    stride = Max[1, Round[1.0 / (frameRate * dt * speedup)]];
    sampledSol = solution[[1 ;; -1 ;; stride]];

    (* Trail length: keep last ~0.3 s worth of frames *)
    trailLen = Max[2, Round[0.3 * frameRate]];

    Print["  Rendering ", Length[sampledSol], " frames..."];

    (* Build each frame with a motion trail *)
    frames = Table[
      Module[{trailStart, trailAngles},
        trailStart  = Max[1, k - trailLen];
        trailAngles = sampledSol[[trailStart ;; k, 2]];
        PendulumFrame[sampledSol[[k, 2]], trailAngles, params]
      ],
      {k, 1, Length[sampledSol]}
    ];

    ExportGIF[frames, filePath, frameRate]
  ]

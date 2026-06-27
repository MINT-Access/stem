(* ========================================================
   src/sonify.wl — Sonification via stem-core SonifyTrajectory

   Converts the pendulum solution {t, theta, omega} into the
   {t, x, y, z, speed} column layout expected by SonifyTrajectory:

     t     — simulation time
     x     — bob x-position = L * Sin[theta]   (stereo pan axis)
     y     — angle theta                         (apex detection on |y|)
     z     — 0.0 (simple pendulum is 2D)
     speed — L * |omega|   (actual bob speed; controls volume)

   Event types:
     "apex"     — local maximum of |y| = maximum swing angle
     "crossing" — x passes through zero = bob at centre
   ======================================================== *)

(* SonifyDoublePendulum
   Builds a binaural stereo WAV for the double pendulum.

   Trajectories:
     Rod 1 — {t, L1·sinθ1, −L1·cosθ1, 0, L1·|ω1|}
     Rod 2 — {t, x2, y2, 0, speed2}
     where x2 = L1·sinθ1 + L2·sinθ2
           y2 = −L1·cosθ1 − L2·cosθ2
           speed2 = sqrt(L1²ω1² + L2²ω2² + 2L1L2ω1ω2·cos(θ1−θ2))

   Mixing: layers are built independently per rod, then the pan for
   rod 1 is offset by −0.4 (biased left) and rod 2 by +0.4 (biased
   right) before the constant-power pan law is applied.  Both stereo
   pairs are summed into one output and normalised by RenderAudio. *)

SonifyDoublePendulum[solution_List, cfg_Association, outPath_String] :=
  Module[
    {L1, L2,
     times, theta1, omega1, theta2, omega2,
     x1, y1, x2, y2, speed1, speed2, nPts, zeros,
     traj1, traj2, trajDuration, cfgDur,
     sp1, mo1, ev1, sp2, mo2, ev2,
     stereo1, stereo2, mixed},

    L1     = GetCfg[cfg, {"simulation","double","length1"}, 1.0];
    L2     = GetCfg[cfg, {"simulation","double","length2"}, 1.0];

    times  = solution[[All, 1]];
    theta1 = solution[[All, 2]];
    omega1 = solution[[All, 3]];
    theta2 = solution[[All, 4]];
    omega2 = solution[[All, 5]];

    x1 =  L1 * Sin[theta1];
    y1 = -L1 * Cos[theta1];
    x2 = x1 + L2 * Sin[theta2];
    y2 = y1 - L2 * Cos[theta2];

    speed1 = L1 * Abs[omega1];
    speed2 = Sqrt[
      L1^2 * omega1^2 + L2^2 * omega2^2 +
      2 * L1 * L2 * omega1 * omega2 * Cos[theta1 - theta2]
    ];

    nPts  = Length[times];
    zeros = ConstantArray[0.0, nPts];

    traj1 = N[Transpose[{times, x1, y1, zeros, speed1}]];
    traj2 = N[Transpose[{times, x2, y2, zeros, speed2}]];

    trajDuration = Last[times];
    cfgDur = DeepMerge[cfg,
               <| "sonification" -> <| "duration" -> trajDuration |> |>];

    Print["  Building spatial + motion layers for rod 1..."];
    sp1 = SpatialLayer[traj1, cfgDur];
    mo1 = MotionLayer[traj1, cfgDur];
    ev1 = EventLayer[traj1, cfgDur, {"apex", "crossing"}];

    Print["  Building spatial + motion layers for rod 2..."];
    sp2 = SpatialLayer[traj2, cfgDur];
    mo2 = MotionLayer[traj2, cfgDur];
    ev2 = EventLayer[traj2, cfgDur, {"apex", "crossing"}];

    (* Bias rod 1 left (−0.4), rod 2 right (+0.4) *)
    stereo1 = MixLayers[
      Append[sp1, "pan" -> Clip[sp1["pan"] - 0.4, {-1.0, 1.0}]],
      mo1, ev1, cfgDur];
    stereo2 = MixLayers[
      Append[sp2, "pan" -> Clip[sp2["pan"] + 0.4, {-1.0, 1.0}]],
      mo2, ev2, cfgDur];

    mixed = stereo1 + stereo2;

    EnsureDir[outPath];
    Print["  Rod 1: ", nPts, " samples, biased left (pan − 0.4)"];
    Print["  Rod 2: ", nPts, " samples, biased right (pan + 0.4)"];

    RenderAudio[mixed, cfgDur, outPath]
  ]


ExportSonification[solution_List, params_Association,
                   cfg_Association, filePath_String] :=
  Module[{L, trajectory, trajDuration, cfgWithDuration},

    L = params["Length"];

    trajectory = N[{
      #[[1]],           (* t *)
      L * Sin[#[[2]]],  (* x: bob x-position for pan *)
      #[[2]],           (* y: angle for apex detection *)
      0.0,              (* z: unused for simple pendulum *)
      L * Abs[#[[3]]]   (* speed: actual bob speed for volume *)
    } & /@ solution];

    trajDuration    = solution[[-1, 1]];
    cfgWithDuration = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> trajDuration |> |>];

    EnsureDir[filePath];
    Print["  Trajectory: ", Length[trajectory], " samples, ",
      FmtN[trajDuration, 4], " s"];

    SonifyTrajectory[trajectory, cfgWithDuration, filePath,
      {"apex", "crossing"}]
  ]

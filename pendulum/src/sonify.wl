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

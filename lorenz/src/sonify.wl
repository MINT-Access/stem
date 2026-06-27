(* ========================================================
   src/sonify.wl — Sonification via stem-core SonifyTrajectory

   The {t, x, y, z} solution is augmented with an
   instantaneous speed column computed via finite differences.
   This approach is attractor-agnostic and works for both
   Lorenz and Rössler (dt=0.005 gives sub-0.01% error).

   Column layout for SonifyTrajectory: {t, x, y, z, speed}

   Event type: "apex"
     Local maxima of |y| correlate with the trajectory
     crossing between the two wings (Lorenz) or completing
     a spiral cycle (Rössler).
   ======================================================== *)

ExportSonification[solution_List, params_Association,
                   cfg_Association, filePath_String] :=
  Module[{dt, vx, vy, vz, speeds, trajectory, trajDuration, cfgWithDuration},

    (* Generic speed via finite differences — works for any 3D attractor *)
    dt     = solution[[2, 1]] - solution[[1, 1]];
    vx     = Differences[solution[[All, 2]]] / dt;
    vy     = Differences[solution[[All, 3]]] / dt;
    vz     = Differences[solution[[All, 4]]] / dt;
    speeds = Append[Sqrt[vx^2 + vy^2 + vz^2],
                    Last[Sqrt[vx^2 + vy^2 + vz^2]]];

    trajectory = N[MapThread[
      {#1[[1]], #1[[2]], #1[[3]], #1[[4]], #2} &,
      {solution, speeds}
    ]];

    trajDuration    = solution[[-1, 1]];
    cfgWithDuration = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> trajDuration |> |>];

    EnsureDir[filePath];
    Print["  Trajectory: ", Length[trajectory], " samples, ",
      FmtN[trajDuration, 4], " s"];

    SonifyTrajectory[trajectory, cfgWithDuration, filePath, {"apex"}]
  ]

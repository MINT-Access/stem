(* ========================================================
   src/sonify.wl — Sonification via stem-core SonifyTrajectory

   The Lorenz solution {t, x, y, z} is augmented with an
   instantaneous speed column computed analytically from the
   Lorenz ODEs (more accurate than finite differences):

     dx/dt = sigma * (y - x)
     dy/dt = x * (rho - z) - y
     dz/dt = x * y - beta * z
     speed = sqrt((dx/dt)^2 + (dy/dt)^2 + (dz/dt)^2)

   Column layout for SonifyTrajectory: {t, x, y, z, speed}

   Event type: "apex"
     Local maxima of |y| correlate with the trajectory
     crossing between the two wings of the attractor.
   ======================================================== *)

ExportSonification[solution_List, params_Association,
                   cfg_Association, filePath_String] :=
  Module[{sigma, rho, beta, trajectory, trajDuration, cfgWithDuration},

    sigma = params["Sigma"];
    rho   = params["Rho"];
    beta  = params["Beta"];

    trajectory = N[{
      #[[1]],                                (* t *)
      #[[2]],                                (* x *)
      #[[3]],                                (* y *)
      #[[4]],                                (* z *)
      Sqrt[                                  (* speed from Lorenz ODEs *)
        (sigma * (#[[3]] - #[[2]]))^2 +
        (#[[2]] * (rho   - #[[4]]) - #[[3]])^2 +
        (#[[2]] * #[[3]] - beta   * #[[4]])^2]
    } & /@ solution];

    trajDuration    = solution[[-1, 1]];
    cfgWithDuration = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> trajDuration |> |>];

    EnsureDir[filePath];
    Print["  Trajectory: ", Length[trajectory], " samples, ",
      FmtN[trajDuration, 4], " s"];

    SonifyTrajectory[trajectory, cfgWithDuration, filePath, {"apex"}]
  ]

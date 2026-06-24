(* ========================================================
   src/model.wl — Lorenz system ODE definition and solver

   The Lorenz equations (Lorenz, 1963):
       x'(t) = sigma * (y - x)
       y'(t) = x * (rho - z) - y
       z'(t) = x * y - beta * z

   Classic chaotic parameters: sigma=10, rho=28, beta=8/3.
   The solution forms a strange attractor — bounded but
   never periodic, sensitive to initial conditions.
   ======================================================== *)


(* SolveLorenz
   Input:  params — Association with keys:
             Sigma, Rho, Beta,
             InitX, InitY, InitZ,
             TimeEnd, TimeStep
   Output: list of {t, x, y, z} quadruples *)

SolveLorenz[params_Association] := Module[
  {sigma, rho, beta, x0, y0, z0, tEnd, dt, sol, times},

  sigma = params["Sigma"];
  rho   = params["Rho"];
  beta  = params["Beta"];
  x0    = params["InitX"];
  y0    = params["InitY"];
  z0    = params["InitZ"];
  tEnd  = params["TimeEnd"];
  dt    = params["TimeStep"];

  sol = NDSolve[
    {
      x'[t] == sigma * (y[t] - x[t]),
      y'[t] == x[t] * (rho - z[t]) - y[t],
      z'[t] == x[t] * y[t] - beta * z[t],
      x[0]  == x0,
      y[0]  == y0,
      z[0]  == z0
    },
    {x, y, z},
    {t, 0, tEnd},
    MaxStepSize -> dt
  ];

  times = Range[0, tEnd, dt];

  {#,
   x[#] /. sol[[1]],
   y[#] /. sol[[1]],
   z[#] /. sol[[1]]
  } & /@ times
]


(* SolveLorenzPair
   Solves two trajectories with nearly identical initial conditions.
   Used to demonstrate sensitive dependence (butterfly effect).
   epsilon — tiny perturbation added to InitX of the second trajectory.
   Returns {solution1, solution2}. *)

SolveLorenzPair[params_Association, epsilon_:0.001] := Module[
  {params2},
  params2 = ReplacePart[params,
    Key["InitX"] -> params["InitX"] + epsilon];
  {SolveLorenz[params], SolveLorenz[params2]}
]


(* LorenzDivergence
   Computes Euclidean distance between two trajectories at each time step.
   Input:  sol1, sol2 — outputs of SolveLorenz
   Output: list of {t, distance} pairs *)

LorenzDivergence[sol1_List, sol2_List] :=
  MapThread[
    {#1[[1]],
     Sqrt[
       (#1[[2]] - #2[[2]])^2 +
       (#1[[3]] - #2[[3]])^2 +
       (#1[[4]] - #2[[4]])^2
     ]
    } &,
    {sol1, sol2}
  ]

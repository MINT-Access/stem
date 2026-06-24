(* ========================================================
   src/model.wl — Pendulum ODE definition and solver

   The equation of motion for a simple pendulum is:
       theta''(t) + (g/L) * Sin[theta(t)] = 0

   This is solved numerically using NDSolve.
   ======================================================== *)

(* SolvePendulum
   Input:  params — an Association with keys:
             Length, Gravity, InitAngle, InitVelocity, TimeEnd, TimeStep
   Output: a list of {time, angle, velocity} triples *)

SolvePendulum[params_Association] := Module[
  {L, g, theta0, omega0, tEnd, dt, sol, times},

  L      = params["Length"];
  g      = params["Gravity"];
  theta0 = params["InitAngle"];
  omega0 = params["InitVelocity"];
  tEnd   = params["TimeEnd"];
  dt     = params["TimeStep"];

  (* Solve the ODE numerically *)
  sol = NDSolve[
    {
      theta''[t] + (g / L) * Sin[theta[t]] == 0,
      theta[0]  == theta0,
      theta'[0] == omega0
    },
    theta,
    {t, 0, tEnd},
    MaxStepSize -> dt
  ];

  (* Sample at regular intervals *)
  times = Range[0, tEnd, dt];

  (* Return list of {t, angle, angular velocity} *)
  {#, theta[#] /. sol[[1]], theta'[#] /. sol[[1]]} & /@ times
]


(* PendulumEnergy
   Computes total mechanical energy at a given state.
   Useful for verifying energy conservation in tests. *)

PendulumEnergy[angle_, velocity_, params_Association] := Module[
  {L, g, m},
  L = params["Length"];
  g = params["Gravity"];
  m = 1.0; (* normalised mass *)
  (* Kinetic + potential energy *)
  0.5 * m * (L * velocity)^2 + m * g * L * (1 - Cos[angle])
]

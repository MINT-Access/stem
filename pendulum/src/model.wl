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


(* DoublePendulumModel
   Solves the double pendulum ODEs derived from the Lagrangian (exact,
   no approximation) using NDSolve with StiffnessSwitching.

   All parameters are read from cfg via GetCfg:
     simulation.double.{length1, length2, mass1, mass2,
                        angle1_deg, angle2_deg}
     simulation.{gravity, duration, timestep}

   Equations of motion:
     α1 = [ -g(2m1+m2)sin θ1 - m2·g·sin(θ1−2θ2)
             - 2·sin(θ1−θ2)·m2·(ω2²L2 + ω1²L1·cos(θ1−θ2)) ]
           / [ L1·(2m1+m2 − m2·cos(2θ1−2θ2)) ]

     α2 = [ 2·sin(θ1−θ2)·(ω1²L1(m1+m2) + g(m1+m2)cos θ1
                            + ω2²L2·m2·cos(θ1−θ2)) ]
           / [ L2·(2m1+m2 − m2·cos(2θ1−2θ2)) ]

   Returns a list of {t, θ1, ω1, θ2, ω2} quintuples sampled at timestep. *)

DoublePendulumModel[cfg_Association] :=
  Module[{L1, L2, m1, m2, g, theta10, theta20, tEnd, dt, sol, times},

    L1      = GetCfg[cfg, {"simulation","double","length1"},    1.0];
    L2      = GetCfg[cfg, {"simulation","double","length2"},    1.0];
    m1      = GetCfg[cfg, {"simulation","double","mass1"},      1.0];
    m2      = GetCfg[cfg, {"simulation","double","mass2"},      1.0];
    g       = GetCfg[cfg, {"simulation","gravity"},             9.81];
    theta10 = GetCfg[cfg, {"simulation","double","angle1_deg"}, 120.0] * Pi / 180.0;
    theta20 = GetCfg[cfg, {"simulation","double","angle2_deg"},  90.0] * Pi / 180.0;
    tEnd    = GetCfg[cfg, {"simulation","duration"},            20.0];
    dt      = GetCfg[cfg, {"simulation","timestep"},             0.01];

    sol = NDSolve[
      {
        th1'[t] == om1[t],
        om1'[t] == (
          -g * (2*m1 + m2) * Sin[th1[t]]
          - m2 * g * Sin[th1[t] - 2*th2[t]]
          - 2 * Sin[th1[t] - th2[t]] * m2 *
            (om2[t]^2 * L2 + om1[t]^2 * L1 * Cos[th1[t] - th2[t]])
        ) / (L1 * (2*m1 + m2 - m2 * Cos[2*th1[t] - 2*th2[t]])),
        th2'[t] == om2[t],
        om2'[t] == (
          2 * Sin[th1[t] - th2[t]] * (
            om1[t]^2 * L1 * (m1 + m2) +
            g * (m1 + m2) * Cos[th1[t]] +
            om2[t]^2 * L2 * m2 * Cos[th1[t] - th2[t]]
          )
        ) / (L2 * (2*m1 + m2 - m2 * Cos[2*th1[t] - 2*th2[t]])),
        th1[0] == N[theta10],
        om1[0] == 0.0,
        th2[0] == N[theta20],
        om2[0] == 0.0
      },
      {th1, om1, th2, om2},
      {t, 0, tEnd},
      Method      -> "StiffnessSwitching",
      MaxStepSize -> dt
    ];

    times = N[Range[0, tEnd, dt]];
    {#,
     th1[#] /. sol[[1]],
     om1[#] /. sol[[1]],
     th2[#] /. sol[[1]],
     om2[#] /. sol[[1]]
    } & /@ times
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

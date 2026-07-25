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


(* DoublePendulumEnergy
   Total mechanical energy of the double pendulum at a given state
   {theta1,omega1,theta2,omega2}, standard Lagrangian-mechanics form:
     KE = (1/2)(m1+m2)L1^2 omega1^2 + (1/2) m2 L2^2 omega2^2
          + m2 L1 L2 omega1 omega2 Cos[theta1-theta2]
     PE = -(m1+m2) g L1 Cos[theta1] - m2 g L2 Cos[theta2]
   (PE's zero point is the pivot; only relative energy matters for a
   conservation check, so the sign/offset convention is unconstrained.)
   Independently verified against DoublePendulumModel's actual NDSolve
   trajectory before writing the check that uses it: energy conserved
   to ~2.5e-10 relative over a 20 s integration at the app's own
   default NDSolve settings (Method->"StiffnessSwitching", no explicit
   PrecisionGoal/AccuracyGoal override) — see AGENTS.md. *)

DoublePendulumEnergy[{theta1_, omega1_, theta2_, omega2_}, L1_, L2_, m1_, m2_, g_] :=
  Module[{ke, pe},
    ke = 0.5*(m1 + m2)*L1^2*omega1^2 + 0.5*m2*L2^2*omega2^2 +
         m2*L1*L2*omega1*omega2*Cos[theta1 - theta2];
    pe = -(m1 + m2)*g*L1*Cos[theta1] - m2*g*L2*Cos[theta2];
    ke + pe
  ];


(* ────────────────────────────────────────────────────────────
   Correctness checks — diagnostic-only (print PASS/FAIL, never
   abort), per blackbody/AGENTS.md §3. This app predated that
   convention (had no printed checks at all before this audit — only
   ad hoc assertions in tests/test_model.wl); see AGENTS.md for the
   full reasoning behind each check.
   ──────────────────────────────────────────────────────────── *)

(* Check 1 (simple pendulum, exact, ANY amplitude) — the exact period
   of a simple pendulum is T = 4 Sqrt[L/g] EllipticK[Sin[theta0/2]^2]
   (WL's EllipticK[m] takes the PARAMETER m = k^2, not the modulus k —
   verified against the small-angle limit before use: as theta0->0,
   EllipticK[0]=Pi/2 exactly, giving T->2 Pi Sqrt[L/g], the familiar
   small-angle formula). This is a strict upgrade over a small-angle-
   only test: it holds at ANY amplitude, verified here against a real
   NDSolve-measured period (zero-crossing timing), not just compared
   to itself. *)
ExactPeriod[L_?NumericQ, g_?NumericQ, theta0_?NumericQ] :=
  4.0 * Sqrt[L / g] * EllipticK[Sin[theta0 / 2.0]^2];

(* MeasuredPeriod — solves the real ODE at amplitude theta0 and
   measures the period from positive-going zero-crossings of the
   angle (theta0 -> 0 -> -theta0 -> 0 -> theta0 is one full period;
   consecutive zero-crossings in the SAME direction are one period
   apart). Linear interpolation between samples for sub-step timing
   accuracy. *)
MeasuredPeriod[L_?NumericQ, g_?NumericQ, theta0_?NumericQ, tEnd_?NumericQ, dt_?NumericQ] :=
  Module[{params, sol, ts, angles, crossings, idx},
    params = <| "Length" -> L, "Gravity" -> g, "InitAngle" -> theta0,
                "InitVelocity" -> 0.0, "TimeEnd" -> tEnd, "TimeStep" -> dt |>;
    sol = SolvePendulum[params];
    ts = sol[[All, 1]]; angles = sol[[All, 2]];
    idx = Select[Range[2, Length[angles]], angles[[# - 1]] > 0 && angles[[#]] <= 0 &];
    crossings = Map[
      Function[i, ts[[i - 1]] + (0.0 - angles[[i - 1]]) *
        (ts[[i]] - ts[[i - 1]]) / (angles[[i]] - angles[[i - 1]])],
      idx];
    If[Length[crossings] >= 2, Mean[Differences[crossings]], $Failed]
  ];

(* ExactPeriodCheck — tests small (10deg), moderate (45deg), large
   (90deg), and very large (150deg) amplitudes, deliberately spanning
   well beyond where the small-angle approximation holds, since the
   whole point of the exact formula is that it works everywhere the
   approximation does not. *)
ExactPeriodCheck[Optional[L_?NumericQ, 1.0], Optional[g_?NumericQ, 9.81],
                 Optional[tolerance_?NumericQ, 0.01]] :=
  Module[{testAnglesDeg, results, maxRelErr},
    testAnglesDeg = {10.0, 45.0, 90.0, 150.0};
    results = Map[
      Function[deg,
        Module[{theta0, exact, measured, tEnd, relErr},
          theta0 = deg * Pi / 180.0;
          exact  = ExactPeriod[L, g, theta0];
          tEnd   = 3.5 * exact;
          measured = MeasuredPeriod[L, g, theta0, tEnd, 0.002];
          relErr = If[NumericQ[measured], Abs[measured - exact] / exact, Infinity];
          <| "angleDeg" -> deg, "exact" -> exact, "measured" -> measured, "relError" -> relErr |>
        ]
      ],
      testAnglesDeg
    ];
    maxRelErr = Max[results[[All, "relError"]]];
    <| "results" -> results, "maxRelError" -> maxRelErr, "pass" -> maxRelErr < tolerance |>
  ];


(* Check 2 (simple pendulum, exact) — total mechanical energy is
   conserved over the full integration, verified at SEVERAL points
   along the trajectory (not just start/end — a check that only
   compares endpoints could miss a mid-trajectory numerical issue
   that happens to cancel out by the final sample). *)
SimpleEnergyConservationCheck[solution_List, params_Association,
                              Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{energies, nSamples, sampleIdx, sampled, relDrift},
    energies  = PendulumEnergy[#[[2]], #[[3]], params] & /@ solution;
    nSamples  = Min[10, Length[energies]];
    sampleIdx = Round[Subdivide[1, Length[energies], nSamples - 1]];
    sampled   = energies[[sampleIdx]];
    relDrift  = (Max[sampled] - Min[sampled]) / Abs[Mean[sampled]];
    <| "sampled" -> sampled, "relDrift" -> relDrift, "pass" -> relDrift < tolerance |>
  ];


(* Check 3 (double pendulum, exact) — total mechanical energy is
   conserved over the full integration, same multi-point sampling as
   check 2. Independently re-derived and numerically verified (see
   DoublePendulumEnergy's docstring and AGENTS.md) that the app's own
   equations of motion conserve energy to ~2.5e-10 relative at the
   app's own default NDSolve settings — 0.001 tolerance here has
   enormous margin without being vacuous. *)
DoubleEnergyConservationCheck[solution_List, L1_?NumericQ, L2_?NumericQ,
                              m1_?NumericQ, m2_?NumericQ, g_?NumericQ,
                              Optional[tolerance_?NumericQ, 0.001]] :=
  Module[{energies, nSamples, sampleIdx, sampled, relDrift},
    energies = Map[
      DoublePendulumEnergy[{#[[2]], #[[3]], #[[4]], #[[5]]}, L1, L2, m1, m2, g] &,
      solution
    ];
    nSamples  = Min[10, Length[energies]];
    sampleIdx = Round[Subdivide[1, Length[energies], nSamples - 1]];
    sampled   = energies[[sampleIdx]];
    relDrift  = (Max[sampled] - Min[sampled]) / Abs[Mean[sampled]];
    <| "sampled" -> sampled, "relDrift" -> relDrift, "pass" -> relDrift < tolerance |>
  ];


(* Check 4 (double pendulum, qualitative, generous tolerance) —
   sensitive dependence on initial conditions: two trajectories
   started epsilon apart in theta1 diverge by at least 100x in
   (theta1,theta2)-space over a moderate integration time.

   THE ACTUAL THRESHOLD FOUND (do not assume a small-angle double
   pendulum is chaotic — it is only weakly so, or not at all): at the
   app's own default 20 s duration, epsilon=1e-4 rad, and
   theta2_0=0.75*theta1_0, divergence ratio stays SINGLE-TO-LOW-
   DOUBLE-DIGIT (not >=100x) for theta1_0 up to 120 degrees — INCLUDING
   the app's own default angle1_deg=120 config value, which does NOT
   reliably show >=100x divergence within 20 s. The transition is
   sharp: 120deg -> ~6x, 121deg -> ~3x, 122deg -> ~17x, 123deg -> ~72x,
   124deg -> ~284x, 125deg -> ~85,000x. This check therefore uses its
   OWN fixed, independent test amplitude (130 degrees — comfortably
   past the transition, not the run's configured angle1_deg), verified
   robust across a 100x range of perturbation sizes (eps 1e-5 to 1e-3
   all gave ratios from ~89,000x to ~5,700,000x at 130 degrees, so the
   check is not sensitive to the exact epsilon chosen). *)
ChaosSensitivityCheck[Optional[testAngleDeg_?NumericQ, 130.0],
                      Optional[epsilon_?NumericQ, 0.0001],
                      Optional[tEnd_?NumericQ, 20.0],
                      Optional[minRatio_?NumericQ, 100.0]] :=
  Module[{cfg1, cfg2, theta10, theta20, sol1, sol2, divStart, divEnd, ratio},
    theta10 = testAngleDeg * Pi / 180.0;
    theta20 = 0.75 * theta10;
    cfg1 = <| "simulation" -> <| "double" -> <| "angle1_deg" -> testAngleDeg,
              "angle2_deg" -> testAngleDeg * 0.75 |>, "duration" -> tEnd |> |>;
    cfg2 = <| "simulation" -> <| "double" -> <| "angle1_deg" -> testAngleDeg + epsilon * 180.0 / Pi,
              "angle2_deg" -> testAngleDeg * 0.75 |>, "duration" -> tEnd |> |>;
    sol1 = DoublePendulumModel[cfg1];
    sol2 = DoublePendulumModel[cfg2];
    divStart = Norm[{sol1[[1, 2]] - sol2[[1, 2]], sol1[[1, 4]] - sol2[[1, 4]]}];
    divEnd   = Norm[{Last[sol1][[2]] - Last[sol2][[2]], Last[sol1][[4]] - Last[sol2][[4]]}];
    ratio    = If[divStart > 0, divEnd / divStart, Missing["undefined"]];
    <| "testAngleDeg" -> testAngleDeg, "divStart" -> divStart, "divEnd" -> divEnd,
       "ratio" -> ratio, "pass" -> NumericQ[ratio] && ratio >= minRatio |>
  ];

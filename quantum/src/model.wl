(* ========================================================
   quantum/src/model.wl — Quantum mechanics models

   Public API:
     QHOModel[cfg]  — coherent state in a quantum harmonic oscillator
     BoxModel[cfg]  — energy superposition in a particle-in-a-box

   Both return an Association:
     "density"     — {nt x nx} Real array: |psi(x,t)|^2
     "x"           — length-nx spatial grid
     "t"           — length-nt time grid
     "dx"          — spatial grid spacing
     "mean_energy" — expectation value of energy (natural units: hbar=m=1)
     "mode"        — "qho" or "box"
     "norm_ok"     — True if every sampled norm is within 1% of 1

   Natural units throughout: hbar = m = 1.
   ======================================================== *)


(* ── QHOModel ────────────────────────────────────────────
   Coherent state |alpha> in the quantum harmonic oscillator.

   Eigenfunctions:  phi_n(x) = (2^n n! sqrt(Pi))^(-1/2) H_n(x) exp(-x^2/2)
   Coefficients:    c_n = exp(-|alpha|^2/2) * alpha^n / sqrt(n!)
   Time evolution:  psi(x,t) = Sum_n c_n phi_n(x) exp(-i omega (n+1/2) t)
   Mean energy:     <E> = omega (|alpha|^2 + 1/2)
   ──────────────────────────────────────────────────────── *)

QHOModel[cfg_Association] :=
  Module[{alpha, omega, nModes, xRange, nPoints, duration, dt,
          xVals, tVals, nx, nt, dx,
          cn, phi, timeCoeffs, psiMatrix, density,
          normChecks, normOk, meanEnergy},

    alpha    = N[GetCfg[cfg, {"simulation","qho","alpha"},    2.0]];
    omega    = N[GetCfg[cfg, {"simulation","qho","omega"},    1.0]];
    nModes   = GetCfg[cfg,   {"simulation","qho","n_modes"},  20];
    xRange   = GetCfg[cfg,   {"simulation","qho","x_range"},  {-8.0, 8.0}];
    nPoints  = GetCfg[cfg,   {"simulation","qho","n_points"}, 200];
    duration = N[GetCfg[cfg, {"simulation","qho","duration"}, 2.0 * Pi]];
    dt       = N[GetCfg[cfg, {"simulation","qho","timestep"}, 0.05]];

    xVals = N[Subdivide[xRange[[1]], xRange[[2]], nPoints - 1]];
    tVals = N[Range[0, duration, dt]];
    nx    = Length[xVals];
    nt    = Length[tVals];
    dx    = N[(xRange[[2]] - xRange[[1]]) / (nPoints - 1)];

    (* Coherent state: c_n = exp(-|alpha|^2 / 2) * alpha^n / sqrt(n!) *)
    cn = Table[
      N[Exp[-Abs[alpha]^2 / 2] * alpha^n / Sqrt[n!]],
      {n, 0, nModes - 1}
    ];

    (* Physicists' HO eigenfunctions: phi_n(x) *)
    phi = Table[
      N[1.0 / Sqrt[2.0^n * n! * Sqrt[Pi]]] *
        N[HermiteH[n, xVals]] * Exp[-xVals^2 / 2.0],
      {n, 0, nModes - 1}
    ];  (* phi[[n+1]] is a length-nx vector *)

    (* Time-evolved coefficients: {nModes x nt} complex matrix
       timeCoeffs[[n+1, it]] = c_n * exp(-i omega (n+1/2) t_it) *)
    timeCoeffs = Table[
      cn[[n + 1]] * Exp[-I * omega * (n + 0.5) * tVals],
      {n, 0, nModes - 1}
    ];

    (* psi(x,t) matrix via single matrix multiply: {nt x nModes} . {nModes x nx} *)
    psiMatrix = Transpose[timeCoeffs] . phi;
    density   = Abs[psiMatrix]^2;

    (* Normalisation check: integral |psi|^2 dx = Sum[row]*dx should be 1 +/- 0.01 *)
    normChecks = Map[
      Abs[Total[#] * dx - 1.0] < 0.01 &,
      density[[Range[1, nt, 10]]]
    ];
    normOk = And @@ normChecks;

    meanEnergy = N[omega * (Abs[alpha]^2 + 0.5)];

    <| "density"     -> density,
       "x"           -> xVals,
       "t"           -> tVals,
       "dx"          -> dx,
       "mean_energy" -> meanEnergy,
       "mode"        -> "qho",
       "norm_ok"     -> normOk |>
  ]


(* ── BoxModel ────────────────────────────────────────────
   Equal superposition of ground state and first excited state
   in a 1D infinite square well of length L.

   Eigenfunctions:  phi_n(x) = sqrt(2/L) sin(n pi x / L),  n = 1, 2, ...
   Energy levels:   E_n = n^2 pi^2 / (2 L^2)
   Initial state:   psi(x,0) = (phi_1 + phi_2) / sqrt(2)
   Mean energy:     <E> = (E_1 + E_2) / 2
   ──────────────────────────────────────────────────────── *)

BoxModel[cfg_Association] :=
  Module[{L, nModes, nPoints, duration, dt,
          xVals, tVals, nx, nt, dx,
          cn, En, phi, timeCoeffs, psiMatrix, density,
          normChecks, normOk, meanEnergy},

    L        = N[GetCfg[cfg, {"simulation","box","L"},        10.0]];
    nModes   = GetCfg[cfg,   {"simulation","box","n_modes"},  10];
    nPoints  = GetCfg[cfg,   {"simulation","box","n_points"}, 200];
    duration = N[GetCfg[cfg, {"simulation","box","duration"}, 20.0]];
    dt       = N[GetCfg[cfg, {"simulation","box","timestep"}, 0.05]];

    (* Spatial grid on [0, L]; endpoints are nodes (Dirichlet b.c.) *)
    xVals = N[Subdivide[0.0, L, nPoints - 1]];
    tVals = N[Range[0, duration, dt]];
    nx    = Length[xVals];
    nt    = Length[tVals];
    dx    = N[L / (nPoints - 1)];

    (* Eigenfunctions phi_n(x) = sqrt(2/L) sin(n pi x / L), n = 1..nModes *)
    phi = Table[
      Sqrt[2.0 / L] * Sin[n * Pi * xVals / L],
      {n, 1, nModes}
    ];

    (* Energy levels E_n = n^2 pi^2 / (2 L^2) *)
    En = Table[N[n^2 * Pi^2 / (2.0 * L^2)], {n, 1, nModes}];

    (* Initial state: (phi_1 + phi_2) / sqrt(2)  =>  c_1 = c_2 = 1/sqrt(2) *)
    cn = ConstantArray[0.0, nModes];
    cn[[1]] = 1.0 / Sqrt[2.0];
    cn[[2]] = 1.0 / Sqrt[2.0];

    (* Time-evolved coefficients: {nModes x nt} complex matrix *)
    timeCoeffs = Table[
      cn[[n]] * Exp[-I * En[[n]] * tVals],
      {n, 1, nModes}
    ];

    psiMatrix = Transpose[timeCoeffs] . phi;
    density   = Abs[psiMatrix]^2;

    normChecks = Map[
      Abs[Total[#] * dx - 1.0] < 0.01 &,
      density[[Range[1, nt, 10]]]
    ];
    normOk = And @@ normChecks;

    (* <E> = Sum |c_n|^2 E_n = (E_1 + E_2) / 2 *)
    meanEnergy = N[Total[cn^2 * En]];

    <| "density"     -> density,
       "x"           -> xVals,
       "t"           -> tVals,
       "dx"          -> dx,
       "mean_energy" -> meanEnergy,
       "mode"        -> "box",
       "norm_ok"     -> normOk |>
  ]

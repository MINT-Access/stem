(* lagrange/src/output.wl — CSV trajectory export for CR3BP modes *)

(* Export the l4/l5 libration trajectory time series as CSV. *)
ExportLibrationTrajectory[model_Association, outCSV_String] :=
  Module[{tSamp, xV, yV, vxV, vyV, omV, r1V, r2V, dLP, nPts, lLabel},
    tSamp  = model["tSamp"];
    xV     = model["xV"];
    yV     = model["yV"];
    vxV    = model["vxV"];
    vyV    = model["vyV"];
    omV    = model["omV"];
    r1V    = model["r1V"];
    r2V    = model["r2V"];
    dLP    = model["dLP"];
    nPts   = model["nPts"];
    lLabel = model["lLabel"];
    ExportCSV[
      Join[
        {{"t_orbit", "x_corot", "y_corot", "vx", "vy",
          "omega_bary", "r1", "r2", "dist_to_" <> lLabel}},
        Transpose[{tSamp / (2*Pi), xV, yV, vxV, vyV, omV, r1V, r2V, dLP}]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nPts, 9]
  ];

(* Export the L1 escape trajectory time series as CSV. *)
ExportEscapeTrajectory[model_Association, outCSV_String] :=
  Module[{tSamp, xV, yV, vxV, vyV, omV, r1V, r2V, dL1, nPts},
    tSamp = model["tSamp"];
    xV    = model["xV"];
    yV    = model["yV"];
    vxV   = model["vxV"];
    vyV   = model["vyV"];
    omV   = model["omV"];
    r1V   = model["r1V"];
    r2V   = model["r2V"];
    dL1   = model["dL1"];
    nPts  = model["nPts"];
    ExportCSV[
      Join[
        {{"t_orbit", "x_corot", "y_corot", "vx", "vy",
          "omega_bary", "r1", "r2", "dist_to_L1"}},
        Transpose[{tSamp / (2*Pi), xV, yV, vxV, vyV, omV, r1V, r2V, dL1}]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nPts, 9]
  ];

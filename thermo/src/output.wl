(* ========================================================
   thermo/src/output.wl — CSV export, correctness-check
   printing, and console summaries
   ======================================================== *)


(* ── Correctness checks (PASS/FAIL, printed every run) ───────────── *)

(* PrintCoreChecks — checks 1 & 2, relevant to every mode since they
   test the MB distribution formula itself, independent of which mode
   is consuming it. *)
PrintCoreChecks[massAmu_?NumericQ, T_?NumericQ] :=
  Module[{normCheck, ratioCheck},
    normCheck  = NormalizationCheck[massAmu, T];
    ratioCheck = SpeedRatioCheck[massAmu, T];
    Print["  [", If[normCheck["pass"], "PASS", "FAIL"], "] Normalisation: integral of f(v) over ",
          "[0, v_max] = ", FmtN[normCheck["integral"], 6],
          "  (expected 1.0, error ", FmtN[normCheck["error"], 4], ")"];
    Print["  [", If[ratioCheck["pass"], "PASS", "FAIL"], "] Characteristic speed ratios: ",
          "v_mean/v_p = ", FmtN[ratioCheck["meanRatio"], 6],
          " (expected Sqrt[4/pi] = ", FmtN[ratioCheck["expectedMeanRatio"], 6], "),  ",
          "v_rms/v_p = ", FmtN[ratioCheck["rmsRatio"], 6],
          " (expected Sqrt[3/2] = ", FmtN[ratioCheck["expectedRmsRatio"], 6], ")"];
    {normCheck, ratioCheck}
  ];

(* PrintEnsembleCheck — check 3, ensemble mode only. *)
PrintEnsembleCheck[speeds_List, massAmu_?NumericQ, T_?NumericQ] :=
  Module[{check},
    check = EnsembleEquilibrationCheck[speeds, massAmu, T];
    Print["  [", If[check["pass"], "PASS", "FAIL"], "] Ensemble equilibration: mean speed = ",
          FmtN[check["meanSpeed"], 6], " m/s  vs analytic v_mean = ",
          FmtN[check["analyticMean"], 6], " m/s  (", FmtN[check["relError"] * 100, 4], "% error)"];
    check
  ];

(* PrintEquipartitionChecks — check 4, equipartition mode only. Run
   against both a monatomic-representative and diatomic-representative
   mass, since the check (mean translational KE = (3/2)kT) is a
   property of the MB distribution alone and must hold regardless of
   molecular species. *)
PrintEquipartitionChecks[monoMassAmu_?NumericQ, diMassAmu_?NumericQ, T_?NumericQ] :=
  Module[{monoCheck, diCheck},
    monoCheck = EquipartitionCheck[monoMassAmu, T];
    diCheck   = EquipartitionCheck[diMassAmu, T];
    Print["  [", If[monoCheck["pass"], "PASS", "FAIL"], "] Equipartition (mass = ",
          monoMassAmu, " amu): mean KE = ", FmtN[monoCheck["meanKE"], 6],
          " J  vs (3/2)kT = ", FmtN[monoCheck["expected"], 6], " J"];
    Print["  [", If[diCheck["pass"], "PASS", "FAIL"], "] Equipartition (mass = ",
          diMassAmu, " amu): mean KE = ", FmtN[diCheck["meanKE"], 6],
          " J  vs (3/2)kT = ", FmtN[diCheck["expected"], 6], " J"];
    {monoCheck, diCheck}
  ];


(* ── CSV export ───────────────────────────────────────────────────── *)

(* ExportDistributionCSV — columns: step, T_K, vp_ms, vmean_ms, vrms_ms *)
ExportDistributionCSV[distResult_Association, outCSV_String] :=
  Module[{TVals, vpVals, vmeanVals, vrmsVals, n, header, rows},
    TVals     = distResult["TVals"];
    vpVals    = distResult["vpVals"];
    vmeanVals = distResult["vmeanVals"];
    vrmsVals  = distResult["vrmsVals"];
    n = Length[TVals];
    header = {{"step", "T_K", "vp_ms", "vmean_ms", "vrms_ms"}};
    rows = Table[{i - 1, TVals[[i]], vpVals[[i]], vmeanVals[[i]], vrmsVals[[i]]}, {i, n}];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];

(* ExportEnsembleCSV — long format, one row per (timestep, particle):
   timestep, particle_index, speed_ms, collided (1 if this particle
   was one of the pair exchanged at this timestep's collision). *)
ExportEnsembleCSV[ensembleModel_Association, outCSV_String] :=
  Module[{history, collisionLog, nParticles, nTimesteps, header, rows},
    history      = ensembleModel["speedsHistory"];
    collisionLog = ensembleModel["collisionLog"];
    nParticles   = ensembleModel["nParticles"];
    nTimesteps   = ensembleModel["nTimesteps"];

    header = {{"timestep", "particle_index", "speed_ms", "collided"}};
    rows = Flatten[
      Table[
        Module[{collidedSet = If[t >= 2, collisionLog[[t - 1]], {}]},
          Table[
            {t - 1, p - 1, history[[t, p]], If[MemberQ[collidedSet, p], 1, 0]},
            {p, nParticles}
          ]
        ],
        {t, nTimesteps + 1}
      ],
      1
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, Length[rows], 4]
  ];

(* ExportCoolingCSV — columns: frame_index, time_s, T_K,
   amplitude_scale (sqrt(T/T_hot), what the audio's loudness follows),
   is_equilibrium_frame *)
ExportCoolingCSV[coolResult_Association, outCSV_String] :=
  Module[{times, TVals, THot, eqFrameIdx, n, header, rows},
    times      = coolResult["times"];
    TVals      = coolResult["TVals"];
    THot       = coolResult["THot"];
    eqFrameIdx = coolResult["eqFrameIdx"];
    n = Length[times];
    header = {{"frame_index", "time_s", "T_K", "amplitude_scale", "is_equilibrium_frame"}};
    rows = Table[
      {i - 1, times[[i]], TVals[[i]], Sqrt[Clip[TVals[[i]] / THot, {0.0, 1.0}]],
       If[i === eqFrameIdx, 1, 0]},
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 5]
  ];

(* ExportEquipartitionCSV — columns: step, T_K, translational_energy_J,
   rotational_energy_J, total_energy_J, rotational_fraction,
   molecule_type *)
ExportEquipartitionCSV[eqResult_Association, outCSV_String] :=
  Module[{TVals, moleculeType, n, header, rows},
    TVals        = eqResult["TVals"];
    moleculeType = eqResult["moleculeType"];
    n = Length[TVals];
    header = {{"step", "T_K", "translational_energy_J", "rotational_energy_J",
                "total_energy_J", "rotational_fraction", "molecule_type"}};
    rows = Table[
      Module[{T = TVals[[i]], transE, rotE, totE, rotFrac},
        transE  = TranslationalMeanEnergy[T];
        rotE    = RotationalMeanEnergy[T, moleculeType];
        totE    = transE + rotE;
        rotFrac = If[totE > 0.0, rotE / totE, 0.0];
        {i - 1, T, transE, rotE, totE, rotFrac, moleculeType}
      ],
      {i, n}
    ];
    ExportCSV[Join[header, rows], outCSV];
    STEMDescribeCSV[outCSV, n, 7]
  ];


(* ── Console summaries ───────────────────────────────────────────── *)

PrintDistributionSummary[distResult_Association, gasName_String, massAmu_?NumericQ] :=
  Module[{TVals},
    TVals = distResult["TVals"];
    STEMSection["Distribution Summary"];
    Print["  Gas: ", gasName, "  (", massAmu, " amu)"];
    STEMPrintN["Temperature range", First[TVals], "K \[LongDash] " <> FmtN[Last[TVals], 5] <> " K", 5];
    STEMPrintN["Temperature steps", Length[TVals]];
    Print["  v_p range:    ", FmtN[First[distResult["vpVals"]], 5],   " -> ", FmtN[Last[distResult["vpVals"]], 5],   " m/s"];
    Print["  v_mean range: ", FmtN[First[distResult["vmeanVals"]], 5], " -> ", FmtN[Last[distResult["vmeanVals"]], 5], " m/s"];
    Print["  v_rms range:  ", FmtN[First[distResult["vrmsVals"]], 5],  " -> ", FmtN[Last[distResult["vrmsVals"]], 5],  " m/s"]
  ];

PrintEnsembleSummary[ensembleModel_Association, gasName_String] :=
  Module[{initSpeeds, finalSpeeds},
    initSpeeds  = ensembleModel["initialSpeeds"];
    finalSpeeds = Last[ensembleModel["speedsHistory"]];
    STEMSection["Ensemble Summary"];
    Print["  Gas: ", gasName, "  (", ensembleModel["massAmu"], " amu)  T = ", ensembleModel["T"], " K"];
    STEMPrintN["Particles", ensembleModel["nParticles"]];
    STEMPrintN["Timesteps (collisions)", ensembleModel["nTimesteps"]];
    Print["  Initial mean speed: ", FmtN[Mean[initSpeeds], 6], " m/s"];
    Print["  Final mean speed:   ", FmtN[Mean[finalSpeeds], 6], " m/s"]
  ];

PrintCoolingSummary[coolResult_Association, gasName_String] :=
  Module[{},
    STEMSection["Cooling Summary"];
    Print["  Gas: ", gasName];
    STEMPrintN["T_hot", coolResult["THot"], "K"];
    STEMPrintN["T_cold", coolResult["TCold"], "K"];
    STEMPrintN["Cooling time constant (tau)", coolResult["tau"], "s", 5];
    STEMPrintN["Thermal equilibrium reached at", coolResult["eqTime"], "s", 5]
  ];

PrintEquipartitionSummary[eqResult_Association, moleculeType_String] :=
  Module[{TVals},
    TVals = eqResult["TVals"];
    STEMSection["Equipartition Summary"];
    Print["  Molecule type: ", moleculeType];
    STEMPrintN["Temperature range", First[TVals], "K \[LongDash] " <> FmtN[Last[TVals], 5] <> " K", 5];
    Print["  Rotational fraction: ", FmtN[eqResult["rotFrac"] * 100, 4], "%  ",
          "(", If[moleculeType === "diatomic", "diatomic: 2 rotational DOF", "monatomic: no rotational DOF"], ")"]
  ];

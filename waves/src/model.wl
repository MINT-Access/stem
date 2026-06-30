(* waves/src/model.wl — FEM wave equation solvers and sanity checks *)

(* Solve the 2D wave equation on a circular membrane (ripple mode).
   Runs physical correctness checks 1-4 and returns a model Association
   containing the PDE solution, listening-point time series, and parameters. *)
RippleModel[cfg_Association] :=
  Module[{c, r, tEnd, nLP, sig, solR, lpFracs, lpX, lpPans, nT, tVals, dt,
          lpDisp, maxR, c1R, arrThr, arrivals, expected, c2R, finiteArr, c3R,
          bPts, maxRim, c4R},
    c    = N @ GetCfg[cfg, {"simulation","waves","wave_speed"},      1.0];
    r    = N @ GetCfg[cfg, {"simulation","waves","membrane_radius"}, 1.0];
    tEnd = N @ GetCfg[cfg, {"simulation","waves","duration"},        4.0];
    nLP  = GetCfg[cfg, {"simulation","waves","listening_points"},    4];

    sig  = N[0.10 * r];
    solR = NDSolveValue[
      {D[u[x, y, t], {t, 2}] ==
         c^2 * Inactive[Laplacian][u[x, y, t], {x, y}],
       u[x, y, 0] == Exp[-(x^2 + y^2) / (2.0 * sig^2)],
       Derivative[0, 0, 1][u][x, y, 0] == 0.0,
       DirichletCondition[u[x, y, t] == 0.0, True]},
      u,
      {x, y} \[Element] Disk[{0.0, 0.0}, r],
      {t, 0.0, tEnd}
    ];
    Print["  PDE solved."];

    lpFracs = N @ Rescale[Range[nLP], {1, nLP}, {0.2, 0.8}];
    lpX     = lpFracs * r;
    lpPans  = N @ Rescale[Range[nLP], {1, nLP}, {-0.8, 0.8}];

    nT    = 300;
    tVals = N @ Rescale[Range[nT], {1, nT}, {0.0, tEnd}];
    dt    = tVals[[2]] - tVals[[1]];

    Print["  Extracting ", nLP, " listening-point time series..."];
    lpDisp = Table[
      Table[solR[lpX[[k]], 0.0, t], {t, tVals}],
      {k, nLP}];

    STEMSection["Physical correctness checks"];

    maxR = Max[Abs[Flatten[lpDisp]]];
    c1R  = maxR > 1.0*^-6 && maxR < 500.0;
    Print["  [", If[c1R, "PASS", "FAIL"], "] Amplitude bounded:  max|u| = ",
      FmtN[maxR, {5,4}], "  (expected 0 < max|u| < 500)"];

    arrThr   = 0.02 * Max[Abs[lpDisp[[1]]]];
    arrivals = Table[
      Module[{idx = SelectFirst[Range[nT], Abs[lpDisp[[k, #]]] >= arrThr &, 0]},
        If[idx === 0, Infinity, tVals[[idx]]]],
      {k, nLP}];
    expected = lpX / c;
    c2R = AllTrue[
      Table[Abs[arrivals[[k]] - expected[[k]]] < Max[0.6, 0.35 * tEnd], {k, nLP}],
      TrueQ];
    Print["  [", If[c2R, "PASS", "WARN"], "] Wavefront arrival times vs distance/c:"];
    Do[
      Print["    LP", k, " r=", FmtN[lpX[[k]], {4,2}],
            "  expected=", FmtN[expected[[k]], {4,2}], " s",
            "  measured=", FmtN[arrivals[[k]], {4,2}], " s"],
      {k, nLP}];

    finiteArr = Select[arrivals, # < Infinity &];
    c3R = Length[finiteArr] >= 2 && AllTrue[Differences[finiteArr], # >= 0 &];
    Print["  [", If[c3R, "PASS", "FAIL"], "] Causality: arrivals ordered ",
      StringRiffle[Map[If[# < Infinity, FmtN[#, {4,2}], "inf"] &, arrivals], " < "], " s"];

    bPts   = Table[{0.97*r*Cos[2 Pi k/16], 0.97*r*Sin[2 Pi k/16]}, {k, 0, 15}];
    maxRim = Quiet[Max[Abs @ Table[solR[p[[1]], p[[2]], tEnd], {p, bPts}]],
                   InterpolatingFunction::femdmval];
    c4R    = NumericQ[maxRim] && maxRim < 0.12;
    Print["  [", If[c4R, "PASS", "FAIL"], "] Dirichlet BC:  max|u| near rim = ",
      If[NumericQ[maxRim], FmtN[maxRim, {6,4}], "N/A"], "  (expected < 0.12)"];

    <|
      "solR"    -> solR,
      "lpDisp"  -> lpDisp,
      "lpX"     -> lpX,
      "lpPans"  -> lpPans,
      "tVals"   -> tVals,
      "nLP"     -> nLP,
      "nT"      -> nT,
      "dt"      -> dt,
      "c"       -> c,
      "r"       -> r,
      "tEnd"    -> tEnd,
      "maxR"    -> maxR
    |>
  ];

(* Solve the 2D wave equation with two coherent point sources (interference mode).
   Runs physical correctness checks 1-4 and returns a model Association. *)
InterferenceModel[cfg_Association] :=
  Module[{c, tankW, tankH, freq, tEnd, srcSep, x1s, y1s, x2s, y2s, srcSig, srcAmpI,
          solI, yLP, xLPMin, xLPMax, nT, tVals, dt, nTStat, nTSweep,
          tStat, tSweep, xSweep, dispStat, dispSweep, dispMoving, xMoving,
          dispFixed, maxI, c1I, nLateI, lateAmpI, c2I, lateFixed, c3I,
          bPtsI, maxBndI, c4I},
    c     = N @ GetCfg[cfg, {"simulation","waves","wave_speed"},       1.0];
    tankW = N @ GetCfg[cfg, {"simulation","waves","tank_width"},       2.0];
    tankH = N @ GetCfg[cfg, {"simulation","waves","tank_height"},      1.0];
    freq  = N @ GetCfg[cfg, {"simulation","waves","source_frequency"}, 2.0];
    tEnd  = N @ GetCfg[cfg, {"simulation","waves","duration"},         4.0];

    srcSep  = N[0.4 * tankW];
    x1s     = N[-srcSep / 2.0];  y1s = 0.0;
    x2s     = N[ srcSep / 2.0];  y2s = 0.0;
    srcSig  = N[0.07 * Min[tankW, tankH]];
    srcAmpI = 1.0;

    solI = NDSolveValue[
      {D[u[x, y, t], {t, 2}] ==
         c^2 * Inactive[Laplacian][u[x, y, t], {x, y}] +
         srcAmpI *
         (Exp[-((x - x1s)^2 + (y - y1s)^2) / (2.0 * srcSig^2)] +
          Exp[-((x - x2s)^2 + (y - y2s)^2) / (2.0 * srcSig^2)]) *
         Sin[2.0 Pi * freq * t],
       u[x, y, 0] == 0.0,
       Derivative[0, 0, 1][u][x, y, 0] == 0.0,
       DirichletCondition[u[x, y, t] == 0.0, True]},
      u,
      {x, y} \[Element] Rectangle[{-tankW/2.0, -tankH/2.0}, {tankW/2.0, tankH/2.0}],
      {t, 0.0, tEnd}
    ];
    Print["  PDE solved."];

    yLP    = N[0.35 * tankH / 2.0];
    xLPMin = N[-0.88 * tankW / 2.0];
    xLPMax = N[ 0.88 * tankW / 2.0];
    nT     = 300;
    tVals  = N @ Rescale[Range[nT], {1, nT}, {0.0, tEnd}];
    dt     = tVals[[2]] - tVals[[1]];

    nTStat  = Floor[nT / 2];
    nTSweep = nT - nTStat;
    tStat   = tVals[[1 ;; nTStat]];
    tSweep  = tVals[[nTStat + 1 ;; nT]];
    xSweep  = N @ Rescale[Range[nTSweep], {1, nTSweep}, {xLPMin, xLPMax}];

    dispStat   = Table[solI[0.0, yLP, t], {t, tStat}];
    dispSweep  = Table[solI[xSweep[[i]], yLP, tSweep[[i]]], {i, nTSweep}];
    dispMoving = Join[dispStat, dispSweep];
    xMoving    = Join[ConstantArray[0.0, nTStat], xSweep];
    dispFixed  = Table[solI[0.0, yLP, t], {t, tVals}];
    Print["  LP time series extracted."];

    STEMSection["Physical correctness checks"];

    maxI = Max[Abs[dispMoving]];
    c1I  = maxI > 1.0*^-8 && maxI < 500.0;
    Print["  [", If[c1I, "PASS", "FAIL"], "] Amplitude bounded:  max|u| = ",
      FmtN[maxI, {5,4}], "  (expected 0 < max|u| < 500)"];

    nLateI   = Max[1, Floor[0.7 * nT]];
    lateAmpI = Max[Abs[dispMoving[[nLateI ;; nT]]]];
    c2I      = lateAmpI > 0.005 * Max[maxI, 1.0*^-6];
    Print["  [", If[c2I, "PASS", "FAIL"], "] Pattern develops:  late-time max|u| = ",
      FmtN[lateAmpI, {5,4}]];

    lateFixed = Max[Abs[dispFixed[[nLateI ;; nT]]]];
    c3I       = lateFixed >= 0.3 * lateAmpI;
    Print["  [", If[c3I, "PASS", "WARN"],
      "] Constructive LP amplitude:  |u| at (0,yLP) = ", FmtN[lateFixed, {5,4}],
      "  sweep late-time max = ", FmtN[lateAmpI, {5,4}]];

    bPtsI = Join[
      Table[{-0.97*tankW/2.0, y},
            {y, Rescale[Range[8], {1, 8}, {-tankH*0.45, tankH*0.45}]}],
      Table[{ 0.97*tankW/2.0, y},
            {y, Rescale[Range[8], {1, 8}, {-tankH*0.45, tankH*0.45}]}]];
    maxBndI = Quiet[Max[Abs @ Table[solI[p[[1]], p[[2]], tEnd], {p, bPtsI}]],
                    InterpolatingFunction::femdmval];
    c4I     = NumericQ[maxBndI] && maxBndI < Max[0.15 * maxI, 0.01];
    Print["  [", If[c4I, "PASS", "FAIL"], "] Dirichlet BC:  max|u| near walls = ",
      If[NumericQ[maxBndI], FmtN[maxBndI, {6,4}], "N/A"],
      "  (expected < 15% of peak)"];

    <|
      "solI"        -> solI,
      "dispMoving"  -> dispMoving,
      "dispFixed"   -> dispFixed,
      "xMoving"     -> xMoving,
      "tVals"       -> tVals,
      "nT"          -> nT,
      "nTStat"      -> nTStat,
      "dt"          -> dt,
      "xLPMin"      -> xLPMin,
      "xLPMax"      -> xLPMax,
      "yLP"         -> yLP,
      "x1s"         -> x1s,
      "x2s"         -> x2s,
      "tankW"       -> tankW,
      "tankH"       -> tankH,
      "tEnd"        -> tEnd,
      "maxI"        -> maxI,
      "c"           -> c,
      "freq"        -> freq
    |>
  ];

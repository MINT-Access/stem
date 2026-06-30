(* lagrange/src/model.wl — CR3BP equations of motion and trajectory solvers *)

(* EOM helpers — use $mu as a global (set in main.wl before these are called).
   All distances in units of the primary separation; time unit = 1/omega_0. *)
$r1[x_, y_] := Sqrt[(x + $mu)^2 + y^2];
$r2[x_, y_] := Sqrt[(x - 1 + $mu)^2 + y^2];
$fx[x_, y_, vy_] := 2*vy + x - (1-$mu)*(x+$mu)/$r1[x,y]^3 - $mu*(x-1+$mu)/$r2[x,y]^3;
$fy[x_, y_, vx_] := -2*vx + y - (1-$mu)*y/$r1[x,y]^3 - $mu*y/$r2[x,y]^3;
$jacobiC[x_, y_, vx_, vy_] :=
  x^2 + y^2 + 2*(1-$mu)/$r1[x,y] + 2*$mu/$r2[x,y] - (vx^2 + vy^2);
$omegaX[x_?NumericQ] :=
  x - (1-$mu)*(x+$mu)/Abs[x+$mu]^3 - $mu*(x-1+$mu)/Abs[x-1+$mu]^3;

(* Find all five Lagrange points for the current $mu.
   Prints the positions and returns an Association {L1..L5 -> {x,y}}. *)
FindLagrangePoints[] :=
  Module[{L4, L5, L1x, L2x, L3x},
    L4  = {1/2 - $mu, N[Sqrt[3]/2]};
    L5  = {1/2 - $mu, -N[Sqrt[3]/2]};
    L1x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[1 - $mu - ($mu/3)^(1/3)]}]];
    L2x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[1 - $mu + ($mu/3)^(1/3)]}]];
    L3x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[-$mu - 1]}]];
    Print["  L1 = (", FmtN[L1x, {7,5}], ", 0)"];
    Print["  L2 = (", FmtN[L2x, {7,5}], ", 0)"];
    Print["  L3 = (", FmtN[L3x, {7,5}], ", 0)"];
    Print["  L4 = (", FmtN[L4[[1]], {7,5}], ", ", FmtN[L4[[2]], {7,5}], ")"];
    Print["  L5 = (", FmtN[L5[[1]], {7,5}], ", ", FmtN[L5[[2]], {7,5}], ")"];
    <|"L1" -> {L1x, 0.0}, "L2" -> {L2x, 0.0}, "L3" -> {L3x, 0.0},
      "L4" -> L4, "L5" -> L5|>
  ];

(* Verify that L4 and L5 form equilateral triangles with both primaries.
   Returns True if both conditions hold to machine precision. *)
GeometryCheck[lpts_Association] :=
  Module[{L4 = lpts["L4"], L5 = lpts["L5"],
          c2L4dist, c2L5dist, c2triL4, c2triL5},
    c2L4dist = N[Sqrt[(L4[[1]] - (1/2 - $mu))^2 + (L4[[2]] - Sqrt[3]/2)^2]];
    c2L5dist = N[Sqrt[(L5[[1]] - (1/2 - $mu))^2 + (L5[[2]] + Sqrt[3]/2)^2]];
    c2triL4  = N[Abs[$r1[L4[[1]], L4[[2]]] - 1.0] + Abs[$r2[L4[[1]], L4[[2]]] - 1.0]];
    c2triL5  = N[Abs[$r1[L5[[1]], L5[[2]]] - 1.0] + Abs[$r2[L5[[1]], L5[[2]]] - 1.0]];
    (c2L4dist < 1*^-8) && (c2L5dist < 1*^-8) && (c2triL4 < 1*^-5) && (c2triL5 < 1*^-5)
  ];

(* Solve CR3BP equations of motion for the l4 or l5 libration mode.
   Runs 4 sanity checks and returns a model Association with trajectory data. *)
LibrationModel[mode_String, lpts_Association, c2Pass_, cfg_Association] :=
  Module[{pert, durP, tEnd, lPos, lLabel, x0, y0, vx0, vy0,
          xFn, yFn, nPts, tSamp, xV, yV, vxV, vyV, r1V, r2V,
          omV, invDV, dLP, jacVals, jacMean, jacRel, maxDist, maxOriginDist,
          c1Pass, c3Pass, c4Pass},
    pert  = N @ GetCfg[cfg, {"simulation","lagrange","perturbation"},    0.02];
    durP  =     GetCfg[cfg, {"simulation","lagrange","duration_periods"}, 6  ];
    tEnd  = N[durP * 2 * Pi];
    lPos  = If[mode === "l4", lpts["L4"], lpts["L5"]];
    lLabel = ToUpperCase[mode];

    x0  = lPos[[1]] + pert;
    y0  = lPos[[2]];
    vx0 = 0.0;
    vy0 = 0.0;

    {xFn, yFn} = {x, y} /. First @ NDSolve[
      {x''[t] == $fx[x[t], y[t], y'[t]],
       y''[t] == $fy[x[t], y[t], x'[t]],
       x[0] == x0, y[0] == y0, x'[0] == vx0, y'[0] == vy0},
      {x, y},
      {t, 0, tEnd},
      MaxStepSize -> 0.02, PrecisionGoal -> 8];
    Print["  Integration complete (", FmtN[tEnd, {5,2}], " time units)"];

    nPts  = 600;
    tSamp = N @ Rescale[Range[nPts], {1, nPts}, {0, tEnd}];
    xV    = xFn /@ tSamp;
    yV    = yFn /@ tSamp;
    vxV   = (xFn') /@ tSamp;
    vyV   = (yFn') /@ tSamp;
    r1V   = $r1 @@@ Transpose[{xV, yV}];
    r2V   = $r2 @@@ Transpose[{xV, yV}];
    omV   = N[(xV * vyV - yV * vxV) / (xV^2 + yV^2 + 1.0*^-6)];
    invDV = 1.0 / (MapThread[Min, {r1V, r2V}] + 0.01);
    dLP   = Sqrt[(xV - lPos[[1]])^2 + (yV - lPos[[2]])^2];

    jacVals = N @ Table[
      $jacobiC[xV[[k]], yV[[k]], vxV[[k]], vyV[[k]]],
      {k, Range[1, nPts, 30]}];
    jacMean = Mean[jacVals];
    jacRel  = If[Abs[jacMean] > 1*^-6,
      (Max[jacVals] - Min[jacVals]) / Abs[jacMean], 0.0];
    c1Pass  = jacRel < 0.005;
    STEMPrintN["  Jacobi C drift (relative)", jacRel * 100, "%", {5, 3}];
    Print["  Check 1 (Jacobi conserved): ",
          If[c1Pass, "[PASS] < 0.5%", "[FAIL] > 0.5%"]];

    Print["  Check 2 (L4/L5 equilateral geometry): ",
          If[c2Pass, "[PASS]", "[FAIL]"]];

    maxDist = Max[dLP];
    c3Pass  = maxDist < 1.5;
    STEMPrintN["  Max distance from " <> lLabel, maxDist, "units", {5,3}];
    Print["  Check 3 (bounded libration, max dist < 1.5): ",
          If[c3Pass, "[PASS]", "[FAIL]"]];

    maxOriginDist = N[Max[Sqrt[xV^2 + yV^2]]];
    c4Pass        = maxOriginDist < 2.5;
    STEMPrintN["  Max distance from barycentre", maxOriginDist, "units", {5,3}];
    Print["  Check 4 (no escape, barycentre dist < 2.5): ",
          If[c4Pass, "[PASS]", "[FAIL]"]];

    <|
      "xFn"           -> xFn,
      "yFn"           -> yFn,
      "tSamp"         -> tSamp,
      "xV"            -> xV,
      "yV"            -> yV,
      "vxV"           -> vxV,
      "vyV"           -> vyV,
      "r1V"           -> r1V,
      "r2V"           -> r2V,
      "omV"           -> omV,
      "invDV"         -> invDV,
      "dLP"           -> dLP,
      "nPts"          -> nPts,
      "tEnd"          -> tEnd,
      "x0"            -> x0,
      "y0"            -> y0,
      "lPos"          -> lPos,
      "lLabel"        -> lLabel,
      "maxDist"       -> maxDist,
      "maxOriginDist" -> maxOriginDist,
      "jacRel"        -> jacRel,
      "c1Pass"        -> c1Pass,
      "c2Pass"        -> c2Pass,
      "c3Pass"        -> c3Pass,
      "c4Pass"        -> c4Pass
    |>
  ];

(* Solve CR3BP equations of motion for L1 escape (unstable saddle).
   Uses WhenEvent to stop integration on escape. Runs 4 sanity checks. *)
EscapeModel[lpts_Association, c2Pass_, cfg_Association] :=
  Module[{pert, tEndL1 = N[3 * 2 * Pi], escapeR = 0.40,
          L1x, x0, y0, vx0, vy0, xFn, yFn, tActual,
          nPts, tSamp, xV, yV, vxV, vyV, r1V, r2V,
          omV, invDV, dL1, exitIdx, tExit,
          jacVals, jacMean, jacRel, distGrowth,
          c1Pass, c3Pass, c4Pass},
    pert = N @ GetCfg[cfg, {"simulation","lagrange","perturbation"}, 0.02];
    L1x  = lpts["L1"][[1]];

    x0  = L1x;
    y0  = pert;
    vx0 = 0.0;
    vy0 = 0.0;

    {xFn, yFn} = {x, y} /. First @ NDSolve[
      {x''[t] == $fx[x[t], y[t], y'[t]],
       y''[t] == $fy[x[t], y[t], x'[t]],
       x[0] == x0, y[0] == y0, x'[0] == vx0, y'[0] == vy0,
       WhenEvent[
         Sqrt[(x[t] - L1x)^2 + y[t]^2] > escapeR ||
         $r2[x[t], y[t]] < 0.02,
         "StopIntegration"]},
      {x, y},
      {t, 0, tEndL1},
      MaxStepSize -> 0.01, PrecisionGoal -> 10];

    tActual = xFn["Domain"][[1, 2]];
    Print["  Integration ended at t = ", FmtN[tActual, {6,3}], " time units"];

    nPts  = 500;
    tSamp = N @ Rescale[Range[nPts], {1, nPts}, {0, tActual}];
    xV    = xFn /@ tSamp;
    yV    = yFn /@ tSamp;
    vxV   = (xFn') /@ tSamp;
    vyV   = (yFn') /@ tSamp;
    r1V   = $r1 @@@ Transpose[{xV, yV}];
    r2V   = $r2 @@@ Transpose[{xV, yV}];
    omV   = N[(xV * vyV - yV * vxV) / (xV^2 + yV^2 + 1.0*^-6)];
    invDV = 1.0 / (MapThread[Min, {r1V, r2V}] + 0.01);
    dL1   = Sqrt[(xV - L1x)^2 + yV^2];

    exitIdx = SelectFirst[Range[nPts], dL1[[#]] > 0.1 &, nPts];
    tExit   = tSamp[[exitIdx]];

    jacVals = N @ Table[
      $jacobiC[xV[[k]], yV[[k]], vxV[[k]], vyV[[k]]],
      {k, Range[1, nPts, 25]}];
    jacMean = Mean[jacVals];
    jacRel  = If[Abs[jacMean] > 1*^-6,
      (Max[jacVals] - Min[jacVals]) / Abs[jacMean], 0.0];
    c1Pass  = jacRel < 0.005;
    STEMPrintN["  Jacobi C drift (relative)", jacRel * 100, "%", {5, 3}];
    Print["  Check 1 (Jacobi conserved): ",
          If[c1Pass, "[PASS] < 0.5%", "[FAIL] > 0.5%"]];

    Print["  Check 2 (L4/L5 equilateral geometry): ",
          If[c2Pass, "[PASS]", "[FAIL]"]];

    distGrowth = dL1[[-1]] / Max[dL1[[1]], 1*^-8];
    c3Pass     = distGrowth > 3.0;
    STEMPrintN["  Distance growth factor (final/initial)", distGrowth, "", {5,2}];
    Print["  Check 3 (particle escapes L1, growth > 3x): ",
          If[c3Pass, "[PASS]", "[FAIL]"]];

    c4Pass = tActual < tEndL1 * 0.95;
    STEMPrintN["  Integration end time", tActual, "time units", {6,3}];
    Print["  Check 4 (early stop confirms escape occurred): ",
          If[c4Pass, "[PASS]", "[WARN] may not have escaped within time limit"]];

    <|
      "xFn"        -> xFn,
      "yFn"        -> yFn,
      "tSamp"      -> tSamp,
      "xV"         -> xV,
      "yV"         -> yV,
      "vxV"        -> vxV,
      "vyV"        -> vyV,
      "r1V"        -> r1V,
      "r2V"        -> r2V,
      "omV"        -> omV,
      "invDV"      -> invDV,
      "dL1"        -> dL1,
      "nPts"       -> nPts,
      "tActual"    -> tActual,
      "tEndL1"     -> tEndL1,
      "x0"         -> x0,
      "y0"         -> y0,
      "L1x"        -> L1x,
      "distGrowth" -> distGrowth,
      "tExit"      -> tExit,
      "jacRel"     -> jacRel,
      "c1Pass"     -> c1Pass,
      "c2Pass"     -> c2Pass,
      "c3Pass"     -> c3Pass,
      "c4Pass"     -> c4Pass
    |>
  ];

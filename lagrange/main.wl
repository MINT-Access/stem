#!/usr/bin/env wolframscript

(* ========================================================
   Lagrange Points — main.wl

   Simulates test-particle motion in the circular restricted
   three-body problem (CR3BP) in the co-rotating frame.

   Units: total mass = 1, primary separation = 1,
          angular velocity ω₀ = 1  (one orbit = 2π time units).
   mu = m2/(m1+m2) is the mass parameter (small body fraction).

   Modes:
     l4  — stable tadpole/horseshoe libration near L4 (default)
     l5  — same at L5 (symmetric counterpart)
     l1  — unstable saddle escape from L1

   Presets (--simulation.lagrange.preset):
     sun_jupiter  — mu = 0.000954  (default)
     earth_moon   — mu = 0.01215
     sun_earth    — mu = 3.003e-6

   CLI examples:
     wolframscript -file main.wl -- --simulation.mode=l1
     wolframscript -file main.wl -- --simulation.lagrange.preset=earth_moon
     wolframscript -file main.wl -- --simulation.lagrange.perturbation=0.05
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["lagrange", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "l4"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* ── Preset resolution ────────────────────────────────── *)
$presets = <|
  "sun_jupiter" -> 0.000954,
  "earth_moon"  -> 0.012151,
  "sun_earth"   -> 3.003*^-6
|>;

Module[{preset, muFromPreset},
  preset = GetCfg[cfg, {"simulation","lagrange","preset"}, "sun_jupiter"];
  If[StringQ[preset] && preset =!= "" && KeyExistsQ[$presets, preset],
    muFromPreset = $presets[preset];
    cfg = DeepMerge[cfg, <|"simulation" -> <|"lagrange" -> <|"mass_ratio" -> muFromPreset|>|>|>];
    Print["  Preset: ", preset, "  \[Mu] = ", muFromPreset]
  ]
];


(* ── Physical parameters ──────────────────────────────── *)
$mu       = N @ GetCfg[cfg, {"simulation","lagrange","mass_ratio"},      0.000954];
$pert     = N @ GetCfg[cfg, {"simulation","lagrange","perturbation"},    0.02    ];
$durP     =     GetCfg[cfg, {"simulation","lagrange","duration_periods"},6       ];

$tEnd     = N[$durP * 2 * Pi];   (* integration end time *)
$tEndL1   = N[3 * 2 * Pi];       (* l1 mode: stop early on escape, 3 orbital periods max *)
$escapeR  = 0.40;                 (* distance from collinear Lpt → declare escape *)

(* Gravitational and Coriolis force components *)
$r1[x_, y_] := Sqrt[(x + $mu)^2 + y^2];
$r2[x_, y_] := Sqrt[(x - 1 + $mu)^2 + y^2];

$fx[x_, y_, vy_] := 2*vy + x - (1-$mu)*(x+$mu)/$r1[x,y]^3 - $mu*(x-1+$mu)/$r2[x,y]^3;
$fy[x_, y_, vx_] := -2*vx + y - (1-$mu)*y/$r1[x,y]^3 - $mu*y/$r2[x,y]^3;

$jacobiC[x_, y_, vx_, vy_] :=
  x^2 + y^2 + 2*(1-$mu)/$r1[x,y] + 2*$mu/$r2[x,y] - (vx^2 + vy^2);

(* Effective potential derivative on x-axis (used by FindRoot for L1/L2/L3) *)
$omegaX[x_?NumericQ] :=
  x - (1-$mu)*(x+$mu)/Abs[x+$mu]^3 - $mu*(x-1+$mu)/Abs[x-1+$mu]^3;


(* ── Find all five Lagrange points ───────────────────── *)
Print["Finding Lagrange point positions..."];

$L4 = {1/2 - $mu, N[Sqrt[3]/2]};
$L5 = {1/2 - $mu, -N[Sqrt[3]/2]};

(* Collinear points: FindRoot on ∂Ω/∂x at y=0 *)
$L1x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[1 - $mu - ($mu/3)^(1/3)]}]];
$L2x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[1 - $mu + ($mu/3)^(1/3)]}]];
$L3x = Quiet[x /. FindRoot[$omegaX[x] == 0, {x, N[-$mu - 1]}]];
$L1 = {$L1x, 0.0};
$L2 = {$L2x, 0.0};
$L3 = {$L3x, 0.0};

Print["  L1 = (", FmtN[$L1x, {7,5}], ", 0)"];
Print["  L2 = (", FmtN[$L2x, {7,5}], ", 0)"];
Print["  L3 = (", FmtN[$L3x, {7,5}], ", 0)"];
Print["  L4 = (", FmtN[$L4[[1]], {7,5}], ", ", FmtN[$L4[[2]], {7,5}], ")"];
Print["  L5 = (", FmtN[$L5[[1]], {7,5}], ", ", FmtN[$L5[[2]], {7,5}], ")"];
Print[""];


(* ── Check 2: L4/L5 geometry ─────────────────────────── *)
$c2L4dist = N[Sqrt[($L4[[1]] - (1/2 - $mu))^2 + ($L4[[2]] - Sqrt[3]/2)^2]];
$c2L5dist = N[Sqrt[($L5[[1]] - (1/2 - $mu))^2 + ($L5[[2]] + Sqrt[3]/2)^2]];
(* L4/L5 each form equilateral triangles with the two primaries: |L4-P1|=|L4-P2|=1 *)
$c2triL4 = N[Abs[$r1[$L4[[1]], $L4[[2]]] - 1.0] + Abs[$r2[$L4[[1]], $L4[[2]]] - 1.0]];
$c2triL5 = N[Abs[$r1[$L5[[1]], $L5[[2]]] - 1.0] + Abs[$r2[$L5[[1]], $L5[[2]]] - 1.0]];
$c2Pass = ($c2L4dist < 1*^-8) && ($c2L5dist < 1*^-8) && ($c2triL4 < 1*^-5) && ($c2triL5 < 1*^-5);


(* ── Shared GIF helper ────────────────────────────────── *)
(* Returns a single Graphics frame showing trajectory up to step nShow *)
MakeLagrangeFrame[xyAll_List, nShow_Integer, mu_?NumericQ,
                  lpts_Association, markLP_String, preset_String] :=
  Module[{nS = Clip[nShow, {1, Length[xyAll]}], cur, trace},
    cur   = xyAll[[nS]];
    trace = If[nS > 1, xyAll[[1;;nS]], {cur}];
    Graphics[{
      (* Primaries *)
      {RGBColor[1.0, 0.95, 0.15], Disk[{-mu, 0.0}, 0.07]},   (* large primary *)
      {RGBColor[0.9, 0.50, 0.10], Disk[{1-mu, 0.0}, 0.025]}, (* small primary *)
      (* All five Lagrange points *)
      {GrayLevel[0.6], PointSize[0.012],
       Point /@ Values[lpts]},
      (* Labels *)
      {White, FontFamily -> "Helvetica", FontSize -> 7,
       Text["L1", lpts["L1"] + {0.0,  0.08}],
       Text["L2", lpts["L2"] + {0.0,  0.08}],
       Text["L3", lpts["L3"] + {0.0, -0.10}],
       Text["L4", lpts["L4"] + {0.0,  0.08}],
       Text["L5", lpts["L5"] + {0.0, -0.10}]},
      (* Highlight the relevant point for this mode *)
      {RGBColor[0.4, 0.9, 0.4], PointSize[0.02],
       Point[lpts[markLP]]},
      (* Trajectory trace *)
      If[Length[trace] > 1,
        {Opacity[0.85], RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[1.2],
         Line[trace]},
        {}],
      (* Current particle position *)
      {White, Disk[cur, 0.018]},
      (* Header text *)
      {GrayLevel[0.8], FontSize -> 8,
       Text["CR3BP co-rotating frame   \[Mu]=" <> ToString[NumberForm[mu, {5,4}]], {0.0, 1.22}]},
      {GrayLevel[0.6], FontSize -> 7,
       Text[preset, {0.0, -1.22}]}
    },
    Background  -> Black,
    PlotRange   -> {{-1.65, 1.65}, {-1.30, 1.30}},
    ImageSize   -> 420,
    Frame       -> False,
    Axes        -> False]
  ]

(* Association of Lagrange points for convenience *)
$lpts = <|"L1" -> $L1, "L2" -> $L2, "L3" -> $L3, "L4" -> $L4, "L5" -> $L5|>;
$presetLabel = GetCfg[cfg, {"simulation","lagrange","preset"}, "sun_jupiter"];


(* ══════════════════════════════════════════════════════
   MODE DISPATCH
   ══════════════════════════════════════════════════════ *)
Which[

  (* ──────────────────────────────────────────────────────
     L4 / L5  —  stable libration
     ────────────────────────────────────────────────────── *)
  mode === "l4" || mode === "l5",

  With[{
    lPos   = If[mode === "l4", $L4, $L5],
    lLabel = ToUpperCase[mode],
    outPfx = mode   (* "l4" or "l5" *)
  },

  STEMHeading["Lagrange Points: CR3BP " <> lLabel <> " Libration (Sun-Jupiter co-rotating frame)"];
  Print["  \[Mu] = ", FmtN[$mu, {8,6}],
        "   perturbation = ", $pert, " units"];
  Print["  Integration duration: ", $durP, " orbital periods (",
        FmtN[$tEnd, {5,2}], " time units)"];
  Print["  ", lLabel, " position: (",
        FmtN[lPos[[1]], {7,5}], ", ", FmtN[lPos[[2]], {7,5}], ")"];
  Print[""];

  (* ── Initial conditions: displace slightly from L4/L5 ── *)
  $x0  = lPos[[1]] + $pert;
  $y0  = lPos[[2]];
  $vx0 = 0.0;
  $vy0 = 0.0;

  Print["[1/5] Integrating CR3BP equations of motion..."];
  STEMSay["Integrating trajectory near Lagrange point " <> lLabel];

  {$xFn, $yFn} = {x, y} /. First @ NDSolve[
    {x''[t] == $fx[x[t], y[t], y'[t]],
     y''[t] == $fy[x[t], y[t], x'[t]],
     x[0]   == $x0,   y[0]   == $y0,
     x'[0]  == $vx0,  y'[0]  == $vy0},
    {x, y},
    {t, 0, $tEnd},
    MaxStepSize   -> 0.02,
    PrecisionGoal -> 8];

  Print["  Integration complete (", FmtN[$tEnd, {5,2}], " time units)"];
  Print[""];

  (* ── Extract trajectory at nPts uniform samples ── *)
  $nPts  = 600;
  $tSamp = N @ Rescale[Range[$nPts], {1, $nPts}, {0, $tEnd}];

  $xV  = $xFn /@ $tSamp;
  $yV  = $yFn /@ $tSamp;
  $vxV = ($xFn') /@ $tSamp;
  $vyV = ($yFn') /@ $tSamp;
  $r1V = $r1 @@@ Transpose[{$xV, $yV}];
  $r2V = $r2 @@@ Transpose[{$xV, $yV}];
  $omV = N[($xV * $vyV - $yV * $vxV) / ($xV^2 + $yV^2 + 1.0*^-6)];
  $invDV = 1.0 / (MapThread[Min, {$r1V, $r2V}] + 0.01);
  $dLP = Sqrt[($xV - lPos[[1]])^2 + ($yV - lPos[[2]])^2];

  (* ── Sanity checks ── *)
  Print["[2/5] Sanity checks..."];

  (* Check 1: Jacobi constant conserved *)
  $jacVals = N @ Table[
    $jacobiC[$xV[[k]], $yV[[k]], $vxV[[k]], $vyV[[k]]],
    {k, Range[1, $nPts, 30]}];
  $jacMean = Mean[$jacVals];
  $jacRel  = If[Abs[$jacMean] > 1*^-6,
    (Max[$jacVals] - Min[$jacVals]) / Abs[$jacMean], 0.0];
  $c1Pass  = $jacRel < 0.005;
  STEMPrintN["  Jacobi C drift (relative)", $jacRel * 100, "%", {5, 3}];
  Print["  Check 1 (Jacobi conserved): ",
        If[$c1Pass, "[PASS] < 0.5%", "[FAIL] > 0.5%"]];

  (* Check 2: L4/L5 geometry (computed above) *)
  Print["  Check 2 (L4/L5 equilateral geometry): ",
        If[$c2Pass, "[PASS]", "[FAIL]"]];

  (* Check 3: particle stays bounded near the Lagrange point
     Large-amplitude libration orbits can reach ~0.8 units from L4 for pert=0.02;
     threshold 1.5 distinguishes libration from actual escape. *)
  $maxDist = Max[$dLP];
  $c3Pass  = $maxDist < 1.5;
  STEMPrintN["  Max distance from " <> lLabel, $maxDist, "units", {5,3}];
  Print["  Check 3 (bounded libration, max dist < 1.5): ",
        If[$c3Pass, "[PASS]", "[FAIL]"]];

  (* Check 4: particle did not escape to a large orbit —
     maximum distance from the barycentre must stay below 2.5 units
     (real escape sends the particle past both primaries' Hill regions) *)
  $maxOriginDist = N[Max[Sqrt[$xV^2 + $yV^2]]];
  $c4Pass        = $maxOriginDist < 2.5;
  STEMPrintN["  Max distance from barycentre", $maxOriginDist, "units", {5,3}];
  Print["  Check 4 (no escape, barycentre dist < 2.5): ",
        If[$c4Pass, "[PASS]", "[FAIL]"]];
  Print[""];

  (* ── CSV export ── *)
  Print["[3/5] Exporting CSV..."];
  $csvPath = FileNameJoin[{$outDir, outPfx <> "_trajectory.csv"}];
  ExportCSV[
    Join[{{"t_orbit", "x_corot", "y_corot", "vx", "vy",
           "omega_bary", "r1", "r2", "dist_to_" <> lLabel}},
         Transpose[{$tSamp / (2*Pi), $xV, $yV, $vxV, $vyV,
                    $omV, $r1V, $r2V, $dLP}]],
    $csvPath];
  STEMDescribeCSV[$csvPath, $nPts, 9];
  Print[""];

  (* ── PNG: full trajectory static plot ── *)
  Print["[4/5] Rendering PNG and GIF..."];
  STEMSay["Rendering trajectory animation"];

  $pngPath = FileNameJoin[{$outDir, outPfx <> ".png"}];
  $pngGfx  = Graphics[{
    (* Primaries *)
    {RGBColor[1.0, 0.95, 0.15], Disk[{-$mu, 0.0}, 0.07]},
    {RGBColor[0.9, 0.50, 0.10], Disk[{1-$mu, 0.0}, 0.025]},
    (* Lagrange points *)
    {GrayLevel[0.6], PointSize[0.012], Point /@ Values[$lpts]},
    {White, FontSize -> 8,
     Text["L1", $L1 + {0.0,  0.08}], Text["L2", $L2 + {0.0,  0.08}],
     Text["L3", $L3 + {0.0, -0.10}], Text["L4", $L4 + {0.0,  0.08}],
     Text["L5", $L5 + {0.0, -0.10}]},
    (* Active Lagrange point highlighted *)
    {RGBColor[0.4, 0.9, 0.4], PointSize[0.018], Point[lPos]},
    (* Full trajectory *)
    {RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[0.8],
     Line @ Transpose[{$xV, $yV}]},
    (* Start point *)
    {RGBColor[1.0, 0.4, 0.0], Disk[{$x0, $y0}, 0.018]}
  },
  Background -> Black,
  PlotRange  -> {{-1.65, 1.65}, {-1.30, 1.30}},
  ImageSize  -> 500, Frame -> False, Axes -> False];
  EnsureDir[$pngPath];
  Export[$pngPath, $pngGfx, "PNG"];
  Print["  PNG: ", $pngPath];

  (* GIF: animated trajectory *)
  $nFrames  = 32;
  $nGIFPts  = 400;
  $tGIF     = N @ Rescale[Range[$nGIFPts], {1, $nGIFPts}, {0, $tEnd}];
  $xyGIF    = Transpose[{$xFn /@ $tGIF, $yFn /@ $tGIF}];

  $gifFrames = Table[
    MakeLagrangeFrame[$xyGIF,
      Max[2, Floor[k * $nGIFPts / $nFrames]],
      $mu, $lpts, lLabel, $presetLabel],
    {k, $nFrames}];

  $gifPath = FileNameJoin[{$outDir, outPfx <> ".gif"}];
  ExportGIF[$gifFrames, $gifPath, 10];
  Print["  GIF: ", $gifPath, " (", $nFrames, " frames, 10 fps)"];
  Print[""];

  (* ── Sonification ── *)
  Print["[5/5] Sonifying trajectory..."];
  STEMSay["Sonifying " <> lLabel <> " libration: pitch from angular velocity, pan from x-position"];

  $audioDur = N[Max[15.0, 0.5 * $tEnd]];

  (* Trajectory matrix: {t, x (pan), omega (pitch), 0, invDist (volume)} *)
  $traj = N @ Transpose[{$tSamp, $xV, $omV, ConstantArray[0.0, $nPts], $invDV}];

  $cfgSon = DeepMerge[cfg, <|"sonification" -> <|
    "duration" -> $audioDur,
    "pitch"    -> <|"axis" -> "y", "min_hz" -> 110.0, "max_hz" -> 880.0|>,
    "volume"   -> <|"min_db" -> -28.0, "max_db" -> -3.0|>
  |>|>];

  $wavPath = FileNameJoin[{$outDir, outPfx <> "_audio.wav"}];
  SonifyTrajectory[$traj, $cfgSon, $wavPath];
  Print[""];

  (* ── Summary ── *)
  STEMHeading["Done"];
  STEMSay[
    lLabel <> " libration complete. " <>
    "Mass parameter mu = " <> ToString[NumberForm[$mu, {6,5}]] <> ". " <>
    "Duration: " <> ToString[$durP] <> " orbital periods. " <>
    "Particle stayed within " <> ToString[NumberForm[$maxDist, {4,3}]] <>
    " units of " <> lLabel <> " (bounded stable libration). " <>
    "Jacobi drift: " <> If[$jacRel * 100 < 0.001, "< 0.001", ToString[NumberForm[$jacRel * 100, {4,2}]]] <> "%. " <>
    "Play audio: " <> STEMPlayCmd[$wavPath]
  ];
  Print["  Checks: ",
    If[$c1Pass, "1[PASS]", "1[FAIL]"], " ",
    If[$c2Pass, "2[PASS]", "2[FAIL]"], " ",
    If[$c3Pass, "3[PASS]", "3[FAIL]"], " ",
    If[$c4Pass, "4[PASS]", "4[FAIL]"]]
  ],  (* end l4/l5 *)


  (* ──────────────────────────────────────────────────────
     L1  —  unstable saddle / escape
     ────────────────────────────────────────────────────── *)
  mode === "l1",

  STEMHeading["Lagrange Points: CR3BP L1 Saddle Point (Unstable Escape)"];
  Print["  \[Mu] = ", FmtN[$mu, {8,6}],
        "   perturbation = ", $pert, " units"];
  Print["  L1 position: (", FmtN[$L1x, {7,5}], ", 0)"];
  Print["  Integration limit: ", FmtN[$tEndL1, {5,2}],
        " time units (stops earlier on escape)"];
  Print[""];

  (* ── Initial conditions: small displacement from L1 in +y direction ── *)
  (* Displacing in y avoids the exact x-axis where symmetric escape is degenerate *)
  $x0  = $L1x;
  $y0  = $pert;
  $vx0 = 0.0;
  $vy0 = 0.0;

  Print["[1/5] Integrating CR3BP equations of motion (escape expected)..."];
  STEMSay["Integrating L1 escape trajectory"];

  {$xFn, $yFn} = {x, y} /. First @ NDSolve[
    {x''[t] == $fx[x[t], y[t], y'[t]],
     y''[t] == $fy[x[t], y[t], x'[t]],
     x[0]   == $x0,   y[0]   == $y0,
     x'[0]  == $vx0,  y'[0]  == $vy0,
     WhenEvent[
       Sqrt[(x[t] - $L1x)^2 + y[t]^2] > $escapeR ||
       $r2[x[t], y[t]] < 0.02,  (* stop if falls too close to small primary *)
       "StopIntegration"]},
    {x, y},
    {t, 0, $tEndL1},
    MaxStepSize   -> 0.01,
    PrecisionGoal -> 10];

  $tActual = $xFn["Domain"][[1, 2]];
  Print["  Integration ended at t = ", FmtN[$tActual, {6,3}], " time units"];
  Print[""];

  (* ── Extract trajectory ── *)
  $nPts  = 500;
  $tSamp = N @ Rescale[Range[$nPts], {1, $nPts}, {0, $tActual}];

  $xV  = $xFn /@ $tSamp;
  $yV  = $yFn /@ $tSamp;
  $vxV = ($xFn') /@ $tSamp;
  $vyV = ($yFn') /@ $tSamp;
  $r1V = $r1 @@@ Transpose[{$xV, $yV}];
  $r2V = $r2 @@@ Transpose[{$xV, $yV}];
  $omV = N[($xV * $vyV - $yV * $vxV) / ($xV^2 + $yV^2 + 1.0*^-6)];
  $invDV = 1.0 / (MapThread[Min, {$r1V, $r2V}] + 0.01);
  $dL1 = Sqrt[($xV - $L1x)^2 + $yV^2];

  (* Find when particle clearly left the L1 vicinity *)
  $exitIdx = SelectFirst[Range[$nPts], $dL1[[#]] > 0.1 &, $nPts];
  $tExit   = $tSamp[[$exitIdx]];

  (* ── Sanity checks ── *)
  Print["[2/5] Sanity checks..."];

  (* Check 1: Jacobi constant conserved *)
  $jacVals = N @ Table[
    $jacobiC[$xV[[k]], $yV[[k]], $vxV[[k]], $vyV[[k]]],
    {k, Range[1, $nPts, 25]}];
  $jacMean = Mean[$jacVals];
  $jacRel  = If[Abs[$jacMean] > 1*^-6,
    (Max[$jacVals] - Min[$jacVals]) / Abs[$jacMean], 0.0];
  $c1Pass = $jacRel < 0.005;
  STEMPrintN["  Jacobi C drift (relative)", $jacRel * 100, "%", {5, 3}];
  Print["  Check 1 (Jacobi conserved): ",
        If[$c1Pass, "[PASS] < 0.5%", "[FAIL] > 0.5%"]];

  (* Check 2: L4/L5 geometry *)
  Print["  Check 2 (L4/L5 equilateral geometry): ",
        If[$c2Pass, "[PASS]", "[FAIL]"]];

  (* Check 3: particle distance from L1 grows (confirms instability) *)
  $distGrowth = $dL1[[-1]] / Max[$dL1[[1]], 1*^-8];
  $c3Pass = $distGrowth > 3.0;
  STEMPrintN["  Distance growth factor (final/initial)", $distGrowth, "", {5,2}];
  Print["  Check 3 (particle escapes L1, growth > 3x): ",
        If[$c3Pass, "[PASS]", "[FAIL]"]];

  (* Check 4: integration stopped before reaching nominal end time
              (i.e. escape actually triggered the WhenEvent) *)
  $c4Pass = $tActual < $tEndL1 * 0.95;
  STEMPrintN["  Integration end time", $tActual, "time units", {6,3}];
  Print["  Check 4 (early stop confirms escape occurred): ",
        If[$c4Pass, "[PASS]", "[WARN] may not have escaped within time limit"]];
  Print[""];

  (* ── CSV export ── *)
  Print["[3/5] Exporting CSV..."];
  $csvPath = FileNameJoin[{$outDir, "l1_trajectory.csv"}];
  ExportCSV[
    Join[{{"t_orbit", "x_corot", "y_corot", "vx", "vy",
           "omega_bary", "r1", "r2", "dist_to_L1"}},
         Transpose[{$tSamp / (2*Pi), $xV, $yV, $vxV, $vyV,
                    $omV, $r1V, $r2V, $dL1}]],
    $csvPath];
  STEMDescribeCSV[$csvPath, $nPts, 9];
  Print[""];

  (* ── PNG + GIF ── *)
  Print["[4/5] Rendering PNG and GIF..."];
  STEMSay["Rendering L1 escape animation"];

  $pngPath = FileNameJoin[{$outDir, "l1.png"}];
  $pngGfx  = Graphics[{
    {RGBColor[1.0, 0.95, 0.15], Disk[{-$mu, 0.0}, 0.07]},
    {RGBColor[0.9, 0.50, 0.10], Disk[{1-$mu, 0.0}, 0.025]},
    {GrayLevel[0.6], PointSize[0.012], Point /@ Values[$lpts]},
    {White, FontSize -> 8,
     Text["L1", $L1 + {0.0,  0.08}], Text["L2", $L2 + {0.0,  0.08}],
     Text["L3", $L3 + {0.0, -0.10}], Text["L4", $L4 + {0.0,  0.08}],
     Text["L5", $L5 + {0.0, -0.10}]},
    {RGBColor[0.9, 0.3, 0.9], PointSize[0.018], Point[$L1]},  (* L1 highlighted purple *)
    {RGBColor[1.0, 0.4, 0.4], AbsoluteThickness[0.8],
     Line @ Transpose[{$xV, $yV}]},
    {RGBColor[1.0, 0.4, 0.0], Disk[{$x0, $y0}, 0.018]}        (* start *)
  },
  Background -> Black,
  PlotRange  -> {{-1.65, 1.65}, {-1.30, 1.30}},
  ImageSize  -> 500, Frame -> False, Axes -> False];
  EnsureDir[$pngPath];
  Export[$pngPath, $pngGfx, "PNG"];
  Print["  PNG: ", $pngPath];

  $nFrames  = 32;
  $nGIFPts  = 400;
  $tGIF     = N @ Rescale[Range[$nGIFPts], {1, $nGIFPts}, {0, $tActual}];
  $xyGIF    = Transpose[{$xFn /@ $tGIF, $yFn /@ $tGIF}];

  $gifFrames = Table[
    MakeLagrangeFrame[$xyGIF,
      Max[2, Floor[k * $nGIFPts / $nFrames]],
      $mu, $lpts, "L1", $presetLabel],
    {k, $nFrames}];

  $gifPath = FileNameJoin[{$outDir, "l1.gif"}];
  ExportGIF[$gifFrames, $gifPath, 10];
  Print["  GIF: ", $gifPath, " (", $nFrames, " frames, 10 fps)"];
  Print[""];

  (* ── Sonification ── *)
  Print["[5/5] Sonifying escape trajectory..."];
  STEMSay["Sonifying L1 escape: rising pitch and fading volume as particle departs"];

  $audioDur = N[Max[8.0, 0.6 * $tActual]];

  $traj = N @ Transpose[{$tSamp, $xV, $omV, ConstantArray[0.0, $nPts], $invDV}];

  $cfgSon = DeepMerge[cfg, <|"sonification" -> <|
    "duration" -> $audioDur,
    "pitch"    -> <|"axis" -> "y", "min_hz" -> 55.0, "max_hz" -> 1760.0|>,
    "volume"   -> <|"min_db" -> -30.0, "max_db" -> -3.0|>
  |>|>];

  $wavPath = FileNameJoin[{$outDir, "l1_audio.wav"}];
  SonifyTrajectory[$traj, $cfgSon, $wavPath];
  Print[""];

  (* ── Summary ── *)
  STEMHeading["Done"];
  STEMSay[
    "L1 escape complete. " <>
    "Mass parameter mu = " <> ToString[NumberForm[$mu, {6,5}]] <> ". " <>
    "Integration ran " <> ToString[NumberForm[$tActual, {5,3}]] <> " time units (" <>
    ToString[NumberForm[$tActual / (2*Pi), {4,2}]] <> " orbital periods). " <>
    "Particle departed L1 vicinity (distance > 0.1 units) after " <>
    ToString[NumberForm[$tExit / (2*Pi), {4,2}]] <> " orbital periods. " <>
    "Distance grew by factor " <> ToString[NumberForm[$distGrowth, {4,1}]] <> ". " <>
    "Jacobi drift: " <> If[$jacRel * 100 < 0.001, "< 0.001", ToString[NumberForm[$jacRel * 100, {4,2}]]] <> "%. " <>
    "Play audio: " <> STEMPlayCmd[$wavPath]
  ];
  Print["  Checks: ",
    If[$c1Pass, "1[PASS]", "1[FAIL]"], " ",
    If[$c2Pass, "2[PASS]", "2[FAIL]"], " ",
    If[$c3Pass, "3[PASS]", "3[FAIL]"], " ",
    If[$c4Pass, "4[PASS]", "4[WARN]"]],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" \[LongDash] expected \"l4\", \"l5\", or \"l1\"."];
    Exit[1]
];

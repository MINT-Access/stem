#!/usr/bin/env wolframscript

(* ========================================================
   2D Wave Propagation — main.wl

   Simulates and sonifies 2D wave propagation using the
   finite element method (NDSolveValue on a spatial Region).

   Two modes:
     ripple       — single Gaussian impulse on a circular membrane;
                    3–4 listening points at increasing radii reveal
                    the wavefront arriving later at each in sequence
     interference — two coherent point sources in a rectangular tank;
                    a sweeping listening point crosses the fringe bands,
                    making constructive/destructive interference audible

   Usage:
     wolframscript -file waves/main.wl
     wolframscript -file waves/main.wl -- --simulation.mode=interference
     wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5
     wolframscript -file waves/main.wl -- --simulation.waves.source_frequency=3.0
     wolframscript -file waves/main.wl -- --simulation.waves.listening_points=6
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

(* Pre-process CLI args: convert "--key value" to "--key=value" *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" && i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next]; i += 2,
      AppendTo[result, arg]; i += 1]]; result];

cfg  = LoadConfig["waves", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "ripple"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

(* ── Shared config ──────────────────────────────────────────── *)
$c     = N @ GetCfg[cfg, {"simulation","waves","wave_speed"},        1.0];
$r     = N @ GetCfg[cfg, {"simulation","waves","membrane_radius"},   1.0];
$tankW = N @ GetCfg[cfg, {"simulation","waves","tank_width"},        2.0];
$tankH = N @ GetCfg[cfg, {"simulation","waves","tank_height"},       1.0];
$freq  = N @ GetCfg[cfg, {"simulation","waves","source_frequency"},  2.0];
$tEnd  = N @ GetCfg[cfg, {"simulation","waves","duration"},          4.0];
$nLP   = GetCfg[cfg, {"simulation","waves","listening_points"},      4];

(* ── Audio helper: build mono signal from trajectory using 3-layer pipeline.
      Bypasses MixLayers so the caller can apply per-LP stereo pan freely. ── *)
WavesMono[traj_?MatrixQ, cfgAudio_Association] := Module[
  {sp, mo, ev, amp, carrier},
  sp      = SpatialLayer[traj, cfgAudio];
  mo      = MotionLayer[traj, cfgAudio];
  ev      = EventLayer[traj, cfgAudio, {}];
  amp     = 10.0^(sp["vol"] / 20.0);
  carrier = Sin[2.0 Pi * Accumulate[sp["pitch"]] / sp["sr"]];
  amp * mo["envelope"] * mo["tremolo"] * mo["roughness"] * carrier + ev["audio"]
];

(* Constant-power stereo pan: mono → {left, right} matrix *)
PanStereo[mono_List, panVal_?NumericQ] :=
  Transpose[{
    mono * Sqrt[N @ Max[0.0, (1.0 - panVal) / 2.0]],
    mono * Sqrt[N @ Max[0.0, (1.0 + panVal) / 2.0]]
  }];

(* Build LP trajectory for SpatialLayer: {t, disp, disp, 0, |d_disp/dt|}
   Displacement drives pitch (axis x) and MotionLayer periodicity.
   Tiny jitter guards against zero-range displacement in Rescale. *)
MakeLPTraj[tAudio_List, disp_List] := Module[{n, dt, speed, dRange, d2},
  n     = Length[tAudio];
  dt    = If[n > 1, tAudio[[2]] - tAudio[[1]], 1.0];
  speed = Abs @ Differences[Append[N @ disp, 0.0]] / N[dt];
  dRange = Max[N @ disp] - Min[N @ disp];
  d2 = If[dRange < 1.0*^-8,
    N @ disp + 1.0*^-6 * Table[Sin[2.0 Pi * i / n], {i, n}],
    N @ disp];
  Transpose[{tAudio, d2, d2, ConstantArray[0.0, n], speed}]
];

(* Config with correct pitch axis and audio duration for LP trajectories *)
AudioCfg[cfgBase_, dur_] :=
  DeepMerge[cfgBase, <|"sonification" -> <|
    "duration" -> N[dur],
    "pitch"    -> <| "axis" -> "x", "min_hz" -> 110.0, "max_hz" -> 880.0 |>,
    "volume"   -> <| "min_db" -> -28.0, "max_db" -> -3.0 |>
  |>|>];

(* Raster frame (nPx×nPx RGB, row-major) from a displacement field sampled on a grid *)
WaveRaster[evalFn_, xRange_, yRange_, clamp_, nPx_] :=
  Table[
    With[{
      xv = N[xRange[[1]] + (j - 0.5) / nPx * (xRange[[2]] - xRange[[1]])],
      yv = N[yRange[[2]] - (i - 0.5) / nPx * (yRange[[2]] - yRange[[1]])]
    },
      evalFn[xv, yv]],
    {i, 1, nPx}, {j, 1, nPx}];

(* Map scalar u ∈ [-1,1] to RGB: negative → blue, zero → white, positive → red *)
DispColor[u_?NumericQ] :=
  With[{v = Clip[N[u], {-1.0, 1.0}]},
    If[v >= 0.0,
      {1.0, 1.0 - v, 1.0 - v},   (* red for positive *)
      {1.0 + v, 1.0 + v, 1.0}    (* blue for negative *)
    ]];

(* ================================================================
   RIPPLE MODE — expanding wavefront on a circular membrane
   ================================================================ *)

Which[

mode === "ripple",

  STEMHeading["2D Wave Propagation: Ripple Mode"];
  Print["  Membrane radius:  ", FmtN[$r, {4,2}], " (units)"];
  Print["  Wave speed:       ", FmtN[$c, {4,2}], " (units/s)"];
  Print["  Duration:         ", FmtN[$tEnd, {4,2}], " s"];
  Print["  Listening points: ", $nLP];
  Print[""];

  (* ── [1/4] Solve PDE + sanity checks ─────────────────────── *)
  Print["[1/4] Solving 2D wave equation on circular membrane (FEM)..."];
  STEMSay["Solving 2D wave equation — circular membrane"];

  $sig = N[0.10 * $r];   (* Gaussian impulse width *)
  $solR = NDSolveValue[
    {D[u[x, y, t], {t, 2}] ==
       $c^2 * Inactive[Laplacian][u[x, y, t], {x, y}],
     u[x, y, 0] == Exp[-(x^2 + y^2) / (2.0 * $sig^2)],
     Derivative[0, 0, 1][u][x, y, 0] == 0.0,
     DirichletCondition[u[x, y, t] == 0.0, True]},
    u,
    {x, y} \[Element] Disk[{0.0, 0.0}, $r],
    {t, 0.0, $tEnd}
  ];
  Print["  PDE solved."];

  (* Listening points along positive x-axis at fractions of radius *)
  $lpFracs = N @ Rescale[Range[$nLP], {1, $nLP}, {0.2, 0.8}];
  $lpX     = $lpFracs * $r;
  $lpPans  = N @ Rescale[Range[$nLP], {1, $nLP}, {-0.8, 0.8}];

  $nT    = 300;
  $tVals = N @ Rescale[Range[$nT], {1, $nT}, {0.0, $tEnd}];
  $dt    = $tVals[[2]] - $tVals[[1]];

  Print["  Extracting ", $nLP, " listening-point time series..."];
  $lpDisp = Table[
    Table[$solR[$lpX[[k]], 0.0, t], {t, $tVals}],
    {k, $nLP}];

  STEMSection["Physical correctness checks"];

  (* Check 1: amplitude bounded, non-zero *)
  $maxR = Max[Abs[Flatten[$lpDisp]]];
  $c1R  = $maxR > 1.0*^-6 && $maxR < 500.0;
  Print["  [", If[$c1R, "PASS", "FAIL"], "] Amplitude bounded:  max|u| = ",
    FmtN[$maxR, {5,4}], "  (expected 0 < max|u| < 500)"];

  (* Check 2: wavefront arrival time ≈ r / wave_speed *)
  $arrThr = 0.02 * Max[Abs[$lpDisp[[1]]]];
  $arrivals = Table[
    Module[{idx = SelectFirst[Range[$nT], Abs[$lpDisp[[k, #]]] >= $arrThr &, 0]},
      If[idx === 0, Infinity, $tVals[[idx]]]],
    {k, $nLP}];
  $expected = $lpX / $c;
  $c2R = AllTrue[
    Table[Abs[$arrivals[[k]] - $expected[[k]]] < Max[0.6, 0.35 * $tEnd], {k, $nLP}],
    TrueQ];
  Print["  [", If[$c2R, "PASS", "WARN"], "] Wavefront arrival times vs distance/c:"];
  Do[
    Print["    LP", k, " r=", FmtN[$lpX[[k]], {4,2}],
          "  expected=", FmtN[$expected[[k]], {4,2}], " s",
          "  measured=", FmtN[$arrivals[[k]], {4,2}], " s"],
    {k, $nLP}];

  (* Check 3: outer LPs receive wave later than inner (causality) *)
  $finiteArr = Select[$arrivals, # < Infinity &];
  $c3R = Length[$finiteArr] >= 2 && AllTrue[Differences[$finiteArr], # >= 0 &];
  Print["  [", If[$c3R, "PASS", "FAIL"], "] Causality: arrivals ordered ",
    StringRiffle[Map[If[# < Infinity, FmtN[#, {4,2}], "∞"] &, $arrivals], " < "], " s"];

  (* Check 4: Dirichlet BC — u ≈ 0 near rim (0.97r to stay inside FEM mesh) *)
  $bPts = Table[{0.97 * $r * Cos[2 Pi k / 16], 0.97 * $r * Sin[2 Pi k / 16]}, {k, 0, 15}];
  $maxRim = Quiet[Max[Abs @ Table[$solR[p[[1]], p[[2]], $tEnd], {p, $bPts}]],
                  InterpolatingFunction::femdmval];
  $c4R = NumericQ[$maxRim] && $maxRim < 0.12;
  Print["  [", If[$c4R, "PASS", "FAIL"], "] Dirichlet BC:  max|u| near rim = ",
    If[NumericQ[$maxRim], FmtN[$maxRim, {6,4}], "N/A"], "  (expected < 0.12)"];
  Print[""];

  (* ── [2/4] Sonify ─────────────────────────────────────────── *)
  Print["[2/4] Sonifying ", $nLP, " listening points..."];
  STEMSay["Sonifying wave propagation at listening points"];

  $stretchR    = 5.0;
  $audioDurR   = N[$tEnd * $stretchR];
  $cfgR        = AudioCfg[cfg, $audioDurR];
  $tAudioR     = N @ Rescale[Range[$nT], {1, $nT}, {0.0, $audioDurR}];

  $allStereoR = Table[
    PanStereo[
      WavesMono[MakeLPTraj[$tAudioR, $lpDisp[[k]]], $cfgR],
      $lpPans[[k]]
    ],
    {k, $nLP}];

  $combinedR = Total[$allStereoR] / $nLP;
  $outWAVR   = FileNameJoin[{$outDir, "ripple_audio.wav"}];
  RenderAudio[$combinedR, $cfgR, $outWAVR];
  STEMDescribeWAV[$outWAVR, $audioDurR];
  Print["  Listen for: wavefront arriving at LP1 (leftmost), then LP2, LP3, LP4 in sequence."];
  Print["  Pan: ", StringRiffle[Map[FmtN[#, {4,2}] &, $lpPans], " → "],
        "  (left to right)"];
  Print[""];

  (* ── [3/4] Animation (GIF + PNG) ─────────────────────────── *)
  Print["[3/4] Exporting ripple animation..."];
  STEMSay["Rendering ripple animation"];

  $nFramesR   = 32;
  $frameTimesR = N @ Rescale[Range[$nFramesR], {1, $nFramesR}, {0.1, $tEnd}];
  $nPxR       = 60;
  $maxAmpR    = Max[0.01, 0.8 * Max[Abs @ Table[
    $solR[0.0, 0.0, t], {t, Rescale[Range[5], {1, 5}, {0.1, 0.4}]}]]];

  $lpDotPx = Map[   (* pixel coords of LP dots in the raster *)
    Function[xLP,
      {Round[$nPxR / 2 + xLP / $r * $nPxR / 2],
       Round[$nPxR / 2]}],
    $lpX];

  $framesR = Table[
    Module[{raster, img},
      raster = Table[
        With[{
          xv = N[$r * (j - $nPxR/2.0) / ($nPxR / 2.0)],
          yv = N[$r * ($nPxR/2.0 - i) / ($nPxR / 2.0)]
        },
          If[xv^2 + yv^2 <= (0.99 * $r)^2,
            DispColor[$solR[xv, yv, t] / $maxAmpR],
            {0.08, 0.08, 0.08}  (* dark background outside disk *)
          ]],
        {i, 1, $nPxR}, {j, 1, $nPxR}];
      (* Overlay yellow dots at LP positions *)
      Do[
        With[{pj = $lpDotPx[[k, 1]], pi = $lpDotPx[[k, 2]]},
          If[1 <= pi <= $nPxR && 1 <= pj <= $nPxR,
            raster[[pi, pj]] = {1.0, 0.9, 0.0}]],  (* yellow *)
        {k, $nLP}];
      Image[raster, ColorSpace -> "RGB", ImageSize -> 280]
    ],
    {t, $frameTimesR}];

  $outGIFR = FileNameJoin[{$outDir, "ripple.gif"}];
  Export[$outGIFR, $framesR, "GIF",
    "DisplayDurations" -> ConstantArray[0.1, $nFramesR],
    "AnimationRepetitions" -> Infinity];
  STEMDescribeGIF[$outGIFR, $nFramesR, 10];

  (* PNG: Plot3D surface at final time *)
  $outPNGR = FileNameJoin[{$outDir, "ripple.png"}];
  Export[$outPNGR,
    Plot3D[$solR[x, y, $tEnd],
      {x, -$r, $r}, {y, -$r, $r},
      RegionFunction -> Function[{xp, yp, z}, xp^2 + yp^2 <= (0.97*$r)^2],
      PlotRange  -> {-$maxAmpR, $maxAmpR} * 0.6,
      ColorFunction -> "TemperatureMap",
      Mesh -> None, Boxed -> False, Axes -> False,
      BoxRatios -> {2, 2, 0.7},
      ImageSize -> 400,
      Background -> Black,
      ViewPoint -> {2.0, -3.0, 1.5}],
    "PNG"];
  Print["  PNG: ", $outPNGR];
  Print[""];

  (* ── [4/4] Data CSV ───────────────────────────────────────── *)
  Print["[4/4] Exporting data table (CSV)..."];
  $csvHeaderR = Join[{"t_s"}, Map["disp_lp" <> ToString[#] <> "_units" &, Range[$nLP]]];
  $csvDataR   = Table[
    Join[{$tVals[[i]]}, Map[$lpDisp[[#, i]] &, Range[$nLP]]],
    {i, $nT}];
  $outCSVR = FileNameJoin[{$outDir, "ripple_data.csv"}];
  Export[$outCSVR, Join[{$csvHeaderR}, $csvDataR], "CSV"];
  STEMDescribeCSV[$outCSVR, $nT, $nLP + 1];
  Print[""],


(* ================================================================
   INTERFERENCE MODE — two coherent sources, fringe pattern
   ================================================================ *)

mode === "interference",

  STEMHeading["2D Wave Propagation: Interference Mode"];
  Print["  Tank:          ", FmtN[$tankW, {4,2}], " \[Times] ", FmtN[$tankH, {4,2}], " (units)"];
  Print["  Wave speed:    ", FmtN[$c, {4,2}], " (units/s)"];
  Print["  Source freq:   ", FmtN[$freq, {4,2}], " Hz   (\[Lambda] = ", FmtN[$c/$freq, {4,2}], " units)"];
  Print["  Duration:      ", FmtN[$tEnd, {4,2}], " s"];
  Print[""];

  (* ── [1/4] Solve PDE + sanity checks ─────────────────────── *)
  Print["[1/4] Solving wave equation with two coherent sources (FEM)..."];
  STEMSay["Solving interference wave equation"];

  (* Source positions: symmetric on x-axis, separated by 40% of tank width *)
  $srcSep  = N[0.4 * $tankW];
  $x1s     = N[-$srcSep / 2.0];  $y1s = 0.0;
  $x2s     = N[ $srcSep / 2.0];  $y2s = 0.0;
  $srcSig  = N[0.07 * Min[$tankW, $tankH]];
  $srcAmpI = 1.0;

  $solI = NDSolveValue[
    {D[u[x, y, t], {t, 2}] ==
       $c^2 * Inactive[Laplacian][u[x, y, t], {x, y}] +
       $srcAmpI *
       (Exp[-((x - $x1s)^2 + (y - $y1s)^2) / (2.0 * $srcSig^2)] +
        Exp[-((x - $x2s)^2 + (y - $y2s)^2) / (2.0 * $srcSig^2)]) *
       Sin[2.0 Pi * $freq * t],
     u[x, y, 0] == 0.0,
     Derivative[0, 0, 1][u][x, y, 0] == 0.0,
     DirichletCondition[u[x, y, t] == 0.0, True]},
    u,
    {x, y} \[Element] Rectangle[{-$tankW/2.0, -$tankH/2.0}, {$tankW/2.0, $tankH/2.0}],
    {t, 0.0, $tEnd}
  ];
  Print["  PDE solved."];

  (* Moving LP: fixed at origin for first half, sweeps x during second half.
     y fixed at 35% of half-height (slightly above x-axis).
     Pan = x-position → natural left-right sweep.
     Fixed constructive LP at (0, yLP): always equidistant from both sources. *)
  $yLP      = N[0.35 * $tankH / 2.0];
  $xLPMin   = N[-0.88 * $tankW / 2.0];
  $xLPMax   = N[ 0.88 * $tankW / 2.0];
  $nT       = 300;
  $tVals    = N @ Rescale[Range[$nT], {1, $nT}, {0.0, $tEnd}];
  $dt       = $tVals[[2]] - $tVals[[1]];

  $nTStat   = Floor[$nT / 2];
  $nTSweep  = $nT - $nTStat;
  $tStat    = $tVals[[1 ;; $nTStat]];
  $tSweep   = $tVals[[$nTStat + 1 ;; $nT]];
  $xSweep   = N @ Rescale[Range[$nTSweep], {1, $nTSweep}, {$xLPMin, $xLPMax}];

  (* Displacement at moving LP *)
  $dispStat  = Table[$solI[0.0, $yLP, t], {t, $tStat}];
  $dispSweep = Table[$solI[$xSweep[[i]], $yLP, $tSweep[[i]]], {i, $nTSweep}];
  $dispMoving = Join[$dispStat, $dispSweep];
  $xMoving    = Join[ConstantArray[0.0, $nTStat], $xSweep];

  (* Fixed constructive LP at (0, yLP) for all t *)
  $dispFixed = Table[$solI[0.0, $yLP, t], {t, $tVals}];

  Print["  LP time series extracted."];

  STEMSection["Physical correctness checks"];

  (* Check 1: amplitude bounded *)
  $maxI = Max[Abs[$dispMoving]];
  $c1I  = $maxI > 1.0*^-8 && $maxI < 500.0;
  Print["  [", If[$c1I, "PASS", "FAIL"], "] Amplitude bounded:  max|u| = ",
    FmtN[$maxI, {5,4}], "  (expected 0 < max|u| < 500)"];

  (* Check 2: pattern develops — non-trivial amplitude after settling *)
  $nLateI   = Max[1, Floor[0.7 * $nT]];
  $lateAmpI = Max[Abs[$dispMoving[[$nLateI ;; $nT]]]];
  $c2I      = $lateAmpI > 0.005 * Max[$maxI, 1.0*^-6];
  Print["  [", If[$c2I, "PASS", "FAIL"], "] Pattern develops:  late-time max|u| = ",
    FmtN[$lateAmpI, {5,4}]];

  (* Check 3: fixed LP at (0, yLP) shows constructive-level amplitude *)
  $lateFixed = Max[Abs[$dispFixed[[$nLateI ;; $nT]]]];
  $c3I       = $lateFixed >= 0.3 * $lateAmpI;
  Print["  [", If[$c3I, "PASS", "WARN"],
    "] Constructive LP amplitude:  |u| at (0,yLP) = ", FmtN[$lateFixed, {5,4}],
    "  sweep late-time max = ", FmtN[$lateAmpI, {5,4}]];

  (* Check 4: Dirichlet BC — u ≈ 0 near walls (0.97 factor stays inside FEM mesh) *)
  $bPtsI = Join[
    Table[{-0.97 * $tankW/2.0, y}, {y, Rescale[Range[8], {1, 8}, {-$tankH*0.45, $tankH*0.45}]}],
    Table[{ 0.97 * $tankW/2.0, y}, {y, Rescale[Range[8], {1, 8}, {-$tankH*0.45, $tankH*0.45}]}]];
  $maxBndI = Quiet[Max[Abs @ Table[$solI[p[[1]], p[[2]], $tEnd], {p, $bPtsI}]],
                   InterpolatingFunction::femdmval];
  $c4I     = NumericQ[$maxBndI] && $maxBndI < Max[0.15 * $maxI, 0.01];
  Print["  [", If[$c4I, "PASS", "FAIL"], "] Dirichlet BC:  max|u| near walls = ",
    If[NumericQ[$maxBndI], FmtN[$maxBndI, {6,4}], "N/A"],
    "  (expected < 15% of peak)"];
  Print[""];

  (* ── [2/4] Sonify ─────────────────────────────────────────── *)
  Print["[2/4] Sonifying moving listening point..."];
  STEMSay["Sonifying wave interference pattern"];

  $stretchI  = 4.0;
  $audioDurI = N[$tEnd * $stretchI];

  (* x-position (-0.88..0.88) maps to pan via SpatialLayer (panAxis="x").
     MinMax[xMoving] = {xLPMin, xLPMax} is non-degenerate → correct pan sweep. *)
  $speedI  = Abs @ Differences[Append[N @ $dispMoving, 0.0]] / $dt;
  $tAudioI = N @ Rescale[Range[$nT], {1, $nT}, {0.0, $audioDurI}];

  $cfgI = DeepMerge[cfg, <|"sonification" -> <|
    "duration"  -> $audioDurI,
    "pitch"     -> <| "axis" -> "y", "min_hz" -> 80.0, "max_hz" -> 1200.0 |>,
    "spatial"   -> <| "pan_axis" -> "x" |>,
    "volume"    -> <| "min_db" -> -28.0, "max_db" -> -3.0 |>
  |>|>];

  (* Trajectory: {t, x_position (pan), displacement (pitch), 0, speed (vol)} *)
  $trajI    = Transpose[{$tAudioI, N @ $xMoving, N @ $dispMoving,
                          ConstantArray[0.0, $nT], $speedI}];
  $outWAVI  = FileNameJoin[{$outDir, "interference_audio.wav"}];
  SonifyTrajectory[$trajI, $cfgI, $outWAVI, {}];
  STEMDescribeWAV[$outWAVI, $audioDurI];
  Print["  First half: LP stationary at centre (constructive) — sustained tone."];
  Print["  Second half: LP sweeps left-to-right — loud/quiet fringe bands audible."];
  Print[""];

  (* ── [3/4] Animation (GIF + PNG) ─────────────────────────── *)
  Print["[3/4] Exporting interference animation..."];
  STEMSay["Rendering interference pattern animation"];

  $nFramesI    = 32;
  $frameTimesI = N @ Rescale[Range[$nFramesI], {1, $nFramesI}, {0.1, $tEnd}];
  $nPxW        = 80;   (* width pixels *)
  $nPxH        = 40;   (* height pixels *)

  (* Amplitude scale: use late-time peak for good contrast *)
  $maxAmpI = Max[0.01,
    Max[Abs @ Table[
      $solI[0.0, 0.0, t],
      {t, Rescale[Range[4], {1, 4}, {$tEnd * 0.7, $tEnd}]}]]];

  $framesI = Table[
    Module[{raster, lpXNow, lpPxCol, lpPxRow},
      raster = Table[
        DispColor[$solI[
          N[$tankW * (j - $nPxW/2.0) / $nPxW],
          N[$tankH * ($nPxH/2.0 - i) / $nPxH],
          t] / $maxAmpI],
        {i, 1, $nPxH}, {j, 1, $nPxW}];
      (* Moving LP dot *)
      lpXNow  = If[t < $tEnd/2.0, 0.0,
                   Rescale[t, {$tEnd/2.0, $tEnd}, {$xLPMin, $xLPMax}]];
      lpPxCol = Round[$nPxW * (lpXNow / $tankW + 0.5)];
      lpPxRow = Round[$nPxH * (0.5 - $yLP / $tankH)];
      If[1 <= lpPxRow <= $nPxH && 1 <= lpPxCol <= $nPxW,
        raster[[lpPxRow, lpPxCol]] = {1.0, 0.95, 0.0}];
      (* Source dots *)
      Do[
        With[{
          sc = Round[$nPxW * (xs / $tankW + 0.5)],
          sr = Round[$nPxH / 2]},
          If[1 <= sr <= $nPxH && 1 <= sc <= $nPxW,
            raster[[sr, sc]] = {0.3, 1.0, 0.3}]],  (* green sources *)
        {xs, {$x1s, $x2s}}];
      Image[raster, ColorSpace -> "RGB", ImageSize -> {480, 240}]
    ],
    {t, $frameTimesI}];

  $outGIFI = FileNameJoin[{$outDir, "interference.gif"}];
  Export[$outGIFI, $framesI, "GIF",
    "DisplayDurations" -> ConstantArray[0.1, $nFramesI],
    "AnimationRepetitions" -> Infinity];
  STEMDescribeGIF[$outGIFI, $nFramesI, 10];

  (* PNG: final frame showing the settled interference pattern *)
  $outPNGI = FileNameJoin[{$outDir, "interference.png"}];
  Export[$outPNGI, Last[$framesI], "PNG"];
  Print["  PNG: ", $outPNGI];
  Print[""];

  (* ── [4/4] Data CSV ───────────────────────────────────────── *)
  Print["[4/4] Exporting data table (CSV)..."];
  $csvHeaderI = {"t_s", "lp_x_units", "displacement_units", "disp_fixed_units"};
  $csvDataI   = Table[
    {$tVals[[i]], $xMoving[[i]], $dispMoving[[i]], $dispFixed[[i]]},
    {i, $nT}];
  $outCSVI = FileNameJoin[{$outDir, "interference_data.csv"}];
  Export[$outCSVI, Join[{$csvHeaderI}, $csvDataI], "CSV"];
  STEMDescribeCSV[$outCSVI, $nT, 4];
  Print[""],


(* Unknown mode *)
True,
  Print["Error: unknown simulation.mode \"", mode,
        "\" \[LongDash] expected \"ripple\" or \"interference\"."];
  Exit[1]

]; (* end Which *)

STEMHeading["Done"];
STEMSay["Wave simulation complete. Play audio: " <>
  STEMPlayCmd[FileNameJoin[{$outDir, mode <> "_audio.wav"}]]]

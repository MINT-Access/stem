(* waves/src/animate.wl — GIF and PNG rendering for wave propagation *)

(* Map scalar u in [-1,1] to RGB: negative -> blue, zero -> white, positive -> red *)
DispColor[u_?NumericQ] :=
  With[{v = Clip[N[u], {-1.0, 1.0}]},
    If[v >= 0.0,
      {1.0, 1.0 - v, 1.0 - v},
      {1.0 + v, 1.0 + v, 1.0}
    ]];

(* Render GIF and PNG for ripple mode.
   GIF: 32-frame false-colour animation with listening-point dots.
   PNG: Plot3D surface at final time. *)
AnimateRipple[model_Association, outDir_String] :=
  Module[{solR, lpX, r, tEnd, maxR,
          nFramesR, frameTimesR, nPxR, maxAmpR,
          lpDotPx, framesR, raster, outGIFR, outPNGR},
    solR  = model["solR"];
    lpX   = model["lpX"];
    r     = model["r"];
    tEnd  = model["tEnd"];
    maxR  = model["maxR"];

    nFramesR    = 32;
    frameTimesR = N @ Rescale[Range[nFramesR], {1, nFramesR}, {0.1, tEnd}];
    nPxR        = 60;
    maxAmpR     = Max[0.01, 0.8 * Max[Abs @ Table[
      solR[0.0, 0.0, t],
      {t, Rescale[Range[5], {1, 5}, {0.1, 0.4}]}]]];

    lpDotPx = Map[
      Function[xLP,
        {Round[nPxR / 2 + xLP / r * nPxR / 2],
         Round[nPxR / 2]}],
      lpX];

    framesR = Table[
      Module[{raster, img},
        raster = Table[
          With[{
            xv = N[r * (j - nPxR/2.0) / (nPxR / 2.0)],
            yv = N[r * (nPxR/2.0 - i) / (nPxR / 2.0)]
          },
            If[xv^2 + yv^2 <= (0.99 * r)^2,
              DispColor[solR[xv, yv, t] / maxAmpR],
              {0.08, 0.08, 0.08}
            ]],
          {i, 1, nPxR}, {j, 1, nPxR}];
        Do[
          With[{pj = lpDotPx[[k, 1]], pi = lpDotPx[[k, 2]]},
            If[1 <= pi <= nPxR && 1 <= pj <= nPxR,
              raster[[pi, pj]] = {1.0, 0.9, 0.0}]],
          {k, Length[lpX]}];
        Image[raster, ColorSpace -> "RGB", ImageSize -> 280]
      ],
      {t, frameTimesR}];

    outGIFR = FileNameJoin[{outDir, "ripple.gif"}];
    Export[outGIFR, framesR, "GIF",
      "DisplayDurations" -> ConstantArray[0.1, nFramesR],
      "AnimationRepetitions" -> Infinity];
    STEMDescribeGIF[outGIFR, nFramesR, 10];

    outPNGR = FileNameJoin[{outDir, "ripple.png"}];
    Export[outPNGR,
      Plot3D[solR[x, y, tEnd],
        {x, -r, r}, {y, -r, r},
        RegionFunction -> Function[{xp, yp, z}, xp^2 + yp^2 <= (0.97*r)^2],
        PlotRange      -> {-maxAmpR, maxAmpR} * 0.6,
        ColorFunction  -> "TemperatureMap",
        Mesh -> None, Boxed -> False, Axes -> False,
        BoxRatios  -> {2, 2, 0.7},
        ImageSize  -> 400,
        Background -> Black,
        ViewPoint  -> {2.0, -3.0, 1.5}],
      "PNG"];
    Print["  PNG: ", outPNGR]
  ];

(* Render GIF and PNG for interference mode.
   GIF: 32-frame animation with moving LP dot and green source dots.
   PNG: final frame showing the settled fringe pattern. *)
AnimateInterference[model_Association, outDir_String] :=
  Module[{solI, tankW, tankH, tEnd, xLPMin, xLPMax, yLP, x1s, x2s, maxI,
          nFramesI, frameTimesI, nPxW, nPxH, maxAmpI, framesI, outGIFI, outPNGI},
    solI   = model["solI"];
    tankW  = model["tankW"];
    tankH  = model["tankH"];
    tEnd   = model["tEnd"];
    xLPMin = model["xLPMin"];
    xLPMax = model["xLPMax"];
    yLP    = model["yLP"];
    x1s    = model["x1s"];
    x2s    = model["x2s"];
    maxI   = model["maxI"];

    nFramesI    = 32;
    frameTimesI = N @ Rescale[Range[nFramesI], {1, nFramesI}, {0.1, tEnd}];
    nPxW        = 80;
    nPxH        = 40;
    maxAmpI     = Max[0.01,
      Max[Abs @ Table[
        solI[0.0, 0.0, t],
        {t, Rescale[Range[4], {1, 4}, {tEnd * 0.7, tEnd}]}]]];

    framesI = Table[
      Module[{raster, lpXNow, lpPxCol, lpPxRow},
        raster = Table[
          DispColor[solI[
            N[tankW * (j - nPxW/2.0) / nPxW],
            N[tankH * (nPxH/2.0 - i) / nPxH],
            t] / maxAmpI],
          {i, 1, nPxH}, {j, 1, nPxW}];
        lpXNow  = If[t < tEnd/2.0, 0.0,
                     Rescale[t, {tEnd/2.0, tEnd}, {xLPMin, xLPMax}]];
        lpPxCol = Round[nPxW * (lpXNow / tankW + 0.5)];
        lpPxRow = Round[nPxH * (0.5 - yLP / tankH)];
        If[1 <= lpPxRow <= nPxH && 1 <= lpPxCol <= nPxW,
          raster[[lpPxRow, lpPxCol]] = {1.0, 0.95, 0.0}];
        Do[
          With[{
            sc = Round[nPxW * (xs / tankW + 0.5)],
            sr = Round[nPxH / 2]},
            If[1 <= sr <= nPxH && 1 <= sc <= nPxW,
              raster[[sr, sc]] = {0.3, 1.0, 0.3}]],
          {xs, {x1s, x2s}}];
        Image[raster, ColorSpace -> "RGB", ImageSize -> {480, 240}]
      ],
      {t, frameTimesI}];

    outGIFI = FileNameJoin[{outDir, "interference.gif"}];
    Export[outGIFI, framesI, "GIF",
      "DisplayDurations" -> ConstantArray[0.1, nFramesI],
      "AnimationRepetitions" -> Infinity];
    STEMDescribeGIF[outGIFI, nFramesI, 10];

    outPNGI = FileNameJoin[{outDir, "interference.png"}];
    Export[outPNGI, Last[framesI], "PNG"];
    Print["  PNG: ", outPNGI]
  ];

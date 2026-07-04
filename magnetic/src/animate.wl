(* ========================================================
   magnetic/src/animate.wl — GIF rendering for all four modes

   Public API:
     AnimateCyclotron[model, outGif]  -> nFrames rendered
     AnimateDrift[model, outGif]      -> nFrames rendered
     AnimateMirror[model, outGif]     -> nFrames rendered
     AnimateMulti[model, outGif]      -> nFrames rendered
   ======================================================== *)

$MagFrames    = 40;
$MagFrameRate = 15;


(* ========================================================
   CYCLOTRON MODE
   ======================================================== *)

AnimateCyclotron[model_Association, outGif_String] :=
  Module[{xArr, yArr, zArr, isHelix, rc, nPts, nFrames, frames},
    xArr = model["x"]; yArr = model["y"]; zArr = model["z"];
    isHelix = model["isHelix"]; rc = model["rc"];
    nPts = Length[xArr]; nFrames = $MagFrames;

    frames = If[!isHelix,
      (* 2D circle: growing trail + current dot + radius annotation *)
      Table[
        With[{nS = Max[2, Round[k * nPts / nFrames]]},
          Graphics[{
            {GrayLevel[0.35], Dashing[{0.02, 0.02}],
             Circle[{0.0, -rc}, rc]},
            {Opacity[0.85], RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[1.5],
             Line[Transpose[{xArr[[;; nS]], yArr[[;; nS]]}]]},
            {RGBColor[1.0, 0.6, 0.0], PointSize[0.025], Point[{xArr[[1]], yArr[[1]]}]},
            {White, Disk[{xArr[[nS]], yArr[[nS]]}, 0.03 * Max[rc, 0.3]]},
            {GrayLevel[0.8], FontSize -> 9,
             Text["r_c = " <> ToString[NumberForm[rc, {4, 3}]], {0.0, rc * 1.35 + 0.15}]}
          },
          Background -> Black,
          PlotRange -> 1.5 * Max[rc, 0.3] * {{-1, 1}, {-1.6, 1}},
          ImageSize -> 420, Frame -> False, Axes -> False]
        ],
        {k, nFrames}
      ],

      (* Helix: 3D parametric plot, rotating view, colour by time *)
      Table[
        With[{nS = Max[2, Round[k * nPts / nFrames]], theta = 2.0 Pi * k / nFrames},
          Graphics3D[{
            Table[
              {ColorData["Rainbow"][i / nS], PointSize[0.012],
               Point[{xArr[[i]], yArr[[i]], zArr[[i]]}]},
              {i, 1, nS, Max[1, Round[nS / 150]]}],
            {RGBColor[1.0, 0.6, 0.0], Sphere[{xArr[[1]], yArr[[1]], zArr[[1]]}, 0.05 * Max[rc, 0.3]]},
            {White, Sphere[{xArr[[nS]], yArr[[nS]], zArr[[nS]]}, 0.06 * Max[rc, 0.3]]}
          },
          Background -> Black, Boxed -> False, Axes -> False,
          ViewPoint -> {2.5 Cos[theta], 2.5 Sin[theta], 1.2},
          ImageSize -> 420,
          PlotRange -> {1.4 * Max[rc, 0.3] * {-1, 1}, 1.4 * Max[rc, 0.3] * {-1, 1}, MinMax[zArr]}]
        ],
        {k, nFrames}
      ]
    ];
    ExportGIF[frames, outGif, $MagFrameRate];
    nFrames
  ]


(* ========================================================
   DRIFT MODE
   ======================================================== *)

AnimateDrift[model_Association, outGif_String] :=
  Module[{xArr, yArr, speedArr, nPts, nFrames, speedMin, speedMax, yRange, frames},
    xArr = model["x"]; yArr = model["y"]; speedArr = model["speed"];
    nPts = Length[xArr]; nFrames = $MagFrames;
    {speedMin, speedMax} = MinMax[speedArr];
    yRange = MinMax[yArr];

    frames = Table[
      With[{nS = Max[2, Round[k * nPts / nFrames]]},
        Graphics[{
          (* Trail coloured by local speed: blue = slow, red = fast *)
          Table[
            {Blend[{RGBColor[0.2, 0.4, 1.0], RGBColor[1.0, 0.25, 0.2]},
                   SafeRescale[speedArr[[i]], {speedMin, speedMax}, {0.0, 1.0}]],
             AbsoluteThickness[2.0],
             Line[{{xArr[[i]], yArr[[i]]}, {xArr[[i + 1]], yArr[[i + 1]]}}]},
            {i, 1, nS - 1}],
          {RGBColor[1.0, 0.6, 0.0], PointSize[0.02], Point[{xArr[[1]], yArr[[1]]}]},
          {White, Disk[{xArr[[nS]], yArr[[nS]]}, 0.04]},
          {GrayLevel[0.7], AbsoluteThickness[1.0],
           Arrow[{{Min[xArr] - 0.3, yRange[[1]] - 0.3}, {Min[xArr] - 0.3, yRange[[2]] + 0.3}}]},
          {GrayLevel[0.8], FontSize -> 9, Text["drift", {Min[xArr] - 0.55, Mean[yRange]}]}
        },
        Background -> Black,
        PlotRange -> {MinMax[xArr] + {-0.6, 0.3}, yRange + {-0.5, 0.5}},
        ImageSize -> 460, Frame -> False, Axes -> False]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, $MagFrameRate];
    nFrames
  ]


(* ========================================================
   MIRROR MODE
   ======================================================== *)

AnimateMirror[model_Association, outGif_String] :=
  Module[{xArr, yArr, zArr, Bfield, bounceTimes, tArr, nPts, nFrames,
          bMin, bMax, zRange, bouncePts, frames},
    xArr = model["x"]; yArr = model["y"]; zArr = model["z"];
    Bfield = model["Bfield"]; tArr = model["t"];
    bounceTimes = model["bounceTimes"];
    nPts = Length[xArr]; nFrames = $MagFrames;
    {bMin, bMax} = MinMax[Bfield];
    zRange = MinMax[zArr];

    (* Nearest trajectory index for each bounce time, for marker placement *)
    bouncePts = Map[
      Function[bt, First[Nearest[tArr -> "Index", bt]]],
      bounceTimes];

    frames = Table[
      With[{nS = Max[2, Round[k * nPts / nFrames]]},
        Graphics3D[{
          (* Field-strength background gradient along z, on the axis *)
          Table[
            {Directive[Opacity[0.25],
              Blend[{RGBColor[0.1, 0.2, 0.6], RGBColor[1.0, 0.5, 0.1]},
                    SafeRescale[Bfield[[i]], {bMin, bMax}, {0.0, 1.0}]]],
             Sphere[{0, 0, zArr[[i]]}, 0.02]},
            {i, 1, nS, Max[1, Round[nS / 60]]}],
          {RGBColor[0.2, 0.85, 1.0], AbsoluteThickness[1.3],
           Line[Transpose[{xArr[[;; nS]], yArr[[;; nS]], zArr[[;; nS]]}]]},
          Table[
            If[bouncePts[[j]] <= nS,
              {RGBColor[1.0, 0.85, 0.1], Sphere[
                {xArr[[bouncePts[[j]]]], yArr[[bouncePts[[j]]]], zArr[[bouncePts[[j]]]]}, 0.045]},
              {}],
            {j, Length[bouncePts]}],
          {RGBColor[1.0, 0.6, 0.0], Sphere[{xArr[[1]], yArr[[1]], zArr[[1]]}, 0.05]},
          {White, Sphere[{xArr[[nS]], yArr[[nS]], zArr[[nS]]}, 0.06]}
        },
        Background -> Black, Boxed -> False, Axes -> False,
        ViewPoint -> {2.4, -2.4, 0.6},
        ImageSize -> 460,
        PlotRange -> {MinMax[xArr] + {-0.2, 0.2}, MinMax[yArr] + {-0.2, 0.2}, zRange + {-0.2, 0.2}}]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, $MagFrameRate];
    nFrames
  ]


(* ========================================================
   MULTI MODE
   ======================================================== *)

AnimateMulti[model_Association, outGif_String] :=
  Module[{proton, alphaP, electron, tArr, nPts, nFrames, rMax, frames},
    proton = model["proton"]; alphaP = model["alpha"]; electron = model["electron"];
    tArr = model["t"]; nPts = Length[tArr]; nFrames = $MagFrames;
    rMax = Max[proton["r"], alphaP["r"], 1.2 * electron["r"], 0.3];

    frames = Table[
      With[{nS = Max[2, Round[k * nPts / nFrames]]},
        Graphics[{
          {RGBColor[0.25, 0.55, 1.0], AbsoluteThickness[1.6],
           Line[Transpose[{proton["x"][[;; nS]], proton["y"][[;; nS]]}]]},
          {RGBColor[0.3, 0.9, 0.4], AbsoluteThickness[1.6],
           Line[Transpose[{alphaP["x"][[;; nS]], alphaP["y"][[;; nS]]}]]},
          {RGBColor[1.0, 0.3, 0.3], AbsoluteThickness[1.6],
           Line[Transpose[{electron["x"][[;; nS]], electron["y"][[;; nS]]}]]},
          {White, PointSize[0.02],
           Point[{proton["x"][[nS]], proton["y"][[nS]]}],
           Point[{alphaP["x"][[nS]], alphaP["y"][[nS]]}],
           Point[{electron["x"][[nS]], electron["y"][[nS]]}]},
          {GrayLevel[0.8], FontSize -> 9,
           Text["proton",   {rMax * 1.15,  0.15}],
           Text["alpha",    {rMax * 1.15, -0.15}],
           Text["electron", {rMax * 1.15, -0.45}]}
        },
        Background -> Black,
        PlotRange -> 1.35 * rMax * {{-1, 1.6}, {-1, 1}},
        ImageSize -> 460, Frame -> False, Axes -> False]
      ],
      {k, nFrames}
    ];
    ExportGIF[frames, outGif, $MagFrameRate];
    nFrames
  ]

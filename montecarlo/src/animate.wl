(* ========================================================
   montecarlo/src/animate.wl — Spin-grid and M(T) GIF animations
   ======================================================== *)


(* RenderGridFrame — spin +1 = white, spin -1 = black. (grid+1)/2 maps
   {-1,1} to {0,1} so GrayLevel can render it directly. *)
RenderGridFrame[grid_List, title_String] :=
  ArrayPlot[(grid + 1) / 2,
    ColorFunction -> GrayLevel, ColorFunctionScaling -> False,
    PlotLabel  -> Style[title, White, 12],
    Background -> Black,
    ImageSize  -> {420, 420},
    Frame      -> False,
    Mesh       -> None
  ];

(* RenderMCurveFrame — M(T) traced left-to-right as the sweep advances,
   a moving cursor at the current point, and a dashed red line at T_c. *)
RenderMCurveFrame[TVals_List, MVals_List, upToIdx_Integer, Tc_?NumericQ] :=
  Module[{pts},
    pts = Transpose[{TVals[[1 ;; upToIdx]], MVals[[1 ;; upToIdx]]}];
    Graphics[
      {
        {RGBColor[0.2, 0.5, 0.9], Thickness[0.004], Line[pts]},
        {Dashed, Red, Thickness[0.003], Line[{{Tc, -1.0}, {Tc, 1.0}}]},
        {Yellow, PointSize[0.02], Point[Last[pts]]}
      },
      PlotRange  -> {{Min[TVals], Max[TVals]}, {-1.0, 1.0}},
      Background -> Black,
      ImageSize  -> {420, 200},
      Frame      -> True,
      FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["T", White, 10], Style["M", White, 10]}
    ]
  ];

(* AnimateSweep — two-panel: spin grid on top, M(T) curve below. *)
AnimateSweep[sweepResult_Association, Tc_?NumericQ, outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{grids, TVals, MVals, nRows, indices, frames},
    grids  = sweepResult["grids"];
    TVals  = sweepResult["T"];
    MVals  = sweepResult["M"];
    nRows  = Length[grids];
    indices = DeleteDuplicates[Round[Subdivide[1, nRows, Min[nFrames, nRows] - 1]]];

    Print["  Rendering ", Length[indices], " sweep frames..."];
    frames = Table[
      Module[{idx = indices[[k]], title, gridPlot, curvePlot},
        title = "T = " <> ToString[NumberForm[TVals[[idx]], {4, 3}]] <>
                "   |M| = " <> ToString[NumberForm[Abs[MVals[[idx]]], {4, 3}]];
        gridPlot  = RenderGridFrame[grids[[idx]], title];
        curvePlot = RenderMCurveFrame[TVals, MVals, idx, Tc];
        GraphicsColumn[{gridPlot, curvePlot}, Background -> Black, Spacings -> 0.3]
      ],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, 10];
    Length[frames]
  ];

(* AnimateCritical — single panel, spin grid at fixed T = T_c. *)
AnimateCritical[critResult_Association, Tc_?NumericQ, outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{grids, nRows, indices, frames},
    grids = critResult["grids"];
    nRows = Length[grids];
    indices = DeleteDuplicates[Round[Subdivide[1, nRows, Min[nFrames, nRows] - 1]]];

    Print["  Rendering ", Length[indices], " critical frames..."];
    frames = Table[
      RenderGridFrame[grids[[indices[[k]]]],
        "T = T_c = " <> ToString[NumberForm[Tc, {4, 3}]] <> "   sweep " <> ToString[indices[[k]]]],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, 10];
    Length[frames]
  ];

(* AnimateQuench — single panel, spin grid coarsening from random noise
   toward large domains. *)
AnimateQuench[quenchResult_Association, TCold_?NumericQ, outGIF_String, Optional[nFrames_Integer, 60]] :=
  Module[{grids, nRows, indices, frames},
    grids = quenchResult["grids"];
    nRows = Length[grids];
    indices = DeleteDuplicates[Round[Subdivide[1, nRows, Min[nFrames, nRows] - 1]]];

    Print["  Rendering ", Length[indices], " quench frames..."];
    frames = Table[
      RenderGridFrame[grids[[indices[[k]]]],
        "T_cold = " <> ToString[NumberForm[TCold, {3, 2}]] <> "   sweep " <> ToString[indices[[k]]]],
      {k, Length[indices]}
    ];
    ExportGIF[frames, outGIF, 10];
    Length[frames]
  ];

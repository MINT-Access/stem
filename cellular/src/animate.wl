(* ========================================================
   src/animate.wl — Cellular automata animation export

   AnimateCellular[grid3D, cfg, outPath]

   For Game of Life (nRows > 1):
     Renders one ArrayPlot frame per generation and exports
     an animated GIF.  Cell size is derived from canvas size
     and grid dimensions — not hardcoded.

   For Rule 110 (nRows == 1):
     The spacetime diagram (all generations stacked vertically)
     is exported as a PNG and as a single-frame GIF for pipeline
     consistency.  The full spacetime view is necessary because
     the Rule 110 triangle pattern is only legible as a whole.
   ======================================================== *)


(* CellularFrame
   Renders one generation of a 2D grid as an ArrayPlot.
   Live cells are white, dead cells are black (high contrast). *)

CellularFrame[genGrid_?MatrixQ, cellPx_Integer] :=
  ArrayPlot[
    genGrid,
    ColorRules -> {0 -> Black, 1 -> White},
    ImageSize  -> cellPx * Reverse[Dimensions[genGrid]],
    Frame      -> None,
    PlotRangePadding -> None
  ]


(* AnimateCellular
   Dispatches on grid shape:
     nRows > 1  → animated GIF (one frame per generation)
     nRows == 1 → spacetime PNG + single-frame GIF            *)

AnimateCellular[grid3D_List, cfg_Association, outPath_String] :=
  Module[{nGen, nRows, nCols, fps, width, height, cellPx,
          frames, spacetime, spacetimePlot, pngPath},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    fps    = GetCfg[cfg, {"animation","fps"},    10];
    width  = GetCfg[cfg, {"animation","width"},  480];
    height = GetCfg[cfg, {"animation","height"}, 480];

    (* Compute cell pixel size to fill the configured canvas *)
    cellPx = Max[1, Floor[Min[width / nCols, height / nRows]]];

    If[nRows === 1,

      (* ── Rule 110: spacetime diagram ── *)
      Print["  Building Rule 110 spacetime diagram (", nGen, " gen x ", nCols, " cells)..."];
      STEMSay["Building Rule 110 spacetime diagram"];

      spacetime = grid3D[[All, 1, All]];   (* {nGen, nCols} matrix *)
      spacetimePlot = ArrayPlot[
        spacetime,
        ColorRules -> {0 -> White, 1 -> Black},
        ImageSize  -> {cellPx * nCols, cellPx * nGen},
        Frame      -> None,
        PlotRangePadding -> None
      ];

      pngPath = StringReplace[outPath, ".gif" -> "_spacetime.png"];
      EnsureDir[pngPath];
      Export[pngPath, spacetimePlot, "PNG"];
      Print["  Spacetime PNG — ", pngPath];

      ExportGIF[{spacetimePlot}, outPath, fps],

      (* ── Game of Life: animated GIF ── *)
      Print["  Rendering ", nGen, " frames (", nRows, "x", nCols,
            " grid, ", cellPx, " px/cell)..."];
      STEMSay["Rendering " <> ToString[nGen] <> " frames"];

      frames = Table[
        (If[Mod[g, 50] === 1 && g > 1,
           STEMSay["Rendered " <> ToString[g-1] <> " of " <>
                   ToString[nGen] <> " frames"]];
         CellularFrame[grid3D[[g]], cellPx]),
        {g, 1, nGen}
      ];

      ExportGIF[frames, outPath, fps]
    ]
  ]

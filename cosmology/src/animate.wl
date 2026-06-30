(* cosmology/src/animate.wl — CMB plots and animations *)

(* Export a PNG of the CMB power spectrum with acoustic peaks marked. *)
AnimateSpectrum[lArr_List, dlArr_List, peakData_Association,
                lMax_Integer, outPNG_String] :=
  Module[{peakIdxs, logLArr, accentPts, plt},
    peakIdxs = peakData["peakIdxs"];
    logLArr  = N @ Log10[lArr];
    accentPts = Map[
      Function[i,
        {Directive[Red, PointSize[0.018]],
         Point[{Log10[lArr[[i]]], dlArr[[i]]}],
         Text[
           Style["Peak " <> ToString[Position[peakIdxs, i][[1, 1]]], 8, Red],
           {Log10[lArr[[i]]], dlArr[[i]] + 200}
         ]}
      ],
      Take[peakIdxs, Min[3, Length[peakIdxs]]]
    ];

    plt = Show[
      ListLinePlot[
        Transpose[{logLArr, dlArr}],
        PlotStyle  -> {Thickness[0.0018], RGBColor[0.18, 0.42, 0.78]},
        PlotRange  -> {{Log10[2], Log10[lMax]}, {0, Automatic}},
        Frame      -> True,
        FrameLabel -> {"log\[ThinSpace]\!\(\*SubscriptBox[\(10\), \(l\)]\)",
                       "\!\(\*SubscriptBox[\(D\), \(l\)]\)  [\[Mu]\!\(\*SuperscriptBox[\(K\), \(2\)]\)]"},
        PlotLabel  -> Style["CMB Temperature Power Spectrum", 14, Bold],
        GridLines  -> Automatic,
        Background -> White,
        ImageSize  -> {600, 360}
      ],
      Graphics[Flatten[accentPts]]
    ];
    Export[outPNG, plt, "PNG"];
    Print["  PNG: ", outPNG]
  ];

(* Render a 32-frame GIF of the Hilbert traversal sweeping across the CMB sky map.
   False-colour: cold=blue, mean=white, hot=red. *)
AnimateSky[skyModel_Association, outGIF_String] :=
  Module[{mapT, traversal, nPix, actualN, nGIFFrames = 32,
          dispDataRGB, gCoords, frameUpTo, gifFrames},
    mapT      = skyModel["mapT"];
    traversal = skyModel["traversal"];
    nPix      = skyModel["nPix"];
    actualN   = skyModel["actualN"];

    dispDataRGB = Map[
      Function[row,
        Map[Function[t,
          With[{t1 = Clip[N[t], {0.0, 1.0}]},
            If[t1 < 0.5,
              {2.0*t1,       2.0*t1,       1.0},
              {1.0,    2.0*(1.0-t1), 2.0*(1.0-t1)}
            ]
          ]
        ], row]
      ],
      Reverse @ N[(mapT - Min[mapT]) / Max[Max[mapT] - Min[mapT], 1.0*^-10]]
    ];

    gCoords   = Map[{#[[1]] - 0.5, actualN - #[[2]] + 0.5} &, traversal];
    frameUpTo = Table[Max[1, Round[k * nPix / nGIFFrames]], {k, nGIFFrames}];

    gifFrames = Table[
      With[{upTo = frameUpTo[[k]]},
        Graphics[{
          Raster[dispDataRGB, {{0, 0}, {actualN, actualN}}],
          {Opacity[0.75], RGBColor[1.0, 0.85, 0.0], Thin,
           Line[gCoords[[1 ;; upTo]]]},
          {White, Disk[gCoords[[upTo]], 0.65]}
        },
        PlotRange    -> {{0, actualN}, {0, actualN}},
        ImagePadding -> None,
        AspectRatio  -> 1,
        ImageSize    -> 256]
      ],
      {k, nGIFFrames}
    ];

    ExportGIF[gifFrames, outGIF, 10];
    STEMDescribeGIF[outGIF, nGIFFrames, 10]
  ];

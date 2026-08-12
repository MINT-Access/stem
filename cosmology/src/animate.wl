(* cosmology/src/animate.wl — CMB plots and animations *)

(* Sane bounds on GIF playback frame rate — see AnimateSky for how these
   keep the sky-traversal animation's playback duration in sync with the
   accompanying WAV without forcing an absurdly fast or glacial frame
   rate at the sky_resolution extremes. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;

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

(* Render a GIF of the Hilbert traversal sweeping across the CMB sky map,
   with the GIF's PLAYBACK DURATION matched to the accompanying WAV's
   duration (nPix * noteDur, both already carried on skyModel from
   SonifySkyMap's inputs) so the sweep animation and its sonification
   stay in sync instead of the GIF racing through the whole traversal in
   a few seconds while the audio plays for the full Hilbert-curve length.

   frameBudget is a RENDER BUDGET, not a literal frame count: frameRate
   is solved as frameBudget/targetDuration and then clamped to
   [$MinAnimationFps, $MaxAnimationFps] (2-30 fps) so a small sky_resolution
   (short WAV) doesn't demand a strobing frame rate and a large one (long
   WAV) doesn't demand an implausibly slow one — the frame COUNT is what
   flexes at the clamp boundary (recomputed as Round[frameRate *
   targetDuration]) so actual playback duration always equals
   targetDuration exactly.

   False-colour: cold=blue, mean=white, hot=red. *)
AnimateSky[skyModel_Association, outGIF_String, frameBudget_Integer:32] :=
  Module[{mapT, traversal, nPix, actualN, noteDur, targetDuration,
          frameRate, nGIFFrames,
          dispDataRGB, gCoords, frameUpTo, gifFrames},
    mapT      = skyModel["mapT"];
    traversal = skyModel["traversal"];
    nPix      = skyModel["nPix"];
    actualN   = skyModel["actualN"];
    noteDur   = skyModel["noteDur"];

    targetDuration = N[nPix * noteDur];
    frameRate  = Clip[frameBudget / targetDuration,
      {$MinAnimationFps, $MaxAnimationFps}];
    nGIFFrames = Max[2, Round[frameRate * targetDuration]];

    Print["  Rendering ", nGIFFrames, " frames at ", FmtN[frameRate, 3],
          " fps (", FmtN[nGIFFrames / frameRate, 3],
          "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."];

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

    ExportGIF[gifFrames, outGIF, frameRate];
    STEMDescribeGIF[outGIF, nGIFFrames, frameRate]
  ];

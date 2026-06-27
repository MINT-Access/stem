(* ========================================================
   signal/animate.wl — Signal visualisation

   AnimateSignal[analysis, cfg, outDir]

   Produces:
     {mode}_animation.gif   — 10-frame GIF, each frame a 3-panel view
                              zoomed to a different time window
     {mode}_waveform.png    — full time-domain: clean + noisy overlay
     {mode}_spectrum.png    — frequency domain: spectra + detected peaks
     {mode}_recovery.png    — full time-domain: clean + recovered overlay

   Panel layout (per frame):
     Left  — time domain: clean (dark blue) + noisy (orange)
     Centre — power spectrum (log scale), peaks marked
     Right  — time domain: clean (dark blue) + recovered (green)
   ======================================================== *)


(* PlotDecimate
   Take at most maxPts evenly spaced samples from list for plot performance. *)

PlotDecimate[list_List, maxPts_Integer : 2000] :=
  Module[{n = Length[list], step},
    If[n <= maxPts, list,
      step = Max[1, Floor[n / maxPts]];
      list[[1 ;; ;; step]]
    ]
  ]


(* SpectrumPlot
   One-sided power spectrum on a log10 scale.
   Shows clean (blue) + noisy (orange), marks detected peaks with red dots.
   Limits x-axis to maxFreqHz for readability. *)

SpectrumPlot[analysis_Association, maxFreqHz_?NumericQ,
             opts : OptionsPattern[ListLinePlot]] :=
  Module[{freqAxis, powClean, powNoisy, nHalf, maxBin,
          peaks, peakPts,
          cleanSub, noisySub, freqSub,
          logFloor},

    freqAxis = analysis["freq_axis"];
    powClean = analysis["spectrum_clean"];
    powNoisy = analysis["spectrum_noisy"];
    peaks    = analysis["recovered_frequencies"];

    nHalf  = Length[freqAxis];
    maxBin = Min[nHalf, 1 + Round[maxFreqHz * (nHalf - 1) / freqAxis[[-1]]]];

    freqSub  = freqAxis[[1 ;; maxBin]];
    cleanSub = Log[10, Max[powClean[[1 ;; maxBin]], 1*^-12]];
    noisySub = Log[10, Max[#, 1*^-12] & /@ powNoisy[[1 ;; maxBin]]];

    peakPts = If[Length[peaks] > 0,
      Map[Function[pf,
        Module[{idx = Nearest[freqSub -> "Index", pf[[1]]][[1]]},
          {pf[[1]], noisySub[[idx]]}
        ]], peaks],
      {}];

    ListLinePlot[
      {PlotDecimate[cleanSub, 1500], PlotDecimate[noisySub, 1500]},
      DataRange    -> {freqSub[[1]], freqSub[[-1]]},
      PlotStyle    -> {Directive[RGBColor[0.2, 0.4, 0.8], Opacity[0.6]],
                       Directive[RGBColor[0.9, 0.5, 0.1], Opacity[0.8]]},
      Frame        -> True,
      FrameLabel   -> {{"log₁₀ power", None}, {"Frequency (Hz)", None}},
      PlotLabel    -> "Power spectrum",
      ImageSize    -> {320, 260},
      Epilog       -> If[Length[peakPts] > 0,
        {RGBColor[0.8, 0.1, 0.1], PointSize[0.025], Point[peakPts]},
        {}],
      GridLines    -> Automatic,
      opts
    ]
  ]


(* TimeDomainFrame
   Returns a {left, right} pair of ListLinePlot objects for the time panels,
   covering the sample range startIdx..endIdx.
   leftSeries  — {clean, comparison1} to overlay in left panel
   rightSeries — {clean, comparison2} to overlay in right panel *)

TimeDomainPanels[clean_List, compare1_List, compare2_List,
                 startIdx_Integer, endIdx_Integer, sr_?NumericQ] :=
  Module[{tStart, tEnd, c, s1, s2, rng},
    tStart = N[startIdx - 1] / sr;
    tEnd   = N[endIdx   - 1] / sr;
    rng    = startIdx ;; endIdx;
    c  = PlotDecimate[clean[[rng]],    1000];
    s1 = PlotDecimate[compare1[[rng]], 1000];
    s2 = PlotDecimate[compare2[[rng]], 1000];

    {
      ListLinePlot[{c, s1},
        DataRange  -> {tStart, tEnd},
        PlotStyle  -> {Directive[RGBColor[0.2, 0.4, 0.8], Thick],
                       Directive[RGBColor[0.9, 0.5, 0.1], Opacity[0.7]]},
        Frame      -> True,
        FrameLabel -> {{"Amplitude", None}, {"Time (s)", None}},
        PlotLabel  -> "Waveform (clean + noisy)",
        ImageSize  -> {300, 260}],

      ListLinePlot[{c, s2},
        DataRange  -> {tStart, tEnd},
        PlotStyle  -> {Directive[RGBColor[0.2, 0.4, 0.8], Thick],
                       Directive[RGBColor[0.2, 0.7, 0.3], Opacity[0.85]]},
        Frame      -> True,
        FrameLabel -> {{"Amplitude", None}, {"Time (s)", None}},
        PlotLabel  -> "Recovery (clean + recovered)",
        ImageSize  -> {300, 260}]
    }
  ]


AnimateSignal[analysis_Association, cfg_Association, outDir_String] :=
  Module[{mode, clean, noisy, recovered, sr, dur, freqs,
          nSamples, nFrames, windowSize,
          fps, width, height, maxFreqHz,
          frames, wStart, wEnd, tdPanels, specP,
          frame, waveformPath, spectrumPath, recoveryPath, gifPath},

    mode      = analysis["mode"];
    clean     = analysis["clean"];
    noisy     = analysis["noisy"];
    recovered = analysis["recovered"];
    sr        = analysis["sample_rate"];
    dur       = analysis["duration"];
    freqs     = analysis["known_frequencies"];

    nSamples  = Length[clean];
    nFrames   = 10;
    fps       = GetCfg[cfg, {"animation","fps"},    10];
    width     = GetCfg[cfg, {"animation","width"},  800];
    height    = GetCfg[cfg, {"animation","height"}, 400];

    (* Max frequency to display in spectrum *)
    maxFreqHz = Switch[mode,
      "sweep", Max[freqs] * 1.1,
      _,       Max[freqs] * 3.0
    ];
    maxFreqHz = Min[maxFreqHz, sr / 2];

    (* ── Static PNGs (full signal) ── *)
    waveformPath  = FileNameJoin[{outDir, mode <> "_waveform.png"}];
    spectrumPath  = FileNameJoin[{outDir, mode <> "_spectrum.png"}];
    recoveryPath  = FileNameJoin[{outDir, mode <> "_recovery.png"}];
    gifPath       = FileNameJoin[{outDir, mode <> "_animation.gif"}];

    EnsureDir[waveformPath];

    Print["  Exporting waveform PNG..."];
    Export[waveformPath,
      ListLinePlot[
        {PlotDecimate[clean, 3000], PlotDecimate[noisy, 3000]},
        DataRange  -> {0, dur},
        PlotStyle  -> {Directive[RGBColor[0.2, 0.4, 0.8], Thick],
                       Directive[RGBColor[0.9, 0.5, 0.1], Opacity[0.6]]},
        Frame      -> True,
        FrameLabel -> {{"Amplitude", None}, {"Time (s)", None}},
        PlotLabel  -> "Waveform: clean (blue) + noisy (orange)",
        ImageSize  -> {width, height}],
      "PNG"];

    Print["  Exporting spectrum PNG..."];
    Export[spectrumPath,
      SpectrumPlot[analysis, maxFreqHz, ImageSize -> {width, height}],
      "PNG"];

    Print["  Exporting recovery PNG..."];
    Export[recoveryPath,
      ListLinePlot[
        {PlotDecimate[clean, 3000], PlotDecimate[recovered, 3000]},
        DataRange  -> {0, dur},
        PlotStyle  -> {Directive[RGBColor[0.2, 0.4, 0.8], Thick],
                       Directive[RGBColor[0.2, 0.7, 0.3], Opacity[0.85]]},
        Frame      -> True,
        FrameLabel -> {{"Amplitude", None}, {"Time (s)", None}},
        PlotLabel  -> "Recovery: clean (blue) + recovered (green)",
        ImageSize  -> {width, height}],
      "PNG"];

    (* ── Animated GIF: 10 frames, each a 3-panel view of one time window ── *)
    Print["  Rendering ", nFrames, " GIF frames..."];
    windowSize = Floor[nSamples / nFrames];

    specP = SpectrumPlot[analysis, maxFreqHz];

    frames = Table[
      wStart = (f - 1) * windowSize + 1;
      wEnd   = Min[f * windowSize, nSamples];
      tdPanels = TimeDomainPanels[clean, noisy, recovered, wStart, wEnd, sr];
      GraphicsGrid[{{tdPanels[[1]], specP, tdPanels[[2]]}},
        ImageSize -> {width, height},
        Spacings  -> 4],
      {f, 1, nFrames}
    ];

    ExportGIF[frames, gifPath, fps];

    Print["  Waveform PNG  — ", waveformPath];
    Print["  Spectrum PNG  — ", spectrumPath];
    Print["  Recovery PNG  — ", recoveryPath];
    STEMDescribeGIF[gifPath, nFrames, fps]
  ]

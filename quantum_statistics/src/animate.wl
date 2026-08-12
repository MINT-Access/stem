(* ========================================================
   quantum_statistics/src/animate.wl — Visualisations for all three modes

   Both spectrum and temperature modes plot Log10[n] on the vertical
   axis, not n itself — Bose-Einstein's occupation number spans some
   30-50 orders of magnitude across each mode's default sweep range
   (verified directly: ~2.5e-34 to ~25 across the spectrum sweep at
   T=300K; ~4e-51 to ~3.8 across the temperature sweep), so a linear
   axis would show nothing but a flat line at zero except at one
   extreme. Log10 is the only honest choice for either plot.
   ======================================================== *)


(* Sane bounds on GIF playback frame rate -- see each AnimateX function
   below for how these keep GIF playback duration in sync with the
   accompanying WAV's real length (spoken intro/outro included) without
   forcing an absurdly fast or glacial frame rate at the extremes. *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* ========================================================
   MODE 1: spectrum — three curves (Log10 n) vs energy, fixed T
   ======================================================== *)

QsSafeLog10[vals_List] := Log10[Clip[Replace[vals, _Missing -> 0.0, {1}], {1.0*^-300, Infinity}]];

RenderSpectrumFrame[model_Association, upTo_Integer] :=
  Module[{eps, logBE, logFD, logMB, yMin, yMax},
    eps = model["epsArr"];
    logBE = QsSafeLog10[model["beArr"]]; logFD = QsSafeLog10[model["fdArr"]]; logMB = QsSafeLog10[model["mbArr"]];
    yMin = Min[Select[Join[logBE, logFD, logMB], # > -300 &]] - 1.0;
    yMax = Max[Join[logBE, logFD, logMB]] + 1.0;
    Graphics[
      {
        {RGBColor[0.3, 0.6, 1.0], Thickness[0.003], Line[Transpose[{eps, logBE}][[1 ;; upTo]]]},
        {RGBColor[0.9, 0.5, 0.1], Thickness[0.003], Line[Transpose[{eps, logFD}][[1 ;; upTo]]]},
        {RGBColor[0.5, 0.85, 0.3], Thickness[0.0025], Dashed, Line[Transpose[{eps, logMB}][[1 ;; upTo]]]},
        Text[Style["Bose-Einstein", White, 10, RGBColor[0.3, 0.6, 1.0]], {eps[[upTo]], logBE[[upTo]] + 0.6}],
        Text[Style["Fermi-Dirac", White, 10, RGBColor[0.9, 0.5, 0.1]], {eps[[upTo]], logFD[[upTo]] - 0.8}],
        Text[Style["Maxwell-Boltzmann", White, 10, RGBColor[0.5, 0.85, 0.3]], {eps[[upTo]], logMB[[upTo]] + 1.2}]
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["energy \[Epsilon] (eV)", White, 10], Style["log10(occupation n)", White, 10]},
      PlotLabel  -> Style["Occupation Number vs Energy, T=" <> ToString[NumberForm[model["T"], {5, 0}]] <> " K", White, 12],
      PlotRange  -> {{model["epsMin"], model["epsMax"]}, {yMin, yMax}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ]
  ];

(* AnimateSpectrum — targetDuration is the accompanying WAV's real,
   final length in seconds (spoken intro + pause + main sweep audio),
   the same value STEMDescribeWAV reports; nFrames is a RENDER BUDGET,
   not a literal frame count -- frameRate is solved as
   nFrames/targetDuration and clamped to [$MinAnimationFps,
   $MaxAnimationFps] so a short WAV doesn't demand a strobing frame
   rate and a long one (spoken intros can run several seconds, on top
   of an 8s default sweep) doesn't demand an implausibly slow one; the
   frame COUNT (Round[frameRate*targetDuration]) is what flexes at the
   clamp boundary so playback duration lands on targetDuration exactly.
   No DeleteDuplicates on indices: once actualNFrames exceeds nSteps, a
   repeated index just holds that frame on screen a little longer,
   which is fine -- deleting repeats would shrink the frame count below
   actualNFrames and pull playback back out of sync. Returns
   {actualNFrames, frameRate} for STEMDescribeGIF. *)
AnimateSpectrum[model_Association, outGif_String, outPng_String,
               targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, frameRate, actualNFrames, indices, frames, eps, logBE, logFD, logMB, yMin, yMax, staticPlt},
    nSteps  = model["nSteps"];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    frames  = RenderSpectrumFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, frameRate];

    eps = model["epsArr"];
    logBE = QsSafeLog10[model["beArr"]]; logFD = QsSafeLog10[model["fdArr"]]; logMB = QsSafeLog10[model["mbArr"]];
    yMin = Min[Select[Join[logBE, logFD, logMB], # > -300 &]] - 1.0;
    yMax = Max[Join[logBE, logFD, logMB]] + 1.0;
    staticPlt = Graphics[
      {
        {RGBColor[0.1, 0.4, 0.85], Thickness[0.0032], Line[Transpose[{eps, logBE}]]},
        {RGBColor[0.85, 0.4, 0.05], Thickness[0.0032], Line[Transpose[{eps, logFD}]]},
        {RGBColor[0.25, 0.65, 0.15], Thickness[0.0028], Dashed, Line[Transpose[{eps, logMB}]]},
        Text[Style["Bose-Einstein", 11, RGBColor[0.1, 0.4, 0.85]], {eps[[-1]] * 0.8, logBE[[-1]] + 0.8}],
        Text[Style["Fermi-Dirac", 11, RGBColor[0.85, 0.4, 0.05]], {eps[[-1]] * 0.8, logFD[[-1]] - 1.0}],
        Text[Style["Maxwell-Boltzmann (classical)", 11, RGBColor[0.25, 0.65, 0.15]], {eps[[-1]] * 0.55, logMB[[-1]] + 1.5}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"energy \[Epsilon] (eV)", "log10(occupation n)"},
      PlotLabel  -> Style["Occupation Number vs Energy, T=" <> ToString[NumberForm[model["T"], {5, 0}]] <> " K", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{model["epsMin"], model["epsMax"]}, {yMin, yMax}},
      ImageSize  -> {640, 400}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];


(* ========================================================
   MODE 2: temperature — three curves (Log10 n) vs Log10(T), fixed eps
   ======================================================== *)

RenderTemperatureFrame[model_Association, upTo_Integer] :=
  Module[{logT, logBE, logFD, logMB, yMin, yMax},
    logT = Log10[model["TArr"]];
    logBE = QsSafeLog10[model["beArr"]]; logFD = QsSafeLog10[model["fdArr"]]; logMB = QsSafeLog10[model["mbArr"]];
    yMin = Min[Select[Join[logBE, logFD, logMB], # > -300 &]] - 1.0;
    yMax = Max[Join[logBE, logFD, logMB]] + 1.0;
    Graphics[
      {
        {RGBColor[0.3, 0.6, 1.0], Thickness[0.003], Line[Transpose[{logT, logBE}][[1 ;; upTo]]]},
        {RGBColor[0.9, 0.5, 0.1], Thickness[0.003], Line[Transpose[{logT, logFD}][[1 ;; upTo]]]},
        {RGBColor[0.5, 0.85, 0.3], Thickness[0.0025], Dashed, Line[Transpose[{logT, logMB}][[1 ;; upTo]]]}
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(T / K)", White, 10], Style["log10(occupation n)", White, 10]},
      PlotLabel  -> Style["Occupation vs Temperature, \[Epsilon]=" <> ToString[NumberForm[model["epsRef"], {3, 2}]] <> " eV", White, 12],
      PlotRange  -> {{Log10[model["TMin"]], Log10[model["TMax"]]}, {yMin, yMax}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ]
  ];

(* AnimateTemperature — same targetDuration/nFrames-budget contract as
   AnimateSpectrum above (see that docstring for the full rationale). *)
AnimateTemperature[model_Association, outGif_String, outPng_String,
                   targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, frameRate, actualNFrames, indices, frames, logT, logBE, logFD, logMB, yMin, yMax, staticPlt},
    nSteps  = model["nSteps"];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    frames  = RenderTemperatureFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, frameRate];

    logT = Log10[model["TArr"]];
    logBE = QsSafeLog10[model["beArr"]]; logFD = QsSafeLog10[model["fdArr"]]; logMB = QsSafeLog10[model["mbArr"]];
    yMin = Min[Select[Join[logBE, logFD, logMB], # > -300 &]] - 1.0;
    yMax = Max[Join[logBE, logFD, logMB]] + 1.0;
    staticPlt = Graphics[
      {
        {RGBColor[0.1, 0.4, 0.85], Thickness[0.0032], Line[Transpose[{logT, logBE}]]},
        {RGBColor[0.85, 0.4, 0.05], Thickness[0.0032], Line[Transpose[{logT, logFD}]]},
        {RGBColor[0.25, 0.65, 0.15], Thickness[0.0028], Dashed, Line[Transpose[{logT, logMB}]]},
        Text[Style["Bose-Einstein", 11, RGBColor[0.1, 0.4, 0.85]], {Log10[model["TMax"]] * 0.7, yMax - 1.0}],
        Text[Style["Fermi-Dirac", 11, RGBColor[0.85, 0.4, 0.05]], {Log10[model["TMax"]] * 0.7, yMax - 2.2}],
        Text[Style["Maxwell-Boltzmann", 11, RGBColor[0.25, 0.65, 0.15]], {Log10[model["TMax"]] * 0.7, yMax - 3.4}],
        Text[Style["converge \[LongLeftArrow]", 10, Gray], {Log10[model["TMin"]] + 0.3, yMin + 1.0}],
        Text[Style["\[LongRightArrow] diverge", 10, Gray], {Log10[model["TMax"]] - 0.3, yMax - 0.3}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"log10(T / K)", "log10(occupation n)"},
      PlotLabel  -> Style["Occupation vs Temperature, \[Epsilon]=" <> ToString[NumberForm[model["epsRef"], {3, 2}]] <> " eV, \[Mu]=0", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{Log10[model["TMin"]], Log10[model["TMax"]]}, {yMin, yMax}},
      ImageSize  -> {640, 400}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];


(* ========================================================
   MODE 3: fermi_sea — FD(eps) at several T, step sharpening/blurring
   ======================================================== *)

$qsFermiSeaColors = {
  RGBColor[0.15, 0.3, 0.9], RGBColor[0.2, 0.55, 0.9], RGBColor[0.25, 0.75, 0.6],
  RGBColor[0.8, 0.65, 0.15], RGBColor[0.9, 0.4, 0.15], RGBColor[0.85, 0.15, 0.15]
};

RenderFermiSeaFrame[model_Association, TIdx_Integer] :=
  Module[{eps, fd, T, color},
    eps = model["epsArr"]; fd = model["fdByT"][[TIdx]]; T = model["TArr"][[TIdx]];
    color = $qsFermiSeaColors[[Mod[TIdx - 1, Length[$qsFermiSeaColors]] + 1]];
    Graphics[
      {
        {Dashed, Gray, Line[{{model["muFermi"], 0}, {model["muFermi"], 1.05}}]},
        {color, Thickness[0.004], Line[Transpose[{eps, fd}]]},
        Text[Style["\[Mu] (Fermi energy)", White, 9, Gray], {model["muFermi"], 1.12}]
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["energy \[Epsilon] (eV)", White, 10], Style["n_FD(\[Epsilon])", White, 10]},
      PlotLabel  -> Style["Fermi Sea, T=" <> ToString[NumberForm[T, {7, 1}]] <> " K", White, 12],
      PlotRange  -> {{model["epsMin"], model["epsMax"]}, {-0.05, 1.2}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ]
  ];

(* AnimateFermiSea — same targetDuration/nFrames-budget contract as
   AnimateSpectrum (see its docstring). baseIndices lays out the
   original pacing -- the coldest (sharpest) and warmest (most blurred)
   T steps each held twice before/after the full sweep -- as a sequence
   of T-array indices; sampleIdx then resamples that sequence to
   actualNFrames slots (repeats hold a frame longer, same "no
   DeleteDuplicates" idiom as the other two modes) so playback duration
   lands on targetDuration exactly while keeping the head/tail dwell. *)
AnimateFermiSea[model_Association, outGif_String, outPng_String,
                targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{nT, baseIndices, frameRate, actualNFrames, sampleIdx, frames, staticPlt},
    nT = Length[model["TArr"]];
    (* hold first (sharpest) and last (most blurred) T steps a little longer *)
    baseIndices = Join[{1, 1}, Range[1, nT], {nT, nT}];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];
    sampleIdx = Round[Subdivide[1, Length[baseIndices], actualNFrames - 1]];
    frames = RenderFermiSeaFrame[model, baseIndices[[#]]] & /@ sampleIdx;
    ExportGIF[frames, outGif, frameRate];

    staticPlt = Graphics[
      {
        {Dashed, Gray, Line[{{model["muFermi"], 0}, {model["muFermi"], 1.05}}]},
        MapIndexed[
          Function[{fd, idx},
            {$qsFermiSeaColors[[Mod[idx[[1]] - 1, Length[$qsFermiSeaColors]] + 1]],
             Thickness[0.003], Line[Transpose[{model["epsArr"], fd}]]}
          ],
          model["fdByT"]
        ],
        Text[Style["coldest \[RightArrow] sharpest step", 10, $qsFermiSeaColors[[1]]],
             {model["muFermi"] * 0.4, 1.12}],
        Text[Style["warmest \[RightArrow] most blurred", 10, Last[$qsFermiSeaColors]],
             {model["epsMax"] * 0.75, 0.55}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"energy \[Epsilon] (eV)", "n_FD(\[Epsilon])"},
      PlotLabel  -> Style["Fermi-Dirac Step: Sharpening as T \[RightArrow] 0", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{model["epsMin"], model["epsMax"]}, {-0.05, 1.2}},
      ImageSize  -> {640, 400}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];

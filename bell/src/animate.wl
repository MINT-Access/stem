(* ========================================================
   bell/src/animate.wl — Visualisations for all three modes

   correlations: compton/sweep's "curve drawn once, marker walks along
     it" style, combined with compton/discovery's classical-vs-quantum
     overlay (both curves drawn together, quantum solid, classical
     dashed) -- a natural merge of the two idioms since this mode IS
     both a sweep and a classical/quantum comparison at once.

   chsh: no natural continuous trajectory (S is a single fixed
     reading, not something that evolves over simulated time), so
     rather than a static-only PNG (compton/discovery's precedent for
     the same reason), the GIF instead animates the CUMULATIVE partial
     sum building toward S term by term -- mirroring the audio's own
     four-note build-up (see sonify.wl), landing on the final gauge
     reading against the classical and quantum (Tsirelson) bounds.

   measurement: qubit/measurement's running-frequency-convergence style
     (a growing curve plus a dashed true-value reference line),
     PNG-only -- no natural animation content beyond the curve itself.
   ======================================================== *)


(* ========================================================
   MODE 1: correlations — quantum vs classical overlay, moving marker
   ======================================================== *)

RenderCorrelationsFrame[model_Association, upTo_Integer] :=
  Module[{delta, EQ, EC},
    delta = model["deltaDegArr"]; EQ = model["EQuantumArr"]; EC = model["EClassicalArr"];
    Graphics[
      {
        {RGBColor[0.9, 0.35, 0.1], Thickness[0.003], Line[Transpose[{delta, EQ}]]},
        {RGBColor[0.2, 0.4, 0.9], Dashed, Thickness[0.0025], Line[Transpose[{delta, EC}]]},
        {RGBColor[1.0, 0.75, 0.2], PointSize[0.02], Point[{delta[[upTo]], EQ[[upTo]]}]},
        Text[Style["quantum: Cos(\[CapitalDelta])", 10, RGBColor[0.9, 0.35, 0.1]], {90, 0.75}],
        Text[Style["classical (local hidden-variable)", 10, RGBColor[0.2, 0.4, 0.9]], {90, -0.75}]
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["angle difference \[CapitalDelta] = a - b (deg)", White, 10],
                     Style["correlation E(a,b)", White, 10]},
      PlotLabel  -> Style["Bell Correlation vs Angle Difference", White, 12],
      PlotRange  -> {{-180, 180}, {-1.1, 1.1}},
      ImageSize  -> {600, 380}, AspectRatio -> 0.5
    ]
  ];

AnimateCorrelations[model_Association, outGif_String, outPng_String,
                    Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, indices, frames, delta, EQ, EC, staticPlt},
    nSteps  = model["nSteps"];
    indices = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];
    frames  = RenderCorrelationsFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, 12];

    delta = model["deltaDegArr"]; EQ = model["EQuantumArr"]; EC = model["EClassicalArr"];
    staticPlt = Graphics[
      {
        {RGBColor[0.8, 0.25, 0.05], Thickness[0.0032], Line[Transpose[{delta, EQ}]]},
        {RGBColor[0.15, 0.3, 0.8], Dashed, Thickness[0.0028], Line[Transpose[{delta, EC}]]},
        Text[Style["quantum: Cos(\[CapitalDelta])", 11, RGBColor[0.8, 0.25, 0.05]], {90, 0.75}],
        Text[Style["classical (local hidden-variable)", 11, RGBColor[0.15, 0.3, 0.8]], {90, -0.75}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"angle difference \[CapitalDelta] = a - b (deg)", "correlation E(a,b)"},
      PlotLabel  -> Style["Bell Correlation: Quantum vs Classical Prediction", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{-180, 180}, {-1.1, 1.1}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];


(* ========================================================
   MODE 2: chsh — cumulative build-up gauge, classical/quantum bounds
   ======================================================== *)

RenderChshFrame[cumValue_?NumericQ, model_Association, stepLabel_String] :=
  Module[{qBound, cBound, range, needleColor},
    qBound = model["quantumBound"]; cBound = model["classicalBound"];
    range = 1.15 * qBound;
    needleColor = If[Abs[cumValue] > cBound, RGBColor[0.95, 0.35, 0.15], RGBColor[0.3, 0.6, 0.95]];
    Graphics[
      {
        {Gray, Thickness[0.01], Line[{{-range, 0}, {range, 0}}]},
        {Dashed, RGBColor[0.9, 0.7, 0.2], Line[{{-cBound, -0.3}, {-cBound, 0.3}}]},
        {Dashed, RGBColor[0.9, 0.7, 0.2], Line[{{cBound, -0.3}, {cBound, 0.3}}]},
        {Dashed, RGBColor[0.9, 0.4, 0.2], Line[{{-qBound, -0.3}, {-qBound, 0.3}}]},
        {Dashed, RGBColor[0.9, 0.4, 0.2], Line[{{qBound, -0.3}, {qBound, 0.3}}]},
        {needleColor, PointSize[0.05], Point[{Clip[cumValue, {-range, range}], 0}]},
        Text[Style["classical limit \[PlusMinus]2", White, 10, RGBColor[0.9, 0.7, 0.2]], {0, -0.75}],
        Text[Style["Tsirelson (quantum) limit \[PlusMinus]2.83", White, 10, RGBColor[0.9, 0.4, 0.2]], {0, 0.75}],
        Text[Style[stepLabel <> " = " <> ToString[NumberForm[cumValue, {5, 3}]], White, 13], {0, -1.05}]
      },
      Background -> Black,
      PlotRange  -> {{-range * 1.05, range * 1.05}, {-1.3, 1.3}},
      ImageSize  -> {620, 260},
      PlotLabel  -> Style["CHSH Gauge \[LongDash] building S term by term", White, 13]
    ]
  ];

AnimateChsh[model_Association, outGif_String, outPng_String] :=
  Module[{terms, labels, cum, frames, staticPlt},
    terms  = {model["Eab"], -model["Eabp"], model["Eapb"], model["Eapbp"]};
    labels = {"E(a,b)", "E(a,b)-E(a,b')", "+E(a',b)", "S = " <> ToString[NumberForm[model["S"], {5, 3}]]};
    cum = Accumulate[terms];
    frames = MapThread[RenderChshFrame[#1, model, #2] &, {cum, labels}];
    (* hold the final frame a little longer *)
    frames = Join[frames, ConstantArray[Last[frames], 3]];
    ExportGIF[frames, outGif, 2];

    staticPlt = RenderChshFrame[model["S"], model, "S"];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];


(* ========================================================
   MODE 3: measurement — running correlation converging, PNG only
   ======================================================== *)

ExportMeasurementPNG[model_Association, outPng_String] :=
  Module[{n, trialIdx, runningCorr, trueE, plt},
    n = model["nTrials"];
    trialIdx = N[Range[1, n]];
    runningCorr = model["runningCorr"];
    trueE = model["trueE"];

    plt = Graphics[
      {
        {RGBColor[0.15, 0.4, 0.85], Thickness[0.0025], Line[Transpose[{trialIdx, runningCorr}]]},
        {RGBColor[0.85, 0.2, 0.1], Dashed, Thickness[0.0022], Line[{{1, trueE}, {n, trueE}}]},
        Text[Style["true E(a,b) = " <> ToString[NumberForm[trueE, {4, 3}]], 10, RGBColor[0.85, 0.2, 0.1]],
             {n * 0.7, trueE + 0.12 * Sign[trueE + 0.001]}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"trial", "running correlation estimate"},
      PlotLabel  -> Style["Bell Measurement: Running Correlation vs Trial", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{1, n}, {-1.1, 1.1}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, plt, "PNG"];
    Print["  PNG: ", outPng]
  ];

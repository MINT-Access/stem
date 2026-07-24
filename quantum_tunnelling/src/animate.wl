(* ========================================================
   quantum_tunnelling/src/animate.wl — GIF/PNG rendering for all
   three modes

   barrier's diagram style follows compton/'s ScatterDiagramGraphics
   directly (arrows from one event, labelled with the outcome
   probabilities). sweep/energy's curve-with-moving-marker style
   follows dynamical/'s bifurcation-diagram convention. Every curve
   plot below sets AspectRatio explicitly -- compton/AGENTS.md's
   pitfall 4 documents an extreme x:y data-range aspect ratio silently
   squishing a bare Graphics[] plot into an unreadable sliver unless
   AspectRatio is set by hand; avoided here from the start rather than
   discovered again by re-rendering and looking.
   ======================================================== *)


(* ── Mode 1: barrier — transmission/reflection diagram ────────────── *)

(* BarrierDiagramGraphics — shared by both the static PNG and each GIF
   frame. `revealFrac` in [0,1]: <0.5 the incoming particle travels
   toward the barrier; >=0.5 the reflected/transmitted outcomes travel
   away from it. Pass 1.0 for the fully-revealed static PNG. *)
BarrierDiagramGraphics[model_Association, revealFrac_?NumericQ] :=
  Module[{L, incomingStart, reflectedEnd, transmittedEnd,
          incomingNow, reflectedNow, transmittedNow, barrierTop, yE, elements},
    L = Min[model["L"], 1.0];   (* visual width cap -- alpha_decay's L is ~1e-6 nm, femtometre scale *)
    barrierTop = 0.6;
    yE = 0.3;   (* incoming/outgoing particle drawn at a fixed height, purely illustrative *)
    incomingStart  = {-1.0, yE};
    reflectedEnd   = {-1.0, yE};
    transmittedEnd = {L + 1.0, yE};

    incomingNow = If[revealFrac <= 0.5,
      {-1.0 * (1.0 - 2.0 * revealFrac), yE},
      {0.0, yE}
    ];
    reflectedNow = If[revealFrac > 0.5,
      {-1.0 * (2.0 * (revealFrac - 0.5)), yE},
      {0.0, yE}
    ];
    transmittedNow = If[revealFrac > 0.5,
      {(L + 1.0) * (2.0 * (revealFrac - 0.5)), yE},
      {L, yE}
    ];

    elements = {
      (* Barrier rectangle, height representing V0 *)
      {RGBColor[0.5, 0.3, 0.1], Opacity[0.55], Rectangle[{0.0, 0.0}, {L, barrierTop}]},
      {White, FontSize -> 9, Text["V0=" <> ToString[NumberForm[model["V0"], {4, 2}]] <> "eV",
                                   {L / 2.0, barrierTop + 0.08}]},

      (* Incoming path + marker *)
      {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{incomingStart, {0.0, yE}}]},
      If[revealFrac <= 0.5,
        {RGBColor[1.0, 0.9, 0.2], PointSize[0.025], Point[incomingNow]},
        {}
      ],
      {GrayLevel[0.6], FontSize -> 9,
       Text["E=" <> ToString[NumberForm[model["E"], {4, 2}]] <> "eV", {-1.0, yE + 0.1}]},

      If[revealFrac > 0.5,
        {
          (* Reflected: bounces back, thickness proportional to Sqrt[R] *)
          {GrayLevel[0.45], Dashing[{0.01, 0.01}], Line[{{0.0, yE}, reflectedEnd}]},
          {RGBColor[0.3, 0.75, 1.0], AbsoluteThickness[1.0 + 4.0 * Sqrt[model["R"]]],
           Arrow[{{0.0, yE}, reflectedNow}]},
          {RGBColor[0.3, 0.75, 1.0], FontSize -> 9,
           Text["reflected, R=" <> ToString[NumberForm[model["R"] * 100.0, {4, 1}]] <> "%",
                {-1.0, yE - 0.15}]},

          (* Transmitted: continues through, thickness proportional to Sqrt[T] *)
          {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{{L, yE}, transmittedEnd}]},
          {RGBColor[1.0, 0.6, 0.1], AbsoluteThickness[1.0 + 4.0 * Sqrt[model["T"]]],
           Arrow[{{L, yE}, transmittedNow}]},
          {RGBColor[1.0, 0.6, 0.1], FontSize -> 9,
           Text["transmitted, T=" <> ToString[NumberForm[model["T"] * 100.0, {4, 4}]] <> "%",
                {L + 1.0, yE - 0.15}]}
        },
        {}
      ]
    };

    Graphics[elements,
      Background -> Black, PlotRange -> {{-1.6, L + 1.6}, {-0.5, barrierTop + 0.3}},
      ImageSize -> 520, Axes -> False, Frame -> False]
  ];

AnimateBarrier[model_Association, outGif_String, outPng_String,
              Optional[nFrames_Integer, 40]] :=
  Module[{frames},
    frames = Table[BarrierDiagramGraphics[model, N[k] / nFrames], {k, nFrames}];
    ExportGIF[frames, outGif, 15];
    Export[outPng, BarrierDiagramGraphics[model, 1.0], "PNG"];
    Print["  PNG: ", outPng];
    nFrames
  ];


(* ── Mode 2: sweep — T vs L, log-y, moving marker ─────────────────── *)

RenderSweepFrame[model_Association, upTo_Integer] :=
  Graphics[
    {
      {GrayLevel[0.55], Thickness[0.0022], Line[Transpose[{model["LArr"], Log10[model["TArr"]]}]]},
      {RGBColor[1.0, 0.6, 0.1], PointSize[0.02], Point[{model["LArr"][[upTo]], Log10[model["TArr"][[upTo]]]}]}
    },
    Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
    FrameLabel -> {Style["barrier width L (nm)", White, 10], Style["log10(T)", White, 10]},
    PlotLabel  -> Style["Tunnelling Probability vs Barrier Width", White, 12],
    PlotRange  -> {{model["widthMin"], model["widthMax"]},
                   {Log10[Min[model["TArr"]]] - 0.3, Log10[Max[model["TArr"]]] + 0.3}},
    AspectRatio -> 0.5, ImageSize -> {560, 380}
  ];

AnimateSweep[model_Association, outGif_String, outPng_String,
            Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, indices, frames, staticPlt},
    nSteps  = model["nSteps"];
    indices = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];
    frames  = RenderSweepFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, 12];

    staticPlt = Graphics[
      {GrayLevel[0.15], Thickness[0.0025], Line[Transpose[{model["LArr"], Log10[model["TArr"]]}]]},
      Background -> White, Frame -> True,
      FrameLabel -> {"barrier width L (nm)", "log10(T)"},
      PlotLabel  -> Style["Tunnelling Probability vs Barrier Width", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{model["widthMin"], model["widthMax"]},
                     {Log10[Min[model["TArr"]]] - 0.3, Log10[Max[model["TArr"]]] + 0.3}},
      AspectRatio -> 0.5, ImageSize -> {600, 360}
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];


(* ── Mode 3: energy — T vs E spanning both regimes, moving marker ─── *)

RenderEnergyFrame[model_Association, upTo_Integer] :=
  Graphics[
    {
      {GrayLevel[0.55], Thickness[0.0022], Line[Transpose[{model["EArr"], model["TArr"]}]]},
      {Yellow, Dashed, Line[{{model["V0"], 0}, {model["V0"], 1}}]},
      {RGBColor[1.0, 0.6, 0.1], PointSize[0.02], Point[{model["EArr"][[upTo]], model["TArr"][[upTo]]}]}
    },
    Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
    FrameLabel -> {Style["particle energy E (eV)", White, 10], Style["transmission T", White, 10]},
    PlotLabel  -> Style["Transmission vs Energy", White, 12],
    PlotRange  -> {{model["EMin"], model["EMax"]}, {0, 1.05}},
    AspectRatio -> 0.5, ImageSize -> {560, 380}
  ];

AnimateEnergy[model_Association, outGif_String, outPng_String,
             Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, indices, frames, staticPlt},
    nSteps  = model["nSteps"];
    indices = DeleteDuplicates[Round[Subdivide[1, nSteps, Min[nFrames, nSteps] - 1]]];
    frames  = RenderEnergyFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, 12];

    staticPlt = Graphics[
      {
        {GrayLevel[0.15], Thickness[0.0025], Line[Transpose[{model["EArr"], model["TArr"]}]]},
        {RGBColor[0.8, 0.2, 0.1], Dashed, Line[{{model["V0"], 0}, {model["V0"], 1}}]},
        Text[Style["E=V0=" <> ToString[NumberForm[model["V0"], {4, 2}]] <> "eV",
                   9, RGBColor[0.8, 0.2, 0.1]],
             {model["V0"], 0.92}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"particle energy E (eV)", "transmission T"},
      PlotLabel  -> Style["Transmission vs Energy: Tunnelling to Resonance", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{model["EMin"], model["EMax"]}, {0, 1.05}},
      AspectRatio -> 0.5, ImageSize -> {620, 380}
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    Length[frames]
  ];

(* ========================================================
   compton/src/animate.wl — GIF/PNG rendering for all four modes

   scatter's diagram style is deliberately simple (three arrows from
   one collision point), similar in spirit to relativity/geodesic's
   orbit diagrams; sweep/energy's curve-with-moving-marker style
   follows dynamical/'s bifurcation-diagram convention (full curve
   drawn once, a marker walks along it); discovery's static overlay
   plot has no GIF (per the build spec's own outputs list -- a single
   comparison plot IS the point for that mode, not an animation).

   Every AnimateX function below takes a targetDuration_?NumericQ (the
   duration, in seconds, of the WAV it will be played alongside -- the
   FULL exported file, spoken intro/outro included, since that is what
   a listener actually starts and stops in sync with the GIF) and an
   nFrames RENDER BUDGET, not a literal frame count: frameRate is
   solved as nFrames/targetDuration and clamped to
   [$MinAnimationFps, $MaxAnimationFps] so a short clip doesn't demand
   a strobing frame rate and a long one (compton's spoken intros
   routinely run 15-35s, dwarfing the 1-3s of actual collision/sweep
   audio) doesn't demand an implausibly slow one; actualNFrames
   (Round[frameRate*targetDuration]) is what flexes at the clamp
   boundary so playback duration always lands on targetDuration
   exactly. See AGENTS.md's "Animation/audio duration sync" entry for
   the bug this replaced (GIFs built from a fixed 40 frames at a fixed
   15/12 fps, entirely decoupled from the WAV -- ratios up to ~14x). *)

$MinAnimationFps = 2;
$MaxAnimationFps = 30;


(* ── Mode 1: scatter — collision diagram ─────────────────────────── *)

(* ScatterDiagramGraphics — shared by both the static PNG and each GIF
   frame. `revealFrac` in [0,1] controls how far the incoming photon
   has travelled (revealFrac<0.5) or the outgoing photon/electron have
   travelled (revealFrac>=0.5); pass 1.0 for the fully-revealed static
   PNG. *)
ScatterDiagramGraphics[model_Association, revealFrac_?NumericQ] :=
  Module[{thetaRad, phiRad, extend, incomingStart, photonOutEnd, electronOutEnd,
          incomingNow, photonOutNow, electronOutNow, arcR, elements},
    thetaRad = model["thetaRad"];
    phiRad   = model["recoilAngleDeg"] * Pi / 180.0;
    extend   = 1.0;

    incomingStart   = {-extend, 0.0};
    photonOutEnd     = extend * {Cos[thetaRad], Sin[thetaRad]};
    electronOutEnd   = 0.55 * extend * {Cos[phiRad], Sin[phiRad]};   (* RecoilElectronAngleDeg
      is already the electron's own (opposite-transverse-side) angle as of the
      model.wl fix -- no extra sign flip needed here anymore. *)

    incomingNow = If[revealFrac <= 0.5,
      incomingStart * (1.0 - 2.0 * revealFrac),
      {0.0, 0.0}
    ];
    photonOutNow = If[revealFrac > 0.5,
      photonOutEnd * (2.0 * (revealFrac - 0.5)),
      {0.0, 0.0}
    ];
    electronOutNow = If[revealFrac > 0.5,
      electronOutEnd * (2.0 * (revealFrac - 0.5)),
      {0.0, 0.0}
    ];

    arcR = 0.22 * extend;

    elements = {
      (* Incoming photon path (dashed guide) + travelling marker *)
      {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{incomingStart, {0.0, 0.0}}]},
      If[revealFrac <= 0.5,
        {RGBColor[1.0, 0.9, 0.2], PointSize[0.025], Point[incomingNow]},
        {}
      ],

      (* Collision point *)
      {White, Disk[{0.0, 0.0}, 0.02 * extend]},

      If[revealFrac > 0.5,
        {
          (* Outgoing photon path + marker *)
          {GrayLevel[0.45], Dashing[{0.02, 0.015}], Line[{{0.0, 0.0}, photonOutEnd}]},
          {RGBColor[1.0, 0.6, 0.1], AbsoluteThickness[2.0], Arrow[{{0.0, 0.0}, photonOutNow}]},
          {RGBColor[1.0, 0.6, 0.1], FontSize -> 9,
           Text["photon' (" <> ToString[NumberForm[model["EPrimeKeV"], {4, 1}]] <> " keV)",
                1.12 * photonOutEnd]},

          (* Recoil electron path + marker *)
          {GrayLevel[0.45], Dashing[{0.01, 0.01}], Line[{{0.0, 0.0}, electronOutEnd}]},
          {RGBColor[0.3, 0.75, 1.0], AbsoluteThickness[2.0], Arrow[{{0.0, 0.0}, electronOutNow}]},
          {RGBColor[0.3, 0.75, 1.0], FontSize -> 9,
           Text["e- recoil (" <> ToString[NumberForm[model["TKeV"], {4, 2}]] <> " keV)",
                1.25 * electronOutEnd]},

          (* Scattering-angle arc *)
          {RGBColor[0.6, 0.9, 0.5], AbsoluteThickness[1.2], Circle[{0.0, 0.0}, arcR, {0.0, thetaRad}]},
          {RGBColor[0.6, 0.9, 0.5], FontSize -> 10,
           Text["theta=" <> ToString[Round[model["thetaDeg"]]] <> "deg",
                1.7 * arcR * {Cos[thetaRad / 2.0], Sin[thetaRad / 2.0]}]}
        },
        {}
      ],

      {GrayLevel[0.6], FontSize -> 9,
       Text["photon (" <> ToString[NumberForm[model["EKeV"], {4, 1}]] <> " keV)",
            {-0.55 * extend, 0.08 * extend}]}
    };

    Graphics[elements,
      Background -> Black, PlotRange -> 1.35 * extend * {{-1, 1}, {-1, 1}},
      ImageSize -> 460, Axes -> False, Frame -> False]
  ];

AnimateScatter[model_Association, outGif_String, outPng_String,
              targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{frameRate, actualNFrames, frames},
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    frames = Table[ScatterDiagramGraphics[model, N[k] / actualNFrames], {k, actualNFrames}];
    ExportGIF[frames, outGif, frameRate];
    Export[outPng, ScatterDiagramGraphics[model, 1.0], "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];


(* ── Mode 2: sweep — Delta_lambda vs theta, moving marker ─────────── *)

RenderSweepFrame[model_Association, upTo_Integer] :=
  Graphics[
    {
      {GrayLevel[0.55], Thickness[0.0022], Line[Transpose[{model["thetaDegArr"], model["deltaLambdaArr"]}]]},
      {RGBColor[1.0, 0.6, 0.1], PointSize[0.02], Point[{model["thetaDegArr"][[upTo]], model["deltaLambdaArr"][[upTo]]}]}
    },
    Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
    FrameLabel -> {Style["scattering angle theta (deg)", White, 10], Style["Delta_lambda (pm)", White, 10]},
    PlotLabel  -> Style["Compton Wavelength Shift", White, 12],
    PlotRange  -> {{0, 180}, {0, 1.1 * Max[model["deltaLambdaArr"]]}},
    ImageSize  -> {560, 380}, AspectRatio -> 0.5
  ];

AnimateSweep[model_Association, outGif_String, outPng_String,
            targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, frameRate, actualNFrames, indices, frames, staticPlt},
    nSteps        = model["nSteps"];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    (* No DeleteDuplicates: a step index repeating (when actualNFrames
       exceeds nSteps, common once targetDuration includes a long
       spoken intro) just holds that frame on screen longer, which is
       fine -- deleting repeats would shrink the frame count below
       actualNFrames and pull playback duration back out of sync. *)
    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    frames  = RenderSweepFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, frameRate];

    staticPlt = Graphics[
      {GrayLevel[0.15], Thickness[0.0025], Line[Transpose[{model["thetaDegArr"], model["deltaLambdaArr"]}]]},
      Background -> White, Frame -> True,
      FrameLabel -> {"scattering angle theta (deg)", "Delta_lambda (pm)"},
      PlotLabel  -> Style["Compton Wavelength Shift vs Angle", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{0, 180}, {0, 1.1 * Max[model["deltaLambdaArr"]]}},
      ImageSize  -> {600, 360}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];


(* ── Mode 3: energy — fractional shift vs incident E, log-x ───────── *)

RenderEnergyFrame[model_Association, upTo_Integer] :=
  Module[{logE, restEnergyIdx},
    logE = Log10[model["EArr"]];
    restEnergyIdx = model["restEnergyIdx"];
    Graphics[
      {
        {GrayLevel[0.55], Thickness[0.0022], Line[Transpose[{logE, model["fracShiftArr"]}]]},
        {Yellow, Dashed, Line[{{Log10[$ElectronRestEnergyKeV], 0}, {Log10[$ElectronRestEnergyKeV], 1}}]},
        {RGBColor[1.0, 0.6, 0.1], PointSize[0.02], Point[{logE[[upTo]], model["fracShiftArr"][[upTo]]}]}
      },
      Background -> Black, Frame -> True, FrameStyle -> Directive[White, Thin],
      FrameLabel -> {Style["log10(incident energy / keV)", White, 10],
                     Style["fractional energy loss (E-E')/E", White, 10]},
      PlotLabel  -> Style["Compton Fractional Energy Loss", White, 12],
      PlotRange  -> {{Log10[model["EMinKev"]], Log10[model["EMaxKev"]]}, {0, 1.0}},
      ImageSize  -> {560, 380}, AspectRatio -> 0.5
    ]
  ];

AnimateEnergy[model_Association, outGif_String, outPng_String,
             targetDuration_?NumericQ, Optional[nFrames_Integer, 40]] :=
  Module[{nSteps, frameRate, actualNFrames, indices, frames, logE, staticPlt},
    nSteps        = model["nSteps"];
    frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * targetDuration]];

    (* No DeleteDuplicates -- see AnimateSweep for why: a repeated
       index just holds a frame longer, keeping actualNFrames (hence
       playback duration) exact. *)
    indices = Round[Subdivide[1, nSteps, actualNFrames - 1]];
    frames  = RenderEnergyFrame[model, #] & /@ indices;
    ExportGIF[frames, outGif, frameRate];

    logE = Log10[model["EArr"]];
    staticPlt = Graphics[
      {
        {GrayLevel[0.15], Thickness[0.0025], Line[Transpose[{logE, model["fracShiftArr"]}]]},
        {RGBColor[0.8, 0.2, 0.1], Dashed, Line[{{Log10[$ElectronRestEnergyKeV], 0}, {Log10[$ElectronRestEnergyKeV], 1}}]},
        Text[Style["m_e c^2 = 511 keV", 9, RGBColor[0.8, 0.2, 0.1]],
             {Log10[$ElectronRestEnergyKeV] + 0.15, 0.92}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"log10(incident energy / keV)", "fractional energy loss (E-E')/E"},
      PlotLabel  -> Style["Compton Fractional Energy Loss vs Incident Energy", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{Log10[model["EMinKev"]], Log10[model["EMaxKev"]]}, {0, 1.0}},
      ImageSize  -> {620, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, staticPlt, "PNG"];
    Print["  PNG: ", outPng];
    {actualNFrames, frameRate}
  ];


(* ── Mode 4: discovery — classical vs quantum overlay (static only) ─ *)

RenderDiscoveryStaticPNG[model_Association, outPng_String] :=
  Module[{thetaDeg, thomsonLambda, comptonLambda, plt},
    thetaDeg      = model["thetaDegArr"];
    thomsonLambda = PhotonWavelengthPm /@ model["EPrimeThomson"];
    comptonLambda = PhotonWavelengthPm /@ model["EPrimeCompton"];

    plt = Graphics[
      {
        {RGBColor[0.2, 0.4, 0.9], Thickness[0.003], Line[Transpose[{thetaDeg, thomsonLambda}]]},
        {RGBColor[0.9, 0.35, 0.1], Thickness[0.003], Line[Transpose[{thetaDeg, comptonLambda}]]},
        Text[Style["Thomson (classical): flat", 10, RGBColor[0.2, 0.4, 0.9]],
             {90.0, thomsonLambda[[1]] - 0.15}],
        Text[Style["Compton (real): rises with angle", 10, RGBColor[0.9, 0.35, 0.1]],
             {120.0, comptonLambda[[Round[3 * Length[comptonLambda] / 4]]] + 0.2}]
      },
      Background -> White, Frame -> True,
      FrameLabel -> {"scattering angle theta (deg)", "outgoing wavelength lambda' (pm)"},
      PlotLabel  -> Style["Compton's 1923 Test: Thomson vs Compton Prediction", 13, Bold],
      GridLines  -> Automatic,
      PlotRange  -> {{0, 180}, {Min[thomsonLambda] - 0.3, Max[comptonLambda] + 0.3}},
      ImageSize  -> {600, 380}, AspectRatio -> 0.5
    ];
    Export[outPng, plt, "PNG"];
    Print["  PNG: ", outPng]
  ];

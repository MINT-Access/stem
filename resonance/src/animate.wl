(* ========================================================
   resonance/src/animate.wl — GIF rendering for all three modes

   Public API:
     AnimateGalilean[model, outGif, targetDuration, nFrames_:150] -> {actualNFrames, frameRate}
     AnimateKirkwood[model, outGif, targetDuration, nFrames_:150] -> {actualNFrames, frameRate}
     AnimateSaturn[model, outGif, targetDuration, nFrames_:150]   -> {actualNFrames, frameRate}

   targetDuration is the desired GIF playback length in seconds --
   callers pass the same duration value used to size the accompanying
   WAV's post-intro audio (see sonify.wl's GalileanBodyDurationSec /
   ChordSweepMainDurationSec) so GIF and audio stay in sync instead of
   the GIF racing through the whole animation in a few seconds while
   the audio plays for the sonification's real length. nFrames is a
   RENDER BUDGET, not a literal frame count -- see AGENTS.md.
   ======================================================== *)

(* GIF timing: frame delay and frame count come from stem-core's
   GIFFramePlan, which clamps the requested rate to 2-30 fps, rounds the
   frame delay to whole centiseconds (what the GIF format stores) and
   derives the frame count from that delay; main.wl then measures both
   files with SyncWAVToGIF. *)

(* Default render BUDGET (not a literal frame count) passed as the
   4th argument to Animate* below: frameRate is solved as
   nFrames/targetDuration and clamped to [2, 30] fps (stem-core GIFFramePlan), then the actual frame count is recomputed as
   Round[frameRate*targetDuration] so playback duration equals
   targetDuration to within half a frame delay. *)
$ResonanceGifFrames = 150;


(* ========================================================
   GALILEAN MODE — top-down orbital animation

   Recomputes its own fine-grained trajectory (independent of the
   model's CSV-resolution "t"/"x*"/"y*" arrays, which may be too
   coarse -- e.g. 200 samples over 32 Io periods -- to trace a smooth
   circle) directly from the idealised period formulas, the same
   "animate at higher resolution than the exported CSV" idiom
   lagrange/src/animate.wl uses for its own GIF-only "nGIFPts" grid.
   ======================================================== *)

GalileanFramePositions[tNow_?NumericQ] :=
  Module[{thIo, thEu, thGa},
    thIo = 2.0 Pi tNow / $TIo;
    thEu = 2.0 Pi tNow / $TEuropa;
    thGa = 2.0 Pi tNow / $TGanymede;
    <|
      "io" -> $RIo * {Cos[thIo], Sin[thIo]},
      "eu" -> $REuropa * {Cos[thEu], Sin[thEu]},
      "ga" -> $RGanymede * {Cos[thGa], Sin[thGa]}
    |>
  ];

MakeGalileanFrame[tNow_?NumericQ, trailTimes_List, plotHalfRange_?NumericQ] :=
  Module[{pos, trailIo, trailEu, trailGa},
    pos = GalileanFramePositions[tNow];
    trailIo = GalileanFramePositions[#]["io"] & /@ trailTimes;
    trailEu = GalileanFramePositions[#]["eu"] & /@ trailTimes;
    trailGa = GalileanFramePositions[#]["ga"] & /@ trailTimes;
    Graphics[{
      (* Reference line: initial alignment direction (theta=0) *)
      {GrayLevel[0.4], Dashing[{0.02, 0.02}], Line[{{0, 0}, {plotHalfRange * 0.95, 0}}]},

      (* Fading trails *)
      If[Length[trailIo] > 1, {Opacity[0.6], RGBColor[0.9, 0.25, 0.2], AbsoluteThickness[1.2], Line[trailIo]}, {}],
      If[Length[trailEu] > 1, {Opacity[0.6], RGBColor[0.25, 0.55, 0.95], AbsoluteThickness[1.2], Line[trailEu]}, {}],
      If[Length[trailGa] > 1, {Opacity[0.6], RGBColor[0.3, 0.85, 0.4], AbsoluteThickness[1.2], Line[trailGa]}, {}],

      (* Jupiter *)
      {RGBColor[0.85, 0.65, 0.35], Disk[{0, 0}, 0.12]},

      (* Moons, current position *)
      {RGBColor[0.9, 0.25, 0.2], Disk[pos["io"], 0.07]},
      {RGBColor[0.25, 0.55, 0.95], Disk[pos["eu"], 0.07]},
      {RGBColor[0.3, 0.85, 0.4], Disk[pos["ga"], 0.07]},

      {White, FontSize -> 9,
       Text["Io", pos["io"] + {0.0, 0.18}],
       Text["Europa", pos["eu"] + {0.0, 0.18}],
       Text["Ganymede", pos["ga"] + {0.0, 0.18}]},

      {GrayLevel[0.7], FontSize -> 9,
       Text["t = " <> ToString[NumberForm[tNow, {5, 2}]] <> " Io periods", {0, -plotHalfRange * 0.95}]}
    },
    Background -> Black,
    PlotRange  -> plotHalfRange * {{-1, 1}, {-1, 1}},
    ImageSize  -> 460, Frame -> False, Axes -> False]
  ];

AnimateGalilean[model_Association, outGif_String, targetDuration_?NumericQ, nFrames_:$ResonanceGifFrames] :=
  Module[{plan, tEnd, frameRate, actualNFrames, nMotion, frameTimes, trailSpan, plotHalfRange, frames},
    tEnd = model["tEnd"];
    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];
    (* targetDuration is the whole post-intro audio (GalileanBodyDurationSec):
       the orbits play over the main body at the audio's Io-period tempo,
       then the last frame holds through the release tail. *)
    nMotion = Clip[Round[actualNFrames * GalileanMainDurationSec[model] / targetDuration],
                   {2, actualNFrames}];
    frameTimes = N @ Join[Subdivide[0.0, tEnd, nMotion - 1],
                          ConstantArray[tEnd, actualNFrames - nMotion]];
    trailSpan = $TIo / 3.0;  (* short fading trail, ~1/3 of an Io period *)
    plotHalfRange = 1.25 * model["rGa"];

    Print["  Rendering ", actualNFrames, " galilean orbital frames at ", FmtDec[frameRate],
      " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
      FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Map[
      Function[tNow,
        Module[{trailTimes},
          trailTimes = N @ Subdivide[Max[0.0, tNow - trailSpan], tNow, 12];
          MakeGalileanFrame[tNow, trailTimes, plotHalfRange]
        ]
      ],
      frameTimes
    ];
    ExportGIF[frames, outGif, plan];
    {actualNFrames, frameRate}
  ];


(* ========================================================
   KIRKWOOD MODE — asteroid belt sweep
   ======================================================== *)

RenderKirkwoodFrame[aVals_List, rhoVals_List, resonances_List, cursorA_?NumericQ,
                    currentLabel_String, aMin_?NumericQ, aMax_?NumericQ] :=
  Graphics[{
    {RGBColor[0.25, 0.55, 0.95], Opacity[0.55],
     FilledCurve[Line[Join[{{aMin, 0}}, Transpose[{aVals, rhoVals}], {{aMax, 0}}]]]},
    {RGBColor[0.25, 0.55, 0.95], AbsoluteThickness[1.4], Line[Transpose[{aVals, rhoVals}]]},

    Table[
      {Dashed, RGBColor[0.95, 0.35, 0.25], Line[{{res["a"], 0}, {res["a"], 1.1}}]},
      {res, resonances}],
    Table[
      {RGBColor[0.95, 0.6, 0.3], FontSize -> 9, Text[res["label"], {res["a"], 1.2}]},
      {res, resonances}],

    {Yellow, AbsoluteThickness[2.0], Line[{{cursorA, 0}, {cursorA, 1.3}}]},

    {White, FontSize -> 11, Text["a = " <> ToString[NumberForm[cursorA, {5, 3}]] <> " AU", {(aMin + aMax) / 2.0, 1.45}]},
    {GrayLevel[0.75], FontSize -> 10, Text[currentLabel, {(aMin + aMax) / 2.0, -0.15}]}
  },
  Background -> Black,
  PlotRange  -> {{aMin, aMax}, {-0.25, 1.55}},
  AspectRatio -> 0.45,
  ImageSize  -> 520, Frame -> True, FrameStyle -> Directive[GrayLevel[0.6], Thin],
  FrameTicksStyle -> White,
  FrameLabel -> {Style["semi-major axis a (AU)", White, 10], Style["asteroid density", White, 10]},
  Axes -> False];

CurrentKirkwoodLabel[cursorA_?NumericQ, resonances_List, gapWidth_?NumericQ] :=
  Module[{nearest},
    nearest = SelectFirst[resonances, Abs[#["a"] - cursorA] < 2.0 * gapWidth &, Missing["None"]];
    If[MissingQ[nearest], "", nearest["label"] <> " resonance"]
  ];

AnimateKirkwood[model_Association, outGif_String, targetDuration_?NumericQ, nFrames_:$ResonanceGifFrames] :=
  Module[{plan, aVals, rhoVals, resonances, gapWidth, aMin, aMax, frameRate, actualNFrames, indices, frames},
    aVals = model["aVals"]; rhoVals = model["rhoVals"]; resonances = model["resonances"];
    gapWidth = model["gapWidth"]; aMin = model["aMin"]; aMax = model["aMax"];

    (* capped at nSteps -- the sweep has only that many distinct
       positions to show; when the cap applies, GIFFramePlan lengthens
       the frame delay instead so the GIF still matches the audio *)
    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration, "MaxFrames" -> model["nSteps"]];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];
    indices = DeleteDuplicates[Round[Subdivide[1, model["nSteps"], actualNFrames - 1]]];

    Print["  Rendering ", Length[indices], " kirkwood sweep frames at ", FmtDec[frameRate],
      " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
      FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Map[
      Function[i,
        RenderKirkwoodFrame[aVals, rhoVals, resonances, aVals[[i]],
          CurrentKirkwoodLabel[aVals[[i]], resonances, gapWidth], aMin, aMax]
      ],
      indices
    ];
    ExportGIF[frames, outGif, plan];
    {Length[frames], frameRate}
  ];


(* ========================================================
   SATURN MODE — ring density sweep, false-colour by region
   ======================================================== *)

$SaturnRegionColor = <|
  "C ring"           -> RGBColor[0.55, 0.55, 0.5],
  "B ring"           -> RGBColor[1.0, 0.92, 0.55],
  "Cassini Division" -> RGBColor[0.05, 0.05, 0.05],
  "A ring"           -> RGBColor[0.75, 0.7, 0.55],
  "Encke gap"        -> RGBColor[0.1, 0.1, 0.1],
  "outside"          -> RGBColor[0.0, 0.0, 0.0]
|>;

RenderSaturnFrame[rVals_List, rhoVals_List, regions_List, cursorR_?NumericQ,
                  rMin_?NumericQ, rMax_?NumericQ] :=
  Module[{regionBars},
    regionBars = Table[
      {$SaturnRegionColor[regions[[i]]], Opacity[0.9],
       Rectangle[{rVals[[i]], 0}, {rVals[[Min[i + 1, Length[rVals]]]], rhoVals[[i]]}]},
      {i, Length[rVals]}
    ];
    Graphics[{
      regionBars,
      {White, AbsoluteThickness[1.2], Line[Transpose[{rVals, rhoVals}]]},
      {Dashed, RGBColor[0.9, 0.3, 0.25],
       Line[{{$SaturnCassiniCenterKm, 0}, {$SaturnCassiniCenterKm, 1.15}}]},
      {RGBColor[0.95, 0.5, 0.4], FontSize -> 9, Text["Cassini Division", {$SaturnCassiniCenterKm, 1.25}]},
      {Yellow, AbsoluteThickness[2.0], Line[{{cursorR, 0}, {cursorR, 1.35}}]},
      {White, FontSize -> 11, Text["r = " <> ToString[Round[cursorR]] <> " km", {(rMin + rMax) / 2.0, 1.5}]}
    },
    Background -> Black,
    PlotRange  -> {{rMin, rMax}, {-0.1, 1.6}},
    AspectRatio -> 0.4,
    ImageSize  -> 560, Frame -> True, FrameStyle -> Directive[GrayLevel[0.6], Thin],
    FrameTicksStyle -> White,
    FrameLabel -> {Style["orbital radius r (km)", White, 10], Style["ring density", White, 10]},
    Axes -> False]
  ];

AnimateSaturn[model_Association, outGif_String, targetDuration_?NumericQ, nFrames_:$ResonanceGifFrames] :=
  Module[{plan, rVals, rhoVals, regions, rMin, rMax, frameRate, actualNFrames, indices, frames},
    rVals = model["rVals"]; rhoVals = model["rhoVals"]; regions = model["regions"];
    rMin = model["rMin"]; rMax = model["rMax"];

    plan      = GIFFramePlan[targetDuration, nFrames / targetDuration, "MaxFrames" -> model["nSteps"]];
    frameRate = plan["FrameRate"];
    actualNFrames = plan["FrameCount"];
    indices = DeleteDuplicates[Round[Subdivide[1, model["nSteps"], actualNFrames - 1]]];

    Print["  Rendering ", Length[indices], " saturn ring sweep frames at ", FmtDec[frameRate],
      " fps (", FmtDec[plan["FrameDelay"]], " s per frame, ",
      FmtDec[plan["GIFDuration"]], " s in total)."];
    frames = Map[
      Function[i, RenderSaturnFrame[rVals, rhoVals, regions, rVals[[i]], rMin, rMax]],
      indices
    ];
    ExportGIF[frames, outGif, plan];
    {Length[frames], frameRate}
  ];

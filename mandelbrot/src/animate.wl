(* ========================================================
   mandelbrot/src/animate.wl — Rendering and Hilbert-traversal
   animation, reusing images/src/animate.wl's own AnimateImageTraversal
   pattern directly (path grown across the image, frame by frame)

   Colour convention (a rendering choice, not a derived fact, stated
   here for clarity): iteration count is mapped to hue via a smooth HSB
   sweep (fast-escaping = blue/violet, slow-escaping = red/orange), and
   points that never escape within the budget (i.e. "in the set" for
   this app's purposes) are rendered black — the same "interior is
   black" convention essentially every standard Mandelbrot renderer
   uses, adopted here for immediate visual recognisability. This is the
   "high_contrast" color_scheme (default), UNCHANGED by the addition
   below.

   color_scheme="escape_gradient" (opt-in, config key
   simulation.mandelbrot.color_scheme) is a second, additive rendering
   option: a continuous cosine-palette gradient over the SMOOTH/
   renormalized iteration count (model.wl's SmoothIterationCount), for
   the rich, continuous "psychedelic" look most people associate with
   Mandelbrot renders, without the banding a naive integer-count
   mapping produces. See AGENTS.md/README, "Escape-gradient color mode."
   ======================================================== *)


(* Sane bounds on GIF playback frame rate — see AnimateFieldTraversal /
   AnimateZoom for how these keep each animation's playback duration in
   sync with its matching WAV's actual duration (spoken intro + pause +
   sonification) without forcing an absurdly fast frame rate for a
   short render or an implausibly slow one for a long one (see
   AGENTS.md, "GIF/WAV duration sync"). *)
$MinAnimationFps = 2;
$MaxAnimationFps = 30;

(* Default for the maxDurationSec parameter added to
   AnimateFieldTraversal/AnimateAndExportField/AnimateZoom — see
   AGENTS.md, "Animation pacing: an explicit, independent duration cap"
   for the full rationale. A large FINITE sentinel (not Infinity --
   NumericQ[Infinity] is False in this WL version, so an Infinity
   default fails the Optional[x_?NumericQ,...] pattern test the moment
   a caller explicitly threads its own already-defaulted value onward,
   e.g. AnimateAndExportField passing maxDurationSec to
   AnimateFieldTraversal -- caught by Set::shape on a real run, not
   merely suspected) preserves the EXACT prior behavior (GIF duration
   == targetDuration, always) for every existing caller (main.wl,
   experiments.wl) with zero code changes on their part -- 10^9 seconds
   is far beyond any real targetDuration this app could ever produce,
   so Min[targetDuration, $DefaultMaxAnimationDurationSec] is always
   targetDuration unless a caller explicitly opts into a real cap. *)
$DefaultMaxAnimationDurationSec = 10.0^9;


(* IterationToColor — HSB hue sweep for escaping points, black for
   points at maxIter (treated as non-escaping / in the set). This is the
   "high_contrast" (default) color_scheme -- untouched by the
   escape_gradient addition below, so its output is byte-identical to
   before that feature existed. *)
IterationToColor[iter_Integer, maxIter_Integer] :=
  If[iter >= maxIter,
    {0.0, 0.0, 0.0},
    Module[{ratio = N[iter] / N[maxIter]},
      List @@ Hue[0.66 * (1.0 - ratio^0.4), 0.85, 0.95]
    ]
  ];

(* SmoothIterationToColor — the "escape_gradient" color_scheme: a smooth
   cosine-based palette (Inigo Quilez's palette[t] = a+b*Cos[2 Pi (c t+d)]
   technique) evaluated on the RENORMALIZED iteration count (model.wl's
   SmoothIterationCount), not the raw integer count -- nu varies
   continuously as a point's escape magnitude varies, so this color
   function is continuous in nu by construction and produces no banding
   (verified directly: a zoomed test render across a boundary spiral
   showed a fully smooth blue->green->yellow->orange sweep with no hard
   edges -- see AGENTS.md/README "Escape-gradient color mode" for the
   comparison against a plain HSV cyclic sweep and a discrete LUT, both
   tried and rejected as visually flatter or less continuous).
   $EscapeGradientCycleLength sets how many renormalized iterations one
   full color cycle spans -- chosen (not derived) by rendering several
   candidates and picking the one that showed rich, continuous color
   both near the boundary and across the open exterior at once. Interior
   (non-escaping) points are always solid black, matching the
   high_contrast interior convention and staying visually distinct from
   every gradient color (the gradient's darkest tone is a deep blue, not
   black). *)
$EscapeGradientCycleLength = 18.0;

(* TraceStyle — the Hilbert-traversal path's line style. escape_gradient
   gets a dark halo stroke under the original white line, so the trace
   stays visible crossing the gradient's bright orange/yellow exterior;
   high_contrast is a single white line.

   traceOpacity is now a REQUIRED, caller-supplied value (see
   $DefaultTraceOpacity below for why 0.8/0.9 -- the values hardcoded
   here until this fix -- are wrong): because a Hilbert traversal
   visits literally every pixel of the grid by construction, by the
   final frame pathG spans the ENTIRE grid, so this "trace" functions
   as a visited-region overlay covering the whole canvas, not a small
   decorative line. At the old opacities this was confirmed (by
   rendering and measuring real output, not assumed) to bury the
   fractal under a dense line maze: escape_gradient's black-halo+white
   two-layer stroke over a full-canvas Hilbert path renders as a near-
   opaque black/white grid with the colorful fractal beneath barely
   visible (mean luminance ratio final/first frame up to ~3x on a
   dense grid), and high_contrast's single white line washes the same
   way without the halo. The halo/line ratio (0.55/0.9) is preserved
   at any traceOpacity so escape_gradient's relative contrast doesn't
   shift as the overlay fades. *)
TraceStyle[pathG_List, colorScheme_String, traceOpacity_?NumericQ] :=
  If[colorScheme === "escape_gradient",
    {
      {Opacity[traceOpacity * (0.55/0.9)], Black, AbsoluteThickness[3.5], Line[pathG]},
      {Opacity[traceOpacity], White, AbsoluteThickness[1.4], Line[pathG]}
    },
    {Opacity[traceOpacity], RGBColor[1.0, 1.0, 1.0], Thin, Line[pathG]}
  ];

(* $DefaultTraceOpacity — chosen by measurement, not guesswork (see
   mandelbrot/VERIFICATION_overlay_fix.md for the actual numbers): at
   the real escape-gradient LinkedIn-video configuration (grid_size=128,
   color_scheme="escape_gradient"), rendering the completed-scan final
   frame at candidate opacities {0.8 (old), 0.4, 0.25, 0.15} and
   comparing each against the unscanned first frame directly (viewed,
   not just measured) showed 0.8 still degrades to a dense line maze
   that hides the fractal, while 0.15 leaves the fractal's shape and
   color gradient clearly legible with the traversal visible as a
   light texture rather than an occlusion -- std-dev-of-luminance
   ("contrast") ratio final/first = 0.838 at 0.15, comfortably above
   the >=60% target. This is also used as the config default (see
   simulation.mandelbrot.trace_opacity, model.wl), so every caller
   that doesn't explicitly override it gets the fix automatically. *)
$DefaultTraceOpacity = 0.15;

(* $TraceFadeFloorOpacity — the opacity the end-of-scan fade (see
   AnimateFieldTraversal's fadeSeconds below) settles at: low enough to
   read as "the overlay has faded," non-zero so the completed Hilbert
   curve stays faintly visible through the closing hold, per the
   overlay-fix review item. *)
$TraceFadeFloorOpacity = 0.05;

(* $HilbertScanLabelFontSize — up from the original 9pt (see
   mandelbrot/VERIFICATION_overlay_fix.md for the measured pixel
   height before/after in the actual exported GIF frame): 9pt was hard
   to read on a phone-sized rendering of the LinkedIn profile export;
   16pt is comfortably larger while still fitting within the frame
   width without colliding with the canvas edge. *)
$HilbertScanLabelFontSize = 16;

SmoothIterationToColor[nu_?NumericQ, maxIter_Integer] :=
  If[nu >= maxIter,
    {0.0, 0.0, 0.0},
    Module[{t, a = {0.5, 0.45, 0.4}, b = {0.5, 0.45, 0.5}, c = {1.0, 0.9, 0.6}, d = {0.65, 0.55, 0.35}},
      t = Mod[nu, $EscapeGradientCycleLength] / $EscapeGradientCycleLength;
      Clip[a + b * Cos[2.0 * Pi * (c * t + d)], {0.0, 1.0}]
    ]
  ];

(* FieldToImage — renders an iteration-count field (in Hilbert-traversal
   order, paired with the traversal's own {col,row} coordinates) as an
   Image, row 1 = bottom (matching images/animate.wl's own Raster
   orientation convention). colorScheme/smoothField are trailing
   optionals so every pre-existing call site (which only ever passed the
   first four arguments) keeps producing pixel-identical output --
   colorScheme defaults to "high_contrast", which never reads
   smoothField at all. *)
FieldToImage[iterField_List, traversal_List, size_Integer, maxIter_Integer,
             Optional[colorScheme_String, "high_contrast"], Optional[smoothField_List, {}]] :=
  Module[{grid},
    grid = ConstantArray[{0.0, 0.0, 0.0}, {size, size}];
    Do[
      grid[[ size - traversal[[i, 2]] + 1, traversal[[i, 1]] ]] =
        If[colorScheme === "escape_gradient",
          SmoothIterationToColor[smoothField[[i]], maxIter],
          IterationToColor[iterField[[i]], maxIter]
        ],
      {i, Length[traversal]}
    ];
    Image[grid, ColorSpace -> "RGB"]
  ];

(* AnimateFieldTraversal — images/'s AnimateImageTraversal pattern,
   reused directly: a GIF of the Hilbert path growing across the
   rendered field.

   targetDuration should be the matching WAV's actual total duration
   (spoken intro + pause + per-pixel note stream, computed just before
   this call — see main.wl/experiments.wl). nFrames is a RENDER
   BUDGET, not a literal frame count: frameRate is solved as
   nFrames/targetDuration and clamped to [$MinAnimationFps,
   $MaxAnimationFps] so a short render doesn't demand a strobing frame
   rate and a long one doesn't demand an implausibly slow one — the
   frame COUNT is what flexes at the clamp boundary (recomputed as
   Round[frameRate * targetDuration]) so actual playback duration
   always equals targetDuration exactly, UNLESS maxDurationSec caps it
   (see below). Returns {actualNFrames, frameRate} so callers can
   report real numbers via STEMDescribeGIF.

   maxDurationSec — an explicit, OPT-IN independent knob (default
   Infinity, i.e. no cap — exact prior behavior) decoupling playback
   duration from resolution/traversal-step-count (nPixels), per
   AGENTS.md "Animation pacing: an explicit, independent duration cap".
   Pacing is computed against Min[targetDuration, maxDurationSec], not
   targetDuration directly, so a caller producing a presentation-video
   GIF for a large grid_size (which drives a proportionally long
   targetDuration, since nPixels notes at a fixed per-note duration
   drives WAV length) can request e.g. maxDurationSec->80.0 and get a
   punchy, capped-duration GIF showing the FULL traversal (no pixels
   skipped — frameUpTo still spans all nPixels) at a correspondingly
   higher frame rate, WITHOUT touching grid_size or sonify.wl at all.
   When capped, the GIF's own duration will legitimately no longer
   equal targetDuration — that's the intended trade-off for this
   opt-in path; the matching audio for a video export must then be
   produced separately at the same (shorter) duration (see
   tools/make_presentation_video.wl usage in AGENTS.md).

   traceOpacity — see $DefaultTraceOpacity above for what this fixes
   and how the default was chosen; a config-driven per-model value is
   threaded in by AnimateAndExportField below.

   fadeSeconds (default 0, i.e. exact prior behavior) reserves the
   LAST fadeSeconds of pacingDuration, in frames at this same frame
   rate, as an end-of-scan reveal: the traversal path stops growing
   once it reaches the full grid at the end of the SCAN portion
   (pacingDuration-fadeSeconds), and the remaining fadeFrames hold
   that completed path while its opacity ramps from traceOpacity down
   to $TraceFadeFloorOpacity, so the overlay visibly clears while the
   completed Hilbert curve stays faintly visible. This is a content
   fade, not a frozen-last-frame hold -- the closing hold itself is
   tools/make_presentation_video.wl's --hold-seconds, applied to the
   already-rendered GIF+WAV; duplicating a hold here would double up
   with that flag, so this only ever adds a genuinely changing
   (fading) tail, never a static one. Total frame count is unchanged
   by fadeSeconds (still Round[frameRate*pacingDuration]) -- frames
   are reallocated from scan to fade, not added on top -- so THIS
   function's own GIF-duration-equals-targetDuration contract is
   unaffected; callers that want the GIF to actually grow by
   fadeSeconds (so the fade is additional time, not a bite out of the
   scan) must pass a correspondingly longer targetDuration -- see
   main.wl's mandelbrot/julia blocks, which pad the exported WAV with
   fadeSeconds of trailing silence for exactly this reason, keeping
   GIF and WAV duration-matched. *)
AnimateFieldTraversal[iterField_List, traversal_List, size_Integer, maxIter_Integer,
                      outGIF_String, targetDuration_?NumericQ, Optional[nFrames_Integer, 150],
                      Optional[colorScheme_String, "high_contrast"], Optional[smoothField_List, {}],
                      Optional[maxDurationSec_?NumericQ, $DefaultMaxAnimationDurationSec],
                      Optional[traceOpacity_?NumericQ, $DefaultTraceOpacity],
                      Optional[fadeSeconds_?NumericQ, 0.0]] :=
  Module[{img, displayData, gCoords, gifFrames, nPixels, frameRate, actualNFrames, pacingDuration,
          markerRadius, fadeFrameCount, scanFrameCount, scanFrameUpTo, scanFrames, fadeFrames, fullPathG},
    nPixels = Length[traversal];
    pacingDuration = Min[targetDuration, maxDurationSec];

    frameRate = Clip[nFrames / pacingDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[2, Round[frameRate * pacingDuration]];

    fadeFrameCount = Min[actualNFrames - 1, Max[0, Round[frameRate * fadeSeconds]]];
    scanFrameCount = actualNFrames - fadeFrameCount;

    img = FieldToImage[iterField, traversal, size, maxIter, colorScheme, smoothField];
    displayData = Reverse @ ImageData[img];
    gCoords = Map[{#[[1]] - 0.5, size - #[[2]] + 0.5} &, traversal];
    scanFrameUpTo = Table[Max[1, Round[k * nPixels / scanFrameCount]], {k, scanFrameCount}];
    fullPathG = gCoords;

    If[pacingDuration < targetDuration,
      Print["  Rendering ", actualNFrames, " traversal frames at ", FmtN[frameRate, 3],
            " fps (", FmtN[actualNFrames / frameRate, 3],
            "s, CAPPED at maxDurationSec -- audio's own duration is ",
            FmtN[targetDuration, 3], "s; resolution/duration decoupled, see AGENTS.md)..."],
      Print["  Rendering ", actualNFrames, " traversal frames at ", FmtN[frameRate, 3],
            " fps (", FmtN[actualNFrames / frameRate, 3],
            "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."]
    ];
    If[fadeFrameCount > 0,
      Print["  ", scanFrameCount, " scan frames + ", fadeFrameCount,
            " end-of-scan fade frames (", FmtN[fadeFrameCount / frameRate, 3],
            "s, overlay opacity ", FmtN[traceOpacity, 3], " -> ", FmtN[$TraceFadeFloorOpacity, 3], ")..."]
    ];

    (* Marker/label sized relative to the grid resolution so they scale
       sensibly if grid_size ever changes -- 0.017*size matches roughly
       double the marker's old fixed radius of 0.65 at the default
       size=64, per the "hard to see, make it larger" feedback. The
       marker's black outline (not just a bigger flat fill) is what
       keeps it visible against BOTH the escape_gradient scheme's
       bright yellow/gold regions and the high_contrast scheme's dark
       background -- a flat color alone can't do that for any single
       hue, since the gradient spans from dark blue to bright yellow. *)
    markerRadius = size * 0.017;

    scanFrames = Table[
      With[{pathG = gCoords[[1 ;; scanFrameUpTo[[k]]]]},
        Graphics[{
          Raster[displayData, {{0, 0}, {size, size}}],
          TraceStyle[pathG, colorScheme, traceOpacity],
          Text[Style["Hilbert-curve scan", $HilbertScanLabelFontSize, White, Bold],
               {size * 0.5, size * 0.045},
               Background -> Directive[Opacity[0.55], Black]],
          (* Marker drawn LAST (on top of the label) so it is never
             hidden -- the label's dark background patch sits in a
             fixed bottom band the traversal legitimately passes
             through, and previously covered the marker for the few
             frames its position fell inside that band. *)
          {EdgeForm[{Black, AbsoluteThickness[1.5]}], Yellow, Disk[Last[pathG], markerRadius]}
        },
        PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
        AspectRatio -> 1, ImageSize -> 320]
      ],
      {k, scanFrameCount}
    ];

    fadeFrames = Table[
      With[{curOpacity = traceOpacity + ($TraceFadeFloorOpacity - traceOpacity) * (k / fadeFrameCount)},
        Graphics[{
          Raster[displayData, {{0, 0}, {size, size}}],
          TraceStyle[fullPathG, colorScheme, curOpacity],
          Text[Style["Hilbert-curve scan", $HilbertScanLabelFontSize, White, Bold],
               {size * 0.5, size * 0.045},
               Background -> Directive[Opacity[0.55], Black]],
          {EdgeForm[{Black, AbsoluteThickness[1.5]}], Yellow, Disk[Last[fullPathG], markerRadius]}
        },
        PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
        AspectRatio -> 1, ImageSize -> 320]
      ],
      {k, fadeFrameCount}
    ];

    gifFrames = Join[scanFrames, fadeFrames];
    ExportGIF[gifFrames, outGIF, frameRate];
    {actualNFrames, frameRate}
  ];


(* ========================================================
   MODE 1/2: mandelbrot, julia — shared renderer
   ======================================================== *)

(* AnimateAndExportField — see AnimateFieldTraversal for the
   targetDuration/nFrames/maxDurationSec/traceOpacity/fadeSeconds
   duration-sync and overlay-fix contract (maxDurationSec and
   fadeSeconds are both OPT-IN, default no-cap/no-fade -- see AGENTS.md
   for the former and TraceStyle/$DefaultTraceOpacity above for the
   latter). traceOpacity is read from model["traceOpacity"] (populated
   from config by MandelbrotModel/JuliaModel), the same Lookup pattern
   colorScheme/smoothField already use, falling back to
   $DefaultTraceOpacity if absent so any caller building a model
   association by hand still gets the fix. Returns {actualNFrames,
   frameRate}. *)
AnimateAndExportField[model_Association, outGIF_String, outPNG_String,
                      targetDuration_?NumericQ, Optional[nFrames_Integer, 150],
                      Optional[maxDurationSec_?NumericQ, $DefaultMaxAnimationDurationSec],
                      Optional[fadeSeconds_?NumericQ, 0.0]] :=
  Module[{img, size, upscaled, gifStats, colorScheme, smoothField, traceOpacity},
    colorScheme = Lookup[model, "colorScheme", "high_contrast"];
    smoothField = Lookup[model, "smoothField", {}];
    traceOpacity = Lookup[model, "traceOpacity", $DefaultTraceOpacity];
    gifStats = AnimateFieldTraversal[model["iterField"], model["traversal"], model["size"], model["maxIter"],
                                      outGIF, targetDuration, nFrames, colorScheme, smoothField, maxDurationSec,
                                      traceOpacity, fadeSeconds];
    size = model["size"];
    img = FieldToImage[model["iterField"], model["traversal"], size, model["maxIter"], colorScheme, smoothField];
    (* Export upscaled via Graphics/Raster (matching the GIF's own
       ImageSize->320 upscaling) -- exporting the raw Image directly
       would write it at its native size x size pixels (e.g. 64x64),
       far too small to view comfortably. *)
    upscaled = Graphics[Raster[Reverse @ ImageData[img], {{0, 0}, {size, size}}],
      PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
      AspectRatio -> 1, ImageSize -> 512];
    Export[outPNG, upscaled, "PNG"];
    Print["  PNG: ", outPNG];
    gifStats
  ];


(* ========================================================
   MODE 3: zoom — GIF cycles through levels; PNG shows all levels in a grid
   ======================================================== *)

ZoomLevelLabel[k_Integer, levels_List] :=
  "level " <> ToString[k] <> "  (" <>
  ToString[NumberForm[levels[[k]]["magnification"], {6, 1}]] <> "x)";

ZoomLevelFrame[images_List, levels_List, k_Integer, size_Integer, imgSize_Integer] :=
  Graphics[{Raster[Reverse @ ImageData[images[[k]]], {{0, 0}, {size, size}}],
            Text[Style[ZoomLevelLabel[k, levels], White, 12, Background -> GrayLevel[0, 0.6]],
                 {size / 2.0, size * 0.06}]},
    PlotRange -> {{0, size}, {0, size}}, ImagePadding -> None,
    AspectRatio -> 1, ImageSize -> imgSize];

(* AnimateZoom — GIF cycles through levels, each level held for a
   share of frames proportional to actualNFrames/nLevels. Same
   duration-sync contract as AnimateFieldTraversal (see its docstring):
   targetDuration is the matching WAV's actual total duration, nFrames
   is a render budget clamped to [$MinAnimationFps, $MaxAnimationFps]
   fps. framesPerLevel is distributed via cumulative rounding so the
   per-level counts sum to exactly actualNFrames (every level gets at
   least one frame) and total playback duration equals targetDuration
   exactly. Returns {actualNFrames, frameRate}. *)
AnimateZoom[model_Association, outGIF_String, outPNG_String,
           targetDuration_?NumericQ, Optional[nFrames_Integer, 150],
           Optional[maxDurationSec_?NumericQ, $DefaultMaxAnimationDurationSec]] :=
  Module[{levels, size, maxIter, gifFrames, images, colorScheme,
          nLevels, nCols, nRows, panelSize, combined, pacingDuration,
          frameRate, actualNFrames, cumCounts, framesPerLevelList},
    levels = model["levels"]; size = model["size"]; maxIter = model["maxIter"];
    colorScheme = Lookup[model, "colorScheme", "high_contrast"];
    nLevels = Length[levels];
    pacingDuration = Min[targetDuration, maxDurationSec];

    images = Map[
      FieldToImage[#["iterField"], model["traversal"], size, maxIter,
                   colorScheme, Lookup[#, "smoothField", {}]] &,
      levels
    ];

    frameRate = Clip[nFrames / pacingDuration, {$MinAnimationFps, $MaxAnimationFps}];
    actualNFrames = Max[nLevels, Round[frameRate * pacingDuration]];
    cumCounts = Round[Range[0, nLevels] * actualNFrames / nLevels];
    framesPerLevelList = Differences[cumCounts];

    If[pacingDuration < targetDuration,
      Print["  Rendering ", actualNFrames, " frames across ", nLevels, " levels at ",
            FmtN[frameRate, 3], " fps (", FmtN[actualNFrames / frameRate, 3],
            "s, CAPPED at maxDurationSec -- audio's own duration is ",
            FmtN[targetDuration, 3], "s)..."],
      Print["  Rendering ", actualNFrames, " frames across ", nLevels, " levels at ",
            FmtN[frameRate, 3], " fps (", FmtN[actualNFrames / frameRate, 3],
            "s, matching audio duration ", FmtN[targetDuration, 3], "s)..."]
    ];

    gifFrames = Flatten[Table[
      ZoomLevelFrame[images, levels, k, size, 320],
      {k, nLevels}, {framesPerLevelList[[k]]}
    ], 1];
    ExportGIF[gifFrames, outGIF, frameRate];

    (* Combined static PNG: all levels side by side in one Graphics
       row (via GraphicsGrid on the same Raster+Text frames the GIF
       already renders correctly), not ImageAssemble/ImageCompose --
       an earlier version using those produced garbled overlaid text,
       caught by viewing the actual rendered PNG during development. *)
    nCols = nLevels; nRows = 1;
    panelSize = 260;
    combined = GraphicsGrid[
      {Table[ZoomLevelFrame[images, levels, k, size, panelSize], {k, nLevels}]},
      Spacings -> 4, Background -> Black, ImageSize -> panelSize * nLevels
    ];
    Export[outPNG, combined, "PNG"];
    Print["  PNG: ", outPNG];
    {actualNFrames, frameRate}
  ];

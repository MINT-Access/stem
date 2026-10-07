(* ========================================================
   tools/src/video_pipeline.wl — Reusable pipeline for
   make_presentation_video.wl

   All functions here are pure/reusable so they can be tested
   directly (Get this file, call functions) without going
   through the CLI driver in make_presentation_video.wl.

   Requires: stem-core/src/utils.wl (EnsureDir, FmtN)
             stem-core/src/synth.wl (ExportAudioBuffer) — only
             needed for the optional --stretch path
   ======================================================== *)


(* ── Duration helpers ─────────────────────────────────────

   GIF duration is the sum of its actual per-frame display
   durations (GIF's "DisplayDurations" element), NOT frame count
   divided by an assumed constant frame rate — durations are
   stored in whole centiseconds (10ms quantization) per frame,
   the same quantization noise documented in the v1.5.1 GIF/WAV
   sync fix, so summing the real per-frame values is exact rather
   than assuming uniformity. GIFFrameRate recovers the average fps
   from the same data, for use when building the output video. *)

GIFDisplayDurations[gifPath_String] := Import[gifPath, "DisplayDurations"]

GIFDurationSeconds[gifPath_String] := N[Total[GIFDisplayDurations[gifPath]]]

(* Rounded to the nearest 0.01 fps: raw floating-point division of
   frame count by summed durations lands a hair off a clean value
   (e.g. 24.999999999999993 instead of 25) purely from float
   summation noise, and that noise was enough to make VideoCombine
   fail internally when muxing (observed: "output frame rate
   changed from 25 to 12500001/500000" followed by
   VideoCombine::interr). *)
GIFFrameRate[gifPath_String] := Module[{durations},
  durations = GIFDisplayDurations[gifPath];
  Round[N[Length[durations] / Total[durations]], 0.01]
]

WAVDurationSeconds[wavPath_String] := Module[{d},
  d = Import[wavPath, "Duration"];
  If[QuantityQ[d], QuantityMagnitude[UnitConvert[d, "Seconds"]], N[d]]
]


(* VerifyDurationMatch
   Step 1 of the required pipeline. Compares GIF and WAV
   duration within tolerance (default 3%, matching the v1.5.1
   GIF/WAV sync fix's documented residual from GIF centisecond
   frame-delay quantization). Returns an Association describing
   the result; does NOT throw — the caller decides whether to
   abort, so the CLI driver can print a clear report either way. *)

VerifyDurationMatch[gifPath_String, wavPath_String, tolerance_:0.03] :=
  Module[{gifDur, wavDur, relDiff, ok},
    gifDur  = GIFDurationSeconds[gifPath];
    wavDur  = WAVDurationSeconds[wavPath];
    relDiff = Abs[gifDur - wavDur] / wavDur;
    ok      = relDiff <= tolerance;
    <|
      "gifDuration" -> gifDur,
      "wavDuration" -> wavDur,
      "relativeDiff" -> relDiff,
      "tolerance" -> tolerance,
      "ok" -> ok
    |>
  ]


(* ── Background inference ─────────────────────────────────

   Apps in this codebase use different backgrounds (pendulum's
   near-white RGBColor[0.97,0.97,1.0]; bell/scattering's solid
   Black for some plots). Rather than hardcode a "light and
   achromatic = background" rule (which only works for pendulum's
   own palette, per pendulum/tests/verify_animation_frames.py),
   the background color is sampled per-video from the four corner
   pixels of the first frame — every app in this codebase centers
   its physics content, so corners are reliably background. *)

BackgroundColorOf[img_Image] := Module[{data},
  data = ImageData[ColorConvert[img, "RGB"], "Byte"];
  Round[Mean[N[{data[[1, 1]], data[[1, -1]], data[[-1, 1]], data[[-1, -1]]}]]]
]


(* ── Content bounding box ─────────────────────────────────

   A pixel counts as "content" if its RGB distance from the
   inferred background color exceeds threshold. This is a
   generalization of verify_animation_frames.py's classification
   rule (which specifically targeted pendulum's near-white
   background + grey support line) to work across arbitrary
   background colors. Support/reference lines (e.g. pendulum's
   grey ceiling line) are NOT specifically excluded here — they
   get included in the content bbox like any other non-background
   pixel. That only makes the crop slightly less tight; it never
   causes clipping, so it's a safe simplification. *)

FrameContentBBox[img_Image, bgColor_List, threshold_:22] :=
  Module[{data, dataT, diff, mask, rowAny, colAny, rowIdx, colIdx},
    data = ImageData[ColorConvert[img, "RGB"], "Byte"];
    (* Transpose to {channel, row, col} so plain Subtract threads
       one scalar bgColor[[c]] against each whole channel plane —
       list arithmetic in WL only broadcasts a scalar against an
       array, not a length-3 vector against the trailing axis of a
       rank-3 array directly. *)
    dataT = Transpose[N[data], {2, 3, 1}];
    diff  = Sqrt[Total[(dataT - bgColor)^2]];
    (* UnitStep, not diff > threshold: relational operators are NOT
       Listable in WL, so a bare ">" comparison against a packed
       array stays symbolic instead of threading elementwise —
       UnitStep IS Listable and gives the same 0/1 mask. *)
    mask = UnitStep[diff - threshold];
    rowAny = Total[mask, {2}];
    colAny = Total[mask, {1}];
    rowIdx = Flatten[Position[Unitize[rowAny], 1]];
    colIdx = Flatten[Position[Unitize[colAny], 1]];
    If[rowIdx === {} || colIdx === {},
      None,
      {Min[rowIdx], Max[rowIdx], Min[colIdx], Max[colIdx]}]
  ]


(* UnionContentBBox
   Union of the content bbox across EVERY frame (not a sample) —
   the same "check every frame" discipline as
   verify_animation_frames.py, since the double-pendulum clipping
   bug this whole pipeline exists to avoid repeating was invisible
   on the frames a human would have spot-checked. *)

UnionContentBBox[frames_List, bgColor_List, threshold_:22] :=
  Module[{bboxes},
    bboxes = DeleteCases[FrameContentBBox[#, bgColor, threshold] & /@ frames, None];
    If[bboxes === {},
      None,
      {Min[bboxes[[All, 1]]], Max[bboxes[[All, 2]]],
       Min[bboxes[[All, 3]]], Max[bboxes[[All, 4]]]}]
  ]


(* AddSymmetricMargin
   Adds marginPx to BOTH sides of BOTH dimensions, then clamps to
   the image bounds. Existing bbox is {rMin,rMax,cMin,cMax}.
   imgDims is {height, width}.

   This exists specifically to avoid two mistakes made by hand
   this session: cropping exactly to the tightest boundary with
   zero margin, and adding a margin to only one side of a
   dimension instead of both. *)

AddSymmetricMargin[bbox_List, marginPx_Integer, imgDims_List] :=
  Module[{rMin, rMax, cMin, cMax, h, w},
    {rMin, rMax, cMin, cMax} = bbox;
    {h, w} = imgDims;
    {
      Max[1, rMin - marginPx], Min[h, rMax + marginPx],
      Max[1, cMin - marginPx], Min[w, cMax + marginPx]
    }
  ]


(* ── Frame composition ────────────────────────────────────

   Layout: a canvas of {targetW, targetH} split into a dark
   title band at the top (titleBandH pixels) and a content area
   below it (targetH - titleBandH pixels). The animation content
   is scaled+padded to fit ENTIRELY within the content area —
   never the title band — so title/content overlap is structurally
   impossible, not merely visually unlikely. The title band is
   built once (it's identical on every frame) and reused. *)

$TitleBandColor = RGBColor[0.09, 0.09, 0.11];
$TitleTextColor = White;

TitleBandFraction = 0.16;

BuildTitleBandImage[title_String, targetW_Integer, titleBandH_Integer] :=
  Rasterize[
    Graphics[
      {$TitleBandColor, Rectangle[{0, 0}, {targetW, titleBandH}],
       $TitleTextColor,
       Text[
         Style[title, Bold, FontFamily -> "Source Sans Pro",
               FontSize -> Round[0.42 * titleBandH]],
         {targetW/2, titleBandH/2}
       ]},
      PlotRange -> {{0, targetW}, {0, titleBandH}},
      ImageSize -> {targetW, titleBandH}
    ],
    ImageSize -> {targetW, titleBandH}, RasterSize -> {targetW, titleBandH}
  ]


(* ComposeFrame
   Crops frameImg to cropBBox, scales it to fill the content area
   as large as the aspect ratio allows, pads (never stretches) to
   the exact content-area size with bgColor, then stacks the fixed
   titleBandImg on top to produce a {targetW,targetH} frame.

   ContentFillFrac scales content to slightly LESS than the full
   content area (94% by default) rather than exactly filling it.
   This exists because AddSymmetricMargin's margin can only be added
   where the SOURCE image actually has spare background pixels
   beyond the content bbox — for a source GIF that is already
   tightly framed natively (observed on lorenz_animation.gif: only
   ~5px of native headroom above/below the trajectory, so the
   requested margin got clamped away to nothing), the crop ends up
   using the image's full native bounds with ~zero added margin, and
   naively scaling that crop to fill the content area exactly would
   carry little to no breathing room into the output regardless of
   scale direction. Reserving a fixed fraction of the content area
   as deliberate padding guarantees a minimum proportional clearance
   in the OUTPUT unconditionally, independent of how tightly the
   source app happened to frame its own animation. *)

ContentFillFrac = 0.94;

ComposeFrame[frameImg_Image, cropBBox_List, bgColor_List,
             targetW_Integer, targetH_Integer, titleBandH_Integer,
             titleBandImg_Image] :=
  Module[{rMin, rMax, cMin, cMax, cropped, cw, ch, contentH,
          scale, newW, newH, resized, padded, canvas},
    {rMin, rMax, cMin, cMax} = cropBBox;
    cropped = ImageTake[frameImg, {rMin, rMax}, {cMin, cMax}];
    {cw, ch} = ImageDimensions[cropped];
    contentH = targetH - titleBandH;

    scale = ContentFillFrac * Min[targetW/cw, contentH/ch];
    newW  = Max[1, Round[cw * scale]];
    newH  = Max[1, Round[ch * scale]];
    resized = ImageResize[cropped, {newW, newH}];

    padded = ImagePad[resized,
      {{Floor[(targetW - newW)/2], Ceiling[(targetW - newW)/2]},
       {Floor[(contentH - newH)/2], Ceiling[(contentH - newH)/2]}},
      RGBColor[bgColor/255.0]
    ];
    padded = ImageResize[padded, {targetW, contentH}];

    canvas = ImageAssemble[{{titleBandImg}, {padded}}];
    ImageResize[canvas, {targetW, targetH}]
  ]


(* ── Whole-video content-clearance verification ───────────

   Re-implements the discipline of
   pendulum/tests/verify_animation_frames.py directly on the
   COMPOSED frames actually used to build the video (every frame,
   not a sample): confirms content never touches the composed
   canvas edge, and confirms content never intrudes into the
   title band's vertical span. *)

VerifyComposedFrames[composedFrames_List, titleBandH_Integer,
                      canvasBgColor_List, marginPx_:3] :=
  Module[{n, w, h, contentH, results, violations, worstTop, worstBottom,
          worstLeft, worstRight, worstTitleClearance},
    n = Length[composedFrames];
    {w, h} = ImageDimensions[First[composedFrames]];
    contentH = h - titleBandH;
    results = Table[
      Module[{contentSub, bbox, rMin, rMax, cMin, cMax, topM, botM, leftM, rightM},
        (* Restrict the content-vs-background classification to the
           content area ONLY (below the title band). Running it on
           the full canvas would classify the (intentionally very
           different-colored) title band itself as "content" against
           the content area's background color, making the check
           useless. topM here doubles as the title-clearance measure:
           it is the distance from the animation content's own top
           edge to the top of the content area, which is exactly
           where the title band boundary sits. *)
        contentSub = ImageTake[composedFrames[[k]], {titleBandH + 1, h}, {1, w}];
        bbox = FrameContentBBox[contentSub, canvasBgColor, 22];
        If[bbox === None,
          <|"frame" -> k, "bbox" -> None|>,
          (
            {rMin, rMax, cMin, cMax} = bbox;
            topM   = rMin - 1;
            botM   = contentH - rMax;
            leftM  = cMin - 1;
            rightM = w - cMax;
            <|"frame" -> k, "bbox" -> bbox,
              "topMargin" -> topM, "bottomMargin" -> botM,
              "leftMargin" -> leftM, "rightMargin" -> rightM,
              "titleClearance" -> topM|>
          )
        ]
      ],
      {k, n}
    ];

    violations = Select[results,
      (#["bbox"] =!= None &&
       (#["topMargin"] < marginPx || #["bottomMargin"] < marginPx ||
        #["leftMargin"] < marginPx || #["rightMargin"] < marginPx ||
        #["titleClearance"] < marginPx)) &];

    worstTop    = Min[Cases[results, KeyValuePattern["topMargin" -> m_] :> m]];
    worstBottom = Min[Cases[results, KeyValuePattern["bottomMargin" -> m_] :> m]];
    worstLeft   = Min[Cases[results, KeyValuePattern["leftMargin" -> m_] :> m]];
    worstRight  = Min[Cases[results, KeyValuePattern["rightMargin" -> m_] :> m]];
    worstTitleClearance = Min[Cases[results, KeyValuePattern["titleClearance" -> m_] :> m]];

    <|
      "nFrames" -> n,
      "canvasSize" -> {w, h},
      "ok" -> (Length[violations] == 0),
      "nViolations" -> Length[violations],
      "violations" -> violations,
      "worstTopMargin" -> worstTop,
      "worstBottomMargin" -> worstBottom,
      "worstLeftMargin" -> worstLeft,
      "worstRightMargin" -> worstRight,
      "worstTitleClearance" -> worstTitleClearance
    |>
  ]


(* ── Optional stretch: chirp-style decoupled time/pitch remap
   applied to a FINISHED WAV buffer ──────────────────────────

   This tool operates on already-rendered GIF/WAV files, not raw
   model arrays, so it cannot call relativity's ChirpToAudio
   directly (that needs the physical frequency/amplitude arrays
   from ChirpModel). Instead it recovers an instantaneous
   frequency/amplitude description of the SOURCE WAV via a Hilbert
   transform — the same analysis technique already used this
   session to VERIFY the chirp fix's rendered WAVs (see commit
   e73161e's message: "Verified via Hilbert-transform instantaneous
   -frequency analysis of the actual rendered WAVs") — then
   interpolates that description onto a longer playback time axis
   and re-synthesizes, exactly mirroring ChirpToAudio's math:
   never resampling the raw waveform, which would divide every
   frequency component by the stretch factor.

   This only makes sense for close-to-monophonic, single
   dominant-tone/sweep audio (chirp-style). It is NOT intended for
   and not verified against multi-voice or narrated audio — those
   are explicitly out of scope for this tool's stretch feature. *)

(* AnalyticSignalFFT
   Discrete analytic signal via the standard FFT method (zero the
   negative-frequency bins, double the positive ones, leave DC/Nyquist
   alone). WL's own HilbertTransform is a SYMBOLIC integral-transform
   function (operates on f[t], not a numeric list — confirmed via its
   ::usage message after it silently failed and produced a multi-GB
   unevaluated symbolic expression on a real test run), so it cannot
   be used directly on a PCM buffer; this is the discrete equivalent. *)

AnalyticSignalFFT[buffer_List] := Module[{n, spec, h, half},
  n = Length[buffer];
  spec = Fourier[buffer];
  h = ConstantArray[0, n];
  h[[1]] = 1;
  If[EvenQ[n],
    half = n/2;
    h[[2 ;; half]] = 2;
    h[[half + 1]] = 1,
    half = (n + 1)/2;
    h[[2 ;; half]] = 2
  ];
  InverseFourier[spec * h]
]


(* UnwrapPhase
   WL has no built-in Unwrap (checked: stays unevaluated, Global`
   context — not a System` symbol in this version). Standard
   unwrapping: accumulate phase differences wrapped into (-Pi,Pi]. *)

UnwrapPhase[phase_List] := Module[{d, wrapped},
  d = Differences[phase];
  wrapped = Mod[d + Pi, 2.0*Pi] - Pi;
  First[phase] + Prepend[Accumulate[wrapped], 0.0]
]


StretchAudioBuffer[buffer_List, srIn_Integer, stretchFactor_?NumericQ] :=
  Module[{analytic, instAmp, instPhase, instFreq, tIn, tPhysSpan,
          tPlaybackSpan, nOut, dtOut, tPlaybackArr, tPhysQuery,
          ampInterp, freqInterp, fAudio, aAudio, phaseArr, hAudio, peak},

    analytic  = AnalyticSignalFFT[N[buffer]];
    instAmp   = Abs[analytic];
    instPhase = UnwrapPhase[Arg[analytic]];
    instFreq  = Join[{0.0}, Differences[instPhase]] * srIn / (2.0*Pi);
    instFreq  = Clip[Abs[instFreq], {20.0, 20000.0}];

    tIn = N@Range[0, Length[buffer]-1] / srIn;
    tPhysSpan = Last[tIn] - First[tIn];
    tPlaybackSpan = tPhysSpan * N[stretchFactor];

    nOut  = Max[1, Round[tPlaybackSpan * srIn]];
    dtOut = 1.0 / srIn;

    tPlaybackArr = N@Range[0, nOut-1] * dtOut;
    tPhysQuery   = Clip[First[tIn] + tPlaybackArr * (tPhysSpan / tPlaybackSpan),
                        {First[tIn], Last[tIn]}];

    ampInterp  = Interpolation[Transpose[{tIn, instAmp}], InterpolationOrder -> 1];
    freqInterp = Interpolation[Transpose[{tIn, instFreq}], InterpolationOrder -> 1];

    fAudio = freqInterp /@ tPhysQuery;
    aAudio = ampInterp /@ tPhysQuery;

    phaseArr = N[2.0*Pi * Accumulate[fAudio] * dtOut];
    hAudio   = aAudio * Sin[phaseArr];

    peak = Max[Abs[hAudio]];
    If[peak > 0.0, hAudio * (0.9/peak), hAudio]
  ]


(* ── Opening/closing hold ─────────────────────────────────

   Extends the composed reel by repeating the first composed frame
   holdStartSeconds and the last composed frame holdEndSeconds, and
   pads the audio with matching digital silence at each end, so
   picture and sound both grow by the same amount and stay in sync.
   Frame rate is unchanged -- this lengthens the reel, it does not
   slow it down (unlike --stretch above).

   HoldFrameCount quantizes a requested hold length to whole video
   frames (Round[seconds*frameRate]) -- the caller feeds that SAME
   frame-quantized duration (nFrames/frameRate), not the raw
   requested seconds, into PadAudioSilence below. Audio padding is
   otherwise sample-accurate (Round[seconds*sampleRate], far finer
   than one video frame period), so if the two sides were each
   independently rounded from the raw requested seconds -- frames
   for video, samples for audio -- they could quantize to different
   actual durations at a low or non-clean frame rate (most visibly
   after --stretch, which can produce a frame rate like 2.5 fps),
   desyncing picture and sound by up to half a frame period at each
   end -- the exact failure this feature exists to prevent. Deriving
   the audio target from the already-quantized video duration instead
   guarantees the two match to within a single audio sample. *)

HoldFrameCount[seconds_?NumericQ, frameRate_?NumericQ] := Round[seconds * frameRate]

HoldFrames[composedFrames_List, nStart_Integer, nEnd_Integer] :=
  Join[
    ConstantArray[First[composedFrames], nStart],
    composedFrames,
    ConstantArray[Last[composedFrames], nEnd]
  ]

(* PadAudioSilence
   Reads wavPath's raw sample data and writes a new WAV with
   holdStartSeconds/holdEndSeconds of silence joined at each end,
   preserving channel count (mono or stereo) exactly. Built on
   AudioData/AudioChannels/AudioSampleRate + ExportAudioBuffer
   (the same headless-safe pattern StretchAudioBuffer's caller
   already uses above) rather than AudioPad/AudioDuration: those
   two returned unevaluated in a real headless wolframscript run
   tried while building this feature (AudioPad[...] and
   AudioDuration[...] both stayed as literal unevaluated
   expressions instead of computing anything) -- the same
   "Audio[] requires a display context" gap ExportAudioBuffer's
   own header comment already documents for Audio[], evidently
   extending to these two functions as well in this WL version. *)

PadAudioSilence[wavPath_String, holdStartSeconds_?NumericQ,
                 holdEndSeconds_?NumericQ, outPath_String] :=
  Module[{audioObj, sr, data, nCh, nStart, nEnd, padded},
    audioObj = Import[wavPath];
    sr = Round[QuantityMagnitude[AudioSampleRate[audioObj]]];
    data = AudioData[audioObj];
    nCh = Length[data];
    nStart = Round[holdStartSeconds * sr];
    nEnd   = Round[holdEndSeconds * sr];
    padded = Join[
      ConstantArray[0., {nCh, nStart}],
      data,
      ConstantArray[0., {nCh, nEnd}],
      2
    ];
    ExportAudioBuffer[padded, outPath, sr];
    outPath
  ]


(* ── Coarse output-size sanity check ───────────────────────

   A second, louder check layered on top of VerifyComposedFrames'
   detailed per-frame clearance check above: flags an output whose
   audio duration, video duration, or file size is unexpectedly
   large. This is a warning, not an abort -- the output file has
   already been written by the time this runs, and stays written
   either way. The point is that a case like an accidental
   1002-second, 88 MB WAV would have been flagged immediately by
   this check instead of being found by hand later. *)

CheckOutputSanity[outPath_String, videoDurationSeconds_?NumericQ,
                   audioDurationSeconds_?NumericQ,
                   maxDurationSeconds_?NumericQ, maxFileMB_?NumericQ] :=
  Module[{fileMB, warnings},
    fileMB = N[FileByteCount[outPath]] / (1024.0*1024.0);
    warnings = {};
    If[videoDurationSeconds > maxDurationSeconds,
      AppendTo[warnings,
        "WARNING: the video duration is " <> FmtN[videoDurationSeconds, 6] <>
        " seconds, which exceeds the configured threshold of " <>
        FmtN[maxDurationSeconds, 6] <> " seconds."]];
    If[audioDurationSeconds > maxDurationSeconds,
      AppendTo[warnings,
        "WARNING: the audio duration is " <> FmtN[audioDurationSeconds, 6] <>
        " seconds, which exceeds the configured threshold of " <>
        FmtN[maxDurationSeconds, 6] <> " seconds."]];
    If[fileMB > maxFileMB,
      AppendTo[warnings,
        "WARNING: the output file size is " <> FmtN[fileMB, 6] <>
        " MB, which exceeds the configured threshold of " <>
        FmtN[maxFileMB, 6] <> " MB."]];
    <|
      "videoDurationSeconds" -> videoDurationSeconds,
      "audioDurationSeconds" -> audioDurationSeconds,
      "fileMB" -> fileMB,
      "maxDurationSeconds" -> maxDurationSeconds,
      "maxFileMB" -> maxFileMB,
      "warnings" -> warnings,
      "ok" -> (Length[warnings] == 0)
    |>
  ]


(* ── Video muxing ─────────────────────────────────────────

   Native WL: FrameListVideo turns the composed frame sequence
   into a Video at the source GIF's own frame rate; VideoCombine
   attaches the WAV as its audio track; Export writes the MP4.
   See tools/README.md for how this was verified to work reliably
   (AudioTrackCount, FrameCount, FrameRate, RasterSize, Duration
   all checked against the inputs on a real muxed file) before
   this tool was built around it, and why no ffmpeg dependency
   was introduced. *)

MuxVideo[composedFrames_List, frameRate_?NumericQ, wavPath_String, outPath_String] :=
  Module[{vid, audioObj, combined},
    vid  = FrameListVideo[composedFrames, FrameRate -> frameRate];
    audioObj = Import[wavPath];
    (* AudioEncoding -> "AAC" is required, not cosmetic: with the
       default (Inherited) encoding, VideoCombine throws an opaque
       VideoCombine::interr "cannot create output video" for every
       STEREO source WAV tested (all of this codebase's sonifications
       use stereo/spatial panning) while silently succeeding for
       mono — confirmed by isolating channel count as the only
       varying factor across otherwise-identical synthetic
       reproductions. Forcing AAC avoids the failure and keeps both
       channels (verified via AudioTrackCount/AudioChannels on the
       muxed output) instead of the alternative workaround of
       downmixing to mono, which would silently discard the spatial
       audio panning several apps rely on. *)
    combined = VideoCombine[{vid, audioObj}, AudioEncoding -> "AAC"];
    EnsureDir[outPath];
    Export[outPath, combined];
    outPath
  ]


(* ── Top-level orchestration ──────────────────────────────

   MakePresentationVideo runs the full required pipeline:
     1. verify GIF/WAV duration match (abort with a clear report
        if they don't, rather than silently producing a desynced
        video)
     2. crop to the real, verified content boundary (union bbox
        across every frame + symmetric margin)
     3. scale to fill the profile frame, pad (never stretch) to
        the exact target dimensions
     4. add the title with structurally-guaranteed clearance
     5. mux video + audio, verify final duration

   profile is "linkedin" ({1080,1080}) or "workshop" ({1920,1080}).
   stretchFactor is Automatic (no stretch) or a numeric factor
   applied to the audio via StretchAudioBuffer (see that function's
   header for what it is and is not appropriate for) — when given,
   the GIF's own playback is also slowed by the same factor so
   video and audio stay in lockstep, by holding each existing frame
   for longer rather than fabricating new frames.

   holdStartSeconds/holdEndSeconds (both default 0, so existing
   callers are unaffected) repeat the first/last composed frame and
   pad the audio with matching silence at each end — see HoldFrames
   and PadAudioSilence above. This is applied AFTER composition, so
   it extends the finished reel rather than being a separate
   post-processing pass over the finished file.

   maxDurationSeconds/maxFileMB (default 600s / 200MB) feed
   CheckOutputSanity, a coarse warn-only check run after muxing —
   see that function's header. It never aborts; "aborted" -> True
   only ever comes from the duration-mismatch check in step 1.

   Returns an Association report. Does not throw on a duration
   mismatch — it returns "aborted" -> True with the reason, so the
   CLI driver controls how loudly to fail. *)

$Profiles = <|
  "linkedin" -> {1080, 1080},
  "workshop" -> {1920, 1080}
|>;

MakePresentationVideo[gifPath_String, wavPath_String, title_String,
                      profile_String, outPath_String,
                      stretchFactor_:Automatic, durationTolerance_:0.03,
                      holdStartSeconds_:0, holdEndSeconds_:0,
                      maxDurationSeconds_:600, maxFileMB_:200] :=
  Module[{targetW, targetH, durCheck, frames, bg, imgDims, marginPx,
          ubbox, cropBBox, frameRate, titleBandH, titleImg, composed,
          wavPathForMux, tmpWav, tmpHoldWav, nHoldStartFrames, nHoldEndFrames,
          stretchedAudio, srIn, muxedPath,
          finalDuration, finalDurCheck, verifyResult, sanityCheck, report},

    If[!KeyExistsQ[$Profiles, profile],
      Return[<|"aborted" -> True,
                "reason" -> "Unknown profile \"" <> profile <>
                            "\" — must be \"linkedin\" or \"workshop\"."|>]];
    {targetW, targetH} = $Profiles[profile];

    (* ── Step 1: duration verification ── *)
    durCheck = VerifyDurationMatch[gifPath, wavPath, durationTolerance];
    If[!durCheck["ok"] && stretchFactor === Automatic,
      Return[<|
        "aborted" -> True,
        "reason" -> "GIF/WAV duration mismatch beyond tolerance — refusing to " <>
                    "produce a desynced video. GIF: " <> ToString[durCheck["gifDuration"]] <>
                    "s, WAV: " <> ToString[durCheck["wavDuration"]] <> "s, relative " <>
                    "difference: " <> ToString[N[100*durCheck["relativeDiff"]]] <> "% " <>
                    "(tolerance " <> ToString[N[100*durationTolerance]] <> "%). " <>
                    "Regenerate the app's outputs so GIF and WAV durations match, or " <>
                    "pass an explicit --stretch factor if this is a known-short " <>
                    "chirp-style source.",
        "durationCheck" -> durCheck
      |>]];

    frames = Import[gifPath, "ImageList"];
    frameRate = GIFFrameRate[gifPath];

    (* ── Optional stretch (audio + matching video slowdown) ── *)
    wavPathForMux = wavPath;
    If[stretchFactor =!= Automatic,
      srIn = Round[QuantityMagnitude[AudioSampleRate[Import[wavPath]]]];
      stretchedAudio = StretchAudioBuffer[
        Flatten[AudioData[Import[wavPath]]], srIn, stretchFactor];
      tmpWav = FileNameJoin[{$TemporaryDirectory,
        "stem_stretched_" <> ToString[RandomInteger[10^9]] <> ".wav"}];
      ExportAudioBuffer[stretchedAudio, tmpWav, srIn];
      wavPathForMux = tmpWav;
      frameRate = frameRate / N[stretchFactor];
    ];

    (* ── Step 2: content-bbox crop ── *)
    bg = BackgroundColorOf[First[frames]];
    imgDims = Reverse[ImageDimensions[First[frames]]];
    ubbox = UnionContentBBox[frames, bg];
    If[ubbox === None,
      Return[<|"aborted" -> True,
                "reason" -> "No non-background content found in any frame of " <> gifPath|>]];
    marginPx = Max[6, Round[0.035 * Max[imgDims]]];
    cropBBox = AddSymmetricMargin[ubbox, marginPx, imgDims];

    (* ── Steps 3-4: scale/pad + title ── *)
    titleBandH = Round[TitleBandFraction * targetH];
    titleImg = BuildTitleBandImage[title, targetW, titleBandH];
    composed = ComposeFrame[#, cropBBox, bg, targetW, targetH, titleBandH, titleImg] & /@ frames;

    (* ── Optional opening/closing hold ── *)
    tmpHoldWav = None;
    nHoldStartFrames = 0;
    nHoldEndFrames = 0;
    If[holdStartSeconds > 0 || holdEndSeconds > 0,
      nHoldStartFrames = HoldFrameCount[holdStartSeconds, frameRate];
      nHoldEndFrames   = HoldFrameCount[holdEndSeconds, frameRate];
      composed = HoldFrames[composed, nHoldStartFrames, nHoldEndFrames];
      tmpHoldWav = FileNameJoin[{$TemporaryDirectory,
        "stem_hold_" <> ToString[RandomInteger[10^9]] <> ".wav"}];
      (* Pad the audio to the frame-quantized duration (nFrames/frameRate),
         not the raw requested holdStartSeconds/holdEndSeconds -- see
         HoldFrameCount's header for why using the raw seconds on this
         side too could desync video and audio at a non-clean frame rate. *)
      PadAudioSilence[wavPathForMux, nHoldStartFrames/frameRate,
        nHoldEndFrames/frameRate, tmpHoldWav];
      wavPathForMux = tmpHoldWav;
    ];

    (* ── Step 5: mux + verify ── *)
    muxedPath = MuxVideo[composed, frameRate, wavPathForMux, outPath];

    (* For a duration >= 1 minute, Import[..., "Duration"] returns a
       Quantity with a MixedUnit (e.g. "4 min 24.666 s"), and
       QuantityMagnitude of THAT returns an unevaluated
       MixedMagnitude[{4, 24.666}] list, not a plain number -- FmtN then
       can't format it, so the CLI's "Muxed duration: ...s" line printed
       literal unevaluated FmtN[MixedMagnitude[...]] junk instead of a
       number (confirmed on a real 264.666s render, and again on a
       118.3s grid_size=256 mandelbrot render). The video/audio muxing
       itself was always correct and unaffected -- only this diagnostic
       print line was wrong. Fixed by converting to a single unit
       (seconds) before extracting the magnitude. *)
    finalDuration = QuantityMagnitude[UnitConvert[Import[muxedPath, "Duration"], "Seconds"]];
    finalDurCheck = <|
      "muxedDuration" -> finalDuration,
      "sourceWavDuration" -> WAVDurationSeconds[wavPathForMux],
      "relativeDiff" -> Abs[finalDuration - WAVDurationSeconds[wavPathForMux]] / WAVDurationSeconds[wavPathForMux]
    |>;

    verifyResult = VerifyComposedFrames[composed, titleBandH, bg];

    (* finalDuration (above) is the actual measured duration of the
       muxed output file, not a theoretical frame-count/frameRate
       value -- this coarse check should flag the real thing that got
       written, including any muxing-stage rounding. *)
    sanityCheck = CheckOutputSanity[muxedPath, finalDuration,
      WAVDurationSeconds[wavPathForMux], maxDurationSeconds, maxFileMB];

    report = <|
      "aborted" -> False,
      "outPath" -> muxedPath,
      "profile" -> profile,
      "targetSize" -> {targetW, targetH},
      "nFrames" -> Length[frames],
      "frameRate" -> frameRate,
      "cropBBox" -> cropBBox,
      "holdStartSeconds" -> holdStartSeconds,
      "holdEndSeconds" -> holdEndSeconds,
      "holdStartFrames" -> nHoldStartFrames,
      "holdEndFrames" -> nHoldEndFrames,
      "effectiveHoldStartSeconds" -> nHoldStartFrames / frameRate,
      "effectiveHoldEndSeconds" -> nHoldEndFrames / frameRate,
      "durationCheck" -> durCheck,
      "finalDurationCheck" -> finalDurCheck,
      "frameVerification" -> verifyResult,
      "sanityCheck" -> sanityCheck
    |>;

    If[stretchFactor =!= Automatic && FileExistsQ[tmpWav], DeleteFile[tmpWav]];
    If[tmpHoldWav =!= None && FileExistsQ[tmpHoldWav], DeleteFile[tmpHoldWav]];

    report
  ]

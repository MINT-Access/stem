(* images/src/sonify.wl — Per-pixel audio synthesis *)

(* TimbreHarmonics
   Maps a brightness value in [0,1] to a StemSynthNote harmonics list.
   Dark pixels get a pure sine (fundamental only); medium brightness
   adds a second harmonic at half amplitude; bright pixels add a third
   harmonic too. Used by hsb mode's timbre-encoded channel: pitch
   encodes hue, and this harmonic richness encodes brightness. *)
TimbreHarmonics[b_?NumericQ] :=
  Which[
    b < 0.333, {1.0},
    b < 0.667, {1.0, 0.5},
    True,      {1.0, 0.5, 0.33}
  ];

(* OverlayAt
   Adds (mixes, not concatenates) clip into buffer starting at startIdx
   (1-based). Clips to buffer bounds; a clip that runs past the end of
   buffer is truncated rather than growing the buffer. *)
OverlayAt[buffer_List, clip_List, startIdx_Integer] :=
  Module[{n = Length[buffer], m = Length[clip], endIdx, clipLen},
    If[startIdx > n || startIdx < 1, Return[buffer]];
    endIdx  = Min[startIdx + m - 1, n];
    clipLen = endIdx - startIdx + 1;
    Join[
      Take[buffer, startIdx - 1],
      buffer[[startIdx ;; endIdx]] + Take[clip, clipLen],
      buffer[[endIdx + 1 ;;]]
    ]
  ];

(* AddQuadrantClicks
   Inserts three brief 880 Hz orientation clicks at the 25%, 50%, and
   75% points of the traversal (50 ms, -20/-15/-20 dB) so a listener
   can track spatial progress through a large image without spoken
   interruption. Only applied to images larger than 32x32 (imgSize > 32);
   smaller images are short enough that clicks would be more disruptive
   than helpful. Applied after normalisation, so the levels are calibrated
   relative to full scale; result is clipped to [-1,1] as a defensive
   measure against the rare sample where a click coincides with a peak. *)
AddQuadrantClicks[buffer_List, sr_Integer, nPixels_Integer,
                  noteDurationBase_?NumericQ, imgSize_Integer] :=
  If[imgSize <= 32,
    buffer,
    Module[{buf = buffer, marks, totalDur},
      totalDur = nPixels * noteDurationBase;
      marks = {
        {0.25, 10^(-20/20.0)},
        {0.50, 10^(-15/20.0)},
        {0.75, 10^(-20/20.0)}
      };
      Scan[
        Function[m,
          Module[{startSample, clip},
            startSample = Max[1, Round[m[[1]] * totalDur * sr]];
            clip = StemSynthNote[880.0, 0.05, m[[2]], {1.0}, 0.3, sr];
            buf = OverlayAt[buf, clip, startSample]
          ]
        ],
        marks
      ];
      Clip[buf, {-1.0, 1.0}]
    ]
  ];

(* SonifyImageMode
   Sonifies the image in the named mode. Returns an Association:
     "channels"    -> {monoBuffer} or {leftBuffer, rightBuffer} (hsb)
     "freqAssigned" -> per-pixel Hz list, for downstream CSV export
     "colourStats"  -> <|"nDistinct"->.., "nRuns"->.., "mostCommon"->..|>
                       for colour mode; Missing[] otherwise
   Buffers are normalised PCM sample lists, not yet exported — main.wl
   prepends the spoken intro and performs the final WAV export so the
   reported duration and file include the intro.
   Requires $imgPalette, PaletteLabColors, NearestPaletteIndexLab,
   ColourRunsFromIndices, BrightnessToFreq from model.wl. *)
SonifyImageMode[mode_String, model_Association,
               freqMin_?NumericQ, freqMax_?NumericQ,
               noteDurationBase_?NumericQ, sr_Integer,
               brightnessScale_String, brightnessGamma_?NumericQ] :=
  Module[{pixBright, pixHue, pixSat, rgbData, traversal, nPixels, imgSize,
          freqAssigned, channels, colourStats = Missing[]},
    pixBright    = model["pixBright"];
    pixHue       = model["pixHue"];
    pixSat       = model["pixSat"];
    rgbData      = model["rgbData"];
    traversal    = model["traversal"];
    nPixels      = model["nPixels"];
    imgSize      = model["imgSize"];
    freqAssigned = ConstantArray[0.0, nPixels];

    Which[

      (* Brightness / scan_horizontal: grayscale value maps to frequency
         (linear or logarithmic). scan_horizontal reuses this formula on
         a raster (not Hilbert) traversal, set upstream in model["traversal"]. *)
      mode === "brightness" || mode === "scan_horizontal",
        Module[{audioBuffer},
          freqAssigned = Map[
            BrightnessToFreq[#, freqMin, freqMax, brightnessScale, brightnessGamma] &,
            pixBright
          ];
          audioBuffer = Flatten @ Table[
            StemSynthNote[freqAssigned[[i]], noteDurationBase, 0.8, {1.0}, 0.2, sr],
            {i, nPixels}
          ];
          audioBuffer = NormalizeBuffer[audioBuffer, 0.92];
          If[mode === "brightness",
            audioBuffer = AddQuadrantClicks[audioBuffer, sr, nPixels, noteDurationBase, imgSize]
          ];
          channels = {audioBuffer};
          Print["  Mapping: dark pixels -> ", FmtN[freqMin, 5],
                " Hz;  bright pixels -> ", FmtN[freqMax, 5], " Hz  (",
                brightnessScale, " scale, gamma ", FmtN[brightnessGamma, 3], ")"]
        ],

      (* Colour: nearest spectral-palette colour (Lab distance) -> fixed
         musical pitch; consecutive same-colour runs merged into one
         held note, duration proportional to run length. *)
      mode === "colour",
        Module[{paletteLab, colourIdxSeq, colourRuns, tally, mostCommonIdx, audioBuffer},
          paletteLab = PaletteLabColors[$imgPalette];
          colourIdxSeq = Table[
            NearestPaletteIndexLab[
              Take[rgbData[[ traversal[[i,2]], traversal[[i,1]] ]], 3],
              paletteLab
            ],
            {i, nPixels}
          ];
          freqAssigned = Map[$imgPalette[[#]]["freq"] &, colourIdxSeq];
          colourRuns   = ColourRunsFromIndices[colourIdxSeq];
          tally        = Tally[colourIdxSeq];
          mostCommonIdx = First[First[SortBy[tally, -Last[#] &]]];

          colourStats = <|
            "nDistinct"  -> Length[DeleteDuplicates[colourIdxSeq]],
            "nRuns"      -> Length[colourRuns],
            "mostCommon" -> $imgPalette[[mostCommonIdx]]["name"]
          |>;

          Print["  Palette colours found:   ", colourStats["nDistinct"], " of ", Length[$imgPalette]];
          Print["  Consecutive colour runs: ", colourStats["nRuns"]];
          Print["  Mean run length:         ",
                FmtN[N[nPixels / colourStats["nRuns"]], {5,1}], " pixels"];
          Print["  Most common colour:      ", colourStats["mostCommon"]];

          audioBuffer = Flatten @ Map[
            Function[run,
              StemSynthNote[$imgPalette[[ First[run] ]]["freq"],
                Length[run] * noteDurationBase, 0.8, {1.0, 0.30}, 0.5, sr]
            ],
            colourRuns
          ];
          channels = {NormalizeBuffer[audioBuffer, 0.92]}
        ],

      (* HSB: hue -> shared fundamental frequency on both channels;
         left is a pure reference tone, right adds brightness-controlled
         harmonics (timbre). Saturation -> amplitude on both channels. *)
      mode === "hsb",
        Module[{fLo = 100.0, fHi = 3900.0, freqHue, amp, leftBuf, rightBuf},
          freqHue = fLo + pixHue * (fHi - fLo);
          amp     = Map[Max[0.10, #] &, pixSat];
          freqAssigned = freqHue;

          leftBuf  = NormalizeBuffer[
            Flatten @ Table[
              StemSynthNote[freqHue[[i]], noteDurationBase, amp[[i]], {1.0}, 0.1, sr],
              {i, nPixels}],
            0.92];
          rightBuf = NormalizeBuffer[
            Flatten @ Table[
              StemSynthNote[freqHue[[i]], noteDurationBase, amp[[i]],
                TimbreHarmonics[pixBright[[i]]], 0.1, sr],
              {i, nPixels}],
            0.92];

          leftBuf  = AddQuadrantClicks[leftBuf,  sr, nPixels, noteDurationBase, imgSize];
          rightBuf = AddQuadrantClicks[rightBuf, sr, nPixels, noteDurationBase, imgSize];

          channels = {leftBuf, rightBuf};
          Print["  Left:  hue -> freq 100-3900 Hz, pure tone (reference pitch)"];
          Print["  Right: same pitch, timbre enriched by brightness ",
                "(pure -> +2nd harmonic -> +2nd+3rd harmonic)"];
          Print["  Both:  saturation -> amplitude (min 0.10)"]
        ],

      True,
        Print["Error: unknown simulation.mode \"", mode, "\" -- expected ",
              "\"brightness\", \"scan_horizontal\", \"colour\", or \"hsb\"."];
        Exit[1]
    ];

    <| "channels" -> channels, "freqAssigned" -> freqAssigned, "colourStats" -> colourStats |>
  ];

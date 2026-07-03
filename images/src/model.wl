(* images/src/model.wl — Image loading, spectral palette, and traversal *)

(* Spectral colour palette: 8 named colours ordered by position in the
   visible light spectrum (violet = shortest wavelength, red = longest),
   plus white (broadband/saturated) and black (absent/zero) as endpoints.
   Each colour has a fixed musical pitch drawn from recognisable diatonic
   note names spanning roughly two octaves from C3, consistent with the
   scale-based (not chord-based) pitch mapping used by other stem apps.
   Black is mapped to freq 0.0, which SonifyImageMode treats as silence. *)
$imgPalette = {
  <| "name" -> "violet", "rgb" -> {0.50, 0.00, 0.50}, "freq" -> 130.81, "spectral_position" -> 1 |>,
  <| "name" -> "blue",   "rgb" -> {0.00, 0.00, 1.00}, "freq" -> 146.83, "spectral_position" -> 2 |>,
  <| "name" -> "cyan",   "rgb" -> {0.00, 1.00, 1.00}, "freq" -> 174.61, "spectral_position" -> 3 |>,
  <| "name" -> "green",  "rgb" -> {0.00, 0.50, 0.00}, "freq" -> 196.00, "spectral_position" -> 4 |>,
  <| "name" -> "yellow", "rgb" -> {1.00, 1.00, 0.00}, "freq" -> 220.00, "spectral_position" -> 5 |>,
  <| "name" -> "orange", "rgb" -> {1.00, 0.50, 0.00}, "freq" -> 261.63, "spectral_position" -> 6 |>,
  <| "name" -> "red",    "rgb" -> {1.00, 0.00, 0.00}, "freq" -> 293.66, "spectral_position" -> 7 |>,
  <| "name" -> "white",  "rgb" -> {1.00, 1.00, 1.00}, "freq" -> 392.00, "spectral_position" -> 8 |>,
  <| "name" -> "black",  "rgb" -> {0.00, 0.00, 0.00}, "freq" -> 0.0,    "spectral_position" -> 9 |>
};

(* PaletteLabColors
   Precomputes each palette entry's RGB colour converted to LABColor.
   Call once per run and reuse across all pixels — converting per-pixel
   is unnecessary since the palette itself never changes during a run. *)
PaletteLabColors[palette_List] :=
  Map[ColorConvert[RGBColor @@ #["rgb"], "LAB"] &, palette];

(* NearestPaletteIndexLab
   Fast per-pixel lookup: rgbPixel is a 3-element {r,g,b} list; paletteLab
   is the precomputed list from PaletteLabColors. Uses ColorDistance in
   the perceptually uniform Lab colour space (rather than Euclidean RGB
   distance) so the nearest-neighbour match tracks human colour
   perception, consistent with Rao's compareColor[] approach. *)
NearestPaletteIndexLab[rgbPixel_List, paletteLab_List] :=
  Module[{pixLab, distances},
    pixLab    = ColorConvert[RGBColor @@ Take[rgbPixel, 3], "LAB"];
    distances = Map[ColorDistance[pixLab, #] &, paletteLab];
    First[Ordering[distances, 1]]
  ];

(* NearestPaletteIndex
   Convenience wrapper for callers (tests, one-off lookups) that don't
   already have a precomputed paletteLab list. Per-pixel sonification
   code should call NearestPaletteIndexLab directly with a precomputed
   paletteLab to avoid reconverting the palette on every pixel. *)
NearestPaletteIndex[rgbPixel_List, palette_List] :=
  NearestPaletteIndexLab[rgbPixel, PaletteLabColors[palette]];

(* ColourRunsFromIndices
   Splits a sequence of palette indices into consecutive equal-value runs.
   Each run becomes one held note in colour mode — a uniform-colour
   sequence of any length collapses to exactly one run. *)
ColourRunsFromIndices[idxSeq_List] := Split[idxSeq];

(* BrightnessToFreq
   Maps a grayscale brightness value in [0,1] to a frequency in Hz.

   scaleType "linear" — freqMin + b*(freqMax - freqMin)   (previous behaviour)
   scaleType "log"    — freqMin * (freqMax/freqMin)^(b^gamma)
                         Matches the logarithmic way human hearing
                         perceives frequency. gamma > 1 compresses
                         highlights (bright end spread out less);
                         gamma < 1 compresses shadows.
   Boundary values match exactly at b=0 (-> freqMin) and b=1 (-> freqMax)
   for both scale types. *)
BrightnessToFreq[b_?NumericQ, freqMin_?NumericQ, freqMax_?NumericQ,
                 Optional[scaleType_String, "log"],
                 Optional[gamma_?NumericQ, 1.0]] :=
  Switch[scaleType,
    "log",    freqMin * (freqMax / freqMin)^(b^gamma),
    "linear", freqMin + b * (freqMax - freqMin),
    _,        freqMin + b * (freqMax - freqMin)
  ];

(* RasterTraversalOrder
   Returns the list of {col, row} pixel coordinates (1-based) visited by
   a simple left-to-right, top-to-bottom raster scan of a 2^n x 2^n grid.
   Used by scan_horizontal mode as a deliberately simpler alternative to
   the Hilbert traversal, so a listener can compare the two directly. *)
RasterTraversalOrder[n_Integer?Positive] :=
  Module[{size = 2^n},
    Flatten[Table[{col, row}, {row, 1, size}, {col, 1, size}], 1]
  ];

(* Load or generate the source image and resize to imgSize x imgSize.
   Returns {processedImg, description_string}. *)
LoadSourceImage[inputFile_String, testImage_String, imgSize_Integer] :=
  Module[{rawImg, desc},
    If[inputFile =!= "",
      rawImg = Quiet[Import[inputFile]];
      If[!ImageQ[rawImg],
        Print["Error: could not load \"", inputFile, "\" as an image."];
        Exit[1]
      ];
      desc = inputFile,
      (* else: generate a built-in test image *)
      rawImg = Switch[testImage,

        "gaussian",
          With[{sz = imgSize, sig = imgSize / 4.0},
            Image[N @ Table[
              Exp[-((x - sz/2)^2 + (y - sz/2)^2) / (2.0 * sig^2)],
              {y, sz}, {x, sz}
            ]]
          ],

        "temperature",
          With[{sz = imgSize},
            Module[{d = N @ Table[
                      Sqrt[(x - sz/2)^2 + (y - sz/2)^2] / (sz / 2.0),
                      {y, sz}, {x, sz}]},
              Image[Map[
                Function[t,
                  Which[
                    t < 0.25, {0.0, 4.0*t, 1.0},
                    t < 0.5,  {0.0, 1.0, 1.0 - 4.0*(t-0.25)},
                    t < 0.75, {4.0*(t-0.5), 1.0, 0.0},
                    True,     {1.0, 1.0 - 4.0*(t-0.75), 0.0}
                  ]],
                d, {2}]]
            ]
          ],

        "quantum",
          With[{sz = imgSize},
            Module[{d = N @ Table[
                      Sin[Pi*x/sz]^2 * Sin[2*Pi*y/sz]^2,
                      {y, sz}, {x, sz}],
                    dmax},
              dmax = Max[d];
              Image[Map[
                Function[v,
                  With[{t = v / dmax},
                    Which[
                      t < 0.333, {3.0*t, 0.0, 0.0},
                      t < 0.667, {1.0, 3.0*(t - 0.333), 0.0},
                      True,      {1.0, 1.0, 3.0*(t - 0.667)}
                    ]]],
                d, {2}]]
            ]
          ],

        _,
          Print["Warning: unknown test_image \"", testImage, "\" -- using gaussian"];
          With[{sz = imgSize, sig = imgSize / 4.0},
            Image[N @ Table[
              Exp[-((x - sz/2)^2 + (y - sz/2)^2) / (2.0 * sig^2)],
              {y, sz}, {x, sz}
            ]]
          ]
      ];
      desc = "built-in test image  (" <> testImage <> ")"
    ];
    {ImageResize[rawImg, {imgSize, imgSize}], desc}
  ];

(* Compute the pixel traversal order and extract per-pixel channel arrays.
   scanDirection selects "hilbert" (default; locality-preserving) or
   "raster" (simple row-major scan, used by scan_horizontal mode).
   Returns an Association with all data needed by sonify, animate, and output. *)
ComputeImageTraversal[processedImg_Image, imgN_Integer, scanDirection_String : "hilbert"] :=
  Module[{traversal, nPixels, imgSize,
          greyData, hsbData, rgbData,
          pixBright, pixHue, pixSat},
    imgSize   = 2^imgN;
    traversal = If[scanDirection === "raster",
      RasterTraversalOrder[imgN],
      HilbertTraversalOrder[imgN]
    ];
    nPixels   = Length[traversal];
    greyData  = ImageData[ColorConvert[processedImg, "Grayscale"]];
    hsbData   = ImageData[ColorConvert[processedImg, "HSB"]];
    rgbData   = ImageData[ColorConvert[processedImg, "RGB"]];
    pixBright = Table[greyData[[ traversal[[i,2]], traversal[[i,1]]   ]], {i, nPixels}];
    pixHue    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 1 ]], {i, nPixels}];
    pixSat    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 2 ]], {i, nPixels}];
    <|
      "img"           -> processedImg,
      "imgN"          -> imgN,
      "imgSize"       -> imgSize,
      "scanDirection" -> scanDirection,
      "traversal"     -> traversal,
      "nPixels"       -> nPixels,
      "pixBright"     -> pixBright,
      "pixHue"        -> pixHue,
      "pixSat"        -> pixSat,
      "rgbData"       -> rgbData
    |>
  ];

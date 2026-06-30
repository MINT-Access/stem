(* images/src/model.wl — Image loading and Hilbert traversal *)

(* Colour palette: 10 named colours with fixed musical pitches (C2-E5).
   Used by colour mode and referenced in the CSV export. *)
$imgPalette = {
  <| "name" -> "black",  "rgb" -> {0.00, 0.00, 0.00}, "freq" -> 130.81 |>,
  <| "name" -> "grey",   "rgb" -> {0.50, 0.50, 0.50}, "freq" -> 164.81 |>,
  <| "name" -> "red",    "rgb" -> {0.90, 0.10, 0.10}, "freq" -> 196.00 |>,
  <| "name" -> "orange", "rgb" -> {1.00, 0.50, 0.00}, "freq" -> 220.00 |>,
  <| "name" -> "yellow", "rgb" -> {1.00, 0.90, 0.00}, "freq" -> 261.63 |>,
  <| "name" -> "green",  "rgb" -> {0.10, 0.80, 0.10}, "freq" -> 329.63 |>,
  <| "name" -> "cyan",   "rgb" -> {0.00, 0.80, 0.80}, "freq" -> 392.00 |>,
  <| "name" -> "blue",   "rgb" -> {0.10, 0.10, 0.90}, "freq" -> 440.00 |>,
  <| "name" -> "violet", "rgb" -> {0.50, 0.00, 0.90}, "freq" -> 523.25 |>,
  <| "name" -> "white",  "rgb" -> {1.00, 1.00, 1.00}, "freq" -> 659.25 |>
};

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

(* Compute Hilbert curve traversal and extract per-pixel channel arrays.
   Returns an Association with all data needed by sonify, animate, and output. *)
ComputeImageTraversal[processedImg_Image, imgN_Integer] :=
  Module[{traversal, nPixels, imgSize,
          greyData, hsbData, rgbData,
          pixBright, pixHue, pixSat},
    imgSize   = 2^imgN;
    traversal = HilbertTraversalOrder[imgN];
    nPixels   = Length[traversal];
    greyData  = ImageData[ColorConvert[processedImg, "Grayscale"]];
    hsbData   = ImageData[ColorConvert[processedImg, "HSB"]];
    rgbData   = ImageData[ColorConvert[processedImg, "RGB"]];
    pixBright = Table[greyData[[ traversal[[i,2]], traversal[[i,1]]   ]], {i, nPixels}];
    pixHue    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 1 ]], {i, nPixels}];
    pixSat    = Table[hsbData[[ traversal[[i,2]], traversal[[i,1]], 2 ]], {i, nPixels}];
    <|
      "img"       -> processedImg,
      "imgN"      -> imgN,
      "imgSize"   -> imgSize,
      "traversal" -> traversal,
      "nPixels"   -> nPixels,
      "pixBright" -> pixBright,
      "pixHue"    -> pixHue,
      "pixSat"    -> pixSat,
      "rgbData"   -> rgbData
    |>
  ];

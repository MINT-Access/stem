(* images/src/sonify.wl — Per-pixel audio synthesis *)

(* Sonify the image in the named mode and write outWAV.
   Returns freqAssigned (per-pixel Hz list) for downstream CSV export.
   Requires $imgPalette from model.wl to be loaded. *)
SonifyImageMode[mode_String, model_Association,
               freqMin_?NumericQ, freqMax_?NumericQ,
               noteDur_?NumericQ, sr_Integer, outWAV_String] :=
  Module[{pixBright, pixHue, pixSat, rgbData, traversal, nPixels,
          freqAssigned, audioBuffer},
    pixBright    = model["pixBright"];
    pixHue       = model["pixHue"];
    pixSat       = model["pixSat"];
    rgbData      = model["rgbData"];
    traversal    = model["traversal"];
    nPixels      = model["nPixels"];
    freqAssigned = ConstantArray[0.0, nPixels];

    Which[

      (* Brightness: grayscale value linearly maps to frequency *)
      mode === "brightness",
        freqAssigned = freqMin + pixBright * (freqMax - freqMin);
        With[{fa = freqAssigned, nd = noteDur, sr0 = sr},
          audioBuffer = Flatten @ Table[
            StemSynthNote[fa[[i]], nd, 0.8, {1.0}, 0.2, sr0],
            {i, nPixels}
          ]
        ];
        ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
        STEMDescribeWAV[outWAV, N[nPixels * noteDur]];
        Print["  Mapping: dark pixels -> ", FmtN[freqMin, 5],
              " Hz;  bright pixels -> ", FmtN[freqMax, 5], " Hz"],

      (* Colour: nearest palette colour -> fixed musical pitch; runs merged *)
      mode === "colour",
        Module[{paletteRGBvals, colourIdxSeq, colourRuns},
          paletteRGBvals = Map[#["rgb"] &, $imgPalette];
          colourIdxSeq = Table[
            With[{pix = Take[rgbData[[ traversal[[i,2]], traversal[[i,1]] ]], 3]},
              First[Ordering[Map[Total[(pix - #)^2] &, paletteRGBvals], 1]]
            ],
            {i, nPixels}
          ];
          freqAssigned = Map[$imgPalette[[#]]["freq"] &, colourIdxSeq];
          colourRuns   = Split[colourIdxSeq];
          Print["  Palette colours found:   ",
                Length[DeleteDuplicates[colourIdxSeq]], " of ",
                Length[$imgPalette]];
          Print["  Consecutive colour runs: ", Length[colourRuns]];
          Print["  Mean run length:         ",
                FmtN[N[nPixels / Length[colourRuns]], {5,1}], " pixels"];
          audioBuffer = Flatten @ Map[
            Function[run,
              StemSynthNote[$imgPalette[[ First[run] ]]["freq"],
                Length[run] * noteDur, 0.8, {1.0, 0.30}, 0.5, sr]
            ],
            colourRuns
          ]
        ];
        ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
        STEMDescribeWAV[outWAV, N[nPixels * noteDur]],

      (* HSB: hue -> left freq, brightness -> right freq, saturation -> amplitude *)
      mode === "hsb",
        Module[{fLo = 100.0, fHi = 3900.0, freqL, freqR, amp,
                leftBuf, rightBuf, snd},
          freqL = fLo + pixHue    * (fHi - fLo);
          freqR = fLo + pixBright * (fHi - fLo);
          amp   = Map[Max[0.10, #] &, pixSat];
          freqAssigned = freqL;
          leftBuf  = NormalizeBuffer[
            Flatten @ Table[StemSynthNote[freqL[[i]], noteDur, amp[[i]], {1.0}, 0.1, sr],
                            {i, nPixels}],
            0.92];
          rightBuf = NormalizeBuffer[
            Flatten @ Table[StemSynthNote[freqR[[i]], noteDur, amp[[i]], {1.0}, 0.1, sr],
                            {i, nPixels}],
            0.92];
          EnsureDir[outWAV];
          snd = Sound[SampledSoundList[{leftBuf, rightBuf}, sr]];
          Export[outWAV, snd, "WAV"]
        ];
        STEMDescribeWAV[outWAV, N[nPixels * noteDur]];
        Print["  Left:  hue        -> freq 100-3900 Hz"];
        Print["  Right: brightness -> freq 100-3900 Hz"];
        Print["  Both:  saturation -> amplitude (min 0.10)"],

      True,
        Print["Error: unknown simulation.mode \"", mode,
              "\" -- expected \"brightness\", \"colour\", or \"hsb\"."];
        Exit[1]
    ];
    freqAssigned
  ];

(* ========================================================
   mandelbrot/src/sonify.wl — Hilbert-traversal sonification,
   reusing images/'s brightness-to-frequency log-mapping technique
   directly (iteration count standing in for "brightness")

   All three modes share ONE per-pixel note stream, one StemSynthNote
   per Hilbert-traversal position, exactly images/brightness mode's
   own pipeline — the only thing that changes between modes is which
   iteration-count field drives the mapping. Slow-escaping/non-
   escaping points (near or inside the set) map to the HIGH end of the
   frequency range, fast-escaping points to the LOW end (a deliberate,
   documented choice — see AGENTS.md design decision 5; there is no
   literal "brightness" here, so the direction is this app's own
   convention, not a physical fact).
   ======================================================== *)


(* IterationToFreq — images/model.wl's BrightnessToFreq log-scale
   formula, duplicated (per this codebase's no-shared-src/ convention)
   and applied to a normalised iteration ratio in [0,1] instead of
   grayscale brightness. *)
IterationToFreq[ratio_?NumericQ, freqMin_?NumericQ, freqMax_?NumericQ] :=
  freqMin * (freqMax / freqMin)^ratio;

(* AddQuadrantClicks — images/sonify.wl's own orientation-click
   pattern, duplicated: three brief 880 Hz clicks at 25%/50%/75% of the
   traversal, so a listener can track spatial progress. *)
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

AddQuadrantClicks[buffer_List, sr_Integer, nPixels_Integer, noteDurationBase_?NumericQ] :=
  Module[{buf = buffer, marks, totalDur},
    totalDur = nPixels * noteDurationBase;
    marks = {{0.25, 10^(-20/20.0)}, {0.50, 10^(-15/20.0)}, {0.75, 10^(-20/20.0)}};
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
  ];

(* BuildFieldAudio — the shared per-pixel note stream: iterField (one
   value per Hilbert-traversal position) -> normalised ratio -> freq
   (log scale) -> one StemSynthNote per pixel, concatenated in
   traversal order. *)
BuildFieldAudio[iterField_List, maxIter_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                noteDurationBase_?NumericQ, sr_Integer] :=
  Module[{nPixels, ratios, freqs, audioBuffer},
    nPixels = Length[iterField];
    ratios  = N[iterField] / N[maxIter];
    freqs   = IterationToFreq[#, freqMin, freqMax] & /@ ratios;
    audioBuffer = Flatten @ Table[
      StemSynthNote[freqs[[i]], noteDurationBase, 0.8, {1.0}, 0.2, sr],
      {i, nPixels}
    ];
    audioBuffer = NormalizeBuffer[audioBuffer, 0.92];
    {audioBuffer, freqs}
  ];


(* ── Mode 1: mandelbrot ───────────────────────────────────────────── *)

BuildMandelbrotAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                     noteDurationBase_?NumericQ, sr_Integer] :=
  Module[{buffer, freqs},
    {buffer, freqs} = BuildFieldAudio[model["iterField"], model["maxIter"], freqMin, freqMax, noteDurationBase, sr];
    buffer = AddQuadrantClicks[buffer, sr, model["nPixels"], noteDurationBase];
    {buffer, freqs}
  ];


(* ── Mode 2: julia ────────────────────────────────────────────────── *)

BuildJuliaAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
               noteDurationBase_?NumericQ, sr_Integer] :=
  Module[{buffer, freqs},
    {buffer, freqs} = BuildFieldAudio[model["iterField"], model["maxIter"], freqMin, freqMax, noteDurationBase, sr];
    buffer = AddQuadrantClicks[buffer, sr, model["nPixels"], noteDurationBase];
    {buffer, freqs}
  ];


(* ── Mode 3: zoom — one combined WAV, a chime marks each new level ─── *)

ZoomLevelChime[level_Integer, sr_Integer] :=
  StemSynthNote[220.0 * 1.5^level, 0.25, 0.6, {1.0, 0.3, 0.15}, 0.4, sr];

BuildZoomAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
              noteDurationBase_?NumericQ, sr_Integer] :=
  Module[{levels, pieces, allFreqs, gap},
    levels = model["levels"];
    gap = ConstantArray[0.0, Round[0.2 * sr]];
    allFreqs = {};
    pieces = Table[
      Module[{buffer, freqs, chime},
        {buffer, freqs} = BuildFieldAudio[levels[[k]]["iterField"], model["maxIter"], freqMin, freqMax, noteDurationBase, sr];
        AppendTo[allFreqs, freqs];
        chime = ZoomLevelChime[k, sr];
        Join[chime, gap, buffer, gap]
      ],
      {k, Length[levels]}
    ];
    {Flatten[pieces], allFreqs}
  ];

(* ========================================================
   src/sonify.wl — Musical sonification of the Lorenz system

   Maps the Lorenz trajectory to audio using direct PCM
   waveform synthesis (no MIDI, works headlessly).

   Design:
     The x-coordinate of the Lorenz system oscillates
     irregularly between the two wings of the butterfly.
     We sonify this as a continuous melody:

     Pitch    — x(t) mapped to a musical scale.
                Positive x (right wing) → upper register.
                Negative x (left wing)  → lower register.
                Wing-jumps sound like melodic leaps.

     Rhythm   — notes triggered at each local extremum of x(t)
                (peaks and troughs), so the rhythm follows
                the natural oscillation of the attractor.

     Volume   — proportional to |x| at each extremum:
                deep swings into a wing are loud.

     Timbre   — additive sine synthesis with harmonics and
                an exponential decay envelope.
                Warm, bell-like tone.

   Scale, synthesis, and export helpers come from stem-core.
   ======================================================== *)


(* FindExtrema
   Returns {time, x-value} at each local peak and trough
   of the x-coordinate. These are the natural "beats"
   of the Lorenz oscillation. *)

FindExtrema[solution_List] :=
  Module[{xs, triples, extrema},
    xs      = solution[[All, 2]];
    triples = Partition[Range[Length[xs]], 3, 1];
    extrema = Select[triples,
      (xs[[#[[2]]]] > xs[[#[[1]]]] && xs[[#[[2]]]] > xs[[#[[3]]]]) ||
      (xs[[#[[2]]]] < xs[[#[[1]]]] && xs[[#[[2]]]] < xs[[#[[3]]]]) &
    ];
    {solution[[#[[2]], 1]], solution[[#[[2]], 2]]} & /@ extrema
  ]


(* BuildWaveform
   Assembles note samples into a single PCM buffer. *)

BuildWaveform[extrema_List, maxX_?NumericQ,
              scale_List, sr_Integer] :=
  Module[
    {totalDur, nTotal, buffer, pairs, maxAbs},

    If[Length[extrema] < 2, Return[{0.0}]];

    totalDur = Last[extrema][[1]];
    nTotal   = Ceiling[totalDur * sr];
    buffer   = ConstantArray[0.0, nTotal];
    pairs    = Partition[extrema, 2, 1];
    maxAbs   = Max[Abs[extrema[[All, 2]]]] + 0.001;

    Scan[
      Function[pair,
        Module[{tStart, tEnd, dur, xVal, vol, freq,
                samples, startIdx, endIdx},
          tStart   = pair[[1, 1]];
          tEnd     = pair[[2, 1]];
          dur      = tEnd - tStart;
          xVal     = pair[[1, 2]];
          vol      = Rescale[Abs[xVal], {0, maxAbs}, {0.2, 1.0}];
          freq     = ScaleLookup[xVal, -maxX, maxX, scale, 261.63];
          samples  = StemSynthNote[freq, dur, vol, {1.00, 0.35, 0.12}, 0.5, sr];
          startIdx = Max[1, Round[tStart * sr] + 1];
          endIdx   = Min[nTotal, startIdx + Length[samples] - 1];
          buffer[[startIdx ;; endIdx]] +=
            samples[[1 ;; (endIdx - startIdx + 1)]];
        ]
      ],
      pairs
    ];

    NormalizeBuffer[buffer]
  ]


(* ExportSonification — main entry point *)

Options[ExportSonification] = {"Scale" -> "MinorPentatonic"};

ExportSonification[solution_List, filePath_String,
                   opts:OptionsPattern[]] :=
  Module[
    {scaleName, scale, extrema, maxX, buffer},

    scaleName = OptionValue["Scale"];
    scale     = Lookup[$StemScales, scaleName, $StemScales["MinorPentatonic"]];

    Print["  Scale:    ", scaleName];
    extrema = FindExtrema[solution];
    Print["  Extrema (note events): ", Length[extrema]];

    If[Length[extrema] < 2,
      Print["  Warning: too few extrema. Try TimeEnd >= 10."];
      Return[$Failed]
    ];

    maxX = Max[Abs[solution[[All, 2]]]];

    Print["  Synthesising at ", $StemSampleRate, " Hz..."];
    buffer = BuildWaveform[extrema, maxX, scale, $StemSampleRate];

    Print["  Duration: ",
      FmtN[Length[buffer] / $StemSampleRate, 4], " s"];
    ExportAudioBuffer[buffer, filePath, $StemSampleRate]
  ]

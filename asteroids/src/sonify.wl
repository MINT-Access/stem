(* ========================================================
   src/sonify.wl — Musical sonification of asteroid data

   Each asteroid becomes one note, played in order of
   miss distance (farthest first, building toward the
   closest). Direct PCM synthesis — works headlessly.

   Design:
     Pitch    — miss distance → scale degree.
                Farthest = highest note (safe, distant).
                Closest  = lowest note (ominous, near).

     Duration — proportional to asteroid velocity.
                Fast asteroids = short sharp notes.
                Slow asteroids = long sustained notes.

     Volume   — proportional to estimated diameter.
                Bigger asteroids are louder.

     Timbre   — safe asteroids: warm sine tone (bell).
                hazardous asteroids: brighter tone with
                extra high harmonics — distinctly different
                character so you can hear the difference.

     Gap      — a short silence between notes gives the
                sequence a clear rhythm.

   Scale, synthesis, and export helpers come from stem-core.
   ======================================================== *)


(* BuildWaveform
   Assembles notes into a PCM buffer, farthest to closest. *)

BuildWaveform[asteroids_List, scale_List, sr_Integer,
              noteDur_?NumericQ, gapDur_?NumericQ] :=
  Module[
    {sorted, minKm, maxKm, maxDiam,
     stepSamples, gapSamples, nTotal, buffer,
     maxVel},

    (* Play farthest → closest: dramatic build toward the near miss *)
    sorted  = Reverse[asteroids];

    minKm   = Min[#["missDistanceKm"] & /@ asteroids];
    maxKm   = Max[#["missDistanceKm"] & /@ asteroids];
    maxDiam = Max[#["diamMeanKm"]     & /@ asteroids] + 0.001;
    maxVel  = Max[#["velocityKmS"]    & /@ asteroids] + 0.001;

    stepSamples = Round[(noteDur + gapDur) * sr];
    gapSamples  = Round[gapDur * sr];
    nTotal      = stepSamples * Length[sorted] + gapSamples;
    buffer      = ConstantArray[0.0, nTotal];

    MapIndexed[
      Function[{ast, idx},
        Module[{i, freq, vol, dur, harmonics, samples, startIdx, endIdx},
          i        = idx[[1]];
          freq     = ScaleLookup[ast["missDistanceKm"],
                       minKm, maxKm, scale, 130.81];
          vol      = Rescale[ast["diamMeanKm"],
                       {0, maxDiam}, {0.25, 1.0}];
          (* Faster asteroids → shorter, punchier notes *)
          dur      = Rescale[ast["velocityKmS"],
                       {Min[#["velocityKmS"] & /@ asteroids], maxVel},
                       {noteDur, noteDur * 0.3}];
          harmonics = If[ast["isHazardous"],
            {1.00, 0.30, 0.20, 0.25, 0.15},   (* bright/harsh *)
            {1.00, 0.35, 0.10}                  (* warm bell    *)
          ];
          samples  = StemSynthNote[freq, dur, vol, harmonics, 0.6, sr];
          startIdx = (i - 1) * stepSamples + 1;
          endIdx   = Min[nTotal, startIdx + Length[samples] - 1];
          buffer[[startIdx ;; endIdx]] +=
            samples[[1 ;; endIdx - startIdx + 1]];
        ]
      ],
      sorted
    ];

    NormalizeBuffer[buffer]
  ]


(* ExportSonification *)

Options[ExportSonification] = {
  "Scale"        -> "MinorPentatonic",
  "NoteDuration" -> 0.55,    (* seconds per note *)
  "GapDuration"  -> 0.12     (* silence between notes *)
};

ExportSonification[asteroids_List, filePath_String,
                   opts:OptionsPattern[]] :=
  Module[
    {scaleName, scale, noteDur, gapDur, buffer},

    scaleName = OptionValue["Scale"];
    scale     = Lookup[$StemScales, scaleName, $StemScales["MinorPentatonic"]];
    noteDur   = OptionValue["NoteDuration"];
    gapDur    = OptionValue["GapDuration"];

    Print["  Scale: ", scaleName, "  notes: ", Length[asteroids]];
    Print["  Hazardous (distinct timbre): ",
      Length[HazardousAsteroids[asteroids]]];

    buffer = BuildWaveform[asteroids, scale, $StemSampleRate,
                           noteDur, gapDur];

    Print["  Duration: ",
      FmtN[Length[buffer] / $StemSampleRate, 4], " s"];
    ExportAudioBuffer[buffer, filePath, $StemSampleRate]
  ]

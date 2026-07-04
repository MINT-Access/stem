(* ========================================================
   src/sonify.wl — Cellular automata sonification (run-length notes)

   Converts a 3D grid array into audio using run-length note
   articulation: a new note is only started when population changes
   significantly (the articulation threshold); consecutive stable
   generations are grouped into a single held note. Stable periods
   sound like one sustained tone; volatile periods produce rapid
   note sequences. This replaces the previous continuous
   per-generation pitch glissando (stem-core's SpatialLayer /
   MotionLayer) with discrete, musically legible notes synthesised
   directly via stem-core's StemSynthNote.

   Pipeline:
     1. GridToTrajectory       — per-generation pan (left/right density
                                 asymmetry), unchanged from the original
                                 implementation.
     2. ComputeArticulations   — decides which generations start a
                                 new note, based on relative or
                                 absolute population change.
     3. ComputeRuns            — groups generations into runs, one
                                 run per note.
     4. BuildNoteAudio         — synthesises one note per run into a
                                 stereo buffer (pitch = mean population
                                 via minor-pentatonic ScaleLookup,
                                 volume = max |Δpop| in the run,
                                 pan = mean trajectory pan over the run).
     5. DetectPopulationEvents — extinction/explosion detection,
                                 unchanged from the original
                                 implementation.
     6. SynthBurst accent tones for those events are additively
        mixed into the same stereo buffer, panned by their own
        generation's pan value.

   Trajectory column mapping (from GridToTrajectory):
     t     — generation number (time axis)
     x     — (left_pop − right_pop) / cols  [pan: left/right asymmetry]
     y     — total_pop / total_cells         [retained for API
                                              stability; no longer
                                              consumed by pitch mapping]
     z     — 0.0
     speed — |Δpopulation| + ε              [retained for API
                                              stability; volume now
                                              comes from run-level
                                              max delta instead]

   Events:
     extinction — population drops > 40% in one step → 150 Hz low burst
     explosion  — population rises > 40% in one step → 900 Hz high burst

   Output CSV: alongside the WAV, a `{name}_data.csv` is written with
   one row per generation — population, articulated (1 = new note
   started here), run_length (length of the run this generation
   belongs to). See ExportArticulationCSV.
   ======================================================== *)


(* GridToTrajectory — unchanged from the original implementation.
   Retained for its pan (left/right asymmetry) column and for API
   stability; density/speed columns are no longer consumed by the
   note-based pitch/volume mapping below. *)

GridToTrajectory[grid3D_List, cfg_Association] :=
  Module[{nGen, nRows, nCols, halfCols,
          populations, leftPop, rightPop,
          pan, density, delta, zeros, t},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    halfCols = Floor[nCols / 2];

    populations = N[Total[grid3D, {2, 3}]];
    leftPop     = N[Total[grid3D[[All, All, 1 ;; halfCols]], {2, 3}]];
    rightPop    = N[Total[grid3D[[All, All, halfCols + 1 ;; nCols]], {2, 3}]];

    pan     = (leftPop - rightPop) / N[nCols];
    density = populations / N[nRows * nCols];
    delta   = Append[Abs[Differences[populations]], 0.0] + 0.01;

    zeros = ConstantArray[0.0, nGen];
    t     = N[Range[0, nGen - 1]];

    Transpose[{t, pan, density, zeros, delta}]
  ]


(* SynthBurst
   Short exponentially-decaying sine burst used for extinction and
   explosion accent tones. Numerically unchanged from the original
   inline code (amp 0.45, decay rate -8/burstLen). *)

SynthBurst[freq_?NumericQ, sr_Integer, burstLen_Integer, amp_:0.45] :=
  amp * Table[Sin[2 Pi * freq * i / sr] * Exp[-8 i / burstLen],
              {i, 0, burstLen - 1}]


(* DetectPopulationEvents
   Unchanged event-detection logic: fractional population change
   between consecutive generations. >40% drop = extinction, >40%
   rise = explosion. Returns 0-indexed generation numbers (the
   earlier generation of each transition pair), the same convention
   as the pre-refactor implementation. Guards prev == 0 before
   dividing. Independent of note articulation — run-length grouping
   below has no effect on event detection or these accent tones. *)

DetectPopulationEvents[populations_List, cfg_Association] :=
  Module[{nGen, extinctions, explosions, extinctEnabled, explosEnabled, prev, cur, frac},
    nGen = Length[populations];
    extinctions = {};
    explosions  = {};
    extinctEnabled = GetCfg[cfg, {"sonification","events","extinction"}, True];
    explosEnabled  = GetCfg[cfg, {"sonification","events","explosion"},  True];

    Do[
      prev = populations[[g]];
      cur  = populations[[g + 1]];
      If[prev > 0,
        frac = (cur - prev) / prev;
        If[extinctEnabled && frac < -0.4, AppendTo[extinctions, g - 1]];
        If[explosEnabled  && frac >  0.4, AppendTo[explosions,  g - 1]]
      ],
      {g, 1, nGen - 1}
    ];

    <| "extinctions" -> extinctions, "explosions" -> explosions |>
  ]


(* ComputeArticulations
   Run-length encodes a population series into note articulation
   points. A new articulation occurs at generation g (1-indexed,
   g > 1) when the change from g-1 to g exceeds the configured
   threshold:
     relative mode (default) — |Δpop| / max(pop_{g-1}, 1) > threshold
     absolute mode           — |Δpop| > threshold_abs
   Generation 1 always articulates (there is no prior value to
   compare against). Returns a 0/1 list the same length as
   populations. *)

ComputeArticulations[populations_List, cfg_Association] :=
  Module[{nGen, mode, threshRel, threshAbs, articulated, prev, cur, changed},
    nGen = Length[populations];
    mode      = GetCfg[cfg, {"simulation","cellular","articulation_mode"},         "relative"];
    threshRel = GetCfg[cfg, {"simulation","cellular","articulation_threshold"},     0.15];
    threshAbs = GetCfg[cfg, {"simulation","cellular","articulation_threshold_abs"}, 5];

    articulated = ConstantArray[0, nGen];
    If[nGen > 0, articulated[[1]] = 1];

    Do[
      prev = populations[[g - 1]];
      cur  = populations[[g]];
      changed = If[mode === "absolute",
        Abs[cur - prev] > threshAbs,
        Abs[cur - prev] / Max[prev, 1] > threshRel
      ];
      If[changed, articulated[[g]] = 1],
      {g, 2, nGen}
    ];

    articulated
  ]


(* ComputeRuns
   Groups consecutive generations into runs using the articulation
   points from ComputeArticulations. Each run captures the data
   needed to synthesise exactly one note:
     start, end — 1-indexed generation range (inclusive)
     length     — number of generations in the run
     meanPop    — mean population over the run (pitch source)
     maxDelta   — max |Δpop| within the run, including the transition
                  that started it, so single-generation runs still
                  carry a meaningful volume signal (volume source)
   Also returns a per-generation runLength list (each generation
   tagged with the length of the run it belongs to) for CSV export. *)

ComputeRuns[populations_List, cfg_Association] :=
  Module[{nGen, articulated, starts, runs, runLengthPerGen},
    nGen = Length[populations];
    articulated = ComputeArticulations[populations, cfg];
    starts = Flatten[Position[articulated, 1]];

    runs = Table[
      Module[{s, e, popsInRun, prevPop, deltasInRun},
        s = starts[[i]];
        e = If[i < Length[starts], starts[[i + 1]] - 1, nGen];
        popsInRun   = populations[[s ;; e]];
        prevPop     = If[s > 1, populations[[s - 1]], popsInRun[[1]]];
        deltasInRun = Abs[Differences[Prepend[popsInRun, prevPop]]];
        <|
          "start"    -> s,
          "end"      -> e,
          "length"   -> e - s + 1,
          "meanPop"  -> Mean[popsInRun],
          "maxDelta" -> Max[deltasInRun]
        |>
      ],
      {i, Length[starts]}
    ];

    runLengthPerGen = ConstantArray[0, nGen];
    Do[
      Do[runLengthPerGen[[g]] = run["length"], {g, run["start"], run["end"]}],
      {run, runs}
    ];

    <| "runs" -> runs, "articulated" -> articulated, "runLength" -> runLengthPerGen |>
  ]


(* RunNoteDuration
   Note duration for a run of the given length: runLength ×
   baseNoteDuration. Exposed as its own function so it can be
   unit-tested directly against the spec (e.g. a run of length 10 at
   0.06 s/generation = 0.6 s). BuildNoteAudio computes the
   sample-accurate equivalent internally (see gensSoFar below) so
   consecutive notes align exactly on the sample grid; the two agree
   to within a single sample of rounding. *)

RunNoteDuration[runLength_Integer, baseNoteDuration_?NumericQ] :=
  N[runLength * baseNoteDuration]


(* ResolveBaseNoteDuration
   base_note_duration can be overridden per simulation mode — e.g.
   simulation.cellular.rule110.base_note_duration — so a different
   default tempo can apply to rule110 without changing life's. Falls
   back to the shared simulation.cellular.base_note_duration if no
   mode-specific override is present. *)

ResolveBaseNoteDuration[cfg_Association] :=
  Module[{mode, sharedDefault},
    mode          = GetCfg[cfg, {"simulation","mode"}, "life"];
    sharedDefault = GetCfg[cfg, {"simulation","cellular","base_note_duration"}, 0.06];
    GetCfg[cfg, {"simulation","cellular", mode, "base_note_duration"}, sharedDefault]
  ]


(* BuildNoteAudio
   Synthesises one held note per run into a stereo buffer.
     Pitch    — mean population of the run, mapped onto the minor
                pentatonic scale via ScaleLookup (rootHz =
                sonification.pitch.min_hz).
     Volume   — max |Δpop| within the run, rescaled to the
                configured dB range across all runs.
     Pan      — mean of the per-generation pan trajectory over the run.
     Duration — run length × base_note_duration, computed from a
                running generation count (gensSoFar) so successive
                notes align exactly on the sample grid with no
                rounding drift. *)

BuildNoteAudio[runs_List, pan_List, populations_List, cfg_Association, sr_Integer] :=
  Module[{baseNoteDur, rootHz, scale, minPop, maxPop,
          volMin, volMax, allMaxDeltas, minDelta, maxDeltaRange,
          nGen, nSamples, audioL, audioR, gensSoFar, harmonics, decayFrac},

    baseNoteDur = ResolveBaseNoteDuration[cfg];
    rootHz      = GetCfg[cfg, {"sonification","pitch","min_hz"}, 150];
    scale       = $StemScales["MinorPentatonic"];

    nGen     = Length[populations];
    nSamples = Round[sr * nGen * baseNoteDur];
    audioL   = ConstantArray[0.0, nSamples];
    audioR   = ConstantArray[0.0, nSamples];

    minPop = Min[populations];
    maxPop = Max[populations];
    If[maxPop == minPop, maxPop = minPop + 1.0];

    volMin = GetCfg[cfg, {"sonification","volume","min_db"}, -24];
    volMax = GetCfg[cfg, {"sonification","volume","max_db"},   0];

    allMaxDeltas  = (#["maxDelta"] & /@ runs);
    minDelta      = Min[allMaxDeltas];
    maxDeltaRange = Max[allMaxDeltas];
    If[maxDeltaRange == minDelta, maxDeltaRange = minDelta + 1.0];

    harmonics = {1.0, 0.3, 0.1};
    decayFrac = 1.2;   (* gentle decay — long runs still read as "sustained" *)

    gensSoFar = 0;
    Do[
      Module[{run, startSample, endSample, dur, meanPanVal,
              freq, ampDb, amp, note, leftGain, rightGain, placeEnd},
        run = runs[[i]];

        startSample = Round[gensSoFar * baseNoteDur * sr] + 1;
        gensSoFar  += run["length"];
        endSample   = Round[gensSoFar * baseNoteDur * sr];
        dur         = N[(endSample - startSample + 1) / sr];

        meanPanVal = Mean[pan[[run["start"] ;; run["end"]]]];
        freq       = ScaleLookup[run["meanPop"], minPop, maxPop, scale, rootHz];
        ampDb      = Rescale[run["maxDelta"], {minDelta, maxDeltaRange}, {volMin, volMax}];
        amp        = 10.0^(ampDb / 20.0);

        note = StemSynthNote[freq, dur, amp, harmonics, decayFrac, sr];

        leftGain  = Sqrt[(1.0 - meanPanVal) / 2.0];
        rightGain = Sqrt[(1.0 + meanPanVal) / 2.0];

        placeEnd = Min[startSample + Length[note] - 1, nSamples];
        If[placeEnd >= startSample,
          audioL[[startSample ;; placeEnd]] +=
            leftGain  * note[[1 ;; placeEnd - startSample + 1]];
          audioR[[startSample ;; placeEnd]] +=
            rightGain * note[[1 ;; placeEnd - startSample + 1]]
        ]
      ],
      {i, Length[runs]}
    ];

    <| "left" -> audioL, "right" -> audioR, "nSamples" -> nSamples |>
  ]


(* ExportArticulationCSV
   Writes the per-generation articulation record alongside the WAV:
   generation (0-indexed, matching ExportCellularStats's convention),
   population, articulated (1 = new note started here), run_length
   (length of the run this generation belongs to). The path is
   derived from outPath by replacing "_audio.wav" with "_data.csv" so
   filenames stay predictable (life_rpentomino_data.csv,
   rule110_data.csv) without threading the pattern/mode name through
   this function. *)

ExportArticulationCSV[populations_List, articulated_List, runLength_List, outPath_String] :=
  Module[{dataPath, header, rows},
    dataPath = If[StringContainsQ[outPath, "_audio.wav"],
      StringReplace[outPath, "_audio.wav" -> "_data.csv"],
      FileNameJoin[{DirectoryName[outPath], "cellular_data.csv"}]
    ];

    header = {{"generation", "population", "articulated", "run_length"}};
    rows = Table[
      {g - 1, populations[[g]], articulated[[g]], runLength[[g]]},
      {g, 1, Length[populations]}
    ];

    ExportCSV[Join[header, rows], dataPath];
    dataPath
  ]


(* SonifyCellular
   Main entry point: produces a stereo WAV at outPath using
   run-length note articulation for pitch/volume/duration, plus the
   original extinction/explosion accent-tone overlay. Also writes the
   companion articulation CSV. *)

SonifyCellular[grid3D_List, cfg_Association, outPath_String] :=
  Module[
    {nGen, nRows, nCols, populations, trajectory, pan, panRange,
     panMin, panMax, sr,
     runsInfo, runs, articulated, runLength,
     noteAudio, audioL, audioR, nSamples,
     events, extinctions, explosions, burstLen, idx,
     genToSample, stereo},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    populations = N[Total[grid3D, {2, 3}]];

    trajectory = GridToTrajectory[grid3D, cfg];

    (* Raw pan is (left_pop - right_pop) / nCols, which is NOT bounded
       to [-1, 1] — population counts can exceed the column count.
       Rescale + clip it into the configured pan range, exactly as
       SpatialLayer did for the previous continuous-glissando mix,
       before it is ever used in a constant-power pan law (an
       unclipped pan would drive Sqrt[(1 ± pan)/2] negative and
       silently produce complex samples). *)
    panRange = GetCfg[cfg, {"sonification","spatial","pan_range"}, {-1.0, 1.0}];
    panMin   = Min[trajectory[[All, 2]]];
    panMax   = Max[trajectory[[All, 2]]];
    pan      = If[panMax == panMin,
      ConstantArray[0.0, nGen],
      Clip[Rescale[trajectory[[All, 2]], {panMin, panMax}, panRange], panRange]
    ];

    sr = GetCfg[cfg, {"sonification","sample_rate"}, 44100];

    runsInfo    = ComputeRuns[populations, cfg];
    runs        = runsInfo["runs"];
    articulated = runsInfo["articulated"];
    runLength   = runsInfo["runLength"];

    noteAudio = BuildNoteAudio[runs, pan, populations, cfg, sr];
    audioL    = noteAudio["left"];
    audioR    = noteAudio["right"];
    nSamples  = noteAudio["nSamples"];

    (* ── Event detection and accent tones (unchanged logic) ── *)
    events      = DetectPopulationEvents[populations, cfg];
    extinctions = events["extinctions"];
    explosions  = events["explosions"];
    burstLen    = Round[0.06 * sr];

    genToSample[g0_] :=
      Clip[Round[g0 / Max[nGen - 1, 1] * nSamples], {1, nSamples}];

    (* Low burst (150 Hz) for each extinction, panned by local density asymmetry *)
    Do[
      idx = genToSample[g];
      With[{panAtEvent = pan[[g + 1]],
            end        = Min[idx + burstLen - 1, nSamples]},
        With[{leftGain  = Sqrt[(1.0 - panAtEvent) / 2.0],
              rightGain = Sqrt[(1.0 + panAtEvent) / 2.0],
              burst     = SynthBurst[150, sr, burstLen]},
          audioL[[idx ;; end]] += leftGain  * burst[[1 ;; end - idx + 1]];
          audioR[[idx ;; end]] += rightGain * burst[[1 ;; end - idx + 1]]
        ]
      ],
      {g, extinctions}
    ];

    (* High burst (900 Hz) for each explosion, panned by local density asymmetry *)
    Do[
      idx = genToSample[g];
      With[{panAtEvent = pan[[g + 1]],
            end        = Min[idx + burstLen - 1, nSamples]},
        With[{leftGain  = Sqrt[(1.0 - panAtEvent) / 2.0],
              rightGain = Sqrt[(1.0 + panAtEvent) / 2.0],
              burst     = SynthBurst[900, sr, burstLen]},
          audioL[[idx ;; end]] += leftGain  * burst[[1 ;; end - idx + 1]];
          audioR[[idx ;; end]] += rightGain * burst[[1 ;; end - idx + 1]]
        ]
      ],
      {g, explosions}
    ];

    Print["  Articulation: ", Length[runs], " notes over ", nGen, " generations (",
      FmtN[N[nGen] / Length[runs], 4], " gens/note avg)"];
    Print["  Extinctions (>40% drop): ", Length[extinctions]];
    Print["  Explosions  (>40% rise): ", Length[explosions]];
    Print["  Audio duration: ", FmtN[N[nSamples] / sr, 4], " s"];

    ExportArticulationCSV[populations, articulated, runLength, outPath];

    stereo = Transpose[{audioL, audioR}];

    EnsureDir[outPath];
    RenderAudio[stereo, cfg, outPath]
  ]

(* ========================================================
   henon/src/sonify.wl — Two deliberately different techniques
   for two deliberately different modes.

   `attractor` reuses lorenz/'s continuous SonifyTrajectory
   pipeline: build a {t,x,y,z,speed} matrix and hand it to
   stem-core, which drives pan/pitch/volume from configurable
   trajectory columns and detects "apex" events itself. This is
   the right tool when the point is the continuous, flowing
   character of riding the attractor.

   `sweep` and `reverse` instead reuse dynamical/'s discrete
   note-per-point idiom: a burst of sound synthesised and
   Part-assigned directly into pre-allocated stereo buffers at
   precise attack times. This is the right tool when the point
   is that individual iterates (and their period) must be
   audibly countable — exactly why dynamical/ chose it for the
   logistic map's rhythm, and exactly why it matters here too:
   sweep's whole narrative is "how many notes before it repeats?"
   See AGENTS.md for the full rationale on why these two modes
   do NOT share one technique.
   ======================================================== *)


(* ── attractor mode: lorenz-style continuous trajectory ────────────
   Column mapping (stem-core defaults, unchanged from lorenz/'s
   own config): pan_axis="x" so Hénon's x_n drives stereo pan;
   pitch_axis="y" so Hénon's y_n drives pitch; apex events fire on
   local maxima of |y_n| — since y_n = b*x_{n-1} is a scaled, one-
   step-lagged copy of x, this lands on the same folding/turning
   points of the attractor a listener would expect an "apex" to be.
   z is unused (Hénon is a 2D map) and set to 0 throughout. Speed is
   a 2D finite-difference speed (not lorenz's 3D one) and drives
   volume via stem-core's SpatialLayer, exactly as in lorenz/. *)
BuildAttractorTrajectory[attractorModel_Association] :=
  Module[{traj, n, xs, ys, vx, vy, speeds, t},
    traj = attractorModel["trajectory"];
    n    = Length[traj];
    xs   = traj[[All, 1]];
    ys   = traj[[All, 2]];
    vx   = Append[Differences[xs], 0.0];
    vy   = Append[Differences[ys], 0.0];
    speeds = Sqrt[vx^2 + vy^2];
    t    = N[Range[0, n - 1]];
    N[MapThread[{#1, #2, #3, 0.0, #4} &, {t, xs, ys, speeds}]]
  ];

(* AttractorStereoBuffer — calls stem-core's three layers directly
   (SpatialLayer/MotionLayer/EventLayer -> MixLayers) rather than the
   one-shot SonifyTrajectory[..., filePath], which writes straight to
   disk via RenderAudio and returns only a file path. Getting the
   {left,right} arrays back here lets main.wl prepend a spoken intro
   buffer before export — the same reason montecarlo/src/sonify.wl
   calls these layers directly instead of SonifyTrajectory. *)
AttractorStereoBuffer[attractorModel_Association, cfg_Association] :=
  Module[{trajectory, sp, mo, ev, stereo},
    trajectory = BuildAttractorTrajectory[attractorModel];
    sp = SpatialLayer[trajectory, cfg];
    mo = MotionLayer[trajectory, cfg];
    ev = EventLayer[trajectory, cfg, {"apex"}];
    stereo = MixLayers[sp, mo, ev, cfg];
    {stereo[[All, 1]], stereo[[All, 2]]}
  ];


(* ── shared discrete-note synthesiser (sweep + reverse) ──────────── *)

(* HenonPitchScale — minor pentatonic across 3 octaves, duplicated
   from dynamical/src/sonify.wl's PitchScale3Octaves per this
   codebase's convention that apps don't import each other's src/
   files (only stem-core is shared). *)
HenonPitchScale[] :=
  Join[Flatten[Table[{0, 3, 5, 7, 10} + 12 * k, {k, 0, 2}]], {36}];

$henonRootHz = 130.81;  (* C3, matching dynamical/'s discrete-note root *)


(* SynthesizeDiscreteNotesHenon
   pitchVals, panVals, speeds, times are parallel lists. Unlike
   dynamical/'s logistic map (always in [0,1] by construction),
   Hénon's x and y ranges depend on (a,b) and aren't known ahead
   of time, so pitchRange/panRange are passed in explicitly —
   computed by the caller from the actual data (MinMax), the same
   data-driven spirit as speedMax below. Pitch from pitchVals via
   ScaleLookup; pan from panVals rescaled to [-1,1]; volume from
   speeds rescaled to [0.25,0.95]. Returns {leftBuf,rightBuf,nSamples}. *)
SynthesizeDiscreteNotesHenon[pitchVals_List, panVals_List, speeds_List, times_List,
                             pitchRange_List, panRange_List,
                             noteDuration_?NumericQ, sr_Integer] :=
  Module[{n, pitchScale, speedMax, nSamples, toneSamples,
          leftBuf, rightBuf, freq, pan, amp, mono, start, len},
    n           = Length[pitchVals];
    pitchScale  = HenonPitchScale[];
    speedMax    = Max[speeds];
    If[speedMax <= 0, speedMax = 1.0];
    toneSamples = Round[noteDuration * sr];
    nSamples    = Round[(Last[times] + noteDuration) * sr] + 1;
    leftBuf     = ConstantArray[0.0, nSamples];
    rightBuf    = ConstantArray[0.0, nSamples];

    Do[
      freq  = ScaleLookup[pitchVals[[i]], pitchRange[[1]], pitchRange[[2]], pitchScale, $henonRootHz];
      pan   = Clip[Rescale[panVals[[i]], panRange, {-1.0, 1.0}], {-1.0, 1.0}];
      amp   = Clip[0.25 + 0.70 * (speeds[[i]] / speedMax), {0.25, 0.95}];
      mono  = StemSynthNote[freq, noteDuration, amp, {1.0, 0.25}, 0.35, sr];
      start = Clip[Round[times[[i]] * sr] + 1, {1, nSamples}];
      len   = Min[toneSamples, nSamples - start + 1, Length[mono]];
      If[len > 0,
        leftBuf[[start ;; start + len - 1]]  += Sqrt[(1.0 - pan) / 2.0] * mono[[1 ;; len]];
        rightBuf[[start ;; start + len - 1]] += Sqrt[(1.0 + pan) / 2.0] * mono[[1 ;; len]]
      ],
      {i, n}
    ];

    {leftBuf, rightBuf, nSamples}
  ];


(* OverlayEvent — centred (pan=0) accent burst, duplicated from
   dynamical/src/sonify.wl verbatim (same per-app-duplication
   convention as HenonPitchScale above). *)
OverlayEvent[leftBuf_List, rightBuf_List, freq_?NumericQ, dur_?NumericQ,
            amp_?NumericQ, startTimeSec_?NumericQ, sr_Integer] :=
  Module[{burst, start, len, n = Length[leftBuf], lb = leftBuf, rb = rightBuf},
    burst = StemSynthNote[freq, dur, amp, {1.0}, 0.3, sr];
    start = Clip[Round[startTimeSec * sr] + 1, {1, n}];
    len   = Min[Length[burst], n - start + 1];
    If[len > 0,
      lb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]];
      rb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]]
    ];
    {lb, rb}
  ];


(* ── sweep mode: dynamical-style discrete notes per a-step ─────────
   Direct 2D-map analogue of dynamical/SonifySweep: x drives pitch,
   y drives pan (the task's "second spatial dimension -> stereo"
   convention), only the first $henonNotesPerStep points of each
   a-step's settled attractor become audible notes, for the same
   duration-budget reason dynamical/AGENTS.md documents (duration =
   a_steps * notes_per_step * note_duration; using every recorded
   attractor point at fine a resolution would run to tens of
   minutes). *)
$henonNotesPerStep = 6;

SonifySweep[sweepModel_Association, landmarks_Association,
           noteDuration_?NumericQ, sr_Integer] :=
  Module[{aValues, attractors, nSteps, stepStartTimes,
          allPoints, xVals, yVals, times, speeds,
          pitchRange, panRange,
          leftBuf, rightBuf, nSamples,
          eventOrder, eventAs, eventFreqs, eventDurs, eventStepIndices},

    aValues    = sweepModel["aValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[aValues];

    stepStartTimes = Table[(k - 1) * $henonNotesPerStep * noteDuration, {k, nSteps}];

    allPoints = Flatten[
      Table[
        With[{pts = attractors[[k]][[1 ;; Min[$henonNotesPerStep, Length[attractors[[k]]]]]]},
          Table[
            <|
              "x"       -> pts[[j, 1]],
              "y"       -> pts[[j, 2]],
              "t"       -> stepStartTimes[[k]] + (j - 1) * noteDuration,
              "speed"   -> Norm[pts[[j]] - pts[[Max[j - 1, 1]]]],
              "a"       -> aValues[[k]],
              "iterIdx" -> j
            |>,
            {j, Length[pts]}
          ]
        ],
        {k, nSteps}
      ],
      1
    ];

    xVals  = allPoints[[All, "x"]];
    yVals  = allPoints[[All, "y"]];
    times  = allPoints[[All, "t"]];
    speeds = allPoints[[All, "speed"]];

    pitchRange = MinMax[xVals];
    panRange   = MinMax[yVals];

    {leftBuf, rightBuf, nSamples} =
      SynthesizeDiscreteNotesHenon[xVals, yVals, speeds, times, pitchRange, panRange, noteDuration, sr];

    (* ── Three named events, in ascending-a order, mirroring
       dynamical/SonifySweep's three-event structure. "periodic_window"
       stands in for dynamical's "period3_window" — the same "island
       of order inside chaos" narrative beat, empirically located
       here rather than assumed (see FindPeriodicWindowA). ── *)
    eventOrder = {"first_bifurcation", "chaos_onset", "periodic_window"};
    eventFreqs = <| "first_bifurcation" -> 660.0, "chaos_onset" -> 440.0, "periodic_window" -> 528.0 |>;
    eventDurs  = <| "first_bifurcation" -> 0.08,  "chaos_onset" -> 0.12,  "periodic_window" -> 0.10  |>;
    eventStepIndices = <||>;

    Scan[
      Function[label,
        Module[{eventA, stepIdx, eventTime},
          eventA = landmarks[label];
          If[eventA >= First[aValues] && eventA <= Last[aValues],
            stepIdx  = First[Nearest[aValues -> "Index", eventA]];
            eventStepIndices[label] = stepIdx;
            eventTime = stepStartTimes[[stepIdx]];
            {leftBuf, rightBuf} = OverlayEvent[leftBuf, rightBuf,
              eventFreqs[label], eventDurs[label], 0.7, eventTime, sr];
            Switch[label,
              "first_bifurcation",
                STEMPrintN["First period-doubling bifurcation reached at a", eventA, "", 4];
                STEMSay["First period-doubling bifurcation. One note becomes two."],
              "chaos_onset",
                STEMPrintN["Onset of chaos reached at a", eventA, "", 4];
                STEMSay["Onset of chaos. Long-term prediction is now impossible."],
              "periodic_window",
                STEMPrintN["Periodic window reached at a", eventA, "", 4];
                STEMSay["A period seven window. A brief return to order inside the chaos."]
            ]
          ]
        ]
      ],
      eventOrder
    ];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nSamples,
      "xVals" -> xVals, "yVals" -> yVals, "times" -> times, "speeds" -> speeds,
      "aVals" -> allPoints[[All, "a"]], "iterIdx" -> allPoints[[All, "iterIdx"]],
      "eventStepIndices" -> eventStepIndices, "sr" -> sr
    |>
  ];


(* ── reverse mode: three-phase discrete-note demonstration ─────────
   Phase 1 "forward": the settled forward segment, played as notes.
   Marker event (990 Hz) signals the turn.
   Phase 2 "reversed": the SAME points, simple array-reversed —
   numerically exact, no re-derivation via the inverse formula.
   Marker event (990 Hz) signals the turn again.
   Phase 3 "inverse_demo": a short handful of points recovered by
   actually applying HenonMapInverse backward — the real proof of
   invertibility, kept deliberately short (see model.wl's
   HenonReverseModel and AGENTS.md for why long backward runs are
   NOT attempted). Uses the same pitch=x, pan=y mapping as sweep
   for a consistent listening idiom across both discrete-note modes. *)
SonifyReverse[reverseModel_Association, noteDuration_?NumericQ, sr_Integer] :=
  Module[{fwd, rev, inv, allPts, gapDur, markerFreq, markerDur,
          t0, phase1Points, phase2Start, phase2Points, phase3Start, phase3Points,
          xVals, yVals, times, speeds, phaseLabels,
          pitchRange, panRange, leftBuf, rightBuf, nSamples,
          markerTimes},

    fwd = reverseModel["forwardSeg"];
    rev = reverseModel["reversedSeg"];
    inv = reverseModel["inverseDemo"];

    gapDur     = 3 * noteDuration;
    markerFreq = 990.0;
    markerDur  = 0.10;

    PhasePoints[pts_List, tStart_?NumericQ] :=
      Table[
        <|
          "x" -> pts[[j, 1]], "y" -> pts[[j, 2]],
          "t" -> tStart + (j - 1) * noteDuration,
          "speed" -> Norm[pts[[j]] - pts[[Max[j - 1, 1]]]]
        |>,
        {j, Length[pts]}
      ];

    phase1Points = PhasePoints[fwd, 0.0];
    phase2Start  = Last[phase1Points]["t"] + noteDuration + gapDur;
    phase2Points = PhasePoints[rev, phase2Start];
    phase3Start  = Last[phase2Points]["t"] + noteDuration + gapDur;
    phase3Points = PhasePoints[inv, phase3Start];

    allPts = Join[phase1Points, phase2Points, phase3Points];
    phaseLabels = Join[
      ConstantArray["forward", Length[phase1Points]],
      ConstantArray["reversed", Length[phase2Points]],
      ConstantArray["inverse_demo", Length[phase3Points]]
    ];

    xVals  = allPts[[All, "x"]];
    yVals  = allPts[[All, "y"]];
    times  = allPts[[All, "t"]];
    speeds = allPts[[All, "speed"]];

    pitchRange = MinMax[xVals];
    panRange   = MinMax[yVals];

    {leftBuf, rightBuf, nSamples} =
      SynthesizeDiscreteNotesHenon[xVals, yVals, speeds, times, pitchRange, panRange, noteDuration, sr];

    markerTimes = {Last[phase1Points]["t"] + noteDuration + gapDur / 2.0,
                   Last[phase2Points]["t"] + noteDuration + gapDur / 2.0};
    Do[
      {leftBuf, rightBuf} = OverlayEvent[leftBuf, rightBuf, markerFreq, markerDur, 0.6, mt, sr],
      {mt, markerTimes}
    ];

    STEMPrintN["Inverse-demo round-trip max error", reverseModel["inverseDemoMaxError"], "", 12];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nSamples,
      "xVals" -> xVals, "yVals" -> yVals, "times" -> times, "speeds" -> speeds,
      "phaseLabels" -> phaseLabels, "sr" -> sr
    |>
  ];

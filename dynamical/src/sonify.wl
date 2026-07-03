(* ========================================================
   dynamical/src/sonify.wl — Discrete event-driven note synthesis

   Design decision: this app uses discrete per-point note bursts
   (StemSynthNote placed at precise attack times, mixed additively
   into pre-allocated stereo buffers via in-place Part-assignment) —
   the same "event-driven note triggering" pattern as primes/src/
   sonify.wl's SonifyGaps, rather than stem-core's continuous
   SonifyTrajectory carrier (phase-accumulated sine, spline-
   interpolated pitch/pan/volume) used by lorenz/pendulum.

   Rationale: the whole point of this app is that period-doubling
   must be *audibly countable* as a rhythm — "period-4 sounds like a
   four-note cycle" — and this is an explicit, testable verification
   requirement ("confirm the rhythmic character of each preset is
   clearly distinguishable"). A continuous phase-accumulated carrier
   with spline-interpolated pitch would smear consecutive attractor
   values into a continuous glide/vibrato rather than crisp, separately
   countable notes, and would very likely fail that requirement. Pitch
   mapping still reuses stem-core's ScaleLookup/SemitoneToHz (the same
   scale-lookup utilities lorenz and pendulum use), so the *pitch
   mapping* convention is shared even though the *event-triggering*
   architecture follows primes' pattern instead. See AGENTS.md for the
   full rationale.

   Buffers are returned, not exported — main.wl prepends the spoken
   intro (speech.wl) before a single final WAV export, matching the
   images/ enhancement's pattern.
   ======================================================== *)


(* PitchScale3Octaves
   Minor pentatonic semitone offsets spanning 3 octaves (0 to 36
   semitones): 5 notes/octave x 3 octaves, plus the top octave's root. *)
PitchScale3Octaves[] :=
  Join[Flatten[Table[{0, 3, 5, 7, 10} + 12 * k, {k, 0, 2}]], {36}];

$dynamicalRootHz = 130.81;  (* C3, consistent with other stem apps *)


(* SynthesizeDiscreteNotes
   xVals, speeds, times are parallel lists (same length): the map value,
   |change from previous point|, and attack time (seconds) for each note.
   Pitch: ScaleLookup on xVals over the 3-octave minor pentatonic scale.
   Pan: xVals rescaled to [-1,1] (low x = left, high x = right).
   Volume: speeds rescaled to [0.25, 0.95] (floor keeps period-1's
   zero-change notes audible rather than silent).
   Returns {leftBuffer, rightBuffer, nSamples}. *)
SynthesizeDiscreteNotes[xVals_List, speeds_List, times_List,
                        noteDuration_?NumericQ, sr_Integer] :=
  Module[{n, pitchScale, speedMax, nSamples, toneSamples,
          leftBuf, rightBuf, freq, pan, amp, mono, start, len},
    n           = Length[xVals];
    pitchScale  = PitchScale3Octaves[];
    speedMax    = Max[speeds];
    If[speedMax <= 0, speedMax = 1.0];
    toneSamples = Round[noteDuration * sr];
    nSamples    = Round[(Last[times] + noteDuration) * sr] + 1;
    leftBuf     = ConstantArray[0.0, nSamples];
    rightBuf    = ConstantArray[0.0, nSamples];

    Do[
      freq  = ScaleLookup[xVals[[i]], 0.0, 1.0, pitchScale, $dynamicalRootHz];
      pan   = Clip[Rescale[xVals[[i]], {0.0, 1.0}, {-1.0, 1.0}], {-1.0, 1.0}];
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


(* OverlayEvent
   Mixes a centred (pan=0) accent burst into leftBuf/rightBuf at
   startTimeSec. Returns the updated {leftBuf, rightBuf} — only called
   a handful of times (three sweep events), so the whole-buffer
   pass-by-value here is negligible, unlike the per-note hot loop above. *)
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


(* ── Sweep mode ─────────────────────────────────────────────────────
   Only the first $sweepNotesPerStep points of each r-step's recorded
   attractor become audible notes (all n_attractor points are already
   post-transient, so any subset is equally valid) — this keeps sweep
   audio duration bounded (duration = r_steps * $sweepNotesPerStep *
   note_duration) regardless of how large n_attractor is configured;
   using the full n_attractor (100 by default) at 500 r_steps would
   produce a ~66-minute file. 8 notes is enough to make any periodicity
   up to period-8 clearly audible as a repeating cycle. *)
$sweepNotesPerStep = 8;

SonifySweep[sweepModel_Association, noteDuration_?NumericQ, sr_Integer] :=
  Module[{rValues, attractors, nSteps, stepStartTimes,
          allPoints, xVals, times, speeds,
          leftBuf, rightBuf, nSamples,
          eventRs, eventOrder, eventFreqs, eventDurs, eventStepIndices},

    rValues    = sweepModel["rValues"];
    attractors = sweepModel["attractors"];
    nSteps     = Length[rValues];

    stepStartTimes = Table[(k - 1) * $sweepNotesPerStep * noteDuration, {k, nSteps}];

    allPoints = Flatten[
      Table[
        With[{pts = attractors[[k]][[1 ;; Min[$sweepNotesPerStep, Length[attractors[[k]]]]]]},
          Table[
            <|
              "x"       -> pts[[j]],
              "t"       -> stepStartTimes[[k]] + (j - 1) * noteDuration,
              "speed"   -> Abs[pts[[j]] - pts[[Max[j - 1, 1]]]],
              "r"       -> rValues[[k]],
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
    times  = allPoints[[All, "t"]];
    speeds = allPoints[[All, "speed"]];

    {leftBuf, rightBuf, nSamples} = SynthesizeDiscreteNotes[xVals, speeds, times, noteDuration, sr];

    (* ── Three named events, in ascending-r order (matches sweep direction) ── *)
    eventRs    = SweepEventRValues[];
    eventOrder = {"first_bifurcation", "chaos_onset", "period3_window"};
    eventFreqs = <| "first_bifurcation" -> 660.0, "chaos_onset" -> 440.0, "period3_window" -> 528.0 |>;
    eventDurs  = <| "first_bifurcation" -> 0.08,  "chaos_onset" -> 0.12,  "period3_window" -> 0.10  |>;
    eventStepIndices = <||>;

    (* Only fire events whose r value actually falls within [rStart, rEnd] —
       a zoomed/narrowed sweep (e.g. r restricted to the cascade itself)
       should not fire an accent tone for an event outside its range just
       because Nearest snaps to whichever boundary happens to be closest. *)
    Scan[
      Function[label,
        Module[{eventR, stepIdx, eventTime},
          eventR = eventRs[label];
          If[eventR >= First[rValues] && eventR <= Last[rValues],
            stepIdx  = First[Nearest[rValues -> "Index", eventR]];
            eventStepIndices[label] = stepIdx;
            eventTime = stepStartTimes[[stepIdx]];
            {leftBuf, rightBuf} = OverlayEvent[leftBuf, rightBuf,
              eventFreqs[label], eventDurs[label], 0.7, eventTime, sr];
            Switch[label,
              "first_bifurcation",
                STEMPrintN["First period-doubling bifurcation reached at r", eventR, "", 4];
                STEMSay["First period-doubling bifurcation. One note becomes two."],
              "chaos_onset",
                STEMPrintN["Onset of chaos reached at r", eventR, "", 4];
                STEMSay["Onset of chaos. Long-term prediction is now impossible."],
              "period3_window",
                STEMPrintN["Period-3 window reached at r", eventR, "", 4];
                STEMSay["Period-3 window. A brief return to order inside the chaos."]
            ]
          ]
        ]
      ],
      eventOrder
    ];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nSamples,
      "xVals" -> xVals, "times" -> times, "speeds" -> speeds,
      "rVals" -> allPoints[[All, "r"]], "iterIdx" -> allPoints[[All, "iterIdx"]],
      "eventRs" -> eventRs, "eventStepIndices" -> eventStepIndices, "sr" -> sr
    |>
  ];


(* ── Iterate mode ───────────────────────────────────────────────────── *)
SonifyIterate[iterateModel_Association, noteDuration_?NumericQ, sr_Integer] :=
  Module[{traj, n, times, speeds, leftBuf, rightBuf, nSamples},
    traj   = iterateModel["trajectory"];
    n      = Length[traj];
    times  = Table[(i - 1) * noteDuration, {i, n}];
    speeds = Prepend[Abs[Differences[traj]], 0.0];

    {leftBuf, rightBuf, nSamples} = SynthesizeDiscreteNotes[traj, speeds, times, noteDuration, sr];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nSamples,
      "xVals" -> traj, "times" -> times, "speeds" -> speeds, "sr" -> sr
    |>
  ];

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
              eventFreqs[label], eventDurs[label], 0.7, eventTime, sr]
          ]
        ]
      ],
      eventOrder
    ];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nSamples,
      "xVals" -> xVals, "times" -> times, "speeds" -> speeds,
      "rVals" -> allPoints[[All, "r"]], "iterIdx" -> allPoints[[All, "iterIdx"]],
      "eventRs" -> eventRs, "eventStepIndices" -> eventStepIndices,
      "eventFreqs" -> eventFreqs, "eventTimes" -> Map[stepStartTimes[[#]] &, eventStepIndices],
      "sr" -> sr
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


(* ── Lyapunov mode ────────────────────────────────────────────────────
   Two continuous tones plus marker bursts, after example S15.4 in
   Grond & Berger, The Sonification Handbook, ch. 15, and variant B of
   prototype_lyapunov.wl (chosen after listening):

     lambda tone     fundamental refHz * 2^(lambda * octavesPerUnit), with
                     2nd and 3rd harmonics at 0.25 and 0.12 of the
                     fundamental's amplitude; lambda is interpolated
                     linearly between sweep steps and the phase is
                     accumulated sample by sample, so the tone glides
                     without clicks
     reference tone  pure sine at refHz (lambda = 0) for the whole sweep;
                     where lambda nears zero the two tones beat
     markers         the sweep mode's accent bursts (OverlayEvent) at the
                     bifurcation points inside the range, plus a period-4
                     marker at r = 3.449

   Unlike the sweep and iterate modes this is a continuous glide, not
   discrete notes: here the quantity heard is a single scalar per r, and
   its crossing of zero is heard as beating against the reference, which
   only a continuous tone can produce (see AGENTS.md design decision 5). *)

$lyapunovHarmonics = {1.0, 0.25, 0.12};   (* fundamental, 2nd, 3rd harmonic *)
$lyapunovToneAmp   = 0.3;                 (* both tones, before loudness normalisation *)
$lyapunovEdgeFade  = 0.02;                (* s, raised-cosine fade in/out of both tones *)

(* LyapunovMarkers
   The marker family: the sweep mode's three events (same frequencies and
   durations as SonifySweep) plus the period-4 bifurcation. 440, 528, 660
   and 880 Hz stand in the ratios 1 : 6/5 : 3/2 : 2, the just-intoned A
   minor triad with its octave, so the added 880 Hz marker belongs to the
   same chord; it takes the 0.08 s length of the other period-doubling
   marker. Returned in ascending r. *)
LyapunovMarkers[] :=
  Module[{ev = SweepEventRValues[]},
    {
      <|"key" -> "first_bifurcation", "r" -> ev["first_bifurcation"],
        "label" -> "first period-doubling bifurcation", "freq" -> 660.0, "dur" -> 0.08|>,
      <|"key" -> "period4", "r" -> 3.449,
        "label" -> "period-4 bifurcation", "freq" -> 880.0, "dur" -> 0.08|>,
      <|"key" -> "chaos_onset", "r" -> ev["chaos_onset"],
        "label" -> "onset of chaos", "freq" -> 440.0, "dur" -> 0.12|>,
      <|"key" -> "period3_window", "r" -> ev["period3_window"],
        "label" -> "period-3 window", "freq" -> 528.0, "dur" -> 0.10|>
    }
  ];

(* LyapunovToneHz — fundamental of the lambda tone. *)
LyapunovToneHz[lambda_, refHz_?NumericQ, octavesPerUnit_?NumericQ] :=
  refHz * 2.0^(lambda * octavesPerUnit);

(* AWeightingResponse
   Linear amplitude response of the A-weighting filter (IEC 61672-1),
   without the +2.00 dB that normalises it to 0 dB at 1 kHz (it cancels
   in the ratio below). Works element-wise on a list of frequencies. *)
AWeightingResponse[f_] :=
  (12194.0^2 * f^4) /
    ((f^2 + 20.6^2) * Sqrt[(f^2 + 107.7^2) * (f^2 + 737.9^2)] * (f^2 + 12194.0^2));

(* LyapunovLoudnessGain
   Equal-loudness compensation for the lambda tone, using A-weighting
   (IEC 61672-1), the standard closed-form approximation to the inverse
   of the 40-phon ISO 226 equal-loudness contour. The tone's A-weighted
   amplitude is the root-sum-square of its three partials, each weighted
   at its own frequency; the gain is the ratio of that amplitude at the
   reference frequency to its value at f, so the gain is exactly 1 when
   lambda = 0 (the lambda tone then matches the reference in level, which
   makes the beating near a crossing deepest) and rises as the tone falls
   in pitch. Over the default range (lambda from -0.5 to log 2, i.e. about
   156 to 356 Hz) it spans +3.3 dB to -3.9 dB. At listening levels
   well above 40 phon A-weighting slightly over-corrects the low end. *)
LyapunovLoudnessGain[f_, refHz_?NumericQ, Optional[harmonics_List, $lyapunovHarmonics]] :=
  Module[{weighted},
    weighted[g_] := Sqrt[Total[MapIndexed[(#1 * AWeightingResponse[#2[[1]] * g])^2 &, harmonics]]];
    weighted[refHz] / weighted[f]
  ];

(* LyapunovHarmonicClearance
   For each harmonic k >= 2 of the lambda tone, the smallest distance in
   semitones between that harmonic and the reference frequency over every
   lambda the sweep can produce (lambda >= floor, since LyapunovExponent
   clips there). Harmonic k sits at k * refHz * 2^(lambda * octavesPerUnit),
   lowest at lambda = floor, so the clearance is
   12 (log2 k + floor * octavesPerUnit). A value <= 0 means the harmonic
   passes through the reference: a false unison, heard as beating as if
   lambda were crossing zero. With floor -0.5 and 1 octave per unit the
   2nd harmonic stays 6 semitones (a tritone) above the reference.
   Returns <|k -> semitones, ...|>. *)
LyapunovHarmonicClearance[floor_?NumericQ, octavesPerUnit_?Positive,
                          Optional[harmonics_List, $lyapunovHarmonics]] :=
  AssociationMap[12.0 * (Log2[N[#]] + floor * octavesPerUnit) &, Range[2, Length[harmonics]]];

(* LyapunovTimeOfR — seconds into the sweep at which it passes r. *)
LyapunovTimeOfR[r_?NumericQ, rMin_?NumericQ, rMax_?NumericQ, durSec_?NumericQ] :=
  (r - rMin) / (rMax - rMin) * durSec;

(* LyapunovPerSample
   lambda at every sample, linearly interpolated between the sweep's
   control points, which sit at t_k = (k-1) * durSec / (steps - 1). *)
LyapunovPerSample[lams_List, nS_Integer, durSec_?NumericQ, sr_Integer] :=
  Module[{dt, pos, i0, fr},
    dt  = durSec / (Length[lams] - 1);
    pos = N[Range[0, nS - 1] / sr] / dt;
    i0  = Clip[Floor[pos], {0, Length[lams] - 2}];
    fr  = pos - i0;
    lams[[i0 + 1]] * (1.0 - fr) + lams[[i0 + 2]] * fr
  ];

LyapunovEdgeFade[nS_Integer, sr_Integer] :=
  Module[{nF = Round[$lyapunovEdgeFade * sr], ramp},
    ramp = 0.5 * (1.0 - Cos[Pi * Range[0, nF - 1] / nF]);
    Join[ramp, ConstantArray[1.0, nS - 2 nF], Reverse[ramp]]
  ];

(* SonifyLyapunov
   sweep = LyapunovSweep output {{r, lambda}, ...}. Returns buffers, not a
   file, like SonifySweep/SonifyIterate, so main.wl can add the spoken
   intro and outro before the single final export. *)
SonifyLyapunov[sweep_List, durSec_?NumericQ, refHz_?NumericQ,
               octavesPerUnit_?NumericQ, sr_Integer] :=
  Module[{rs, lams, rMin, rMax, nS, lamS, freqS, phase, fade, gainS,
          lamTone, refTone, mono, leftBuf, rightBuf, markers},
    rs   = sweep[[All, 1]];
    lams = sweep[[All, 2]];
    rMin = First[rs]; rMax = Last[rs];
    nS   = Round[durSec * sr];

    lamS  = LyapunovPerSample[lams, nS, durSec, sr];
    freqS = LyapunovToneHz[lamS, refHz, octavesPerUnit];
    phase = 2.0 Pi * Accumulate[freqS] / sr;
    fade  = LyapunovEdgeFade[nS, sr];
    gainS = LyapunovLoudnessGain[freqS, refHz];

    lamTone = $lyapunovToneAmp * fade * gainS *
      Total[MapIndexed[#1 * Sin[#2[[1]] * phase] &, $lyapunovHarmonics]];
    refTone = $lyapunovToneAmp * fade * Sin[2.0 Pi * refHz * N[Range[0, nS - 1] / sr]];
    mono    = lamTone + refTone;
    leftBuf = mono; rightBuf = mono;

    markers = Select[LyapunovMarkers[], rMin <= #["r"] <= rMax &];
    markers = Map[Append[#, "time" -> LyapunovTimeOfR[#["r"], rMin, rMax, durSec]] &, markers];
    Scan[
      ({leftBuf, rightBuf} = OverlayEvent[leftBuf, rightBuf, #["freq"], #["dur"], 0.7, #["time"], sr]) &,
      markers];

    <|
      "leftBuf" -> leftBuf, "rightBuf" -> rightBuf, "nSamples" -> nS,
      "markers" -> markers, "gainRangeDB" -> 20.0 * Log10[MinMax[gainS]],
      "toneHzRange" -> MinMax[freqS], "sr" -> sr
    |>
  ];


(* ── Divergence mode ──────────────────────────────────────────────────
   Three voices:
     voice 1 (hard left)  orbit started at x0
     voice 2 (hard right) orbit started at x0 + delta
     voice 3 (centre)     the separation |x_n - y_n|, a continuous tone
     marker (centre)      $divergenceSaturationMarker, 1320 Hz, once, when
                          the separation first exceeds `saturation`
   Voices 1 and 2 use iterate mode's note mapping (ScaleLookup pitch on
   PitchScale3Octaves, StemSynthNote with harmonics {1, 0.25} and decay
   0.35, one note of note_duration per iterate, volume 0.25 + 0.70 *
   step / max step), with the pan replaced by hard left / hard right and
   two changes that make identical orbits produce identical samples:
     - the max step normalising the volume is shared by both orbits
       (iterate mode normalises by its own orbit's max, which would give
       the two voices different volumes while their orbits still agree);
     - the volume is quantised to 16 levels, like the 16 scale degrees of
       the pitch. A continuous volume would differ by ~1e-6 from the first
       note on, which flips 16-bit rounding in some samples, so the two
       channels would never be sample-identical.
   So the mapping's audible resolution is one quantisation step: 1/15 of
   the x range in pitch (one scale degree) and 1/15 of the shared max
   step in volume. While the separation is below it the two channels are
   the same note for note and the stereo image is centred.

   Voice 3's pitch is linear in Log10[separation]: delta sounds at
   $divergenceLowHz (220 Hz), a separation of 1 two octaves higher
   (880 Hz). Exponential growth delta * e^(lambda n) is therefore a
   steady rise of 2 lambda / (Ln[10] * -Log10[delta]) octaves per
   iteration (0.0668 at delta = 1e-6 and lambda = Log[2]); shrinking is a
   steady fall. Separations below $divergenceSeparationFloor (1e-12,
   including the exact 0. converging orbits reach) hold at the bottom of
   the range, 55 Hz for delta = 1e-6. The timbre is odd harmonics only
   (a hollow, clarinet-like tone), sustained and gliding, against the
   plucked notes of the orbit voices. *)

$divergenceLowHz          = 220.0;
$divergenceOctaves        = 2.0;
$divergenceSepHarmonics   = {1.0, 0.0, 0.2, 0.0, 0.08};
$divergenceSepAmp         = 0.3;
$divergenceVolumeLevels   = 16;
$divergenceNoteHarmonics  = {1.0, 0.25};   (* as SynthesizeDiscreteNotes *)
$divergenceNoteDecay      = 0.35;           (* as SynthesizeDiscreteNotes *)

(* $divergenceSaturationMarker
   A member of the marker family (440 : 528 : 660 : 880 = the just A minor
   triad with its octave, LyapunovMarkers) that no other event in the app
   uses: 1320 Hz = 3 x 440, the triad's fifth an octave above the 660 Hz
   marker. It lies above every orbit note (the scale tops out at C6,
   1046.5 Hz) and above the separation tone's fundamental (at most
   880 Hz), so it cannot be mistaken for either. Until the narration
   rework it reused the 440 Hz chaos-onset accent. *)
$divergenceSaturationMarker = <|"freq" -> 1320.0, "dur" -> 0.12|>;

(* DivergenceSeparationHz — voice 3's pitch for a separation (or list). *)
DivergenceSeparationHz[sep_, delta_?NumericQ] :=
  Module[{ld = Log10[N[delta]]},
    $divergenceLowHz * 2.0^($divergenceOctaves *
      (Log10[Clip[sep, {N[$divergenceSeparationFloor], 1.0}]] - ld) / (-ld))
  ];

(* DivergenceNoteMapping
   Pitch (Hz) and quantised volume of every note of both orbits.
   Returns <|"freqX", "freqY", "ampX", "ampY", "stepMax",
   "resolution" (min of the pitch and volume bins, in x units),
   "firstDifferentNote" (first n whose pitch or volume differs between
   the orbits, Missing[] if none)|>. *)
DivergenceNoteMapping[xs_List, ys_List] :=
  Module[{scale = PitchScale3Octaves[], nLev = $divergenceVolumeLevels - 1,
          stepX, stepY, stepMax, quant, freqX, freqY, ampX, ampY, diff},
    stepX = Prepend[Abs[Differences[xs]], 0.0];
    stepY = Prepend[Abs[Differences[ys]], 0.0];
    stepMax = Max[stepX, stepY];
    If[stepMax <= 0, stepMax = 1.0];
    quant[steps_] := 0.25 + 0.70 * Round[nLev * Clip[steps / stepMax, {0.0, 1.0}]] / nLev;
    freqX = ScaleLookup[#, 0.0, 1.0, scale, $dynamicalRootHz] & /@ xs;
    freqY = ScaleLookup[#, 0.0, 1.0, scale, $dynamicalRootHz] & /@ ys;
    ampX = quant[stepX]; ampY = quant[stepY];
    diff = FirstPosition[MapThread[#1 != #2 || #3 != #4 &, {freqX, freqY, ampX, ampY}], True, {Missing[]}, {1}][[1]];
    <|"freqX" -> freqX, "freqY" -> freqY, "ampX" -> ampX, "ampY" -> ampY,
      "stepMax" -> stepMax,
      "pitchBin" -> 1.0 / (Length[scale] - 1), "volumeBin" -> stepMax / nLev,
      "resolution" -> Min[1.0 / (Length[scale] - 1), stepMax / nLev],
      "firstDifferentNote" -> If[IntegerQ[diff], diff - 1, Missing[]]|>
  ];

(* DivergenceNoteBuffer — one mono voice of discrete notes. *)
DivergenceNoteBuffer[freqs_List, amps_List, noteDuration_?NumericQ, nSamples_Integer, sr_Integer] :=
  Module[{buf = ConstantArray[0.0, nSamples], toneSamples = Round[noteDuration * sr],
          mono, start, len},
    Do[
      mono  = StemSynthNote[freqs[[i]], noteDuration, amps[[i]],
                            $divergenceNoteHarmonics, $divergenceNoteDecay, sr];
      start = Clip[Round[(i - 1) * noteDuration * sr] + 1, {1, nSamples}];
      len   = Min[toneSamples, nSamples - start + 1, Length[mono]];
      If[len > 0, buf[[start ;; start + len - 1]] += mono[[1 ;; len]]],
      {i, Length[freqs]}];
    buf
  ];

(* SonifyDivergence
   orbits = DivergenceOrbits output. Returns buffers (main.wl adds the
   spoken intro and outro) plus the note mapping. *)
SonifyDivergence[orbits_Association, noteDuration_?NumericQ, saturation_?NumericQ,
                 separationVoice_, sr_Integer] :=
  Module[{xs = orbits["x"], ys = orbits["y"], sep = orbits["separation"], n, nSamples,
          mapping, left, right, logSep, dt, pos, i0, fr, lsS, freqS, phase, fade, sepTone,
          nSat, markerTime = Missing[]},
    n = Length[xs];
    nSamples = Round[n * noteDuration * sr] + 1;
    mapping  = DivergenceNoteMapping[xs, ys];
    left  = DivergenceNoteBuffer[mapping["freqX"], mapping["ampX"], noteDuration, nSamples, sr];
    right = DivergenceNoteBuffer[mapping["freqY"], mapping["ampY"], noteDuration, nSamples, sr];

    If[TrueQ[separationVoice],
      (* Log10 of the clamped separation, linear between note onsets. *)
      logSep = Log10[Clip[sep, {N[$divergenceSeparationFloor], 1.0}]];
      dt  = noteDuration;
      pos = N[Range[0, nSamples - 1] / sr] / dt;
      i0  = Clip[Floor[pos], {0, n - 2}];
      fr  = Clip[pos - i0, {0.0, 1.0}];
      lsS = logSep[[i0 + 1]] * (1.0 - fr) + logSep[[i0 + 2]] * fr;
      freqS = DivergenceSeparationHz[10.0^lsS, orbits["delta"]];
      phase = 2.0 Pi * Accumulate[freqS] / sr;
      fade  = LyapunovEdgeFade[nSamples, sr];
      sepTone = $divergenceSepAmp * fade *
        Total[MapIndexed[#1 * Sin[#2[[1]] * phase] &, $divergenceSepHarmonics]] /
        Total[$divergenceSepHarmonics];
      left  += Sqrt[0.5] * sepTone;
      right += Sqrt[0.5] * sepTone];

    (* Saturation marker, once, at the first n above saturation. *)
    nSat = DivergenceFit[sep, saturation]["nSat"];
    If[IntegerQ[nSat],
      markerTime = nSat * noteDuration;
      {left, right} = OverlayEvent[left, right, $divergenceSaturationMarker["freq"],
        $divergenceSaturationMarker["dur"], 0.7, markerTime, sr]];

    <|"leftBuf" -> left, "rightBuf" -> right, "nSamples" -> nSamples,
      "noteSamples" -> Round[noteDuration * sr], "mapping" -> mapping,
      "markerTime" -> markerTime, "separationVoice" -> TrueQ[separationVoice], "sr" -> sr|>
  ];

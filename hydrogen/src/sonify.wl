(* ========================================================
   hydrogen/src/sonify.wl — Audio synthesis for all three modes

   Public API:
     SonifyOrbitals[orbitalModel, freqMin, freqMax, noteDuration, sr]
     BuildSpectrumAudio[nMax, freqMin, freqMax, chordDur, noteDur, sr]
     SonifyCascades[cascadesList, freqMin, freqMax, sr]
   ======================================================== *)


(* AudioFreqFromRange
   Shared log-scale frequency mapping used by both spectrum and
   transitions modes: nu_audio = freqMin * (freqMax/freqMin)^t,
   t = (nu - nuMin)/(nuMax - nuMin) clipped to [0,1]. *)
AudioFreqFromRange[nu_?NumericQ, nuMin_?NumericQ, nuMax_?NumericQ,
                   freqMin_?NumericQ, freqMax_?NumericQ] :=
  If[nuMax > nuMin,
    freqMin * (freqMax / freqMin)^Clip[(nu - nuMin) / (nuMax - nuMin), {0.0, 1.0}],
    freqMin
  ];

(* AmplitudeFromRange
   Log-compressed amplitude in [floor,1] from a value's position within
   [lo,hi] -- Einstein A coefficients span orders of magnitude, so a
   linear rescale would make all but the single brightest line
   inaudible. *)
AmplitudeFromRange[x_?NumericQ, lo_?NumericQ, hi_?NumericQ, Optional[floor_?NumericQ, 0.2]] :=
  If[hi > lo,
    floor + (1.0 - floor) * Clip[(Log[x] - Log[lo]) / (Log[hi] - Log[lo]), {0.0, 1.0}],
    1.0
  ];


(* ── Orbitals mode ────────────────────────────────────────────────
   |psi|^2 -> pitch and amplitude, both on a log scale (matching
   images/src/model.wl's BrightnessToFreq approach): density values
   below 10^-6 of the peak are treated as nodes and rendered as silence
   (StemSynthNote[0, ...] is naturally all-zero, so freq=0 needs no
   special-casing downstream). *)

SonifyOrbitals[orbitalModel_Association, freqMin_?NumericQ, freqMax_?NumericQ,
              noteDuration_?NumericQ, sr_Integer] :=
  Module[{densityFlat, nPixels, dMax, threshold, logNorm, freqs, amps, buffer},
    densityFlat = orbitalModel["densityFlat"];
    nPixels     = orbitalModel["nPixels"];
    dMax        = Max[densityFlat];
    threshold   = dMax * 1.0*^-6;

    logNorm = Map[
      If[# <= threshold, 0.0,
        Clip[(Log[#] - Log[threshold]) / (Log[dMax] - Log[threshold]), {0.0, 1.0}]
      ] &,
      densityFlat
    ];
    freqs = Map[If[# <= 0.0, 0.0, freqMin * (freqMax / freqMin)^#] &, logNorm];
    amps  = Map[If[# <= 0.0, 0.0, 0.2 + 0.75 * #] &, logNorm];

    buffer = NormalizeBuffer[
      Join @@ Table[
        StemSynthNote[freqs[[i]], noteDuration, amps[[i]], {1.0, 0.3}, 0.3, sr],
        {i, nPixels}
      ],
      0.92
    ];

    <| "buffer" -> buffer, "freqs" -> freqs, "amps" -> amps, "logNorm" -> logNorm |>
  ];


(* ── Spectrum mode ────────────────────────────────────────────────
   Chord: every line simultaneously for chordDur seconds.
   Sweep: every line in turn (series ascending, then n_upper ascending
   within a series -- Lyman alpha, beta, ... then Balmer alpha, beta,
   ... -- so the sweep scans UV -> visible -> IR), with a soft 660 Hz
   bell layered onto each Balmer line so the four visible-light lines
   stand out audibly during the scan. *)

BuildSpectrumAudio[nMax_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                   chordDur_?NumericQ, noteDur_?NumericQ, sr_Integer] :=
  Module[{lines, nuVals, nuMin, nuMax, aVals, aMin, aMax,
          audioFreqs, amps, chordBuf, order, sweepLines, sweepFreqs, sweepAmps,
          sweepClips, sweepBuf, bellDur, bellClip},

    lines  = BuildSpectralLines[nMax];
    nuVals = Map[#["nu_Hz"] &, lines];
    nuMin  = Min[nuVals]; nuMax = Max[nuVals];
    aVals  = Map[#["einstein_A"] &, lines];
    aMin   = Min[aVals]; aMax = Max[aVals];

    audioFreqs = Map[AudioFreqFromRange[#, nuMin, nuMax, freqMin, freqMax] &, nuVals];
    amps       = Map[AmplitudeFromRange[#, aMin, aMax] &, aVals];

    (* Chord *)
    chordBuf = NormalizeBuffer[
      Total[Table[
        StemSynthNote[audioFreqs[[i]], chordDur, amps[[i]], {1.0, 0.35, 0.15}, 0.7, sr],
        {i, Length[lines]}
      ]],
      0.9
    ];

    (* Sweep order: series (n_lower) ascending, then n_upper ascending *)
    order = Ordering[lines, All,
      (#1["n_lower"] < #2["n_lower"] ||
       (#1["n_lower"] === #2["n_lower"] && #1["n_upper"] < #2["n_upper"])) &];
    sweepLines = lines[[order]];
    sweepFreqs = audioFreqs[[order]];
    sweepAmps  = amps[[order]];

    bellDur = Min[noteDur * 0.6, 0.15];
    bellClip = StemSynthNote[660.0, bellDur, 0.35, {1.0}, 0.3, sr];

    sweepClips = Table[
      With[{note = StemSynthNote[sweepFreqs[[i]], noteDur, sweepAmps[[i]], {1.0, 0.3}, 0.4, sr]},
        If[sweepLines[[i]]["n_lower"] == 2,
          note + PadRight[bellClip, Length[note]],
          note
        ]
      ],
      {i, Length[sweepLines]}
    ];
    sweepBuf = NormalizeBuffer[Join @@ sweepClips, 0.9];

    <|
      "lines" -> lines, "audioFreqs" -> audioFreqs, "amps" -> amps,
      "sweepOrder" -> order, "chordBuf" -> chordBuf, "sweepBuf" -> sweepBuf,
      "nuMin" -> nuMin, "nuMax" -> nuMax
    |>
  ];


(* ── Transitions (cascade) mode ───────────────────────────────────
   Each transition step -> one note: pitch from photon frequency (log
   scale, same mapping as spectrum mode), duration ~ 1/A (slow
   transitions ring longer), amplitude ~ A (log-compressed, brighter =
   louder), stereo pan from the upper state's l. Realisations are
   concatenated with a short pause between them. *)

PanForL[l_Integer] := Switch[l, 0, -1.0, 1, 0.0, 2, 0.6, 3, 1.0, _, 1.0];

$CascadeDurationScale = 3.5*^6;   (* calibrated so mid-range A ~ 0.1-1 s notes *)
$CascadeDurationRange = {0.08, 1.2};

SonifyCascades[cascadesList_List, freqMin_?NumericQ, freqMax_?NumericQ, sr_Integer] :=
  Module[{allSteps, nuVals, nuMin, nuMax, aVals, aMin, aMax,
          pauseSamples, perRealization, pairBufs, leftBufs, rightBufs, leftBuffer, rightBuffer,
          freqLists, durLists, panLists},

    allSteps = Flatten[cascadesList];
    nuVals   = Map[PhotonFrequencyHz[#["n_upper"], #["n_lower"]] &, allSteps];
    nuMin    = Min[nuVals]; nuMax = Max[nuVals];
    aVals    = Map[#["einstein_A"] &, allSteps];
    aMin     = Min[aVals]; aMax = Max[aVals];
    pauseSamples = Round[0.3 * sr];

    perRealization = Map[
      Function[steps,
        Module[{perStep, clips},
          perStep = Map[
            Function[step,
              Module[{nu, freq, amp, dur, pan, mono},
                nu   = PhotonFrequencyHz[step["n_upper"], step["n_lower"]];
                freq = AudioFreqFromRange[nu, nuMin, nuMax, freqMin, freqMax];
                amp  = AmplitudeFromRange[step["einstein_A"], aMin, aMax];
                dur  = Clip[$CascadeDurationScale / step["einstein_A"], $CascadeDurationRange];
                pan  = PanForL[step["l_upper"]];
                mono = StemSynthNote[freq, dur, amp, {1.0, 0.4, 0.15}, 0.4, sr];
                <|
                  "freq" -> freq, "dur" -> dur, "pan" -> pan,
                  "left" -> mono * Sqrt[(1.0 - pan) / 2.0],
                  "right" -> mono * Sqrt[(1.0 + pan) / 2.0]
                |>
              ]
            ],
            steps
          ];
          <|
            "freqs" -> Map[#["freq"] &, perStep],
            "durs"  -> Map[#["dur"] &, perStep],
            "pans"  -> Map[#["pan"] &, perStep],
            "left"  -> Join @@ Map[#["left"] &, perStep],
            "right" -> Join @@ Map[#["right"] &, perStep]
          |>
        ]
      ],
      cascadesList
    ];

    freqLists = Map[#["freqs"] &, perRealization];
    durLists  = Map[#["durs"] &, perRealization];
    panLists  = Map[#["pans"] &, perRealization];
    leftBufs  = Map[#["left"] &, perRealization];
    rightBufs = Map[#["right"] &, perRealization];

    leftBuffer  = If[Length[leftBufs] > 1,
      Join @@ Riffle[leftBufs,  Table[ConstantArray[0.0, pauseSamples], {Length[leftBufs] - 1}]],
      Join @@ leftBufs
    ];
    rightBuffer = If[Length[rightBufs] > 1,
      Join @@ Riffle[rightBufs, Table[ConstantArray[0.0, pauseSamples], {Length[rightBufs] - 1}]],
      Join @@ rightBufs
    ];

    <|
      "left" -> NormalizeBuffer[leftBuffer, 0.92],
      "right" -> NormalizeBuffer[rightBuffer, 0.92],
      "nuMin" -> nuMin, "nuMax" -> nuMax, "aMin" -> aMin, "aMax" -> aMax,
      "freqLists" -> freqLists, "durLists" -> durLists, "panLists" -> panLists
    |>
  ];

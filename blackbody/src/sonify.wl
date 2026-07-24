(* ========================================================
   blackbody/src/sonify.wl — Additive spectral synthesis for
   black body radiation

   Core primitive: SynthesizeAdditiveFrame mixes N simultaneous sine
   partials into one short stereo "frame" of audio -- the same
   technique thermo/src/sonify.wl uses to make the Maxwell-Boltzmann
   curve audible directly as a spectral envelope, applied here to the
   Planck curve instead:

     spectrum / star (single preset) -- one held "chord" frame whose
       partial amplitudes trace B(nu,T) across the full radio-to-X-ray
       sweep, followed by a sequential sweep through the same bins in
       frequency order (the chord-then-sweep structure of
       hydrogen/src/sonify.wl's BuildSpectrumAudio).

     temperature -- one frame per temperature step (as thermo's
       cooling mode), each frame's spectral envelope built from the
       SAME BlackbodySpectrumBins primitive, with overall amplitude
       scaled by StefanBoltzmannLoudness and a soft peak-marker tone
       giving Wien's law an explicit, audible pitch cue.

     star ("all") -- a short chord frame per preset, ascending
       temperature, each preceded by a spoken star name -- reuses the
       temperature-mode per-frame primitive at a handful of discrete
       named temperatures instead of a continuous sweep
       (BuildStarTourSegments, spliced together with speech by main.wl).

   Each frame gets a short (5 ms) linear fade in/out (FrameWindow) so
   concatenated frames (synthesised independently with phase reset to
   zero) do not click at frame boundaries.
   ======================================================== *)


(* FrameWindow — linear fade in/out envelope, capped so fades never
   overlap for very short frames. *)
FrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];

(* SynthesizeAdditiveFrame — freqs/amps/pans are parallel lists, one
   entry per simultaneous partial. amps are pre-scaled by the caller
   (typically 1/Sqrt[n]). Returns {leftBuf, rightBuf}. *)
SynthesizeAdditiveFrame[freqs_List, amps_List, pans_List,
                        frameDuration_?NumericQ, sr_Integer] :=
  Module[{n = Length[freqs], nSamples, t, leftBuf, rightBuf, fadeSamples, envelope, mono},
    nSamples = Max[1, Round[frameDuration * sr]];
    t        = N[Range[0, nSamples - 1]] / sr;
    leftBuf  = ConstantArray[0.0, nSamples];
    rightBuf = ConstantArray[0.0, nSamples];

    Do[
      mono = amps[[i]] * Sin[2.0 * Pi * freqs[[i]] * t];
      leftBuf  += Sqrt[(1.0 - pans[[i]]) / 2.0] * mono;
      rightBuf += Sqrt[(1.0 + pans[[i]]) / 2.0] * mono,
      {i, n}
    ];

    fadeSamples = Min[Round[0.005 * sr], Floor[nSamples / 4]];
    envelope    = FrameWindow[nSamples, fadeSamples];
    {leftBuf * envelope, rightBuf * envelope}
  ];


(* ── Planck spectrum discretisation, shared by all three modes ────
   Log-spaced bins in physical frequency nu (spanning many decades,
   radio to X-ray), log-mapped onto [audioFreqMin, audioFreqMax] --
   matches thermo's MBSpectrumBins and hydrogen's AudioFreqFromRange:
   equal musical intervals correspond to equal frequency ratios in
   BOTH the physical and audio domains, so the log map preserves the
   curve's shape perceptually. Amplitudes are radiance values
   normalised so the peak bin = 1.0. *)
BlackbodySpectrumBins[T_?NumericQ, nBins_Integer, nuMin_?NumericQ, nuMax_?NumericQ,
                      audioFreqMin_?NumericQ, audioFreqMax_?NumericQ] :=
  Module[{nuBins, radiances, maxRad, audioFreqs, amps},
    nuBins    = Table[nuMin * (nuMax / nuMin)^(N[i] / nBins), {i, nBins}];
    (* Quiet[General::munfl] -- radiance at the coolest/highest-frequency
       bin combinations legitimately underflows to a subnormal-or-zero
       double (h*nu >> k*T there, so the true value is astronomically
       small); this is correct physics, not a bug, so the noisy
       "too small to represent" warning is suppressed rather than
       worked around. *)
    {radiances, maxRad, amps} = Quiet[
      Module[{r, m, a},
        r = PlanckRadianceFreq[#, T] & /@ nuBins;
        m = Max[r];
        If[m <= 0.0, m = 1.0];
        a = r / m;
        (* Clamp to exactly 0.0 below 1e-12 (inaudible either way): bins
           this far into the curve's tail otherwise carry a legitimate
           but subnormal float value, which underflows to something
           EVEN smaller (General::munfl) the moment any caller scales
           it further (e.g. by 1/Sqrt[nBins] or a loudness factor) --
           clamping here, once, is simpler than quieting every such
           scaling operation downstream. *)
        a = Map[If[# < 1.0*^-12, 0.0, #] &, a];
        {r, m, a}
      ],
      General::munfl
    ];
    audioFreqs = audioFreqMin * (audioFreqMax / audioFreqMin)^
                   (Log[nuBins / nuMin] / Log[nuMax / nuMin]);
    <| "nuBins" -> nuBins, "audioFreqs" -> audioFreqs, "amps" -> amps, "nBins" -> nBins |>
  ];

(* PeakBinIndex — index of the bin nearest the true (numerically
   located) Wien's-law peak, used to mark the peak audibly and
   visually with a consistent bin choice across sonify/animate. *)
PeakBinIndex[spec_Association] := First[Ordering[spec["amps"], -1]];


(* AddVisibleBandMarkers — two soft taps at the audio frequencies
   corresponding to the 400nm and 700nm visible-band edges, near the
   start of a frame. Mirrors thermo's AddTripleTap (fixed reference
   pitches, not encoding a data value via pitch) but with exactly two
   taps at the physically-derived band-edge frequencies rather than
   three fixed pitches -- this app's "you cannot see most of the light
   a star emits" demonstration is precisely about where those two
   edges fall relative to the whole curve. *)
AddVisibleBandMarkers[leftBuf_List, rightBuf_List, sr_Integer,
                      freqLo_?NumericQ, freqHi_?NumericQ] :=
  Module[{tapFreqs = {freqLo, freqHi}, tapDur = 0.05, tapGap = 0.02, tapAmp = 0.22,
          lb = leftBuf, rb = rightBuf, n = Length[leftBuf], tapSamples, burst, start, len},
    tapSamples = Round[tapDur * sr];
    Do[
      burst = tapAmp * Table[
        Sin[2.0 Pi tapFreqs[[i]] k / sr] * Exp[-4.0 k / tapSamples],
        {k, 0, tapSamples - 1}];
      start = Round[(i - 1) * tapGap * sr] + 1;
      len   = Min[tapSamples, n - start + 1];
      If[len > 0,
        lb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]];
        rb[[start ;; start + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]]
      ],
      {i, 2}
    ];
    {lb, rb}
  ];

(* AddPeakMarker — single soft tap at a frame's Wien's-law peak audio
   frequency, giving pitch an explicit, audible marker on top of the
   full spectral envelope (which already implies the peak position
   less directly, via which partial is loudest). Mirrors thermo's
   AddEquilibriumAccent (one fixed-role accent per frame). *)
AddPeakMarker[leftBuf_List, rightBuf_List, sr_Integer, peakFreq_?NumericQ] :=
  Module[{dur = 0.08, amp = 0.35, burst, lb = leftBuf, rb = rightBuf,
          n = Length[leftBuf], burstLen, len},
    burstLen = Round[dur * sr];
    burst = amp * Table[Sin[2.0 Pi peakFreq k / sr] * Exp[-3.0 k / burstLen], {k, 0, burstLen - 1}];
    len = Min[Length[burst], n];
    lb[[1 ;; len]] += Sqrt[0.5] * burst[[1 ;; len]];
    rb[[1 ;; len]] += Sqrt[0.5] * burst[[1 ;; len]];
    {lb, rb}
  ];


(* ── Mode 1: spectrum (and star mode, single preset) ─────────────
   Chord: one held frame, the full spectral envelope, marked with
   visible-band-edge taps. Sweep: the same bins played sequentially in
   ascending frequency order, with a distinct bell overlay on the two
   bins nearest the visible-band edges (the sweep's own "accent tone
   or timbral change at both edges"). *)

BuildSpectrumAudio[T_?NumericQ, nBins_Integer, nuMin_?NumericQ, nuMax_?NumericQ,
                   audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                   chordDur_?NumericQ, noteDur_?NumericQ, sr_Integer] :=
  Module[{spec, chordAmps, pans, chordL, chordR, peakIdx, peakFreq,
          visLoIdx, visHiIdx, bellDur, bellClip, sweepClips, sweepL, sweepR},

    spec      = BlackbodySpectrumBins[T, nBins, nuMin, nuMax, audioFreqMin, audioFreqMax];
    peakIdx   = PeakBinIndex[spec];
    peakFreq  = spec["audioFreqs"][[peakIdx]];

    (* Chord: full envelope held for chordDur seconds *)
    chordAmps = spec["amps"] / Sqrt[N[nBins]];
    pans      = ConstantArray[0.0, nBins];
    {chordL, chordR} = SynthesizeAdditiveFrame[spec["audioFreqs"], chordAmps, pans, chordDur, sr];
    {chordL, chordR} = AddVisibleBandMarkers[chordL, chordR, sr, $VisibleFreqLo, $VisibleFreqHi];

    (* Sweep: same bins, one note at a time, ascending nu (already the
       table order from BlackbodySpectrumBins) *)
    visLoIdx = First[Ordering[Abs[spec["nuBins"] - $VisibleFreqLo], 1]];
    visHiIdx = First[Ordering[Abs[spec["nuBins"] - $VisibleFreqHi], 1]];
    bellDur  = Min[noteDur * 0.6, 0.15];
    bellClip = StemSynthNote[880.0, bellDur, 0.3, {1.0}, 0.3, sr];

    sweepClips = Table[
      With[{note = StemSynthNote[spec["audioFreqs"][[i]], noteDur, 0.15 + 0.55 * spec["amps"][[i]],
                                  {1.0, 0.3}, 0.4, sr]},
        If[i === visLoIdx || i === visHiIdx,
          note + PadRight[bellClip, Length[note]],
          note
        ]
      ],
      {i, nBins}
    ];
    sweepL = NormalizeBuffer[Flatten[sweepClips], 0.9];
    sweepR = sweepL;

    <|
      "chordL" -> chordL, "chordR" -> chordR,
      "sweepL" -> sweepL, "sweepR" -> sweepR,
      "spec" -> spec, "T" -> T, "peakIdx" -> peakIdx, "peakFreq" -> peakFreq,
      "visLoIdx" -> visLoIdx, "visHiIdx" -> visHiIdx,
      "nuMin" -> nuMin, "nuMax" -> nuMax, "nBins" -> nBins
    |>
  ];


(* ── Mode 2: temperature ──────────────────────────────────────────
   One spectral-envelope frame per T step (thermo's cooling-mode
   structure), amplitude-scaled by StefanBoltzmannLoudness, each frame
   marked with a soft peak tone at its own Wien's-law peak frequency. *)

BuildTemperatureAudio[Tmin_?NumericQ, Tmax_?NumericQ, nSteps_Integer,
                      nBins_Integer, nuMin_?NumericQ, nuMax_?NumericQ,
                      audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                      frameDuration_?NumericQ, sr_Integer] :=
  Module[{TVals, peakFreqs, loudness, frames, leftAll, rightAll},
    TVals     = N[Subdivide[Tmin, Tmax, nSteps - 1]];
    peakFreqs = PeakFrequencyFromWavelength /@ TVals;
    loudness  = StefanBoltzmannLoudness[#, Tmin, Tmax] & /@ TVals;

    frames = MapThread[
      Function[{T, loud},
        Module[{spec, amps, pans, l, r, audioPeakFreq},
          spec = BlackbodySpectrumBins[T, nBins, nuMin, nuMax, audioFreqMin, audioFreqMax];
          amps = loud * spec["amps"] / Sqrt[N[nBins]];
          pans = ConstantArray[0.0, nBins];
          {l, r} = SynthesizeAdditiveFrame[spec["audioFreqs"], amps, pans, frameDuration, sr];
          audioPeakFreq = spec["audioFreqs"][[PeakBinIndex[spec]]];
          AddPeakMarker[l, r, sr, audioPeakFreq]
        ]
      ],
      {TVals, loudness}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "TVals" -> TVals, "peakFreqs" -> peakFreqs, "loudness" -> loudness,
      "frameDuration" -> frameDuration, "nBins" -> nBins,
      "nuMin" -> nuMin, "nuMax" -> nuMax
    |>
  ];


(* ── Mode 3: star, "all" tour ─────────────────────────────────────
   One short chord frame per preset, ascending temperature, reusing
   the same per-frame primitive as temperature mode (loudness/pitch
   both follow directly from the same physics) but at a handful of
   discrete named temperatures instead of a continuous sweep. Returns
   the per-star segments UNCONCATENATED (not Flattened) so main.wl can
   splice a spoken star-name announcement before each one. *)
BuildStarTourSegments[order_List, presets_Association, nBins_Integer,
                      nuMin_?NumericQ, nuMax_?NumericQ,
                      audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                      segmentDuration_?NumericQ, sr_Integer] :=
  Module[{Ts, Tmin, Tmax, segments},
    Ts   = presets /@ order;
    Tmin = Min[Ts]; Tmax = Max[Ts];

    segments = Map[
      Function[T,
        Module[{spec, loud, amps, pans, l, r, audioPeakFreq},
          spec = BlackbodySpectrumBins[T, nBins, nuMin, nuMax, audioFreqMin, audioFreqMax];
          loud = StefanBoltzmannLoudness[T, Tmin, Tmax];
          amps = loud * spec["amps"] / Sqrt[N[nBins]];
          pans = ConstantArray[0.0, nBins];
          {l, r} = SynthesizeAdditiveFrame[spec["audioFreqs"], amps, pans, segmentDuration, sr];
          audioPeakFreq = spec["audioFreqs"][[PeakBinIndex[spec]]];
          {l, r} = AddPeakMarker[l, r, sr, audioPeakFreq];
          <| "T" -> T, "left" -> l, "right" -> r |>
        ]
      ],
      Ts
    ];

    <| "segments" -> segments, "order" -> order, "Ts" -> Ts,
       "Tmin" -> Tmin, "Tmax" -> Tmax, "segmentDuration" -> segmentDuration |>
  ];

(* ========================================================
   quantum_statistics/src/sonify.wl — Three modes, all built on
   thermo/src/sonify.wl's additive-spectral-envelope primitive
   (SynthesizeAdditiveFrame: many simultaneous sine partials, one
   frame's worth of audio, amplitude-weighted by a physical curve)

   `spectrum`: THREE simultaneous voices, one per distribution (BE,
     FD, MB), each its own additive spectral-envelope frame exactly
     like thermo/distribution's MB spectrum — but each voice gets its
     OWN pan position AND its own frequency register (BE low/hard
     left, FD mid/centre, MB high/hard right), so three genuinely
     different-sounding textures play at once and the ear can track
     where in the energy sweep they agree or diverge. A sequential
     tour was considered and rejected: hearing all three AT ONCE, at
     the same instant, is what actually answers "do they sound similar
     or different at this T" — a sequential comparison would only ever
     let you compare against memory, not directly.

   `temperature`: the SAME three-voice/three-register idea, now swept
     continuously over T (phase-accumulation, compton/sweep's
     technique) instead of held fixed — loudness AND pitch both
     log-compressed per voice (blackbody/temperature's
     StefanBoltzmannLoudness technique, essential here since n_BE
     spans some 50 orders of magnitude across the default T range).

   `fermi_sea`: one additive frame per T step (thermo/distribution's
     own per-T-frame concatenation idiom, reused directly), each
     frame's spectral envelope tracing FD(eps) at that T — audibly a
     bright, sharply-differentiated chord at low T (a real step) softening
     into a smoother, more uniform texture at high T (the step blurred
     out).
   ======================================================== *)


(* QsNormalizeStereoPair — scales BOTH channels by the SAME factor
   (preserving pan balance, unlike normalizing each channel
   independently) so the joint peak sits at ceiling. Applied to every
   mode's final mixed output here, since summing three simultaneous
   voices (spectrum/temperature) or a full-width spectral frame
   (fermi_sea) can exceed +-1.0 before this step. *)
QsNormalizeStereoPair[left_List, right_List, Optional[ceiling_?NumericQ, 0.9]] :=
  Module[{peak = Max[Abs[Join[left, right]]]},
    If[peak > ceiling, {left, right} * (ceiling / peak), {left, right}]
  ];

QsFrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];

(* SynthesizeAdditiveFrame — duplicated from thermo/src/sonify.wl (per
   this codebase's no-shared-src/ convention). *)
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
    envelope    = QsFrameWindow[nSamples, fadeSamples];
    {leftBuf * envelope, rightBuf * envelope}
  ];

(* NormalizeSpectrumAmps — divides by the array's own max (guarding
   against an all-zero/Missing array), matching thermo/'s
   MBSpectrumBins convention exactly (each voice normalised to its OWN
   peak, not a shared peak — see module header for why this is the
   honest choice for Bose-Einstein's naturally huge dynamic range). *)
NormalizeSpectrumAmps[vals_List] :=
  Module[{cleaned, maxV},
    cleaned = Replace[vals, _Missing -> 0.0, {1}];
    maxV = Max[cleaned];
    If[maxV <= 0.0, maxV = 1.0];
    cleaned / maxV
  ];


(* ========================================================
   MODE 1: spectrum — three simultaneous voices, fixed T
   ======================================================== *)

$qsVoiceRanges = <|
  "BE" -> {110.0, 700.0},   "FD" -> {220.0, 1400.0},  "MB" -> {440.0, 2800.0}
|>;
$qsVoicePans = <| "BE" -> -0.7, "FD" -> 0.0, "MB" -> 0.7 |>;

BuildSpectrumAudio[model_Association, nBins_Integer, duration_?NumericQ, sr_Integer] :=
  Module[{epsMin, epsMax, epsBins, tFrac, beVals, fdVals, mbVals,
          freqsBE, freqsFD, freqsMB, ampsBE, ampsFD, ampsMB,
          lBE, rBE, lFD, rFD, lMB, rMB, leftAll, rightAll},
    epsMin = model["epsMin"]; epsMax = model["epsMax"];
    epsBins = N @ Subdivide[epsMin, epsMax, nBins - 1];
    tFrac = (epsBins - epsMin) / (epsMax - epsMin);

    beVals = BoseEinsteinOccupation[#, 0.0, model["T"]] & /@ epsBins;
    fdVals = FermiDiracOccupation[#, 0.0, model["T"]] & /@ epsBins;
    mbVals = MaxwellBoltzmannOccupation[#, 0.0, model["T"]] & /@ epsBins;

    freqsBE = $qsVoiceRanges["BE"][[1]] * ($qsVoiceRanges["BE"][[2]] / $qsVoiceRanges["BE"][[1]])^tFrac;
    freqsFD = $qsVoiceRanges["FD"][[1]] * ($qsVoiceRanges["FD"][[2]] / $qsVoiceRanges["FD"][[1]])^tFrac;
    freqsMB = $qsVoiceRanges["MB"][[1]] * ($qsVoiceRanges["MB"][[2]] / $qsVoiceRanges["MB"][[1]])^tFrac;

    ampsBE = NormalizeSpectrumAmps[beVals] / Sqrt[N[nBins]];
    ampsFD = NormalizeSpectrumAmps[fdVals] / Sqrt[N[nBins]];
    ampsMB = NormalizeSpectrumAmps[mbVals] / Sqrt[N[nBins]];

    {lBE, rBE} = SynthesizeAdditiveFrame[freqsBE, ampsBE, ConstantArray[$qsVoicePans["BE"], nBins], duration, sr];
    {lFD, rFD} = SynthesizeAdditiveFrame[freqsFD, ampsFD, ConstantArray[$qsVoicePans["FD"], nBins], duration, sr];
    {lMB, rMB} = SynthesizeAdditiveFrame[freqsMB, ampsMB, ConstantArray[$qsVoicePans["MB"], nBins], duration, sr];

    leftAll  = lBE + lFD + lMB;
    rightAll = rBE + rFD + rMB;
    QsNormalizeStereoPair[leftAll, rightAll]
  ];


(* ========================================================
   MODE 2: temperature — three voices, continuous T sweep
   ======================================================== *)

(* QsLogCompressedNorm — blackbody/temperature's StefanBoltzmannLoudness
   technique, generalised to any positive array: floor + (1-floor) *
   Clip[(Log[val]-Log[min])/(Log[max]-Log[min]),{0,1}], using the
   array's OWN observed (floored-to-avoid-Log[0]) min/max — essential
   here since n_BE spans ~50 orders of magnitude across the default T
   range, where a linear map would be silent except at the very top. *)
QsLogCompressedNorm[vals_List, Optional[floor_?NumericQ, 0.08]] :=
  Module[{cleaned, safeCleaned, logVals, logMin, logMax},
    cleaned = Replace[vals, _Missing -> 0.0, {1}];
    safeCleaned = Clip[cleaned, {1.0*^-300, Infinity}];
    logVals = Log[safeCleaned];
    logMin = Min[logVals]; logMax = Max[logVals];
    If[logMax - logMin < 1.0*^-9, Return[ConstantArray[1.0, Length[vals]]]];
    floor + (1.0 - floor) * Clip[(logVals - logMin) / (logMax - logMin), {0.0, 1.0}]
  ];

BuildTemperatureAudio[model_Association, duration_?NumericQ, sr_Integer] :=
  Module[{TMin, TMax, epsRef, nSamples, dt, tFrac, logTAudio, TAudio,
          beAudio, fdAudio, mbAudio, loudBE, loudFD, loudMB,
          pitchNormBE, pitchNormFD, pitchNormMB, fBE, fFD, fMB,
          phaseBE, phaseFD, phaseMB, envelope, fadeSamples,
          monoBE, monoFD, monoMB, leftAll, rightAll},
    TMin = model["TMin"]; TMax = model["TMax"]; epsRef = model["epsRef"];
    nSamples = Round[duration * sr];
    dt = 1.0 / sr;
    tFrac = N[Range[0, nSamples - 1]] / (nSamples - 1);

    logTAudio = Log10[TMin] + (Log10[TMax] - Log10[TMin]) * tFrac;
    TAudio = 10.0^logTAudio;

    beAudio = BoseEinsteinOccupation[epsRef, 0.0, #] & /@ TAudio;
    fdAudio = FermiDiracOccupation[epsRef, 0.0, #] & /@ TAudio;
    mbAudio = MaxwellBoltzmannOccupation[epsRef, 0.0, #] & /@ TAudio;

    loudBE = QsLogCompressedNorm[beAudio]; loudFD = QsLogCompressedNorm[fdAudio]; loudMB = QsLogCompressedNorm[mbAudio];

    fBE = $qsVoiceRanges["BE"][[1]] * ($qsVoiceRanges["BE"][[2]] / $qsVoiceRanges["BE"][[1]])^loudBE;
    fFD = $qsVoiceRanges["FD"][[1]] * ($qsVoiceRanges["FD"][[2]] / $qsVoiceRanges["FD"][[1]])^loudFD;
    fMB = $qsVoiceRanges["MB"][[1]] * ($qsVoiceRanges["MB"][[2]] / $qsVoiceRanges["MB"][[1]])^loudMB;

    phaseBE = N[2.0 Pi * Accumulate[fBE] * dt];
    phaseFD = N[2.0 Pi * Accumulate[fFD] * dt];
    phaseMB = N[2.0 Pi * Accumulate[fMB] * dt];

    fadeSamples = Round[0.05 * sr];
    envelope = QsFrameWindow[nSamples, fadeSamples];

    monoBE = 0.5 * loudBE * Sin[phaseBE] * envelope;
    monoFD = 0.5 * loudFD * Sin[phaseFD] * envelope;
    monoMB = 0.5 * loudMB * Sin[phaseMB] * envelope;

    leftAll  = Sqrt[(1.0 - $qsVoicePans["BE"]) / 2.0] * monoBE +
               Sqrt[(1.0 - $qsVoicePans["FD"]) / 2.0] * monoFD +
               Sqrt[(1.0 - $qsVoicePans["MB"]) / 2.0] * monoMB;
    rightAll = Sqrt[(1.0 + $qsVoicePans["BE"]) / 2.0] * monoBE +
               Sqrt[(1.0 + $qsVoicePans["FD"]) / 2.0] * monoFD +
               Sqrt[(1.0 + $qsVoicePans["MB"]) / 2.0] * monoMB;

    QsNormalizeStereoPair[leftAll, rightAll]
  ];


(* ========================================================
   MODE 3: fermi_sea — one additive frame per T step (thermo/
   distribution's per-T-frame concatenation idiom, reused directly)
   ======================================================== *)

BuildFermiSeaAudio[model_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                   frameDuration_?NumericQ, sr_Integer] :=
  Module[{TArr, epsArr, epsMin, epsMax, tFrac, freqs, frames, leftAll, rightAll},
    TArr = model["TArr"]; epsArr = model["epsArr"];
    epsMin = model["epsMin"]; epsMax = model["epsMax"];
    tFrac = (epsArr - epsMin) / (epsMax - epsMin);
    freqs = freqMin * (freqMax / freqMin)^tFrac;

    frames = Table[
      Module[{fdVals, amps, pans, l, r},
        fdVals = model["fdByT"][[k]];
        amps = NormalizeSpectrumAmps[fdVals] / Sqrt[N[Length[epsArr]]];
        pans = ConstantArray[0.0, Length[epsArr]];
        {l, r} = SynthesizeAdditiveFrame[freqs, amps, pans, frameDuration, sr];
        {l, r}
      ],
      {k, Length[TArr]}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    QsNormalizeStereoPair[leftAll, rightAll]
  ];

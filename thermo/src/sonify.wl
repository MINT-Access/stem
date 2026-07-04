(* ========================================================
   thermo/src/sonify.wl — Additive spectral synthesis for
   classical statistical mechanics

   Core primitive: SynthesizeAdditiveFrame mixes N simultaneous sine
   partials (each with its own frequency/amplitude/pan) into one short
   stereo "frame" of audio. All four modes are built from this same
   primitive:

     distribution / cooling — one frame per temperature step, N_bins
       partials per frame weighted by the Maxwell-Boltzmann density
       f(v) at each bin's speed, so the frame's spectral envelope
       literally traces the MB curve. Frames concatenate into a
       temperature sweep.

     ensemble — one frame per collision timestep, N_particles partials
       (one per particle), each at a fixed pan position and a
       frequency derived from that particle's current speed. Frames
       concatenate into a continuously-updating chord.

     equipartition — same MB-spectrum frames as distribution/cooling
       on the LEFT channel; a rotational-energy drone (diatomic only)
       on the RIGHT channel.

   Each frame gets a short (5 ms) linear fade in/out (FrameWindow) —
   frames are synthesised independently with phase reset to zero, so
   without a fade, concatenating them produces audible clicks at every
   frame boundary.
   ======================================================== *)


(* FrameWindow — linear fade in/out envelope, capped so fades never
   overlap for very short frames. *)
FrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]]   = ramp;
      env[[-fs ;;]]    = Reverse[ramp]
    ];
    env
  ];

(* SynthesizeAdditiveFrame
   freqs/amps/pans are parallel lists, one entry per simultaneous
   partial. amps are pre-scaled by the caller (typically 1/Sqrt[n] so
   that summing n incoherent partials keeps RMS level roughly
   independent of n — standard additive-synthesis practice; final
   NormalizeBuffer at export time handles the rest). Returns
   {leftBuf, rightBuf}, each of length Round[frameDuration*sr]. *)
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


(* ── MB spectrum discretisation (distribution/cooling/equipartition) ── *)

(* MBSpectrumBins
   Discretises f(v) into nBins bins spanning (0, v_max], mapping each
   bin's speed logarithmically onto [freqMin, freqMax] (matches human
   pitch perception: equal musical intervals = equal speed ratios).
   Amplitudes are density values normalised so the peak bin = 1.0. *)
MBSpectrumBins[massAmu_?NumericQ, T_?NumericQ, nBins_Integer,
               freqMin_?NumericQ, freqMax_?NumericQ] :=
  Module[{vmax, vBins, densities, maxDensity, freqs, amps},
    vmax       = MaxSpeed[massAmu, T];
    vBins      = (N[Range[1, nBins]] / nBins) * vmax;
    densities  = MBDensity[#, massAmu, T] & /@ vBins;
    maxDensity = Max[densities];
    If[maxDensity <= 0.0, maxDensity = 1.0];
    freqs = freqMin * (freqMax / freqMin)^(vBins / vmax);
    amps  = densities / maxDensity;
    <| "vBins" -> vBins, "freqs" -> freqs, "amps" -> amps, "vmax" -> vmax |>
  ];


(* AddTripleTap
   Overlays the three characteristic-speed marker taps (330/440/550 Hz,
   30 ms each, 10 ms apart, soft/centred) at the start of a frame. These
   are fixed reference pitches marking "a new temperature step just
   started" — they do NOT encode v_p/v_mean/v_rms via pitch (the GIF's
   vertical marker lines do that visually instead; see distribution.gif
   in animate.wl). *)
AddTripleTap[leftBuf_List, rightBuf_List, sr_Integer] :=
  Module[{tapFreqs = {330.0, 440.0, 550.0}, tapDur = 0.03, tapGap = 0.01, tapAmp = 0.18,
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
      {i, 3}
    ];
    {lb, rb}
  ];

(* AddEquilibriumAccent — single soft 220 Hz burst marking the moment
   cooling mode reaches within 10% of T_cold ("thermal equilibrium"). *)
AddEquilibriumAccent[leftBuf_List, rightBuf_List, sr_Integer] :=
  Module[{freq = 220.0, dur = 0.15, amp = 0.5, burst, lb = leftBuf, rb = rightBuf,
          n = Length[leftBuf], burstLen, len},
    burstLen = Round[dur * sr];
    burst = amp * Table[Sin[2.0 Pi freq k / sr] * Exp[-3.0 k / burstLen], {k, 0, burstLen - 1}];
    len = Min[Length[burst], n];
    lb[[1 ;; len]] += Sqrt[0.5] * burst[[1 ;; len]];
    rb[[1 ;; len]] += Sqrt[0.5] * burst[[1 ;; len]];
    {lb, rb}
  ];


(* ── Mode 1: distribution ─────────────────────────────────────────── *)

BuildDistributionAudio[massAmu_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ, nSteps_Integer,
                       nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                       frameDuration_?NumericQ, sr_Integer] :=
  Module[{TVals, vpVals, vmeanVals, vrmsVals, frames, leftAll, rightAll},
    TVals     = N[Subdivide[TStart, TEnd, nSteps - 1]];
    vpVals    = MostProbableSpeed[massAmu, #] & /@ TVals;
    vmeanVals = MeanSpeed[massAmu, #]         & /@ TVals;
    vrmsVals  = RMSSpeed[massAmu, #]          & /@ TVals;

    frames = Map[
      Function[T,
        Module[{spec, amps, pans, l, r},
          spec = MBSpectrumBins[massAmu, T, nBins, freqMin, freqMax];
          amps = spec["amps"] / Sqrt[N[nBins]];
          pans = ConstantArray[0.0, nBins];
          {l, r} = SynthesizeAdditiveFrame[spec["freqs"], amps, pans, frameDuration, sr];
          AddTripleTap[l, r, sr]
        ]
      ],
      TVals
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "TVals" -> TVals, "vpVals" -> vpVals, "vmeanVals" -> vmeanVals, "vrmsVals" -> vrmsVals,
      "frameDuration" -> frameDuration, "nBins" -> nBins,
      "freqMin" -> freqMin, "freqMax" -> freqMax, "massAmu" -> massAmu
    |>
  ];


(* ── Mode 2: ensemble ─────────────────────────────────────────────── *)

BuildEnsembleAudio[ensembleModel_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                   frameDuration_?NumericQ, sr_Integer] :=
  Module[{nParticles, massAmu, T, history, vmax, pans, ampPerVoice, frames, leftAll, rightAll},
    nParticles = ensembleModel["nParticles"];
    massAmu    = ensembleModel["massAmu"];
    T          = ensembleModel["T"];
    history    = ensembleModel["speedsHistory"];
    vmax       = MaxSpeed[massAmu, T];
    pans       = If[nParticles > 1,
      N[Range[0, nParticles - 1]] / (nParticles - 1) * 2.0 - 1.0,
      {0.0}
    ];
    ampPerVoice = 1.0 / nParticles;

    frames = Map[
      Function[speeds,
        Module[{freqs, amps},
          freqs = freqMin * (freqMax / freqMin)^Clip[speeds / vmax, {0.0, 1.0}];
          amps  = ConstantArray[ampPerVoice, nParticles];
          SynthesizeAdditiveFrame[freqs, amps, pans, frameDuration, sr]
        ]
      ],
      history
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "vmax" -> vmax, "pans" -> pans, "frameDuration" -> frameDuration
    |>
  ];


(* ── Mode 3: cooling ──────────────────────────────────────────────── *)

BuildCoolingAudio[massAmu_?NumericQ, THot_?NumericQ, TCold_?NumericQ, tau_?NumericQ,
                  duration_?NumericQ, nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                  frameDuration_?NumericQ, sr_Integer] :=
  Module[{nFrames, times, TVals, eqTime, eqFrameIdx, frames, leftAll, rightAll},
    nFrames = Max[1, Round[duration / frameDuration]];
    times   = N[Range[0, nFrames - 1]] * frameDuration;
    TVals   = CoolingTemperature[#, THot, TCold, tau] & /@ times;
    eqTime  = ThermalEquilibriumTime[tau, 0.10];
    eqFrameIdx = Min[nFrames, Max[1, Round[eqTime / frameDuration] + 1]];

    frames = Table[
      Module[{T, spec, amps, pans, l, r, ampScale},
        T = TVals[[k]];
        spec     = MBSpectrumBins[massAmu, T, nBins, freqMin, freqMax];
        ampScale = Sqrt[Clip[T / THot, {0.0, 1.0}]];  (* quieter as the gas cools *)
        amps     = ampScale * spec["amps"] / Sqrt[N[nBins]];
        pans     = ConstantArray[0.0, nBins];
        {l, r}   = SynthesizeAdditiveFrame[spec["freqs"], amps, pans, frameDuration, sr];
        If[k === eqFrameIdx, {l, r} = AddEquilibriumAccent[l, r, sr]];
        {l, r}
      ],
      {k, nFrames}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "TVals" -> TVals, "times" -> times, "eqTime" -> eqTime, "eqFrameIdx" -> eqFrameIdx,
      "frameDuration" -> frameDuration, "nBins" -> nBins,
      "freqMin" -> freqMin, "freqMax" -> freqMax, "massAmu" -> massAmu,
      "THot" -> THot, "TCold" -> TCold, "tau" -> tau
    |>
  ];


(* ── Mode 4: equipartition ────────────────────────────────────────── *)

(* Rotational drone frequency range — sqrt(kT) itself is a physically
   tiny number (~1e-11 at room temperature) with no natural audio
   scale, so it is remapped onto an audible "warm low drone" band
   (40-150 Hz) linearly in Sqrt[T], preserving the freq ~ Sqrt[T]
   ~ Sqrt[rotational energy] shape the physics calls for while landing
   somewhere a listener can actually hear. *)
$thermoRotFreqLo = 40.0;
$thermoRotFreqHi = 150.0;

RotationalDroneFreq[T_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ] :=
  Module[{sT = Sqrt[T], sLo = Sqrt[TStart], sHi = Sqrt[TEnd]},
    $thermoRotFreqLo + ($thermoRotFreqHi - $thermoRotFreqLo) *
      Clip[(sT - sLo) / (sHi - sLo), {0.0, 1.0}]
  ];

BuildEquipartitionAudio[massAmu_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ, nSteps_Integer,
                        nBins_Integer, freqMin_?NumericQ, freqMax_?NumericQ,
                        frameDuration_?NumericQ, moleculeType_String, sr_Integer] :=
  Module[{TVals, rotFrac, frames, leftAll, rightAll},
    TVals   = N[Subdivide[TStart, TEnd, nSteps - 1]];
    rotFrac = If[moleculeType === "diatomic", RotationalFraction[TStart, "diatomic"], 0.0];

    frames = Map[
      Function[T,
        Module[{spec, ampsL, pansL, l, rDummy, r, nSamplesFrame, rotFreq, tVec, env, fadeSamples},
          spec  = MBSpectrumBins[massAmu, T, nBins, freqMin, freqMax];
          ampsL = spec["amps"] / Sqrt[N[nBins]];
          pansL = ConstantArray[0.0, nBins];
          {l, rDummy} = SynthesizeAdditiveFrame[spec["freqs"], ampsL, pansL, frameDuration, sr];

          nSamplesFrame = Length[l];
          If[moleculeType === "diatomic",
            rotFreq     = RotationalDroneFreq[T, TStart, TEnd];
            tVec        = N[Range[0, nSamplesFrame - 1]] / sr;
            fadeSamples = Min[Round[0.005 * sr], Floor[nSamplesFrame / 4]];
            env         = FrameWindow[nSamplesFrame, fadeSamples];
            r = rotFrac * Sin[2.0 Pi rotFreq tVec] * env,
            r = ConstantArray[0.0, nSamplesFrame]
          ];
          {l, r}
        ]
      ],
      TVals
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];

    <|
      "left" -> leftAll, "right" -> rightAll, "sr" -> sr,
      "TVals" -> TVals, "moleculeType" -> moleculeType, "rotFrac" -> rotFrac,
      "frameDuration" -> frameDuration
    |>
  ];

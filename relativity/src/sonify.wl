(* ========================================================
   relativity/src/sonify.wl — Audio export for gravitational wave chirp

   Public API:
     SonifyRelativity[model, cfg, outDir]

   The gravitational wave strain h(t) IS an audio waveform.
   Time-stretching and optional frequency-shifting make the
   millisecond-scale chirp audible.

   Primary output:
     chirp.wav     — main event with configured parameters

   Preset comparison outputs (always produced):
     gw150914.wav  — 36+29 M☉ binary black hole merger (LIGO first detection)
     gw170817.wav  — 1.17+1.36 M☉ neutron star merger (final 10s of inspiral)
     stellar.wav   — 10+8 M☉ stellar-mass binary
   ======================================================== *)


(* ── ChirpToAudio ─────────────────────────────────────────
   Convert a strain array to a normalised audio buffer.

   strain      — raw h(t) array at sr_model samples/s
   sr_model    — model sample rate (Hz)
   sr_out      — output audio sample rate (Hz)
   timeStretch — factor > 1 slows the signal down (audible duration longer)
   freqShift   — multiplicative pitch shift (1.0 = no shift)

   Time stretching: output duration = T_original × timeStretch / freqShift.
   The strain is time-expanded by timeStretch and pitch-shifted by freqShift
   via resampling.  freqShift > 1 raises pitch and shortens duration.

   Normalises the output to peak 0.9.
   ─────────────────────────────────────────────────────────── *)

ChirpToAudio[strain_List, srModelRaw_?NumericQ,
             srOutRaw_?NumericQ, timeStretch_?NumericQ,
             freqShift_?NumericQ] :=
  Module[{srModel, srOut, n, T, Tout, nOut, tSrc, hInterp, tDest, hOut, peak},

    srModel = Round[srModelRaw];
    srOut   = Round[srOutRaw];
    n = Length[strain];
    T = N[(n - 1) / srModel];     (* original duration, seconds *)

    (* Output duration and sample count.
       freqShift > 1 compresses (higher pitch, shorter).
       timeStretch > 1 expands (lower pitch, longer). *)
    Tout = T * N[timeStretch / freqShift];
    nOut = Max[1, Round[Tout * srOut]];

    (* Build interpolation over physical time t ∈ [0, T] *)
    tSrc    = N @ Range[0, n - 1] / srModel;
    hInterp = Interpolation[Transpose[{tSrc, N @ strain}],
                            InterpolationOrder -> 1];

    (* For output sample k (0-indexed), the corresponding physical time is:
         t_phys = (k / srOut) × freqShift / timeStretch
       This maps the output time grid back to the original signal. *)
    tDest = Clip[
      N @ Range[0, nOut - 1] / srOut * (freqShift / timeStretch),
      {0.0, T}];

    hOut = hInterp /@ tDest;

    (* Normalise to peak amplitude 0.9 *)
    peak = Max[Abs[hOut]];
    If[peak > 0.0, hOut * (0.9 / peak), hOut]
  ]


(* ── SonifyPreset ─────────────────────────────────────────
   Compute ChirpModel for given masses and distance, apply
   audio processing, and export to wavPath.

   maxInspiral — if > 0, truncate to the last maxInspiral
                 seconds of the inspiral before merger.
   ─────────────────────────────────────────────────────────── *)

SonifyPreset[pm1_?NumericQ, pm2_?NumericQ, pDistMpc_?NumericQ,
             cfg_Association, wavPath_String] :=
  SonifyPreset[pm1, pm2, pDistMpc, cfg, wavPath, 0.0]

SonifyPreset[pm1_?NumericQ, pm2_?NumericQ, pDistMpc_?NumericQ,
             cfg_Association, wavPath_String,
             maxInspiral_?NumericQ] :=
  Module[{presetCfg, model, strain, mergerIdx, srModel,
          srOut, timeStretch, freqShift, audio, startIdx},

    (* Merge preset masses/distance into a local config *)
    presetCfg = DeepMerge[cfg, <|
      "simulation" -> <|"chirp" -> <|
        "mass1_solar"  -> pm1,
        "mass2_solar"  -> pm2,
        "distance_mpc" -> pDistMpc
      |>|>|>];

    model = ChirpModel[presetCfg];

    strain    = model["strain"];
    mergerIdx = model["merger_index"];
    srModel   = Round @ model["sample_rate"];

    srOut       = Round @ GetCfg[cfg, {"sonification","sample_rate"},          44100];
    timeStretch = N @ GetCfg[cfg, {"sonification","chirp","time_stretch"}, 4.0];
    freqShift   = N @ GetCfg[cfg, {"sonification","chirp","frequency_shift"}, 1.0];

    (* Optional truncation to final maxInspiral seconds of inspiral *)
    If[maxInspiral > 0.0,
      startIdx = Max[1, mergerIdx - Round[maxInspiral * srModel]];
      strain   = Join[strain[[startIdx ;; mergerIdx]],
                      strain[[mergerIdx + 1 ;; -1]]]
    ];

    audio = ChirpToAudio[strain, srModel, srOut, timeStretch, freqShift];

    EnsureDir[wavPath];
    ExportAudioBuffer[audio, wavPath, srOut];
    STEMDescribeWAV[wavPath, N[Length[audio] / srOut]]
  ]


(* ── SonifyRelativity ──────────────────────────────────── *)

SonifyRelativity[model_Association, cfg_Association, outDir_String] :=
  Module[{
    mode, strain, mergerIdx, srModel,
    srOut, timeStretch, freqShift,
    chirpMass, fSweepMin, fSweepMax, tc, audioDur,
    mainPath, audio
  },

  mode = model["mode"];
  If[mode === "geodesic", Return @ SonifyGeodesic[model, cfg, outDir]];

  strain    = model["strain"];
  mergerIdx = model["merger_index"];
  srModel   = Round @ model["sample_rate"];
  chirpMass = model["chirp_mass_solar"];
  fSweepMin = N @ First[model["frequency"]];
  fSweepMax = model["peak_frequency"];
  tc        = model["coalescence_time"];

  srOut       = Round @ GetCfg[cfg, {"sonification","sample_rate"},              44100];
  timeStretch = N @ GetCfg[cfg, {"sonification","chirp","time_stretch"},     4.0];
  freqShift   = N @ GetCfg[cfg, {"sonification","chirp","frequency_shift"}, 1.0];

  (* ── Primary chirp WAV (current model parameters) ── *)
  mainPath = FileNameJoin[{outDir, "chirp.wav"}];
  Print["  Processing main chirp..."];
  audio    = ChirpToAudio[strain, srModel, srOut, timeStretch, freqShift];
  EnsureDir[mainPath];
  ExportAudioBuffer[audio, mainPath, srOut];
  audioDur = N[Length[audio] / srOut];
  STEMDescribeWAV[mainPath, audioDur];

  (* ── Preset comparison WAVs ─────────────────────── *)
  Print[""];
  Print["  Computing preset comparison WAVs..."];

  (* GW150914: 36+29 solar mass binary black hole, 410 Mpc *)
  Print["  GW150914 (36+29 M☉ binary black hole, 410 Mpc)..."];
  SonifyPreset[36.0, 29.0, 410.0, cfg,
    FileNameJoin[{outDir, "gw150914.wav"}]];

  (* GW170817: 1.17+1.36 solar mass neutron star merger, 40 Mpc.
     Inspiral is ~172 s long; truncate to the final 10 s where
     the sweep through the audio band is most dramatic. *)
  Print["  GW170817 (1.17+1.36 M☉ neutron star merger, 40 Mpc, last 10 s)..."];
  SonifyPreset[1.17, 1.36, 40.0, cfg,
    FileNameJoin[{outDir, "gw170817.wav"}],
    10.0];   (* truncate to last 10 s of inspiral *)

  (* Stellar mass binary: 10+8 solar masses, 100 Mpc *)
  Print["  Stellar (10+8 M☉, 100 Mpc)..."];
  SonifyPreset[10.0, 8.0, 100.0, cfg,
    FileNameJoin[{outDir, "stellar.wav"}]];

  (* ── Terminal announcements ──────────────────────── *)
  Print[""];
  STEMSay[
    "Gravitational wave audio ready. " <>
    "Chirp mass: " <> ToString[NumberForm[chirpMass, {4,1}]] <> " solar masses. " <>
    "Frequency sweep: " <> ToString[Round[fSweepMin]] <>
    " to " <> ToString[Round[fSweepMax]] <> " hertz. " <>
    "Merger time: " <> ToString[NumberForm[tc, {4,3}]] <> " seconds. " <>
    "Audio duration: " <> ToString[NumberForm[audioDur, {4,2}]] <> " seconds. " <>
    "Listen for rising pitch and amplitude ending in abrupt merger, " <>
    "followed by fading ringdown."
  ]
]


(* ── SonifyGeodesic ──────────────────────────────────────
   Sonify a Schwarzschild geodesic trajectory.

   Pitch mapping (per orbit_type):
     bound    — frequency ∝ dφ/dτ (orbital angular velocity)
                The tone wobbles as the particle speeds up near periapsis
                and slows near apoapsis; GR periapsis advance is audible
                as a slow drift in the wobble pattern.
     plunging — frequency ∝ 1/√(1−2/r̃)  (gravitational blueshift);
                amplitude ∝ redshift → fades to silence at the horizon.
     photon   — same blueshift pitch as plunging; amplitude constant
                (deflected photon: frequency blips up then back down).

   All modes normalised so the mean pitch lands at pitch_base_hz.
   ─────────────────────────────────────────────────────────── *)

SonifyGeodesic[model_Association, cfg_Association, outDir_String] :=
  Module[{
    orbitType, tauArr, rArr, dphiArr, redshiftArr, omegaMean,
    n,
    srOut, pitchBase, durS,
    nAudio, idxArr,
    fAudio, fMean, ampArr, phaseArr, hAudio, peak, eps,
    wavPath
  },

  orbitType   = model["orbit_type"];
  tauArr      = model["tau"];
  rArr        = model["r"];
  dphiArr     = model["dphi_dtau"];
  redshiftArr = model["redshift"];
  omegaMean   = model["omega_mean"];
  n           = Length[tauArr];

  srOut     = Round @ GetCfg[cfg, {"sonification","sample_rate"},              44100];
  pitchBase = N @ GetCfg[cfg, {"sonification","geodesic","pitch_base_hz"}, 220.0];
  durS      = N @ GetCfg[cfg, {"sonification","geodesic","duration_s"},     10.0];

  nAudio = Round[durS * srOut];
  eps    = 1.0*^-8;

  (* Map each audio sample linearly to a model array index *)
  idxArr = Clip[Round[N @ Range[0, nAudio-1] * (n-1) / (nAudio-1)] + 1, {1, n}];

  (* Compute instantaneous pitch and amplitude arrays *)
  Which[
    orbitType === "bound",
      (* Pitch ∝ angular velocity; mean maps to pitch_base_hz *)
      fAudio = N[pitchBase * dphiArr[[idxArr]] / Max[omegaMean, eps]];
      ampArr = N[redshiftArr[[idxArr]]],    (* mild redshift variation ~89-95% *)

    orbitType === "plunging",
      (* Pitch rises as r→2 (blueshift); amplitude fades to 0 at horizon *)
      fAudio = N[pitchBase / Sqrt[Clip[1.0 - 2.0/rArr[[idxArr]], {eps, 1.0}]]];
      fMean  = N @ Mean[fAudio];
      fAudio = N[pitchBase * fAudio / Max[fMean, eps]];  (* normalise mean to pitchBase *)
      ampArr = N[redshiftArr[[idxArr]]],

    orbitType === "photon",
      (* Pitch follows gravitational blueshift; amplitude stays constant *)
      fAudio = N[pitchBase / Sqrt[Clip[1.0 - 2.0/rArr[[idxArr]], {eps, 1.0}]]];
      fMean  = N @ Mean[fAudio];
      fAudio = N[pitchBase * fAudio / Max[fMean, eps]];
      ampArr = N[redshiftArr[[idxArr]]],

    True,
      fAudio = ConstantArray[pitchBase, nAudio];
      ampArr = ConstantArray[1.0, nAudio]
  ];

  (* Clip to a safe audible range *)
  fAudio = Clip[fAudio, {20.0, 8000.0}];

  (* Integrate phase: Φ[k] = 2π · Σᵢ f[i] · Δt_audio *)
  phaseArr = N[2.0 Pi * Accumulate[fAudio] * (durS / nAudio)];
  hAudio   = ampArr * Sin[phaseArr];

  (* Normalise to peak 0.9 *)
  peak = Max[Abs[hAudio]];
  If[peak > 0.0, hAudio = 0.9 * hAudio / peak];

  wavPath = FileNameJoin[{outDir, "geodesic.wav"}];
  EnsureDir[wavPath];
  ExportAudioBuffer[hAudio, wavPath, srOut];
  STEMDescribeWAV[wavPath, durS];

  Print[""];
  STEMSay[
    "Geodesic audio ready. Orbit type: " <> orbitType <> ". " <>
    Switch[orbitType,
      "bound",
        "Pitch follows orbital angular frequency — hear the particle speed up at " <>
        "periapsis and slow at apoapsis. GR periapsis advance shifts the wobble pattern " <>
        "slightly each orbit, producing a slow drift.",
      "plunging",
        "Pitch rises as the particle blueshifts falling toward the event horizon. " <>
        "Amplitude fades to silence as gravitational redshift suppresses the signal.",
      "photon",
        "Pitch follows the gravitational blueshift as the photon passes near the " <>
        "black hole and deflects back out.",
      _,
        "Pitch follows orbital angular frequency."
    ]
  ]
]

(* ========================================================
   relativity/src/sonify.wl — Audio export for gravitational wave chirp

   Public API:
     SonifyRelativity[model, cfg, outDir]

   The gravitational wave strain h(t) IS the physical signal, but it
   is re-synthesized (not resampled) for playback — see ChirpToAudio
   below and the "Time-stretch bug" entry in AGENTS.md for why.

   Primary output:
     chirp.wav     — main event with configured parameters

   Preset comparison outputs (always produced):
     gw150914.wav  — 36+29 M☉ binary black hole merger (LIGO first detection)
     gw170817.wav  — 1.17+1.36 M☉ neutron star merger (final 10s of inspiral)
     stellar.wav   — 10+8 M☉ stellar-mass binary
   ======================================================== *)


(* ── ChirpToAudio ─────────────────────────────────────────
   Re-synthesize an audio buffer from the REAL, physically-accurate
   frequency and amplitude arrays, remapped onto a playback time axis.

   tPhys, fPhys, aPhys — physical time (s) / frequency (Hz, unaltered
                         real GW frequency) / amplitude arrays, all
                         from model.wl (ChirpModel), optionally
                         pre-truncated by the caller (e.g. maxInspiral)
   srOutRaw    — output audio sample rate (Hz)
   timeStretch — playback duration = (physical time span of tPhys) ×
                 timeStretch. Values > 1 slow real time down (longer,
                 more audible clip); < 1 would compress it.
   freqShift   — independent pitch multiplier (1.0 = no shift),
                 applied directly to the real frequency values with
                 NO effect on playback duration.

   IMPORTANT — do not resample the waveform. The previous
   implementation built h(t) once (via ChirpModel's Cos[2π φ(t)]) and
   then resampled THAT waveform onto a stretched time grid. Resampling
   a waveform divides every frequency component by the resample
   factor — so a 4.2× "time stretch" silently divided the real
   20–412 Hz sweep down to ~5–97 Hz, well below what typical speakers
   render audibly. See AGENTS.md § "Time-stretch bug: pitch-shift
   conflated with duration-stretch" for the full story.

   This version never touches the waveform. It interpolates fPhys and
   aPhys — real values — onto the *playback* time axis, then
   re-integrates phase over playback time. The real frequency values
   are therefore preserved exactly, regardless of how much the
   duration is stretched or compressed, because the frequency axis is
   never divided by the stretch factor.

   Normalises the output to peak 0.9.
   ─────────────────────────────────────────────────────────── *)

ChirpToAudio[tPhys_List, fPhys_List, aPhys_List, srOutRaw_?NumericQ,
             timeStretch_?NumericQ, freqShift_?NumericQ] :=
  Module[{srOut, t0, tRealSpan, Tplayback, nOut, dtOut,
          tPlaybackArr, tPhysQuery, fInterp, aInterp,
          fAudio, aAudio, phaseArr, hAudio, peak},

    srOut     = Round[srOutRaw];
    t0        = First[tPhys];
    tRealSpan = Last[tPhys] - t0;     (* real physical duration spanned *)

    Tplayback = tRealSpan * N[timeStretch];
    nOut      = Max[1, Round[Tplayback * srOut]];
    dtOut     = 1.0 / srOut;

    (* Playback-time axis, mapped back to the physical time each
       playback sample corresponds to. Linear remap: t_phys advances
       (tRealSpan/Tplayback) = 1/timeStretch physical seconds per
       playback second. This is a re-timing of the time AXIS, not a
       resample of the waveform. *)
    tPlaybackArr = N @ Range[0, nOut - 1] * dtOut;
    tPhysQuery   = Clip[t0 + tPlaybackArr * (tRealSpan / Tplayback),
                        {t0, Last[tPhys]}];

    fInterp = Interpolation[Transpose[{tPhys, N @ fPhys}], InterpolationOrder -> 1];
    aInterp = Interpolation[Transpose[{tPhys, N @ aPhys}], InterpolationOrder -> 1];

    (* freqShift multiplies the real frequency values directly — a
       genuine, independent pitch control with no effect on nOut/
       Tplayback (unlike the old resample-based implementation, where
       pitch and duration were mathematically coupled). *)
    fAudio = N[freqShift] * (fInterp /@ tPhysQuery);
    aAudio = aInterp /@ tPhysQuery;

    (* Reconstruct phase by integrating the REAL (optionally
       pitch-shifted) frequency values over PLAYBACK time. This is
       what preserves true frequency content regardless of stretch. *)
    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dtOut];
    hAudio   = aAudio * Cos[phaseArr];

    (* Normalise to peak amplitude 0.9 *)
    peak = Max[Abs[hAudio]];
    If[peak > 0.0, hAudio * (0.9 / peak), hAudio]
  ]


(* ── SonifyPreset ─────────────────────────────────────────
   Compute ChirpModel for given masses and distance, apply
   audio processing, and export to wavPath.

   maxInspiral         — if > 0, truncate to the last maxInspiral
                         seconds of the inspiral before merger.
   timeStretchOverride — Automatic to use the shared
                         sonification.chirp.time_stretch config value,
                         or an explicit numeric override for presets
                         whose real duration is different enough in
                         character to deserve their own stretch factor
                         (see GW170817 in SonifyRelativity).
   ─────────────────────────────────────────────────────────── *)

SonifyPreset[pm1_?NumericQ, pm2_?NumericQ, pDistMpc_?NumericQ,
             cfg_Association, wavPath_String] :=
  SonifyPreset[pm1, pm2, pDistMpc, cfg, wavPath, 0.0, Automatic]

SonifyPreset[pm1_?NumericQ, pm2_?NumericQ, pDistMpc_?NumericQ,
             cfg_Association, wavPath_String,
             maxInspiral_?NumericQ] :=
  SonifyPreset[pm1, pm2, pDistMpc, cfg, wavPath, maxInspiral, Automatic]

SonifyPreset[pm1_?NumericQ, pm2_?NumericQ, pDistMpc_?NumericQ,
             cfg_Association, wavPath_String,
             maxInspiral_?NumericQ, timeStretchOverride_] :=
  Module[{presetCfg, model, tArr, fArr, aArr, mergerIdx, srModel,
          srOut, timeStretch, freqShift, audio, startIdx},

    (* Merge preset masses/distance into a local config *)
    presetCfg = DeepMerge[cfg, <|
      "simulation" -> <|"chirp" -> <|
        "mass1_solar"  -> pm1,
        "mass2_solar"  -> pm2,
        "distance_mpc" -> pDistMpc
      |>|>|>];

    model = ChirpModel[presetCfg];

    tArr      = model["time"];
    fArr      = model["frequency"];
    aArr      = model["amplitude"];
    mergerIdx = model["merger_index"];
    srModel   = Round @ model["sample_rate"];

    srOut       = Round @ GetCfg[cfg, {"sonification","sample_rate"}, 44100];
    timeStretch = If[timeStretchOverride === Automatic,
      N @ GetCfg[cfg, {"sonification","chirp","time_stretch"}, 4.0],
      N @ timeStretchOverride];
    freqShift   = N @ GetCfg[cfg, {"sonification","chirp","frequency_shift"}, 1.0];

    (* Optional truncation to final maxInspiral seconds of inspiral.
       Slices the real time/frequency/amplitude arrays in lockstep —
       ChirpToAudio only ever sees real, unaltered values. *)
    If[maxInspiral > 0.0,
      startIdx = Max[1, mergerIdx - Round[maxInspiral * srModel]];
      tArr = Join[tArr[[startIdx ;; mergerIdx]], tArr[[mergerIdx + 1 ;; -1]]];
      fArr = Join[fArr[[startIdx ;; mergerIdx]], fArr[[mergerIdx + 1 ;; -1]]];
      aArr = Join[aArr[[startIdx ;; mergerIdx]], aArr[[mergerIdx + 1 ;; -1]]]
    ];

    audio = ChirpToAudio[tArr, fArr, aArr, srOut, timeStretch, freqShift];

    EnsureDir[wavPath];
    ExportAudioBuffer[NormalizeToLoudness[audio, -17.0, 0.97, srOut], wavPath, srOut];
    STEMDescribeWAV[wavPath, N[Length[audio] / srOut]]
  ]


(* ── SonifyRelativity ──────────────────────────────────── *)

SonifyRelativity[model_Association, cfg_Association, outDir_String] :=
  Module[{
    mode, tArr, fArr, aArr, mergerIdx,
    srOut, timeStretch, freqShift, gw170817Stretch,
    chirpMass, fSweepMin, fSweepMax, tc, audioDur,
    mainPath, audio
  },

  mode = model["mode"];
  If[mode === "geodesic", Return @ SonifyGeodesic[model, cfg, outDir]];

  tArr      = model["time"];
  fArr      = model["frequency"];
  aArr      = model["amplitude"];
  mergerIdx = model["merger_index"];
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
  audio    = ChirpToAudio[tArr, fArr, aArr, srOut, timeStretch, freqShift];
  EnsureDir[mainPath];
  ExportAudioBuffer[NormalizeToLoudness[audio, -17.0, 0.97, srOut], mainPath, srOut];
  audioDur = N[Length[audio] / srOut];
  STEMDescribeWAV[mainPath, audioDur];

  (* ── Preset comparison WAVs ─────────────────────── *)
  Print[""];
  Print["  Computing preset comparison WAVs..."];

  (* GW150914: 36+29 solar mass binary black hole, 410 Mpc.
     Real coalescence time ~0.85 s from f_min=20 Hz — the shared
     time_stretch (default 4×) makes this a short, dramatic ~3.6 s clip. *)
  Print["  GW150914 (36+29 M☉ binary black hole, 410 Mpc)..."];
  SonifyPreset[36.0, 29.0, 410.0, cfg,
    FileNameJoin[{outDir, "gw150914.wav"}]];

  (* GW170817: 1.17+1.36 solar mass neutron star merger, 40 Mpc.
     Real inspiral from f_min=20 Hz is ~188 s long — far too long to
     stretch further, so this preset already needs *compressing*, not
     stretching, to become a practical clip. We truncate to the final
     10 s of real inspiral (where the sweep through the audio band is
     most dramatic) and then apply a DEDICATED, smaller stretch factor
     (sonification.chirp.gw170817_time_stretch, default 1.5×) rather
     than reusing the shared 4× tuned for GW150914's much shorter
     merger: reusing 4× here would produce a ~40 s clip, disproportionate
     for a demo; 1.5× gives ~15 s — still ~4× longer than GW150914's
     clip (deliberately conveying "long, gradual inspiral" rather than
     "short, dramatic merger"), without being impractically long. *)
  gw170817Stretch = N @ GetCfg[cfg, {"sonification","chirp","gw170817_time_stretch"}, 1.5];
  Print["  GW170817 (1.17+1.36 M☉ neutron star merger, 40 Mpc, last 10 s)..."];
  SonifyPreset[1.17, 1.36, 40.0, cfg,
    FileNameJoin[{outDir, "gw170817.wav"}],
    10.0,             (* truncate to last 10 s of inspiral *)
    gw170817Stretch]; (* dedicated stretch — see comment above *)

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
  ExportAudioBuffer[NormalizeToLoudness[hAudio, -17.0, 0.97, srOut], wavPath, srOut];
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

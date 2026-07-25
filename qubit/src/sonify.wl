(* ========================================================
   qubit/src/sonify.wl — Three modes, three techniques.

   `gates` reuses lorenz/'s and henon/attractor's continuous-
   trajectory pipeline (SpatialLayer/MotionLayer/EventLayer via
   MixLayers, called directly rather than through SonifyTrajectory
   so a spoken intro can be prepended — the same workaround henon/
   and brownian/ use) — a gate genuinely IS a continuous rotation of
   the Bloch vector about some axis, and the Bloch vector's own
   {x,y,z} components map directly onto the trajectory's spatial
   columns with no invented mapping needed. A short accent tone marks
   each gate boundary (dynamical/henon-style OverlayEvent), giving
   the "narrated per-gate" structure compton/scatter's discrete event
   sequence has, adapted to a continuous underlying signal.

   `rabi` reuses the phase-accumulation glissando idiom from
   compton/sweep, relativity's chirp, and brownian/ensemble — P(1)(t)
   drives PITCH directly (not amplitude — see the reasoning below),
   so the oscillation rate Omega is literally audible as a rate of
   pitch change, the same "the equation IS the pitch bend" logic
   those apps already establish.

   `measurement` reuses the SAME continuous phase-accumulation
   technique as `rabi` (both are "one scalar quantity evolving over
   an index/time axis"), NOT bayes/coin's spectral-density layering —
   there is no evolving distribution SHAPE to render here (the true
   probability |alpha|^2 is fixed throughout a run; only the RUNNING
   ESTIMATE of it evolves), so bayes/coin's additive-spectral
   technique doesn't have anything to attach to. The connection to
   bayes/coin is structural and conceptual (both use SeedRandom'd
   Bernoulli draws with a running Accumulate), not a shared audio
   technique — see AGENTS.md.
   ======================================================== *)


(* ── gates mode ────────────────────────────────────────────────────── *)

(* BuildGatesTrajectory — {t,x,y,z,speed} matrix directly from the
   Bloch path's own {x,y,z} coordinates (no invented spatial mapping
   needed — the Bloch sphere's coordinates ARE the trajectory's
   spatial columns). Speed is genuine kinematic speed (finite
   differences of the path) — unlike brownian/'s deliberate deviation,
   there is no reason to substitute a different quantity here: "how
   fast is the Bloch vector currently rotating" is itself a physically
   meaningful thing to hear as volume. *)
BuildGatesTrajectory[rPath_List] :=
  Module[{n = Length[rPath], t, vx, vy, vz, speeds},
    t = N[Range[0, n - 1]];
    vx = Append[Differences[rPath[[All, 1]]], 0.0];
    vy = Append[Differences[rPath[[All, 2]]], 0.0];
    vz = Append[Differences[rPath[[All, 3]]], 0.0];
    speeds = Sqrt[vx^2 + vy^2 + vz^2];
    N[MapThread[{#1, #2, #3, #4, #5} &, {t, rPath[[All, 1]], rPath[[All, 2]], rPath[[All, 3]], speeds}]]
  ];

(* GatesStereoBuffer — calls stem-core's three layers directly (see
   module header), then overlays a short accent tone at each gate
   boundary (dynamical/henon's OverlayEvent pattern, duplicated per
   this codebase's no-shared-src/ convention). *)
GatesStereoBuffer[gatesResult_Association, cfg_Association] :=
  Module[{trajectory, sp, mo, ev, stereo, left, right, boundaries, n, sr, duration, dt},
    trajectory = BuildGatesTrajectory[gatesResult["rPath"]];
    sp = SpatialLayer[trajectory, cfg];
    mo = MotionLayer[trajectory, cfg];
    ev = EventLayer[trajectory, cfg, {"apex"}];
    stereo = MixLayers[sp, mo, ev, cfg];
    left = stereo[[All, 1]]; right = stereo[[All, 2]];

    n = Length[gatesResult["rPath"]];
    sr = CfgAt[cfg, {"sonification", "sample_rate"}, 44100];
    duration = CfgAt[cfg, {"sonification", "duration"}, N[n - 1]];
    dt = duration / N[Max[n - 1, 1]];

    boundaries = gatesResult["gateBoundaries"];
    Do[
      Module[{tSec, burst, startSample, len},
        tSec = (boundaries[[k]] - 1) * dt;
        burst = StemSynthNote[660.0, 0.08, 0.6, {1.0}, 0.3, sr];
        startSample = Clip[Round[tSec * sr] + 1, {1, Length[left]}];
        len = Min[Length[burst], Length[left] - startSample + 1];
        If[len > 0,
          left[[startSample ;; startSample + len - 1]]  += Sqrt[0.5] * burst[[1 ;; len]];
          right[[startSample ;; startSample + len - 1]] += Sqrt[0.5] * burst[[1 ;; len]]
        ]
      ],
      {k, 2, Length[boundaries]}  (* skip the k=1 boundary (t=0, no gate applied yet) *)
    ];
    {left, right}
  ];

(* CfgAt duplicated from stem-core/sonification.wl's private helper
   (not exported by that package) — same duplication henon/'s and
   brownian/'s output.wl carry for the same reason. *)
CfgAt[cfg_Association, keys_List, default_] :=
  With[{inner = Fold[Lookup[#1, #2, <||>] &, cfg, Most[keys]]},
    Lookup[inner, Last[keys], default]
  ];


(* ── shared continuous phase-accumulation glissando (rabi + measurement) ──
   BuildGlissandoBuffer — interpolates a scalar curve y(t) up to full
   audio-sample resolution and maps it (linearly, since both P(1) and
   a running frequency are already naturally bounded to [0,1] — no
   log compression needed the way blackbody's multi-decade sweeps
   require) onto [freqMin,freqMax] Hz, then drives a continuous tone
   via cumulative phase (compton/sweep's, relativity's, and
   brownian/ensemble's shared Accumulate-based technique). *)
BuildGlissandoBuffer[tVals_List, yVals_List, freqMin_?NumericQ, freqMax_?NumericQ,
                     duration_?NumericQ, sr_Integer] :=
  Module[{yInterp, nSamples, dt, tAudio, yAudio, fAudio, phaseArr, fadeSamples, envelope, mono},
    yInterp = Interpolation[Transpose[{tVals, yVals}], InterpolationOrder -> 1];
    nSamples = Round[duration * sr];
    dt = 1.0 / sr;
    tAudio = Rescale[N[Range[0, nSamples - 1]], {0, nSamples - 1}, {First[tVals], Last[tVals]}];
    yAudio = Clip[yInterp /@ tAudio, {0.0, 1.0}];
    fAudio = freqMin + (freqMax - freqMin) * yAudio;

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];
    fadeSamples = Round[0.05 * sr];
    envelope = QubitFrameWindow[nSamples, fadeSamples];
    mono = 0.8 * Sin[phaseArr] * envelope;
    {mono, mono}
  ];

QubitFrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ── rabi mode ─────────────────────────────────────────────────────── *)

(* RabiStereoBuffer — pitch tracks P(1)(t) directly (NOT amplitude):
   Rabi oscillation is fundamentally a FREQUENCY phenomenon (the drive
   frequency Omega), so encoding population inversion as continuous
   pitch bend lets a listener directly perceive the oscillation RATE
   as a rate of pitch change — the same "the equation IS the pitch
   bend" choice compton/sweep and relativity's chirp make for their
   own governing formulas. An amplitude-only mapping would convey
   *magnitude* (how excited) but not *rate* (how fast Omega drives
   the oscillation) nearly as directly. *)
RabiStereoBuffer[Omega_?NumericQ, tMax_?NumericQ, freqMin_?NumericQ, freqMax_?NumericQ,
                 duration_?NumericQ, sr_Integer] :=
  Module[{tVals, p1Vals},
    tVals = N[Subdivide[0.0, tMax, 500]];
    p1Vals = RabiProbability1[Omega, #] & /@ tVals;
    BuildGlissandoBuffer[tVals, p1Vals, freqMin, freqMax, duration, sr]
  ];


(* ── measurement mode ─────────────────────────────────────────────── *)

(* MeasurementStereoBuffer — pitch tracks the running empirical
   frequency of outcome 0, converging toward the true |alpha|^2 as
   trials accumulate — audible as a wobbly tone that gradually settles
   onto a steady pitch. See module header for why this reuses the
   glissando technique rather than bayes/coin's spectral layering. *)
MeasurementStereoBuffer[trialsResult_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                        duration_?NumericQ, sr_Integer] :=
  Module[{n, tVals, yVals},
    n = trialsResult["nTrials"];
    tVals = N[Range[1, n]];
    yVals = trialsResult["runningFreq0"];
    BuildGlissandoBuffer[tVals, yVals, freqMin, freqMax, duration, sr]
  ];

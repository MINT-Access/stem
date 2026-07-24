(* ========================================================
   brownian/src/sonify.wl — Three modes, three techniques,
   one deliberate deviation.

   `walk` reuses lorenz/'s and henon/attractor's continuous-
   trajectory pipeline (SpatialLayer/MotionLayer/EventLayer via
   MixLayers, called directly rather than through SonifyTrajectory
   so a spoken intro can be prepended — the same workaround
   montecarlo/ and henon/ use) — the same kind of continuous 2D
   position trajectory those apps sonify.

   BUT: volume here comes from r = sqrt(x^2+y^2), the displacement
   from the origin — NOT from speed, the convention every other
   trajectory app in this codebase uses. This is deliberate: "how
   far has it wandered from where it started" is the physically
   meaningful quantity for a diffusing particle. A speed-driven
   volume would just track local jitter, which is present at every
   temperature and every diffusion coefficient and says nothing
   about diffusion specifically — r's slow, noisy growth IS the
   phenomenon. Implemented by feeding r into the trajectory's own
   "speed" column (column 5 of the {t,x,y,z,speed} matrix stem-core
   expects) rather than an actual kinematic speed — SpatialLayer's
   volume computation reads that column directly, so this is a
   clean substitution with no stem-core changes needed. See
   AGENTS.md for the full rationale, including the side effect this
   has on MotionLayer's roughness/envelope (which also reads the
   same column).

   `ensemble` reuses the phase-accumulation glissando idiom from
   compton/sweep and relativity/'s chirp (Phi[k] = 2 Pi
   Accumulate[f]*dt) — but here the frequency array comes from
   interpolating a REAL Monte Carlo ensemble RMS(t) curve up to
   audio-sample resolution, not recomputing a closed-form physics
   formula at every sample the way compton/relativity do (there is
   no continuous closed form for an ensemble average — it has to
   be run at some finite step resolution and only then interpolated).

   `temperature` reuses thermo/distribution's per-step-frame
   concatenation idiom: one short frame per temperature, Flatten
   across steps.
   ======================================================== *)


(* ── walk mode ──────────────────────────────────────────────────── *)

(* BuildWalkTrajectory — {t,x,y,z,speed} matrix from a WalkTrajectory
   table, with r (NOT kinematic speed) in the 5th column. z unused
   (this is a 2D walk), set to 0 throughout. *)
BuildWalkTrajectory[walkTable_List] :=
  Module[{n = Length[walkTable]},
    N[Table[
      {walkTable[[i, 1]], walkTable[[i, 2]], walkTable[[i, 3]], 0.0, walkTable[[i, 4]]},
      {i, n}
    ]]
  ];

(* WalkStereoBuffer — calls stem-core's three layers directly
   (SpatialLayer/MotionLayer/EventLayer -> MixLayers) rather than the
   one-shot SonifyTrajectory[..., filePath], so the {left,right}
   arrays come back for main.wl to prepend a spoken intro before
   export (same pattern as henon/src/sonify.wl's AttractorStereoBuffer). *)
WalkStereoBuffer[walkTable_List, cfg_Association] :=
  Module[{trajectory, sp, mo, ev, stereo},
    trajectory = BuildWalkTrajectory[walkTable];
    sp = SpatialLayer[trajectory, cfg];
    mo = MotionLayer[trajectory, cfg];
    ev = EventLayer[trajectory, cfg, {"apex"}];
    stereo = MixLayers[sp, mo, ev, cfg];
    {stereo[[All, 1]], stereo[[All, 2]]}
  ];


(* ── ensemble mode ──────────────────────────────────────────────── *)

(* EnsembleGlissandoBuffer — interpolates the ensemble's empirical
   RMS(t) curve up to full audio-sample resolution, maps it to a log
   frequency range (linear-in-RMS -> log-in-Hz, so the sqrt(t) shape
   of the underlying physics is preserved in the pitch-vs-time curve
   a listener actually hears, while frequency itself still moves
   perceptually sensibly), and drives a single continuous glissando
   tone via cumulative phase (relativity's / compton/sweep's chirp
   technique) — no closed form to recompute at each sample here, so
   the coarse ensemble RMS(t) curve (computed once, at the model's
   own nSteps resolution) is interpolated rather than regenerated. *)
EnsembleGlissandoBuffer[ensembleModel_Association, freqMin_?NumericQ, freqMax_?NumericQ,
                       duration_?NumericQ, sr_Integer] :=
  Module[{t, rms, rmsInterp, nSamples, tAudio, rmsAudio, rmsMax,
          normRms, fAudio, dt, phaseArr, fadeSamples, envelope, mono},
    t   = ensembleModel["t"];
    rms = ensembleModel["rms"];

    rmsInterp = Interpolation[Transpose[{t, rms}], InterpolationOrder -> 1];
    nSamples  = Round[duration * sr];
    dt        = 1.0 / sr;
    tAudio    = Rescale[N[Range[0, nSamples - 1]], {0, nSamples - 1}, {First[t], Last[t]}];
    rmsAudio  = rmsInterp /@ tAudio;

    rmsMax  = Last[rms];  (* RMS(t) is monotonically non-decreasing *)
    normRms = Clip[rmsAudio / rmsMax, {0.0, 1.0}];
    fAudio  = freqMin * (freqMax / freqMin)^normRms;

    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];

    fadeSamples = Round[0.05 * sr];
    envelope    = BrownianFrameWindow[nSamples, fadeSamples];
    mono        = 0.8 * Sin[phaseArr] * envelope;

    {mono, mono}  (* centred — the ensemble average has no spatial position of its own *)
  ];

(* BrownianFrameWindow — linear fade in/out, duplicated per this
   codebase's convention (blackbody/thermo/compton each carry their
   own copy rather than sharing one beyond stem-core). *)
BrownianFrameWindow[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ── temperature mode ───────────────────────────────────────────── *)

(* BuildTemperatureAudio — one short WalkStereoBuffer frame per
   temperature step, concatenated (thermo/distribution's per-step-
   frame idiom). Fixed dt across all frames means a hotter
   temperature's larger D shows up directly as bigger per-step
   jiggle amplitude — the audible "hotter = more agitated" goal —
   without needing any separate rate/amplitude scaling logic.

   frameDuration OVERRIDES cfg's own sonification.duration for each
   short frame — that shared key is `walk` mode's full-length-audio
   knob, not a per-frame one; without this override every one of
   these short snippets would try to stretch across the SAME full
   configured duration (e.g. the default 10s), turning a handful of
   temperature steps into many minutes of audio. *)
BuildTemperatureAudio[tVals_List, dVals_List, nStepsPerFrame_Integer,
                     dt_?NumericQ, frameDuration_?NumericQ, cfg_Association] :=
  Module[{cfgFrame, frames, leftAll, rightAll},
    cfgFrame = DeepMerge[cfg, <| "sonification" -> <| "duration" -> frameDuration |> |>];
    frames = MapThread[
      Function[{T, D},
        Module[{walkTable, left, right},
          walkTable = WalkTrajectory[nStepsPerFrame, D, dt];
          {left, right} = WalkStereoBuffer[walkTable, cfgFrame];
          {left, right}
        ]
      ],
      {tVals, dVals}
    ];
    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    {leftAll, rightAll}
  ];

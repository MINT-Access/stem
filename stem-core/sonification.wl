(* ============================================================
   stem-core/sonification.wl
   Three-layer sonification API
   ============================================================ *)

BeginPackage["StemCore`Sonification`"]

(* Public symbols *)
SpatialLayer; MotionLayer; EventLayer;
MixLayers; RenderAudio; SonifyTrajectory;

Begin["`Private`"]

(* ------------------------------------------------------------
   CfgAt — safe nested key-path lookup with default

   Walks cfg["k1"]["k2"]...["kN"] and returns default if any
   level is absent or not an Association.  Replaces the broken
   pattern Lookup[cfg, {"k1","k2","k3"}, default], which returns
   a list of individual top-level lookups rather than a path walk.
   ------------------------------------------------------------ *)

CfgAt[cfg_Association, keys_List, default_] :=
  With[{inner = Fold[Lookup[#1, #2, <||>] &, cfg, Most[keys]]},
    Lookup[inner, Last[keys], default]
  ]


(* ------------------------------------------------------------
   LAYER 1 — Spatial
   Maps position/velocity to stereo pan, pitch, and volume.

   Input: time series of {t, x, y, z, speed} rows
   Output: Association of sample-rate audio arrays
   ------------------------------------------------------------ *)

SpatialLayer[trajectory_?MatrixQ, cfg_Association] := Module[
  {t, x, y, z, speed,
   panRange, pitchRange, volRange, sampleRate, duration,
   panAxis, pitchAxis,
   nSamples, times,
   panArr, pitchArr, volArr},

  (* Unpack trajectory columns: {t, x, y, z, speed} *)
  {t, x, y, z, speed} = Transpose[trajectory];

  panRange   = CfgAt[cfg, {"sonification","spatial","pan_range"},   {-1.0, 1.0}];
  pitchRange = {
    CfgAt[cfg, {"sonification","pitch","min_hz"}, 110],
    CfgAt[cfg, {"sonification","pitch","max_hz"}, 880]};
  volRange   = {
    CfgAt[cfg, {"sonification","volume","min_db"}, -24],
    CfgAt[cfg, {"sonification","volume","max_db"},   0]};
  sampleRate = CfgAt[cfg, {"sonification","sample_rate"}, 44100];
  duration   = CfgAt[cfg, {"sonification","duration"}, Last[t]];

  panAxis   = CfgAt[cfg, {"sonification","spatial","pan_axis"},  "x"];
  pitchAxis = CfgAt[cfg, {"sonification","pitch","axis"},        "y"];

  nSamples = Round[sampleRate * duration];
  times    = Rescale[Range[nSamples], {1, nSamples}, {First[t], Last[t]}];

  (* Interpolate the chosen axes onto the audio sample grid *)
  With[
    {panSrc   = Switch[panAxis,   "x", x, "y", y, "z", z, _, x],
     pitchSrc = Switch[pitchAxis, "x", x, "y", y, "z", z, _, y]},

    panArr   = Clip[Rescale[
                 Interpolation[Transpose[{t, panSrc}],   Method -> "Spline"][times],
                 MinMax[panSrc], panRange], panRange];

    pitchArr = Rescale[
                 Interpolation[Transpose[{t, pitchSrc}], Method -> "Spline"][times],
                 MinMax[pitchSrc], pitchRange];

    (* Volume from speed: fast = louder *)
    volArr   = Rescale[
                 Interpolation[Transpose[{t, speed}],    Method -> "Spline"][times],
                 MinMax[speed], volRange]
  ];

  <| "pan"   -> panArr,    (* -1 left … +1 right *)
     "pitch" -> pitchArr,  (* Hz, per sample *)
     "vol"   -> volArr,    (* dB, per sample *)
     "times" -> times,
     "sr"    -> sampleRate |>
]


(* ------------------------------------------------------------
   LAYER 2 — Motion character
   Adds timbre modulations that encode the quality of motion.

   tremolo   — oscillatory / periodic motion
   roughness — chaotic / turbulent motion
   envelope  — damped (decaying amplitude) or driven (sustained)
   ------------------------------------------------------------ *)

MotionLayer[trajectory_?MatrixQ, cfg_Association] := Module[
  {t, x, y, z, speed,
   sr, nSamples, times,
   tremoloRate, tremoloDepth, roughnessDepth,
   lyapunovProxy,  (* local divergence as chaos indicator *)
   periodicity,    (* autocorrelation as periodicity indicator *)
   tremoloArr, roughnessArr, envelopeArr},

  {t, x, y, z, speed} = Transpose[trajectory];
  sr       = CfgAt[cfg, {"sonification","sample_rate"}, 44100];
  nSamples = Round[sr * CfgAt[cfg, {"sonification","duration"}, Last[t]]];
  times    = Rescale[Range[nSamples], {1, nSamples}, {First[t], Last[t]}];

  tremoloRate    = CfgAt[cfg, {"sonification","motion","tremolo_rate_hz"}, 6.0];
  tremoloDepth   = CfgAt[cfg, {"sonification","motion","tremolo_depth"},   0.4];
  roughnessDepth = CfgAt[cfg, {"sonification","motion","noise_depth"},     0.15];

  (* Periodicity: high autocorrelation → strong tremolo *)
  periodicity = With[
    {ac = CorrelationFunction[x, {0, Min[200, Length[x] - 1]}]},
    Abs[Mean[Rest[ac]]]   (* scalar ∈ [0,1] *)
  ];

  (* Chaos proxy: variance of successive speed differences *)
  lyapunovProxy = Clip[
    Variance[Differences[speed]] / (Variance[speed] + $MachineEpsilon),
    {0, 1}];

  (* Tremolo: sinusoidal AM at tremoloRate, scaled by periodicity *)
  tremoloArr = 1.0 - tremoloDepth * periodicity *
    (0.5 + 0.5 * Sin[2 Pi * tremoloRate * times]);

  (* Roughness: white noise scaled by chaos proxy *)
  roughnessArr = 1.0 + roughnessDepth * lyapunovProxy *
    RandomReal[{-1, 1}, nSamples];

  (* Amplitude envelope: shape follows interpolated speed *)
  With[
    {speedInterp = Interpolation[Transpose[{t, speed}], Method -> "Spline"][times]},
    envelopeArr = Rescale[speedInterp, MinMax[speedInterp]]
  ];

  <| "tremolo"     -> tremoloArr,    (* multiplicative AM ∈ (0,1] *)
     "roughness"   -> roughnessArr,  (* multiplicative noise ∈ ~(0.85,1.15) *)
     "envelope"    -> envelopeArr,   (* amplitude shape ∈ [0,1] *)
     "periodicity" -> periodicity,
     "chaosLevel"  -> lyapunovProxy |>
]


(* ------------------------------------------------------------
   LAYER 3 — Events
   Detects discrete moments and synthesises short marker tones.

   Each event is a {time, type, intensity} triple.
   Types: "apex", "crossing", "approach", "period_double"
   ------------------------------------------------------------ *)

EventLayer[trajectory_?MatrixQ, cfg_Association,
           eventTypes_List : {"apex", "crossing"}] := Module[
  {t, x, y, z, speed,
   sr, duration, nSamples,
   events = {},
   apexTimes, crossTimes,
   eventAudio},

  {t, x, y, z, speed} = Transpose[trajectory];
  sr       = CfgAt[cfg, {"sonification","sample_rate"}, 44100];
  duration = CfgAt[cfg, {"sonification","duration"}, Last[t]];
  nSamples = Round[sr * duration];

  (* Apex detection: local maxima of |y| with minimum prominence.
     Table produces Length[t]-2 booleans for indices 2..n-1;
     Pick against t[[2;;-2]] so lengths match. *)
  If[MemberQ[eventTypes, "apex"],
    With[{yAbs = Abs[y]},
      apexTimes = Pick[t[[2 ;; -2]],
        Table[
          yAbs[[i]] > yAbs[[i - 1]] && yAbs[[i]] > yAbs[[i + 1]] &&
          yAbs[[i]] > 0.5 * Max[yAbs],
          {i, 2, Length[t] - 1}], True];
      events = Join[events,
        {#, "apex",
           Rescale[Abs[y[[Nearest[t -> "Index", #][[1]]]]],
                   MinMax[Abs[y]]]} & /@ apexTimes]
    ]
  ];

  (* Zero-crossing detection: x passes through origin *)
  If[MemberQ[eventTypes, "crossing"],
    crossTimes = Pick[t[[2 ;;]],
      Negative[x[[;; -2]] * x[[2 ;;]]], True];
    events = Join[events,
      {#, "crossing", 0.6} & /@ crossTimes]
  ];

  (* Synthesise marker: short sine burst for each event *)
  eventAudio = ConstantArray[0.0, nSamples];
  Do[
    With[
      {evtSample = Clip[Round[ev[[1]] / duration * nSamples], {1, nSamples}],
       evtIntens  = ev[[3]],
       burstLen   = Round[0.04 * sr],   (* 40 ms click/tone *)
       freq       = Switch[ev[[2]],
                      "apex",     880,
                      "crossing", 440,
                      "approach", 660,
                      _,          550]},
      With[{burst = evtIntens * 0.5 *
              Table[Sin[2 Pi * freq * i / sr] *
                    Exp[-8 i / burstLen],
                    {i, 0, burstLen - 1}]},
        eventAudio[[
          evtSample ;; Min[evtSample + burstLen - 1, nSamples]]] +=
          burst[[;; Min[burstLen, nSamples - evtSample + 1]]]
      ]
    ],
    {ev, events}
  ];

  <| "audio"  -> eventAudio,
     "events" -> events,
     "sr"     -> sr |>
]


(* ------------------------------------------------------------
   MixLayers — combine all three into a stereo WAV-ready array
   Output: {nSamples × 2} matrix (left, right channels)
   ------------------------------------------------------------ *)

MixLayers[spatial_Association, motion_Association,
          events_Association, cfg_Association] := Module[
  {sr, nSamples, t,
   pan, pitch, vol, tremolo, roughness, envelope, evtAudio,
   amp, carrier, leftCh, rightCh},

  sr       = spatial["sr"];
  nSamples = Length[spatial["times"]];
  t        = spatial["times"];

  pan       = spatial["pan"];
  pitch     = spatial["pitch"];
  vol       = spatial["vol"];
  tremolo   = motion["tremolo"];
  roughness = motion["roughness"];
  envelope  = motion["envelope"];
  evtAudio  = events["audio"];

  (* Amplitude from dB volume *)
  amp = 10.0^(vol / 20.0);

  (* Phase-accumulation carrier: variable-pitch sine *)
  carrier = Sin[2 Pi * Accumulate[pitch] / sr];

  (* Apply all modulations *)
  With[{mono = amp * envelope * tremolo * roughness * carrier + evtAudio},

    (* Constant-power pan law *)
    leftCh  = mono * Sqrt[(1.0 - pan) / 2.0];
    rightCh = mono * Sqrt[(1.0 + pan) / 2.0];

    Transpose[{leftCh, rightCh}]   (* nSamples × 2 *)
  ]
]


(* ------------------------------------------------------------
   RenderAudio — write the final WAV file
   ------------------------------------------------------------ *)

RenderAudio[stereoData_?MatrixQ, cfg_Association, outPath_String] :=
  Module[{sr, normalized, sound},
    sr         = CfgAt[cfg, {"sonification","sample_rate"}, 44100];
    normalized = stereoData / (Max[Abs[stereoData]] + $MachineEpsilon);
    sound      = Sound[SampledSoundList[Transpose[normalized], sr]];
    Export[outPath, sound, "WAV"];
    outPath
  ]


(* ------------------------------------------------------------
   SonifyTrajectory — single entry point for all apps
   trajectory: matrix with columns {t, x, y, z, speed}
   eventTypes: subset of {"apex","crossing","approach"}
   ------------------------------------------------------------ *)

SonifyTrajectory[trajectory_?MatrixQ, cfg_Association,
                 outPath_String,
                 eventTypes_List : {"apex", "crossing"}] :=
  Module[{sp, mo, ev, stereo},
    sp     = SpatialLayer[trajectory, cfg];
    mo     = MotionLayer[trajectory, cfg];
    ev     = EventLayer[trajectory, cfg, eventTypes];
    stereo = MixLayers[sp, mo, ev, cfg];
    RenderAudio[stereo, cfg, outPath]
  ]

End[]
EndPackage[]

(* ========================================================
   compton/src/sonify.wl — Audio synthesis for all four modes

   scatter: a short narrated sequence of discrete events (incoming
     tone, collision click, outgoing tone, recoil thud) -- StemSynthNote
     bursts, the same "single event, several discrete sounds" idiom
     scattering/'s scatter mode uses for its accent tone, but built
     entirely from discrete notes here since there is no continuous
     trajectory to ride (see AGENTS.md design decision 2 on why not).

   sweep / discovery: a SINGLE continuous tone (or two, for discovery)
     whose instantaneous frequency is computed at full audio-sample
     resolution and integrated into a continuous phase via
     Accumulate -- exactly relativity/src/sonify.wl's chirp technique
     (phaseArr = 2*Pi*Accumulate[fAudio]*dt), reused here because this
     app's own "equation IS the pitch bend" framing (per the build
     spec) is the same relationship relativity/'s chirp has to its
     governing frequency formula. A per-block discrete-note sweep
     (thermo/blackbody's per-step-frame style) would introduce audible
     clicks at every step; a glissando needs continuous phase.

   energy: discrete per-step frames (thermo/blackbody's per-step-frame
     style) -- appropriate here since each step plays a DYAD (incoming
     + outgoing note together), which a continuous single-phase
     accumulator cannot represent.
   ======================================================== *)


(* ── Shared: collision/backscatter accent burst ──────────────────── *)
(* Same construction as scattering's ScatteringAccentBurst / stem-core's
   EventLayer bursts: a short decaying sine, not pre-mixed into a
   full-length buffer. *)
ComptonAccentBurst[freq_?NumericQ, dur_?NumericQ, amp_?NumericQ, sr_Integer] :=
  Module[{burstLen = Max[1, Round[dur * sr]]},
    amp * Table[Sin[2.0 Pi * freq * k / sr] * Exp[-6.0 * k / burstLen], {k, 0, burstLen - 1}]
  ];

(* PanBuffer — splits a mono buffer into {left,right} at a FIXED pan
   value. For per-sample-varying pan (sweep/discovery), the panning is
   done inline on the full arrays instead (see BuildSweepAudio). *)
PanBuffer[mono_List, pan_?NumericQ] :=
  {Sqrt[(1.0 - pan) / 2.0] * mono, Sqrt[(1.0 + pan) / 2.0] * mono};


(* ========================================================
   MODE 1: scatter — narrated single-event sequence
   ======================================================== *)

BuildScatterAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                  EMinKev_?NumericQ, EMaxKev_?NumericQ, sr_Integer] :=
  Module[{
    freqIn, freqOut, thudFreq, pan, thudPan, noteDur, clickDur, thudDur, gapDur,
    inMono, inL, inR, click, clickL, clickR,
    outMono, outL, outR, thud, thudL, thudR, gap,
    leftAll, rightAll
  },
    freqIn   = PhotonPitchHz[model["EKeV"],      EMinKev, EMaxKev, audioFreqMin, audioFreqMax];
    freqOut  = PhotonPitchHz[model["EPrimeKeV"], EMinKev, EMaxKev, audioFreqMin, audioFreqMax];
    pan      = model["pan"];
    thudPan  = -pan;   (* recoil electron: opposite transverse side, by momentum conservation *)

    (* Thud pitch: low drone (40-150 Hz, blackbody's RotationalDroneFreq
       band) scaled by the FRACTION of incident energy the electron
       carries away (T/E) -- audible presence for the recoil electron,
       proportional to how much of the collision it actually absorbed. *)
    thudFreq = 40.0 + 110.0 * Clip[model["TKeV"] / model["EKeV"], {0.0, 1.0}];

    noteDur  = 1.1; clickDur = 0.05; thudDur = 0.7; gapDur = 0.15;

    inMono = StemSynthNote[freqIn, noteDur, 0.75, {1.0, 0.3}, 0.35, sr];
    {inL, inR} = PanBuffer[inMono, 0.0];   (* incoming: always centred, the reference tone *)

    click = ComptonAccentBurst[1500.0, clickDur, 0.9, sr];
    {clickL, clickR} = PanBuffer[click, 0.0];

    outMono = StemSynthNote[freqOut, noteDur, 0.75, {1.0, 0.3}, 0.35, sr];
    {outL, outR} = PanBuffer[outMono, pan];

    thud = StemSynthNote[thudFreq, thudDur, 0.2 + 0.6 * Clip[model["TKeV"] / model["EKeV"], {0.0, 1.0}],
                          {1.0, 0.15}, 0.5, sr];
    {thudL, thudR} = PanBuffer[thud, thudPan];

    gap = ConstantArray[0.0, Round[gapDur * sr]];

    (* Outgoing photon and recoil thud sound together (both are the
       collision's outcome, at t=collision), not in sequence. *)
    leftAll  = Join[inL, gap, clickL, gap,
                    PadRight[outL, Max[Length[outL], Length[thudL]]] +
                    PadRight[thudL, Max[Length[outL], Length[thudL]]]];
    rightAll = Join[inR, gap, clickR, gap,
                    PadRight[outR, Max[Length[outR], Length[thudR]]] +
                    PadRight[thudR, Max[Length[outR], Length[thudR]]]];

    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 2: sweep — continuous glissando, angle 0..180
   ======================================================== *)

BuildSweepAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
               EMinKev_?NumericQ, EMaxKev_?NumericQ, duration_?NumericQ, sr_Integer] :=
  Module[{nSamples, dt, tFrac, thetaDegAudio, EPrimeAudio, fAudio,
          phaseArr, envelope, fadeSamples, mono, panAudio, leftAll, rightAll},
    nSamples = Round[duration * sr];
    dt       = 1.0 / sr;
    tFrac    = N[Range[0, nSamples - 1]] / (nSamples - 1);

    (* Recompute E' and pan at full audio-sample resolution (not just
       at the model's nSteps grid) -- a smooth glissando needs a
       continuous instantaneous frequency, not an interpolation of a
       coarse step grid. *)
    thetaDegAudio = model["angleMin"] + (model["angleMax"] - model["angleMin"]) * tFrac;
    EPrimeAudio   = ComptonOutgoingEnergyKeV[model["EKeV"], #] & /@ (thetaDegAudio * Pi / 180.0);
    fAudio        = PhotonPitchHz[#, EMinKev, EMaxKev, audioFreqMin, audioFreqMax] & /@ EPrimeAudio;
    panAudio      = ComptonPan /@ thetaDegAudio;

    (* Phase by cumulative summation -- relativity/src/sonify.wl's
       chirp technique (Phi[k] = 2*Pi*Sum[f[i]*dt]), reused here so the
       swept tone has no phase discontinuities between samples. *)
    phaseArr = N[2.0 Pi * Accumulate[fAudio] * dt];

    fadeSamples = Round[0.05 * sr];
    envelope    = FrameWindowCompton[nSamples, fadeSamples];
    mono        = 0.8 * Sin[phaseArr] * envelope;

    leftAll  = Sqrt[(1.0 - panAudio) / 2.0] * mono;
    rightAll = Sqrt[(1.0 + panAudio) / 2.0] * mono;

    {leftAll, rightAll}
  ];

(* FrameWindowCompton — linear fade in/out, same construction as
   blackbody/thermo's FrameWindow (duplicated per app convention, not
   shared beyond stem-core). *)
FrameWindowCompton[nSamples_Integer, fadeSamples_Integer] :=
  Module[{env = ConstantArray[1.0, nSamples], fs = Min[fadeSamples, Floor[nSamples/2]], ramp},
    If[fs > 0,
      ramp = N[Range[0, fs - 1]] / fs;
      env[[1 ;; fs]] = ramp;
      env[[-fs ;;]]  = Reverse[ramp]
    ];
    env
  ];


(* ========================================================
   MODE 3: energy — discrete per-step dyad frames
   ======================================================== *)

BuildEnergyAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                 frameDuration_?NumericQ, sr_Integer] :=
  Module[{EMinKev, EMaxKev, EArr, EPrimeArr, restEnergyIdx, nSteps, frames, leftAll, rightAll},
    EMinKev = model["EMinKev"]; EMaxKev = model["EMaxKev"];
    EArr = model["EArr"]; EPrimeArr = model["EPrimeArr"];
    restEnergyIdx = model["restEnergyIdx"];
    nSteps = model["nSteps"];

    frames = Table[
      Module[{freqIn, freqOut, noteIn, noteOut, l, r, accent},
        freqIn  = PhotonPitchHz[EArr[[i]],      EMinKev, EMaxKev, audioFreqMin, audioFreqMax];
        freqOut = PhotonPitchHz[EPrimeArr[[i]], EMinKev, EMaxKev, audioFreqMin, audioFreqMax];
        noteIn  = StemSynthNote[freqIn,  frameDuration, 0.4, {1.0}, 0.5, sr];
        noteOut = StemSynthNote[freqOut, frameDuration, 0.4, {1.0}, 0.5, sr];
        {l, r} = PanBuffer[noteIn + noteOut, 0.0];
        If[i === restEnergyIdx,
          accent = ComptonAccentBurst[880.0, 0.06, 0.5, sr];
          l[[1 ;; Length[accent]]] += Sqrt[0.5] * accent;
          r[[1 ;; Length[accent]]] += Sqrt[0.5] * accent
        ];
        {l, r}
      ],
      {i, nSteps}
    ];

    leftAll  = Flatten[frames[[All, 1]]];
    rightAll = Flatten[frames[[All, 2]]];
    {leftAll, rightAll}
  ];


(* ========================================================
   MODE 4: discovery — binaural, continuous sweep both channels
   ======================================================== *)

BuildDiscoveryAudio[model_Association, audioFreqMin_?NumericQ, audioFreqMax_?NumericQ,
                    EMinKev_?NumericQ, EMaxKev_?NumericQ, duration_?NumericQ, sr_Integer] :=
  Module[{nSamples, dt, tFrac, thetaDegAudio, thetaRadAudio,
          EPrimeComptonAudio, freqThomson, fComptonAudio,
          phaseThomson, phaseCompton, envelope, fadeSamples, leftAll, rightAll},
    nSamples = Round[duration * sr];
    dt       = 1.0 / sr;
    tFrac    = N[Range[0, nSamples - 1]] / (nSamples - 1);

    thetaDegAudio = model["angleMin"] + (model["angleMax"] - model["angleMin"]) * tFrac;
    thetaRadAudio = thetaDegAudio * Pi / 180.0;

    (* Thomson (classical): flat -- constant frequency the whole time,
       equal to the incident photon's own pitch. No Accumulate needed
       (a genuinely constant frequency has no discontinuity to smooth). *)
    freqThomson  = PhotonPitchHz[model["EKeV"], EMinKev, EMaxKev, audioFreqMin, audioFreqMax];
    phaseThomson = N[2.0 Pi * freqThomson * Range[0, nSamples - 1] * dt];

    (* Compton (real): the same continuous-phase technique as sweep mode. *)
    EPrimeComptonAudio = ComptonOutgoingEnergyKeV[model["EKeV"], #] & /@ thetaRadAudio;
    fComptonAudio      = PhotonPitchHz[#, EMinKev, EMaxKev, audioFreqMin, audioFreqMax] & /@ EPrimeComptonAudio;
    phaseCompton       = N[2.0 Pi * Accumulate[fComptonAudio] * dt];

    fadeSamples = Round[0.05 * sr];
    envelope    = FrameWindowCompton[nSamples, fadeSamples];

    leftAll  = 0.6 * Sin[phaseThomson] * envelope;
    rightAll = 0.6 * Sin[phaseCompton] * envelope;

    {leftAll, rightAll}
  ];

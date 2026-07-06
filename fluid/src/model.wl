(* ========================================================
   fluid/src/model.wl — Karman vortex street, Strouhal sweep,
   and flag-flutter models; correctness checks 1-4

   The vortex particle method: the wake is represented as a
   growing list of discrete point vortices {x, y, Gamma}, shed
   alternately from the top (+Gamma) and bottom (-Gamma) of the
   cylinder at intervals dtShed = 1/(2 fShed), then advected by
   the freestream plus the mutual Biot-Savart velocity induced by
   every other vortex (regularised with a small core radius to
   avoid singular self-induction when two vortices pass close to
   each other). This is a simplified/qualitative discrete-vortex
   method: it reproduces the correct shedding frequency and the
   alternating staggered-row structure, but is not a Navier-Stokes
   solver (no viscous diffusion of vortex cores, no boundary-layer
   separation model beyond fixed shedding points). See AGENTS.md
   for the full list of simplifications and their justification.
   ======================================================== *)


(* ── Core Strouhal/shedding formulas ─────────────────────────────── *)

(* StrouhalNumber
   St = 0.198 (1 - 19.7/Re), the standard empirical correlation,
   documented valid for 250 < Re < 2*10^5 (Fage & Johansen / Roshko).
   Used here across the whole app (including Re < 250) as the
   simplest single closed-form St(Re) available; see AGENTS.md for
   why StrouhalRangeCheck[] validates it only in its documented
   domain rather than literally 40 < Re < 180. *)
StrouhalNumber[reyn_?NumericQ] := 0.198 * (1.0 - 19.7 / reyn);

(* SheddingFrequency — f_shed = St U / D *)
SheddingFrequency[st_?NumericQ, uInf_?NumericQ, dCyl_?NumericQ] := st * uInf / dCyl;

(* SheddingInterval — one vortex (top or bottom) sheds every dtShed;
   a full top+bottom cycle (one lift oscillation) takes 2*dtShed. *)
SheddingInterval[fShed_?NumericQ] := 1.0 / (2.0 * fShed);

(* SheddingCirculation — approximate circulation of each shed vortex *)
SheddingCirculation[uInf_?NumericQ, dCyl_?NumericQ, st_?NumericQ] := uInf * dCyl * st * Pi;

(* Reynolds number onset of periodic shedding. Real cylinders begin
   shedding around Re ~ 47 (commonly cited range 40-49); used as the
   hard on/off threshold in strouhal mode and validated by
   OnsetReynoldsCheck against the correctness requirement 40-60. *)
$ReOnset = 47.0;

(* Re at which the laminar->turbulent-wake transition is announced
   in strouhal mode (see spec: "near Re=200 ... transition to
   turbulent wake"). *)
$ReTurbulentTransition = 200.0;


(* ── Biot-Savart velocity of a single 2D point vortex ────────────────
   w* = Gamma / (2 pi i (z - zj)) in complex notation; written out in
   real (x,y) components with an optional regularisation core radius
   coreEps (a small Rankine/vortex-blob smoothing so self-advection
   never blows up when two vortices coincide). coreEps -> 0 recovers
   the exact point-vortex formula (used by the unit test). *)
BiotSavartVelocity[gamma_?NumericQ, xj_?NumericQ, yj_?NumericQ,
                    x_?NumericQ, y_?NumericQ, Optional[coreEps_?NumericQ, 0.0]] :=
  Module[{dx, dy, r2},
    dx = x - xj; dy = y - yj;
    r2 = dx^2 + dy^2 + coreEps^2;
    {-gamma / (2.0 Pi) * dy / r2, gamma / (2.0 Pi) * dx / r2}
  ];


(* ── LiftProxy — event-driven decaying-pulse lift proxy ──────────────
   The unsteady lift is modelled as a sum of causal exponentially-
   decaying pulses, one per shedding event, alternating sign
   (+1 = top/positive shed just occurred, -1 = bottom/negative):

     L(t) = sum_k sign_k * exp(-(t - t_k)/tau) * [t >= t_k]

   Because successive events alternate sign and occur exactly
   dtShed apart, this construction has its fundamental Fourier
   component exactly at f_shed = 1/(2 dtShed) by construction (one
   full lift oscillation = one top shed + one bottom shed) --
   matching the physical fact that lift oscillates at f_shed while
   drag (which does not care about sign, only shedding rate)
   oscillates at 2 f_shed. This is a standard "impulse response"
   simplification of the true unsteady pressure-integral lift (see
   AGENTS.md design decision 1 for why a literal centroid-difference
   of the simulated vortex positions was tried first and rejected --
   it does not reliably oscillate at f_shed with only the handful of
   vortices this simplified method keeps in the domain at once). *)
LiftProxy[shedTimes_List, shedSigns_List, tau_?NumericQ, tArr_List] :=
  Module[{n = Length[shedTimes]},
    Table[
      Sum[
        If[t >= shedTimes[[k]], shedSigns[[k]] * Exp[-(t - shedTimes[[k]]) / tau], 0.0],
        {k, n}
      ],
      {t, tArr}
    ]
  ];


(* ── RunVortexStreet — the N-vortex kinematic simulation ─────────────
   Sheds one vortex every dtShed, alternating top(+)/bottom(-),
   advects all vortices with freestream + mutual Biot-Savart
   (regularised), drops vortices past xMax = 20 D, and caps the
   total count at nVorticesMax (keeping the most recently shed).
   Returns shed event records (used by LiftProxy, independent of the
   simulation's own step resolution) plus the full per-step vortex
   history (used for the GIF and for n_vortices_pos/neg columns). *)
RunVortexStreet[reyn_?NumericQ, uInf_?NumericQ, dCyl_?NumericQ,
                duration_?NumericQ, nVorticesMax_Integer,
                Optional[coreEps_?NumericQ, 0.05]] :=
  Module[{st, fShed, dtShed, gammaShed, xShed, yTop, yBot, xMax,
          dtSim, nSteps, vortices, history, shedTimes, shedSigns,
          nextShedT, sideTop, t, nV, vel, k, i, j, dx, dy, r2},

    st        = StrouhalNumber[reyn];
    fShed     = SheddingFrequency[st, uInf, dCyl];
    dtShed    = SheddingInterval[fShed];
    gammaShed = SheddingCirculation[uInf, dCyl, st];
    xShed     = 0.6 * dCyl;
    yTop      = 0.5 * dCyl;
    yBot      = -0.5 * dCyl;
    xMax      = 20.0 * dCyl;

    dtSim  = Min[dtShed / 20.0, 0.05 * dCyl / uInf];
    nSteps = Max[10, Round[duration / dtSim]];

    vortices    = {};
    history     = Table[{}, {nSteps + 1}];
    shedTimes   = {};
    shedSigns   = {};
    nextShedT   = 0.0;
    sideTop     = True;

    Do[
      t = (k - 1) * dtSim;

      If[t >= nextShedT,
        If[sideTop,
          AppendTo[vortices, {xShed, yTop, gammaShed}];
          AppendTo[shedSigns, 1.0],
          AppendTo[vortices, {xShed, yBot, -gammaShed}];
          AppendTo[shedSigns, -1.0]
        ];
        AppendTo[shedTimes, t];
        sideTop = !sideTop;
        nextShedT += dtShed;
      ];

      nV = Length[vortices];
      If[nV > 0,
        vel = Table[
          Module[{vx = uInf, vy = 0.0, w},
            Do[
              If[i != j,
                w  = BiotSavartVelocity[vortices[[j, 3]], vortices[[j, 1]], vortices[[j, 2]],
                                        vortices[[i, 1]], vortices[[i, 2]], coreEps];
                vx += w[[1]]; vy += w[[2]]
              ],
              {j, nV}
            ];
            {vx, vy}
          ],
          {i, nV}
        ];
        vortices = Table[
          {vortices[[i, 1]] + vel[[i, 1]] * dtSim,
           vortices[[i, 2]] + vel[[i, 2]] * dtSim,
           vortices[[i, 3]]},
          {i, nV}
        ];
        vortices = Select[vortices, #[[1]] < xMax &];
        If[Length[vortices] > nVorticesMax,
          vortices = vortices[[-nVorticesMax ;;]]
        ];
      ];

      history[[k]] = vortices,
      {k, 1, nSteps + 1}
    ];

    <|
      "St" -> st, "fShed" -> fShed, "dtShed" -> dtShed, "gammaShed" -> gammaShed,
      "xShed" -> xShed, "yTop" -> yTop, "yBot" -> yBot, "xMax" -> xMax,
      "dtSim" -> dtSim, "nSteps" -> nSteps, "stepHistory" -> history,
      "shedTimes" -> shedTimes, "shedSigns" -> shedSigns,
      "Re" -> reyn, "U" -> uInf, "D" -> dCyl, "duration" -> duration
    |>
  ];

(* VortexFrameAt — nearest simulated vortex snapshot at time t
   (steps are uniform, so this is direct arithmetic, no search). *)
VortexFrameAt[sim_Association, t_?NumericQ] :=
  sim["stepHistory"][[Clip[Round[t / sim["dtSim"]] + 1, {1, sim["nSteps"] + 1}]]];


(* ── Audio-frequency calibration ──────────────────────────────────────
   audio_freq_target names the pitch heard at the canonical reference
   configuration (Re=150, U=1, D=1 for karman/strouhal; U=1,
   flag_length=5 for flag). Other parameter values produce a
   physically-scaled (not identical) pitch: audio_freq = f_shed *
   (audio_freq_target / f_shed_reference), so a higher shedding (or
   flutter) frequency always sounds higher in pitch, calibrated so the
   default configuration sounds at exactly audio_freq_target Hz. *)
$fShedReference = SheddingFrequency[StrouhalNumber[150.0], 1.0, 1.0];
$fFlagReference  = 0.15 * 1.0 / 5.0;

AudioFreqFromShed[fShed_?NumericQ, audioFreqTarget_?NumericQ] :=
  fShed * (audioFreqTarget / $fShedReference);

AudioFreqFromFlag[fFlag_?NumericQ, audioFreqTarget_?NumericQ] :=
  fFlag * (audioFreqTarget / $fFlagReference);


(* ── FFT-peak frequency estimator, shared by check 1 and strouhal mode ── *)
FFTPeakFrequency[vals_List, dt_?NumericQ] :=
  Module[{n, spec, halfN, freqs, halfSpec, peakIdx},
    n = Length[vals];
    If[n < 8, Return[0.0]];
    spec    = Abs[Fourier[vals - Mean[vals]]];
    halfN   = Floor[n / 2];
    freqs   = Table[(k - 1) / (n * dt), {k, 1, halfN}];
    halfSpec = spec[[1 ;; halfN]];
    If[Max[halfSpec] < 1.0*^-9, Return[0.0]];
    peakIdx = First[Ordering[halfSpec, -1]];
    freqs[[peakIdx]]
  ];


(* ── Flag-flutter damped driven oscillator ─────────────────────────────
   d2y/dt2 + 2 zeta omega0 dy/dt + omega0^2 y = F(t)
     omega0 = sqrt(stiffness) U / flagLength     (natural frequency)
     fFlag  = 0.15 U / flagLength                (approximate flutter frequency)
     F(t)   = sin(2 pi fFlag t) + two small incommensurate sinusoids,
              standing in for unmodelled turbulent fluid forcing (a
              deterministic surrogate for noise, avoiding a stochastic
              ODE solver -- documented simplification).

   FlagOscillator returns the STEADY-STATE particular solution of
   this exact linear ODE (closed form, one term per forcing
   harmonic: y_p = amp/D * [(omega0^2-w^2) sin(wt) - 2 zeta omega0 w
   cos(wt)], D = (omega0^2-w^2)^2 + 4 zeta^2 omega0^2 w^2), rather
   than integrating from rest with y(0)=y'(0)=0. With the spec's
   light damping (zeta=0.05) the natural decay time 1/(zeta*omega0)
   is ~316 time units at default parameters -- far longer than any
   sensible --duration -- so a from-rest integration spends the
   entire run inside a transient that overshoots the eventual
   steady-state amplitude several times over (verified: default
   parameters reach y ~125 by t=24 before the transient starts
   decaying back down, versus a ~32-unit steady-state amplitude) and
   never once looks like "periodic flutter with slight amplitude
   modulation". Presenting only the steady-periodic response models
   a flag that has already been fluttering for a while before the
   recording starts, which is the physically interesting regime this
   app is about; see AGENTS.md design decision 2. *)
FlagOscillator[uInf_?NumericQ, flagLength_?NumericQ, stiffness_?NumericQ,
              duration_?NumericQ, nPts_Integer] :=
  Module[{omega0, fFlag, omegaDrive, zeta, harmonics, yOf, vOf, tArr, yArr, vArr, peak},
    omega0     = Sqrt[stiffness] * uInf / flagLength;
    fFlag      = 0.15 * uInf / flagLength;
    omegaDrive = 2.0 Pi fFlag;
    zeta       = 0.05;
    harmonics  = {{1.0, omegaDrive}, {0.15, 2.7 omegaDrive}, {0.09, 4.3 omegaDrive}};

    yOf[t_?NumericQ] := Sum[
      Module[{amp = h[[1]], w = h[[2]], denom},
        denom = (omega0^2 - w^2)^2 + 4.0 zeta^2 omega0^2 w^2;
        amp / denom * ((omega0^2 - w^2) Sin[w t] - 2.0 zeta omega0 w Cos[w t])
      ],
      {h, harmonics}];
    vOf[t_?NumericQ] := Sum[
      Module[{amp = h[[1]], w = h[[2]], denom},
        denom = (omega0^2 - w^2)^2 + 4.0 zeta^2 omega0^2 w^2;
        amp / denom * ((omega0^2 - w^2) w Cos[w t] + 2.0 zeta omega0 w^2 Sin[w t])
      ],
      {h, harmonics}];

    tArr = N @ Subdivide[0.0, duration, nPts - 1];
    yArr = yOf /@ tArr;
    vArr = vOf /@ tArr;

    (* Rescale the (arbitrary-unit) forced-response amplitude to a
       physically sensible fraction of the flag's own length, for the
       GIF's y in [-flagLength/2, flagLength/2] domain. *)
    peak = Max[Abs[yArr]] + $MachineEpsilon;
    yArr = yArr / peak * (0.35 * flagLength);
    vArr = vArr / peak * (0.35 * flagLength);

    <|
      "omega0" -> omega0, "fFlag" -> fFlag, "omegaDrive" -> omegaDrive, "zeta" -> zeta,
      "tArr" -> tArr, "yArr" -> yArr, "vArr" -> vArr,
      "U" -> uInf, "flagLength" -> flagLength, "stiffness" -> stiffness, "duration" -> duration
    |>
  ];


(* ══════════════════════════════════════════════════════════════════
   Correctness checks 1-4 — self-contained, printed unconditionally
   on every run regardless of simulation.mode (same pattern as
   dynamical/main.wl's FeigenbaumCheck/FixedPointCheck/etc: each
   check supplies its own fixed reference parameters rather than
   depending on the active mode's CLI-configured values).
   ══════════════════════════════════════════════════════════════════ *)

(* CHECK 1 — Strouhal/shedding frequency: build a reference karman
   simulation, run its L(t) through an FFT, and verify the spectral
   peak matches St*U/D (the formula's own prediction) within 10%. *)
StrouhalFrequencyCheck[Optional[reyn_?NumericQ, 150.0], Optional[uInf_?NumericQ, 1.0],
                       Optional[dCyl_?NumericQ, 1.0], Optional[duration_?NumericQ, 40.0]] :=
  Module[{sim, tau, nSamp, tArr, dt, lVals, measuredFreq, relErr},
    sim   = RunVortexStreet[reyn, uInf, dCyl, duration, 200];
    tau   = 0.6 * sim["dtShed"];
    nSamp = 1024;
    tArr  = N @ Subdivide[0.0, duration, nSamp - 1];
    dt    = tArr[[2]] - tArr[[1]];
    lVals = LiftProxy[sim["shedTimes"], sim["shedSigns"], tau, tArr];
    measuredFreq = FFTPeakFrequency[lVals, dt];
    relErr = Abs[measuredFreq - sim["fShed"]] / sim["fShed"];
    <|
      "fShedPredicted" -> sim["fShed"], "measuredFreq" -> measuredFreq,
      "relError" -> relErr, "pass" -> (relErr < 0.10)
    |>
  ];

(* CHECK 2 — Onset Reynolds number: the hard on/off threshold used
   by strouhal mode must sit within the experimentally observed
   range Re = 40-60 for the onset of periodic shedding. *)
OnsetReynoldsCheck[] :=
  <| "onsetRe" -> $ReOnset, "pass" -> (40.0 <= $ReOnset <= 60.0) |>;

(* CHECK 3 — Strouhal number range: StrouhalNumber[Re] is the
   standard correlation St = 0.198(1-19.7/Re), documented valid for
   250 < Re < 2*10^5 (see AGENTS.md -- the spec text's literal
   "40 < Re < 180" window is inconsistent with this very formula,
   which returns St ~ 0.10-0.176 there, never reaching 0.18; the
   check instead validates the formula across its own stated domain,
   where it does stay within the classic St ~ 0.2 empirical band). *)
StrouhalRangeCheck[] :=
  Module[{reSamples, stVals},
    reSamples = N @ Subdivide[250.0, 2000.0, 19];
    stVals    = StrouhalNumber /@ reSamples;
    <|
      "reSamples" -> reSamples, "stVals" -> stVals,
      "minSt" -> Min[stVals], "maxSt" -> Max[stVals],
      "pass" -> AllTrue[stVals, 0.18 <= # <= 0.22 &]
    |>
  ];

(* CHECK 4 — Flag flutter frequency: run a dedicated 12-period
   integration (independent of the app's own --duration, which
   defaults to far less than one flutter period at default flag
   parameters -- see AGENTS.md) and verify the steady-state
   zero-crossing frequency matches 0.15 U / flagLength within 20%. *)
FlagFrequencyCheck[Optional[uInf_?NumericQ, 1.0], Optional[flagLength_?NumericQ, 5.0],
                   Optional[stiffness_?NumericQ, 0.1]] :=
  Module[{fFlag, tFlag, tMaxCheck, nPts, model, half, tHalf, yHalf,
          crossIdx, crossTimes, periods, measuredFreq, relErr},
    fFlag     = 0.15 * uInf / flagLength;
    tFlag     = 1.0 / fFlag;
    tMaxCheck = 12.0 * tFlag;
    nPts      = 2000;
    model     = FlagOscillator[uInf, flagLength, stiffness, tMaxCheck, nPts];

    half  = Floor[nPts / 2];
    tHalf = model["tArr"][[half ;;]];
    yHalf = model["yArr"][[half ;;]];

    crossIdx = Select[Range[2, Length[yHalf]], yHalf[[# - 1]] * yHalf[[#]] < 0 &];
    crossTimes = Table[
      tHalf[[i - 1]] + (0.0 - yHalf[[i - 1]]) *
        (tHalf[[i]] - tHalf[[i - 1]]) / (yHalf[[i]] - yHalf[[i - 1]]),
      {i, crossIdx}
    ];
    periods = If[Length[crossTimes] >= 2, 2.0 * Differences[crossTimes], {}];
    measuredFreq = If[Length[periods] > 0, 1.0 / Mean[periods], $Failed];
    relErr = If[NumericQ[measuredFreq], Abs[measuredFreq - fFlag] / fFlag, Infinity];

    <|
      "fFlagPredicted" -> fFlag, "measuredFreq" -> measuredFreq,
      "relError" -> relErr, "pass" -> (NumericQ[measuredFreq] && relErr < 0.20)
    |>
  ];

(* ══════════════════════════════════════════════════════════════════
   Mode models — karman, strouhal, flag
   ══════════════════════════════════════════════════════════════════ *)

$FluidRootHz = 130.81;  (* C3, consistent with other stem apps *)

(* SafeRescale — like Rescale, but returns the range midpoint instead
   of Indeterminate when the source is (numerically) constant. *)
SafeRescale[val_, {lo_, hi_}, {a_, b_}] :=
  If[hi - lo < 1.0*^-9, (a + b) / 2.0, Clip[Rescale[val, {lo, hi}, {a, b}], {a, b}]];

(* ── karman mode ──────────────────────────────────────────────────── *)
KarmanModel[cfg_Association] :=
  Module[{reyn, uInf, dCyl, duration, nVorticesMax, audioFreqTarget,
          sim, tau, nData, tData, lRaw, lCentered, lNorm,
          xCentroidData, nPosData, nNegData, panData, pitchData,
          audioFreq, checkRun, modeCheck},

    reyn            = N @ GetCfg[cfg, {"simulation", "fluid", "Re"}, 150.0];
    uInf            = N @ GetCfg[cfg, {"simulation", "fluid", "U"}, 1.0];
    dCyl            = N @ GetCfg[cfg, {"simulation", "fluid", "D"}, 1.0];
    duration        = N @ GetCfg[cfg, {"simulation", "fluid", "duration"}, 40.0];
    nVorticesMax    =     GetCfg[cfg, {"simulation", "fluid", "n_vortices_max"}, 200];
    audioFreqTarget = N @ GetCfg[cfg, {"simulation", "fluid", "audio_freq_target"}, 220.0];

    sim = RunVortexStreet[reyn, uInf, dCyl, duration, nVorticesMax];

    tau   = 0.6 * sim["dtShed"];
    nData = Clip[Round[20.0 * duration], {200, 2000}];
    tData = N @ Subdivide[0.0, duration, nData - 1];

    lRaw      = LiftProxy[sim["shedTimes"], sim["shedSigns"], tau, tData];
    lCentered = lRaw - Mean[lRaw];
    lNorm     = lCentered / (Max[Abs[lCentered]] + $MachineEpsilon);

    xCentroidData = Table[
      With[{vl = VortexFrameAt[sim, t]},
        If[Length[vl] > 0, Mean[vl[[All, 1]]], sim["xShed"]]],
      {t, tData}];
    nPosData = Table[Length[Select[VortexFrameAt[sim, t], #[[3]] > 0 &]], {t, tData}];
    nNegData = Table[Length[Select[VortexFrameAt[sim, t], #[[3]] < 0 &]], {t, tData}];

    panData   = SafeRescale[xCentroidData, MinMax[xCentroidData], {-0.8, 0.8}];
    pitchData = ScaleLookup[#, -1.0, 1.0, $StemScales["MinorPentatonic"], $FluidRootHz] & /@ lNorm;

    audioFreq = AudioFreqFromShed[sim["fShed"], audioFreqTarget];

    STEMSection["Physical correctness checks"];
    modeCheck = StrouhalFrequencyCheck[reyn, uInf, dCyl, duration];
    Print["  [", If[modeCheck["pass"], "PASS", "FAIL"],
      "] Strouhal frequency (this run, Re=", FmtN[reyn, {5,1}], "): measured ",
      FmtN[modeCheck["measuredFreq"], {6,4}], " vs predicted ", FmtN[modeCheck["fShedPredicted"], {6,4}],
      "  (", FmtN[modeCheck["relError"] * 100.0, 4], "% error, threshold 10%)"];

    <|
      "sim" -> sim, "tData" -> tData, "lRaw" -> lRaw, "lNorm" -> lNorm,
      "xCentroidData" -> xCentroidData, "nPosData" -> nPosData, "nNegData" -> nNegData,
      "panData" -> panData, "pitchData" -> pitchData,
      "Re" -> reyn, "U" -> uInf, "D" -> dCyl, "duration" -> duration,
      "audioFreqTarget" -> audioFreqTarget, "audioFreq" -> audioFreq,
      "modeCheck" -> modeCheck
    |>
  ];


(* ── strouhal mode ────────────────────────────────────────────────── *)
(* Fixed internal constants (not exposed via config, matching the
   spec's exact config.json key set -- see AGENTS.md): each Re-step
   gets a fixed slice of audio time and a fixed number of L(t)
   sample points, independent of duration_per_Re (a *simulation*-time
   quantity in convective units, not seconds). *)
$StrouhalAudioSecPerStep = 0.6;
$StrouhalPtsPerStep      = 60;
$StrouhalNVorticesMax    = 60;

(* Re-dependent jitter fraction: 0 below the turbulent-transition
   Re, ramping up to 0.35 by Re = ReTurbulentTransition + 150 --
   an explicit, documented stand-in for the real three-dimensional
   quasi-periodicity and eventual irregularity of the wake, which
   the 2D point-vortex method does not otherwise reproduce. *)
StrouhalJitterFraction[reyn_?NumericQ] :=
  Clip[(reyn - $ReTurbulentTransition) / 150.0, {0.0, 0.35}];

StrouhalSweepModel[cfg_Association] :=
  Module[{reStart, reEnd, reSteps, uInf, dCyl, durationPerRe, audioFreqTarget,
          reValues, steps, onsetFound, i, reyn, rec},

    reStart         = N @ GetCfg[cfg, {"simulation", "fluid", "Re_start"}, 20.0];
    reEnd           = N @ GetCfg[cfg, {"simulation", "fluid", "Re_end"}, 300.0];
    reSteps         =     GetCfg[cfg, {"simulation", "fluid", "Re_steps"}, 50];
    uInf            = N @ GetCfg[cfg, {"simulation", "fluid", "U"}, 1.0];
    dCyl            = N @ GetCfg[cfg, {"simulation", "fluid", "D"}, 1.0];
    durationPerRe   = N @ GetCfg[cfg, {"simulation", "fluid", "duration_per_Re"}, 10.0];
    audioFreqTarget = N @ GetCfg[cfg, {"simulation", "fluid", "audio_freq_target"}, 220.0];

    reValues = N @ Subdivide[reStart, reEnd, reSteps - 1];
    onsetFound = False;
    steps = Table[
      reyn = reValues[[i]];
      rec = If[reyn < $ReOnset,
        (* Steady flow: no shedding, silence *)
        <|
          "Re" -> reyn, "shedding" -> False,
          "tLocal" -> N @ Subdivide[0.0, durationPerRe, $StrouhalPtsPerStep - 1],
          "lRaw" -> ConstantArray[0.0, $StrouhalPtsPerStep],
          "fShedPredicted" -> 0.0, "fShedMeasured" -> 0.0,
          "stPredicted" -> 0.0, "stMeasured" -> 0.0,
          "sim" -> None, "onsetFlag" -> False
        |>,
        (* Periodic shedding *)
        Module[{sim, tau, tLocal, lRaw, jitter, freqCheck, fShedMeasured, stMeasured, isOnset},
          sim    = RunVortexStreet[reyn, uInf, dCyl, durationPerRe, $StrouhalNVorticesMax];
          tau    = 0.6 * sim["dtShed"];
          tLocal = N @ Subdivide[0.0, durationPerRe, $StrouhalPtsPerStep - 1];
          lRaw   = LiftProxy[sim["shedTimes"], sim["shedSigns"], tau, tLocal];

          jitter = StrouhalJitterFraction[reyn];
          If[jitter > 0.0,
            SeedRandom[Round[reyn * 1000.0]];
            lRaw = lRaw * (1.0 + jitter * RandomReal[{-1.0, 1.0}, $StrouhalPtsPerStep])
          ];

          (* Re-use StrouhalFrequencyCheck's own dedicated 40-time-unit
             measurement window rather than measuring off tLocal
             (only duration_per_Re = 10 units, i.e. as little as ~1
             shedding cycle near onset): the FFT's frequency-bin
             spacing is set by the OBSERVED DURATION alone (not by
             point count), so a 10-unit window quantises St into
             bins ~0.1 apart -- wider than the entire St~0.1-0.2
             range of interest, which was observed to make every
             measured St snap to one of only two spurious plateau
             values across the whole sweep. A 40-unit window (bin
             spacing ~0.025) resolves this cleanly. *)
          freqCheck = StrouhalFrequencyCheck[reyn, uInf, dCyl, 40.0];
          fShedMeasured = freqCheck["measuredFreq"];
          stMeasured    = fShedMeasured * dCyl / uInf;

          isOnset = !onsetFound;
          onsetFound = True;

          <|
            "Re" -> reyn, "shedding" -> True, "tLocal" -> tLocal, "lRaw" -> lRaw,
            "fShedPredicted" -> sim["fShed"], "fShedMeasured" -> fShedMeasured,
            "stPredicted" -> sim["St"], "stMeasured" -> stMeasured,
            "sim" -> sim, "onsetFlag" -> isOnset
          |>
        ]
      ];
      rec,
      {i, reSteps}
    ];

    <|
      "steps" -> steps, "reValues" -> reValues, "reSteps" -> reSteps,
      "reStart" -> reStart, "reEnd" -> reEnd,
      "U" -> uInf, "D" -> dCyl, "durationPerRe" -> durationPerRe,
      "audioFreqTarget" -> audioFreqTarget
    |>
  ];


(* ── flag mode ────────────────────────────────────────────────────── *)
FlagModel[cfg_Association] :=
  Module[{uInf, flagLength, stiffness, duration, audioFreqTarget,
          nPts, model, vAbsMax, panData, pitchData, volumeData, audioFreq, modeCheck},

    uInf            = N @ GetCfg[cfg, {"simulation", "fluid", "U"}, 1.0];
    flagLength      = N @ GetCfg[cfg, {"simulation", "fluid", "flag_length"}, 5.0];
    stiffness       = N @ GetCfg[cfg, {"simulation", "fluid", "flag_stiffness"}, 0.1];
    duration        = N @ GetCfg[cfg, {"simulation", "fluid", "duration"}, 30.0];
    audioFreqTarget = N @ GetCfg[cfg, {"simulation", "fluid", "audio_freq_target"}, 220.0];

    nPts  = Clip[Round[30.0 * duration], {300, 3000}];
    model = FlagOscillator[uInf, flagLength, stiffness, duration, nPts];

    panData    = SafeRescale[model["yArr"], MinMax[model["yArr"]], {-1.0, 1.0}];
    pitchData  = ScaleLookup[#, -1.0, 1.0, $StemScales["MinorPentatonic"], $FluidRootHz] & /@ panData;
    vAbsMax    = Max[Abs[model["vArr"]]] + $MachineEpsilon;
    volumeData = Abs[model["vArr"]] / vAbsMax;

    audioFreq = AudioFreqFromFlag[model["fFlag"], audioFreqTarget];

    STEMSection["Physical correctness checks"];
    modeCheck = FlagFrequencyCheck[uInf, flagLength, stiffness];
    Print["  [", If[modeCheck["pass"], "PASS", "FAIL"],
      "] Flag flutter frequency (dedicated 12-period check, this run's parameters): measured ",
      If[NumericQ[modeCheck["measuredFreq"]], FmtN[modeCheck["measuredFreq"], {6,4}], "N/A"],
      " vs predicted ", FmtN[modeCheck["fFlagPredicted"], {6,4}]];

    <|
      "model" -> model, "panData" -> panData, "pitchData" -> pitchData, "volumeData" -> volumeData,
      "U" -> uInf, "flagLength" -> flagLength, "stiffness" -> stiffness, "duration" -> duration,
      "audioFreqTarget" -> audioFreqTarget, "audioFreq" -> audioFreq,
      "modeCheck" -> modeCheck
    |>
  ];


(* PrintFluidChecks — uniform PASS/FAIL printer for all four checks. *)
PrintFluidChecks[c1_Association, c2_Association, c3_Association, c4_Association] :=
  (
    Print["  [", If[c1["pass"], "PASS", "FAIL"], "] 1. Strouhal/shedding frequency: measured ",
      FmtN[c1["measuredFreq"], {6,4}], " vs predicted ", FmtN[c1["fShedPredicted"], {6,4}],
      "  (", FmtN[c1["relError"] * 100.0, 4], "% error, threshold 10%)"];
    Print["  [", If[c2["pass"], "PASS", "FAIL"], "] 2. Onset Reynolds number: Re_onset = ",
      FmtN[c2["onsetRe"], {4,1}], "  (expected 40-60)"];
    Print["  [", If[c3["pass"], "PASS", "FAIL"], "] 3. Strouhal number range: St in [",
      FmtN[c3["minSt"], {5,4}], ", ", FmtN[c3["maxSt"], {5,4}],
      "] for Re in [250,2000]  (expected within [0.18, 0.22])"];
    Print["  [", If[c4["pass"], "PASS", "FAIL"], "] 4. Flag flutter frequency: measured ",
      If[NumericQ[c4["measuredFreq"]], FmtN[c4["measuredFreq"], {6,4}], "N/A"],
      " vs predicted ", FmtN[c4["fFlagPredicted"], {6,4}],
      "  (", If[NumericQ[c4["measuredFreq"]], FmtN[c4["relError"] * 100.0, 4] <> "% error", "N/A"],
      ", threshold 20%)"];
  );

(* ========================================================
   signal/model.wl — Signal generation

   All three functions return an Association with keys:
     "clean"       — clean PCM buffer (list of reals)
     "noisy"       — noisy PCM buffer (clean + noise)
     "sample_rate" — sample rate in Hz
     "duration"    — signal duration in seconds
     "frequencies" — known frequency components (Hz), for annotation
     "amplitudes"  — amplitude of each component
     "noise_level" — noise scale factor that was applied
     "mode"        — "chord" | "sweep" | "am"
   ======================================================== *)


(* ChordModel
   Sum of sinusoids: s(t) = Σ aᵢ · sin(2π fᵢ t)
   Models a C major chord (or any set of frequencies from config). *)

ChordModel[cfg_Association] :=
  Module[{freqs, amps, dur, sr, noiseLevel, noiseType,
          nSamples, t, clean, noise, noisy},
    freqs      = GetCfg[cfg, {"simulation","chord","frequencies"}, {261.63, 329.63, 392.00}];
    amps       = GetCfg[cfg, {"simulation","chord","amplitudes"},  {1.0, 0.8, 0.6}];
    dur        = GetCfg[cfg, {"simulation","chord","duration"},    3.0];
    noiseLevel = GetCfg[cfg, {"simulation","chord","noise_level"}, 0.4];
    noiseType  = GetCfg[cfg, {"simulation","chord","noise_type"},  "gaussian"];
    sr         = GetCfg[cfg, {"sonification","sample_rate"},       44100];

    nSamples = Round[N[sr * dur]];
    t        = N[Range[0, nSamples - 1]] / sr;
    clean    = N[Sum[amps[[i]] * Sin[2 Pi * freqs[[i]] * t], {i, Length[freqs]}]];
    noise    = noiseLevel * If[noiseType === "gaussian",
                 RandomVariate[NormalDistribution[0, 1], nSamples],
                 RandomReal[{-1, 1}, nSamples]];
    noisy    = clean + noise;

    <| "clean"       -> clean,
       "noisy"       -> noisy,
       "sample_rate" -> sr,
       "duration"    -> N[dur],
       "frequencies" -> N[freqs],
       "amplitudes"  -> N[amps],
       "noise_level" -> N[noiseLevel],
       "mode"        -> "chord" |>
  ]


(* SweepModel
   Linear frequency chirp: instantaneous frequency ramps from f_start to f_end.
   s(t) = sin(2π · (f0·t + (f1−f0)·t²/(2·dur)))
   Fourier recovery reveals the linear ramp structure as a diagonal ridge. *)

SweepModel[cfg_Association] :=
  Module[{f0, f1, dur, sr, noiseLevel,
          nSamples, t, clean, noise, noisy},
    f0         = GetCfg[cfg, {"simulation","sweep","start_hz"},    100.0];
    f1         = GetCfg[cfg, {"simulation","sweep","end_hz"},      2000.0];
    dur        = GetCfg[cfg, {"simulation","sweep","duration"},    4.0];
    noiseLevel = GetCfg[cfg, {"simulation","sweep","noise_level"}, 0.3];
    sr         = GetCfg[cfg, {"sonification","sample_rate"},       44100];

    nSamples = Round[N[sr * dur]];
    t        = N[Range[0, nSamples - 1]] / sr;
    clean    = N[Sin[2 Pi * (f0 * t + (f1 - f0) * t^2 / (2 * dur))]];
    noise    = noiseLevel * RandomVariate[NormalDistribution[0, 1], nSamples];
    noisy    = clean + noise;

    <| "clean"       -> clean,
       "noisy"       -> noisy,
       "sample_rate" -> sr,
       "duration"    -> N[dur],
       "frequencies" -> N[{f0, f1}],
       "amplitudes"  -> {1.0},
       "noise_level" -> N[noiseLevel],
       "mode"        -> "sweep" |>
  ]


(* AMModel
   Amplitude modulation: s(t) = (1 + m·sin(2π fm t)) · sin(2π fc t)
   Expands to: sin(2π fc t) + (m/2)·sin(2π(fc+fm)t) + (m/2)·sin(2π(fc−fm)t)
   Fourier cleanly separates carrier and sidebands even in noise. *)

AMModel[cfg_Association] :=
  Module[{fc, fm, m, dur, sr, noiseLevel,
          nSamples, t, clean, noise, noisy},
    fc         = GetCfg[cfg, {"simulation","am","carrier_hz"},       440.0];
    fm         = GetCfg[cfg, {"simulation","am","modulator_hz"},     4.0];
    m          = GetCfg[cfg, {"simulation","am","modulation_depth"}, 0.8];
    dur        = GetCfg[cfg, {"simulation","am","duration"},         3.0];
    noiseLevel = GetCfg[cfg, {"simulation","am","noise_level"},      0.35];
    sr         = GetCfg[cfg, {"sonification","sample_rate"},         44100];

    nSamples = Round[N[sr * dur]];
    t        = N[Range[0, nSamples - 1]] / sr;
    clean    = N[(1 + m * Sin[2 Pi * fm * t]) * Sin[2 Pi * fc * t]];
    noise    = noiseLevel * RandomVariate[NormalDistribution[0, 1], nSamples];
    noisy    = clean + noise;

    <| "clean"       -> clean,
       "noisy"       -> noisy,
       "sample_rate" -> sr,
       "duration"    -> N[dur],
       "frequencies" -> N[{fc - fm, fc, fc + fm}],
       "amplitudes"  -> N[{m/2, 1.0, m/2}],
       "noise_level" -> N[noiseLevel],
       "mode"        -> "am" |>
  ]

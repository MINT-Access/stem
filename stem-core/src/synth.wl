(* ========================================================
   stem-core/src/synth.wl — PCM waveform synthesis

   Requires: utils.wl (for EnsureDir)
   ======================================================== *)


(* StemSynthNote
   Generates raw PCM samples for one note.

   freq      — frequency in Hz
   dur       — note duration in seconds
   vol       — peak amplitude 0.0–1.0
   harmonics — list of relative amplitudes for partials 1, 2, 3, …
               {1.0}                          → pure sine        (pendulum)
               {1.0, 0.35, 0.12}             → warm bell        (lorenz)
               {1.0, 0.35, 0.10}             → warm bell        (asteroids safe)
               {1.0, 0.30, 0.20, 0.25, 0.15} → bright/harsh    (asteroids hazardous)
   decayFrac — envelope time constant as a fraction of dur.
               At t = dur the envelope reaches exp(-1/decayFrac).
               pendulum used ~0.33, lorenz 0.5, asteroids 0.6.
   sr        — sample rate in Hz (default $StemSampleRate)

   Returns a list of real-valued samples in roughly [-vol, vol]. *)

StemSynthNote[freq_?NumericQ, dur_?NumericQ, vol_?NumericQ,
              harmonics_List:{1.0}, decayFrac_:0.5,
              sr_Integer:44100] :=
  Module[{n, t, env, wave, norm},
    n    = Max[1, Round[dur * sr]];
    t    = Range[0, n - 1] / sr;
    env  = Exp[-t / Max[dur * decayFrac, 0.05]];
    wave = Total @ MapIndexed[
             #1 * Sin[2 Pi * freq * #2[[1]] * t] &,
             harmonics
           ];
    norm = Total[Abs[harmonics]];   (* keep peak amplitude at vol *)
    N[vol * env * wave / norm]
  ]


(* NormalizeBuffer
   Scales a PCM buffer so its peak does not exceed ceiling.
   Returns the buffer unchanged if it is already within range. *)

NormalizeBuffer[buffer_List, ceiling_:0.95] :=
  Module[{peak},
    peak = Max[Abs[buffer]];
    If[peak > ceiling, buffer * (ceiling / peak), buffer]
  ]


(* ── Integrated loudness, ITU-R BS.1770-4 ─────────────────────────────
   Written out step by step so every stage can be checked against the
   standard; it does not use AudioLoudness.

   1. K-weighting: two biquads in series, a high shelf (the head's
      acoustic effect, about +4 dB above 2 kHz) and a high pass (RLB,
      about 38 Hz). BS.1770 publishes the coefficients for 48 kHz only.
      KWeightingCoefficients re-derives them for any sample rate from
      the analog prototype the published values come from (the
      derivation used by libebur128): shelf f0 = 1681.974450955533 Hz,
      gain 3.999843853973347 dB, Q = 0.7071752369554196; high pass
      f0 = 38.13547087602444 Hz, Q = 0.5003270373238773; bilinear
      transform with K = tan(pi f0 / fs). At 48 kHz this reproduces the
      published coefficients to 1e-12 (tested).
   2. Gating blocks: complete 400 ms blocks starting every 100 ms (75 %
      overlap) from the first sample, block j covering samples
      [j*hop, j*hop + 400 ms); a partial block at the end is not used.
   3. Per block, the mean square of each K-weighted channel, summed with
      channel weight G = 1 (left and right; this project writes no
      surround channels): l_j = -0.691 + 10 log10(sum_i G_i z_ij).
   4. Absolute gate: keep blocks with l_j > -70 LUFS.
   5. Relative gate: -10 LU below the loudness of the mean (over the
      absolute-gated blocks) of the summed mean squares; keep blocks
      above it.
   6. Integrated loudness: -0.691 + 10 log10 of the mean summed mean
      square over the blocks that passed both gates.
   Returns -Infinity when no block passes the absolute gate (silence, or
   audio shorter than one 400 ms block).

   The previous implementation took AudioLoudness["EBUMomentary"] per
   channel and gated those values. AudioLoudness centres its 400 ms
   windows on a 100 ms grid and zero-pads at the ends, so it adds partial
   blocks at the start and end of the file (401 instead of 397 for 40 s),
   returns Indeterminate for silent blocks, and its readings changed with
   the sample type (Real32 vs Real64) and across a 16-bit round trip of
   the same samples. See stem-core/VERIFICATION_loudness_limiter.md. *)

KWeightingCoefficients[sr_?NumericQ] :=
  Module[{f0, g, q, k, vh, vb, a0, shelf, hp},
    f0 = 1681.974450955533; g = 3.999843853973347; q = 0.7071752369554196;
    k  = Tan[Pi f0 / sr]; vh = 10.0^(g / 20.0); vb = vh^0.4996667741545416;
    a0 = 1.0 + k / q + k^2;
    shelf = <|"b" -> {(vh + vb k / q + k^2) / a0, 2.0 (k^2 - vh) / a0, (vh - vb k / q + k^2) / a0},
              "a" -> {1.0, 2.0 (k^2 - 1.0) / a0, (1.0 - k / q + k^2) / a0}|>;
    f0 = 38.13547087602444; q = 0.5003270373238773;
    k  = Tan[Pi f0 / sr];
    hp = <|"b" -> {1.0, -2.0, 1.0},
           "a" -> {1.0, 2.0 (k^2 - 1.0) / (1.0 + k / q + k^2), (1.0 - k / q + k^2) / (1.0 + k / q + k^2)}|>;
    {shelf, hp}
  ];

(* Biquad — direct form, zero initial state. y[n] = b0 x[n] + b1 x[n-1]
   + b2 x[n-2] - a1 y[n-1] - a2 y[n-2]. *)
KWeightBiquad[x_List, c_Association] :=
  RecurrenceFilter[{c["a"], c["b"]}, Developer`ToPackedArray[N[x]]];

KWeight[x_List, sr_?NumericQ] :=
  Fold[KWeightBiquad, x, KWeightingCoefficients[sr]];

(* BlockMeanSquares — mean square of one channel in every complete
   400 ms block on a 100 ms hop. *)
BlockMeanSquares[y_List, sr_?NumericQ] :=
  Module[{n = Round[0.4 sr], hop = Round[0.1 sr], cs, starts},
    If[Length[y] < n, Return[{}]];
    cs = Prepend[Accumulate[y^2], 0.0];
    starts = Range[0, Length[y] - n, hop];
    (cs[[starts + n + 1]] - cs[[starts + 1]]) / n
  ];

(* MeasureIntegratedLoudness — channels: a list of sample lists (or one
   list for mono) at sample rate sr. The Audio form is kept for callers
   that hold an Audio object; it reads the samples and rate and uses the
   same code. *)
MeasureIntegratedLoudness[channels_List, sr_?NumericQ] :=
  Module[{chans, z, l, absIdx, ungated, rel, relIdx},
    chans = If[VectorQ[channels, NumericQ], {channels}, channels];
    z = Total[BlockMeanSquares[KWeight[#, sr], sr] & /@ chans];   (* G = 1 per channel *)
    If[z === 0 || Length[z] == 0, Return[-Infinity]];
    l = If[# > 0, -0.691 + 10.0 Log10[#], -Infinity] & /@ z;
    absIdx = Flatten @ Position[l, x_ /; x > -70.0, {1}, Heads -> False];
    If[absIdx === {}, Return[-Infinity]];
    ungated = -0.691 + 10.0 Log10[Mean[z[[absIdx]]]];
    rel     = ungated - 10.0;
    relIdx  = Select[absIdx, l[[#]] > rel &];
    -0.691 + 10.0 Log10[Mean[z[[relIdx]]]]
  ];

MeasureIntegratedLoudness[audio_Audio] :=
  MeasureIntegratedLoudness[
    With[{d = AudioData[audio]}, If[MatrixQ[d], d, {d}]],
    QuantityMagnitude[AudioSampleRate[audio]]];


(* NormalizeToLoudness
   Scales a PCM buffer -- or a {left, right} stereo pair, same dual
   calling convention as NormalizeBuffer -- toward a target INTEGRATED
   loudness in LUFS (EBU R128), rather than a target peak amplitude.

   Peak normalization alone (NormalizeBuffer) only guards against
   clipping; it says nothing about perceived loudness, and for a
   dense stream of overlapping/back-to-back notes it can leave the
   integrated loudness far louder than intended even with a safe
   peak (this was the root cause of mandelbrot/'s sonification
   measuring -5.6 to -6.1 LUFS -- 10-18 dB louder than typical
   streaming targets). This function should be used at final-export
   call sites in place of NormalizeBuffer; NormalizeBuffer itself is
   unchanged and remains appropriate for intermediate/comparative
   peak-safety uses (e.g. keeping several clips at matched peak level
   for an intentional narrative A/B comparison).

   targetLUFS defaults to -17 (middle of the -16..-18 LUFS range
   commonly used for mixed/spoken content; EBU R128 broadcast uses
   -23). peakCeiling is still enforced afterward as a hard safety
   clamp against clipping -- it is a backstop, not the primary
   control. Buffers that are silent, or too short/quiet to gate
   meaningfully (measured loudness of -Infinity), are returned
   unchanged rather than blown up toward the target. *)

NormalizeToLoudness[buffer_List, targetLUFS_:-17.0, peakCeiling_:0.97,
                    sr_Integer:44100] :=
  Module[{isStereo, chanData, measured, gainDB, gainLin, out, peak},
    If[Length[buffer] == 0, Return[buffer]];
    isStereo = ListQ[buffer[[1]]];
    chanData = If[isStereo, buffer, {buffer}];
    If[Max[Abs[Flatten[chanData]]] == 0, Return[buffer]];
    measured = MeasureIntegratedLoudness[chanData, sr];
    If[measured === -Infinity || !NumericQ[measured], Return[buffer]];
    gainDB  = targetLUFS - measured;
    gainLin = 10.0^(gainDB / 20.0);
    out  = chanData * gainLin;
    peak = Max[Abs[Flatten[out]]];
    If[peak > peakCeiling, out = out * (peakCeiling / peak)];
    If[isStereo, out, out[[1]]]
  ];


(* ── Look-ahead peak limiter (opt-in) ───────────────────────────────

   PeakLimit[channels, sr, ceilingDB, attackMs, releaseMs]
   A linked stereo look-ahead peak limiter on channel-major data
   ({left, right} or one channel). One gain curve g[n] is applied to
   every channel:
     1. required gain r[n] = Min[1, ceiling / Max_channels |x[n]|];
     2. look-ahead hold: h[n] = Min of r over [n, n + W - 1], W = the
        attack time in samples (odd), so the gain is already reduced
        when a peak arrives;
     3. attack smoothing: s[n] = mean of h over [n - W + 1, n], with
        h[1] standing in before the first sample. Every value in that
        window covers sample n, so s[n] <= r[n]: the output never
        exceeds the ceiling;
     4. release: g[n] = s[n] if s[n] <= g[n-1], else
        g[n-1] + (1 - a) (s[n] - g[n-1]), a = Exp[-1 / (release * sr)];
        rising slowly keeps g <= s.
   Returns <|"data" (limited channels), "gain" (g), "maxReductionDB"|>. *)

PeakLimitRelease =
  Compile[{{s, _Real, 1}, {a, _Real}},
    Module[{g = s, n = Length[s]},
      Do[If[s[[i]] > g[[i - 1]], g[[i]] = g[[i - 1]] + (1.0 - a) (s[[i]] - g[[i - 1]])], {i, 2, n}];
      g]];

PeakLimit[channels_List, sr_?NumericQ, ceilingDB_?NumericQ, attackMs_?NumericQ, releaseMs_?NumericQ] :=
  Module[{chans, c, w, r, peak, req, hold, smooth, g, a, n},
    chans = If[VectorQ[channels, NumericQ], {channels}, channels];
    n = Length[First[chans]];
    c = 10.0^(ceilingDB / 20.0);
    w = Max[1, 2 Round[attackMs / 1000.0 * sr / 2] + 1];  r = (w - 1) / 2;
    peak = Abs[First[chans]];
    Do[peak = (peak + Abs[ch] + Abs[peak - Abs[ch]]) / 2.0, {ch, Rest[chans]}];   (* elementwise max *)
    req  = Clip[c / (peak + 10.0^-300), {0.0, 1.0}];
    hold = If[r == 0, req, MinFilter[Join[req, ConstantArray[1.0, 2 r]], r][[r + 1 ;; r + n]]];
    (* pad the start with the first held gain, not 1: hold[[1]] covers
       samples 1..w, so every value in the first windows still covers the
       peak it protects (padding with 1 let a peak in the first 5 ms
       through: measured +0.2 dB over the ceiling at sample 83) *)
    smooth = If[w == 1, hold, MovingAverage[Join[ConstantArray[First[hold], w - 1], hold], w]];
    a = Exp[-1.0 / (releaseMs / 1000.0 * sr)];
    g = PeakLimitRelease[Developer`ToPackedArray[N[smooth]], a];
    <|"data" -> (# * g & /@ chans), "gain" -> g, "maxReductionDB" -> -20.0 Log10[Min[g]]|>
  ];

(* LimiterSettings[cfg] — the audio.limiter block of an app's merged
   config, or None when the limiter is off for this run. Sub-keys:
   enabled (default False), ceiling_dbfs (-1.0), attack_ms (5),
   release_ms (50), and optionally modes, a list of simulation.mode
   values the limiter applies to (default: every mode). *)
LimiterSettings[cfg_Association] :=
  Module[{lim = Lookup[Lookup[cfg, "audio", <||>], "limiter", <||>], mode, modes},
    If[!AssociationQ[lim] || !TrueQ[Lookup[lim, "enabled", False]], Return[None]];
    mode  = Lookup[Lookup[cfg, "simulation", <||>], "mode", Missing[]];
    modes = Lookup[lim, "modes", All];
    If[ListQ[modes] && !MemberQ[modes, mode], Return[None]];
    <|"ceiling_dbfs" -> N @ Lookup[lim, "ceiling_dbfs", -1.0], "attack_ms" -> N @ Lookup[lim, "attack_ms", 5.0],
      "release_ms" -> N @ Lookup[lim, "release_ms", 50.0]|>
  ];

(* LimitedNormalizeToLoudness
   NormalizeToLoudness with the peak limiter in the loop: scale to the
   target loudness, limit to the ceiling, re-measure, correct the gain
   and repeat (at most 12 passes) until the limited result is within
   0.02 LU of the target. The peak ceiling of NormalizeToLoudness still
   applies afterwards as a backstop. Sets $StemLastLimiter to
   <|"ceilingDB", "attackMs", "releaseMs", "maxReductionDB", "passes",
   "lufs", "gain"|> for the app to report. *)
$StemLastLimiter = None;

LimitedNormalizeToLoudness[buffer_List, targetLUFS_?NumericQ, peakCeiling_?NumericQ, sr_Integer,
                           lim_Association] :=
  Module[{isStereo, chanData, y, res, l, k = 0, out, peak},
    isStereo = ListQ[buffer[[1]]];
    chanData = If[isStereo, buffer, {buffer}];
    l = MeasureIntegratedLoudness[chanData, sr];
    If[!NumericQ[l], Return[buffer]];
    y = chanData * 10.0^((targetLUFS - l) / 20.0);
    While[True,
      k++;
      res = PeakLimit[y, sr, lim["ceiling_dbfs"], lim["attack_ms"], lim["release_ms"]];
      l = MeasureIntegratedLoudness[res["data"], sr];
      If[Abs[l - targetLUFS] <= 0.02 || k >= 12, Break[]];
      y = y * 10.0^((targetLUFS - l) / 20.0)];
    out  = res["data"];
    peak = Max[Abs[Flatten[out]]];
    If[peak > peakCeiling, out = out * (peakCeiling / peak)];
    $StemLastLimiter = <|"ceilingDB" -> lim["ceiling_dbfs"], "attackMs" -> lim["attack_ms"],
      "releaseMs" -> lim["release_ms"], "maxReductionDB" -> res["maxReductionDB"], "passes" -> k,
      "lufs" -> l, "gain" -> res["gain"]|>;
    If[isStereo, out, out[[1]]]
  ];


(* ExportAudioBuffer
   Wraps a PCM buffer in a Sound object and writes a WAV file.
   Uses SampledSoundList which exports correctly in headless
   wolframscript sessions (Audio[] requires a display context). *)

ExportAudioBuffer[buffer_List, filePath_String,
                  sr_Integer:44100] :=
  Module[{snd},
    EnsureDir[filePath];
    snd = Sound[SampledSoundList[buffer, sr]];
    Export[filePath, snd, "WAV"];
    filePath
  ]

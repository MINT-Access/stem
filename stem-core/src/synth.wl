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


(* MeasureIntegratedLoudness
   EBU R128 / ITU-R BS.1770 integrated loudness of a WL Audio object,
   in LUFS. Built on AudioLoudness["EBUMomentary"] (400ms/100ms-hop
   K-weighted blocks, matching the BS.1770 gating block definition
   exactly) plus the standard two-stage gating: discard blocks below
   an absolute -70 LUFS threshold, then discard blocks below a
   relative threshold 10 LU under the mean of what's left.

   NOTE: AudioLoudness's own built-in stereo combination was checked
   against a reference implementation (Python pyloudnorm, itself
   BS.1770-4) on this project's actual stereo WAV output and found to
   average channel power rather than sum it -- undercounting
   integrated loudness on stereo files by a systematic ~3 dB (10*Log10[0.5]).
   Worked around here by measuring each channel separately via
   AudioChannelSeparate and summing per-channel mean-square power
   ourselves with BS.1770's channel gain of 1.0 for L/R (this project
   never produces surround channels, so no other gain applies).
   Validated to within ~1 dB of pyloudnorm across mono and stereo
   files spanning -35 to -5 LUFS. *)

MeasureIntegratedLoudness[audio_Audio] :=
  Module[{zFromL, lFromZ, chans, perChanL, zPerBlock, blockLoudness,
          absGated, ungated, relThresh, finalGated},
    zFromL[l_] := 10.0^((l + 0.691) / 10.0);
    lFromZ[z_] := -0.691 + 10.0 * Log10[z];
    chans = AudioChannelSeparate[audio];
    perChanL  = AudioLoudness[#, "EBUMomentary"]["Values"] & /@ chans;
    zPerBlock = Total[Map[zFromL, perChanL, {2}]];
    blockLoudness = lFromZ /@ zPerBlock;
    absGated = Select[blockLoudness, # > -70.0 &];
    If[Length[absGated] == 0, Return[-Infinity]];
    ungated   = lFromZ[Mean[zFromL /@ absGated]];
    relThresh = ungated - 10.0;
    finalGated = Select[absGated, # > relThresh &];
    If[Length[finalGated] == 0, Return[ungated]];
    lFromZ[Mean[zFromL /@ finalGated]]
  ];


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
  Module[{isStereo, chanData, aud, measured, gainDB, gainLin, out, peak},
    If[Length[buffer] == 0, Return[buffer]];
    isStereo = ListQ[buffer[[1]]];
    chanData = If[isStereo, buffer, {buffer}];
    If[Max[Abs[Flatten[chanData]]] == 0, Return[buffer]];
    aud = Audio[chanData, "SampleRate" -> sr];
    measured = MeasureIntegratedLoudness[aud];
    If[measured === -Infinity || !NumericQ[measured], Return[buffer]];
    gainDB  = targetLUFS - measured;
    gainLin = 10.0^(gainDB / 20.0);
    out  = chanData * gainLin;
    peak = Max[Abs[Flatten[out]]];
    If[peak > peakCeiling, out = out * (peakCeiling / peak)];
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

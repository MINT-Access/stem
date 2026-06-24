(* ========================================================
   stem-core/src/synth.wl — PCM waveform synthesis

   Consolidates:
     - SynthesizeNote (pendulum/src/sonify.wl:67)
       SynthNote      (lorenz/src/sonify.wl:75)
       SynthNote      (asteroids/src/sonify.wl:54)
       All three use exp-decay × additive-sine synthesis;
       differ only in harmonics and decay speed.

     - NormalizeBuffer: identical in lorenz/src/sonify.wl:125
       and asteroids/src/sonify.wl:124; pendulum used a
       slightly different always-normalise variant at line 180.

     - ExportAudioBuffer: identical Sound[SampledSoundList]+Export
       blocks in lorenz/src/sonify.wl:157 and
       asteroids/src/sonify.wl:154; pendulum used Audio[] at
       line 188 (replaced here with the headless-safe form).

   Requires: utils.wl (for EnsureDir)
   ======================================================== *)


(* StemSynthNote
   Generates raw PCM samples for one note.

   freq      — frequency in Hz
   dur       — note duration in seconds
   vol       — peak amplitude 0.0–1.0
   harmonics — list of relative amplitudes for partials 1, 2, 3, …
               {1.0}              → pure sine  (pendulum style)
               {1.0, 0.35, 0.12} → warm bell  (lorenz / asteroids safe)
               {1.0, 0.30, 0.20, 0.25, 0.15} → bright/harsh (asteroids hazardous)
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
   Returns the buffer unchanged if it is already within range.

   Replaces identical blocks in lorenz/src/sonify.wl:125 and
   asteroids/src/sonify.wl:124, and the unconditional variant
   in pendulum/src/sonify.wl:180. *)

NormalizeBuffer[buffer_List, ceiling_:0.95] :=
  Module[{peak},
    peak = Max[Abs[buffer]];
    If[peak > ceiling, buffer * (ceiling / peak), buffer]
  ]


(* ExportAudioBuffer
   Wraps a PCM buffer in a Sound object and writes a WAV file.
   Uses SampledSoundList which works correctly in headless
   wolframscript (Audio[] requires a display context on some builds).

   Replaces the Sound[SampledSoundList]+Export blocks in
   lorenz/src/sonify.wl:157–162 and asteroids/src/sonify.wl:154–159,
   and the Audio[]+Export block in pendulum/src/sonify.wl:188–190. *)

ExportAudioBuffer[buffer_List, filePath_String,
                  sr_Integer:44100] :=
  Module[{snd},
    EnsureDir[filePath];
    snd = Sound[SampledSoundList[buffer, sr]];
    Export[filePath, snd, "WAV"];
    filePath
  ]

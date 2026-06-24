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

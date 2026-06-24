(* ========================================================
   stem-core/src/scales.wl — Musical scales and pitch mapping

   Consolidates:
     - $SampleRate = 44100 from all three sonify.wl files
     - $Scales tables from lorenz/src/sonify.wl and
       asteroids/src/sonify.wl (merged; asteroids added "Phrygian",
       lorenz added "Major" and "WholeTone")
     - SemitoneToHz from lorenz/src/sonify.wl:44 and
       asteroids/src/sonify.wl:39 (byte-for-byte identical)
     - ScaleLookup replaces XToFrequency (lorenz),
       DistanceToFrequency (asteroids), AngleToFrequency (pendulum) —
       all three used the same Rescale → Round → Clip → lookup body
   ======================================================== *)


$StemSampleRate = 44100;   (* Hz — standard CD quality *)


(* $StemScales
   Semitone offsets above a root note, two octaves.
   Pass the list to ScaleLookup along with a root frequency. *)

$StemScales = <|
  "MinorPentatonic" -> {0,  3,  5,  7, 10, 12, 15, 17, 19, 22},
  "MajorPentatonic" -> {0,  2,  4,  7,  9, 12, 14, 16, 19, 21},
  "Major"           -> {0,  2,  4,  5,  7,  9, 11, 12, 14, 16},
  "Minor"           -> {0,  2,  3,  5,  7,  8, 10, 12, 14, 15},
  "WholeTone"       -> {0,  2,  4,  6,  8, 10, 12, 14, 16, 18},
  "Phrygian"        -> {0,  1,  3,  5,  7,  8, 10, 12, 13, 15}
|>;


(* SemitoneToHz
   Converts a semitone offset above rootHz to a frequency in Hz.
   Identical to the definitions in lorenz/src/sonify.wl:44 and
   asteroids/src/sonify.wl:39, generalised to accept a root. *)

SemitoneToHz[semitones_?NumericQ, rootHz_?NumericQ] :=
  rootHz * 2.0^(semitones / 12.0)


(* ScaleLookup
   Maps a scalar value in [lo, hi] to a frequency from a scale.

   value   — the data value to sonify (angle, x-coordinate, distance, …)
   lo, hi  — the expected range of value; lo maps to scale degree 1,
             hi maps to scale degree n
   scale   — a list of semitone offsets, e.g. $StemScales["Minor"]
   rootHz  — frequency of scale degree 1 in Hz

   Replaces:
     AngleToFrequency[theta, maxAngle]        pendulum/src/sonify.wl:50
     XToFrequency[x, maxX, scale]             lorenz/src/sonify.wl:48
     DistanceToFrequency[km, minKm, maxKm, scale]  asteroids/src/sonify.wl:41 *)

ScaleLookup[value_?NumericQ, lo_?NumericQ, hi_?NumericQ,
            scale_List, rootHz_?NumericQ] :=
  Module[{n, idx},
    n   = Length[scale];
    idx = Clip[Round[Rescale[value, {lo, hi}, {1, n}]], {1, n}];
    SemitoneToHz[scale[[idx]], rootHz]
  ]

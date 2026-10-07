(* ========================================================
   blackbody/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildSpectrumIntroText[T_?NumericQ, nBins_Integer] :=
  "Planck black body spectrum at " <> ToString[Round[T]] <> " Kelvin, " <>
  ToString[nBins] <> " frequency bins from radio to X-ray. First, the full curve as " <>
  "a single chord -- every frequency sounding at once, weighted by the Planck curve " <>
  "itself. Two soft taps mark the edges of the narrow band of visible light. Then, " <>
  "the same bins swept one at a time from radio up to X-ray.";

BuildSpectrumOutroText[] :=
  "Notice how little of the sweep fell between the two taps -- that narrow sliver " <>
  "is all of the light a human eye can see. Everything else in the sweep is light " <>
  "this star emits that no eye can detect.";

BuildTemperatureIntroText[Tmin_?NumericQ, Tmax_?NumericQ] :=
  "Temperature sweep from " <> ToString[Round[Tmin]] <> " to " <> ToString[Round[Tmax]] <>
  " Kelvin, red dwarf to blue giant. Listen for the pitch of the marked peak rising " <>
  "as temperature increases -- that is Wien's displacement law. Listen for the " <>
  "overall loudness growing, compressed onto a manageable range -- the true growth, " <>
  "following the Stefan-Boltzmann law, is the fourth power of temperature.";

BuildStarIntroText[starName_String, T_?NumericQ] :=
  "Black body spectrum of " <> starName <> ", temperature " <> ToString[Round[T]] <>
  " Kelvin.";

BuildStarTourIntroText[] :=
  "A tour of six black bodies, from coolest to hottest: a red dwarf, Betelgeuse, " <>
  "the Sun, Sirius A, Rigel, and a white dwarf. Listen for the pitch of each " <>
  "chord's peak rising and the chord growing louder as temperature increases.";

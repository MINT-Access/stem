(* ========================================================
   clt/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro/outro text builders, one per mode ─────────────────────── *)

SourceDisplayName[name_String] := Switch[name,
  "uniform",     "a uniform distribution",
  "exponential", "an exponential distribution",
  "bernoulli",   "a coin flip",
  _,             name
];

BuildSweepIntroText[sourceName_String, nMax_Integer] :=
  "The Central Limit Theorem, sweep mode: the sample mean of " <> ToString[nMax] <>
  " draws from " <> SourceDisplayName[sourceName] <> ", one at a time up to " <> ToString[nMax] <>
  ". Listen for the spectrum both narrowing, as the mean's own spread shrinks, and " <>
  "smoothing into a symmetric bell shape, regardless of how lopsided the starting " <>
  "distribution looked.";

BuildCompareIntroText[sourceLeft_String, sourceRight_String, nMax_Integer] :=
  "Compare mode: two very different starting distributions, standardized so only " <>
  "their shape matters, not their scale. Left channel: " <> SourceDisplayName[sourceLeft] <>
  ". Right channel: " <> SourceDisplayName[sourceRight] <>
  ". Both sweep from 1 up to " <> ToString[nMax] <> " draws. Listen for two completely " <>
  "different sounds at the start converging toward the very same shape by the end.";

BuildDiceIntroText[nMax_Integer] :=
  "The Central Limit Theorem's most familiar illustration: the sum of " <> ToString[nMax] <>
  " fair six-sided dice, one at a time up to " <> ToString[nMax] <>
  ". A single die is flat -- six equally likely outcomes. Listen for that flat, jagged " <>
  "sound smoothing into an unmistakable bell shape, purely from summing more dice -- " <>
  "not narrowing, since the sum's spread actually grows, but smoothing all the same.";

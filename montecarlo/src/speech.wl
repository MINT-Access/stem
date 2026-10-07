(* ========================================================
   montecarlo/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildSweepIntroText[nSize_Integer, TStart_?NumericQ, TEnd_?NumericQ, Tc_?NumericQ] :=
  "Two-dimensional Ising model, " <> ToString[nSize] <> " by " <> ToString[nSize] <> " lattice. " <>
  "Temperature sweep from " <> ToString[NumberForm[TStart, {3, 1}]] <> " to " <>
  ToString[NumberForm[TEnd, {3, 1}]] <> ". The critical temperature is " <>
  ToString[NumberForm[Tc, {5, 4}]] <> ". Listen for the phase transition: the loudest, " <>
  "most turbulent moment marks the critical point, where the system crosses from disorder " <>
  "into ferromagnetic order.";

BuildCriticalIntroText[Tc_?NumericQ] :=
  "Two-dimensional Ising model at the critical temperature, T equals " <>
  ToString[NumberForm[Tc, {5, 4}]] <> ". The system is at its most complex state: " <>
  "correlated domains at all scales, magnetisation fluctuating continuously. " <>
  "Neither ordered nor random.";

BuildQuenchIntroText[THot_?NumericQ, TCold_?NumericQ] :=
  "Two-dimensional Ising model: instantaneous quench from T equals " <>
  ToString[NumberForm[THot, {3, 1}]] <> " to T equals " <> ToString[NumberForm[TCold, {3, 1}]] <>
  ". Listen for the system struggling to order from a random initial state -- competing " <>
  "domains forming, growing, and merging -- before settling into ferromagnetic order.";

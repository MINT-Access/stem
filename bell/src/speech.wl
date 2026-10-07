(* ========================================================
   bell/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


BuildCorrelationsIntroText[] :=
  "Bell correlations. Two entangled qubits, measured at a sweeping angle " <>
  "difference. The right channel plays the real quantum correlation; the " <>
  "left channel plays what any local hidden-variable theory would predict. " <>
  "Listen for the gap between them.";

BuildChshIntroText[sValue_?NumericQ] :=
  "The C H S H inequality. Four correlation measurements combine into one " <>
  "number, S, equal to " <> ToString[NumberForm[sValue, {4, 3}]] <> ". No local " <>
  "hidden-variable theory can exceed two. Listen for the gap between the " <>
  "classical limit and the quantum result.";

BuildMeasurementIntroText[nTrials_Integer, trueE_?NumericQ] :=
  ToString[nTrials] <> " paired measurements of an entangled qubit pair, true " <>
  "correlation equals " <> ToString[NumberForm[trueE, {3, 2}]] <> ". Alice's " <>
  "outcomes play on the left, Bob's on the right — each individually " <>
  "unpredictable, fifty-fifty. Then listen for the running correlation " <>
  "converging toward the true value.";

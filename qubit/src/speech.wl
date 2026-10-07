(* ========================================================
   qubit/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


BuildGatesIntroText[gateNames_List] :=
  "Qubit gate sequence: " <> StringRiffle[gateNames, ", "] <> ". Each gate is a " <>
  "continuous rotation of the Bloch vector about some axis. Listen for the " <>
  "stereo position and pitch tracing that rotation, and a marker tone at " <>
  "the start of each new gate.";

BuildRabiIntroText[Omega_?NumericQ] :=
  "Rabi oscillation. A qubit driven on resonance, Omega equals " <>
  ToString[NumberForm[Omega, {3, 2}]] <> ". Listen for the pitch rising and " <>
  "falling as the population inversion oscillates between the ground and " <>
  "excited state.";

BuildMeasurementIntroText[nTrials_Integer, p0True_?NumericQ] :=
  ToString[nTrials] <> " independent measurements of a qubit in superposition, " <>
  "true probability of measuring zero equals " <> ToString[NumberForm[p0True, {3, 2}]] <>
  ". Listen for the pitch settling as the empirical frequency converges toward " <>
  "the true value — the quantum analogue of a coin's bias becoming clear flip " <>
  "by flip.";

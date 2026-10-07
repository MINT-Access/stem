(* ========================================================
   hydrogen/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro / outro text builders, one per mode ───────────────────── *)

BuildOrbitalsIntroText[orbitalKey_String, n_Integer, l_Integer, m_Integer, gridSize_Integer] :=
  "Hydrogen atom " <> OrbitalDisplayName[orbitalKey] <> " orbital: quantum numbers n=" <>
  ToString[n] <> ", l=" <> ToString[l] <> ", m=" <> ToString[m] <> ". " <>
  ToString[gridSize] <> " by " <> ToString[gridSize] <>
  " cross-section in the x z plane, scanned in Hilbert curve order. The brightest regions " <>
  "-- highest electron probability -- produce the highest pitch. Nodes, where the wave " <>
  "function is exactly zero, produce silence.";

BuildSpectrumIntroText[nMax_Integer, nLines_Integer] :=
  "Hydrogen emission spectrum, transitions from n=2 to n=" <> ToString[nMax] <> ". " <>
  ToString[nLines] <> " spectral lines from Lyman through Paschen series. You will hear " <>
  "first a chord of all lines simultaneously, then a sweep from ultraviolet through visible " <>
  "to infrared. The four Balmer series lines -- the visible hydrogen spectrum -- are marked " <>
  "with a soft bell tone during the sweep.";

BuildSpectrumOutroText[] :=
  "That was the complete hydrogen spectrum -- Lyman ultraviolet, Balmer visible light, and " <>
  "Paschen infrared, all produced by the same single electron falling between energy levels.";

BuildTransitionsIntroText[nRealizations_Integer, nStart_Integer, lStart_Integer] :=
  "Hydrogen electron cascade, " <> ToString[nRealizations] <>
  " realisations starting from n=" <> ToString[nStart] <> ", l=" <> ToString[lStart] <>
  ". Each realisation is a different random path through the energy levels, following " <>
  "quantum selection rules. All paths end at the ground state -- the lowest, final note. " <>
  "The differences between realisations are quantum randomness.";

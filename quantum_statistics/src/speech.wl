(* ========================================================
   quantum_statistics/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


BuildSpectrumIntroText[T_?NumericQ] :=
  "Quantum statistics. Bose-Einstein, Fermi-Dirac, and Maxwell-Boltzmann " <>
  "occupation numbers, at temperature " <> ToString[NumberForm[T, {5, 0}]] <>
  " Kelvin. Bose-Einstein plays on the left, Fermi-Dirac in the centre, " <>
  "Maxwell-Boltzmann on the right, low to high pitch tracing low to high " <>
  "energy. Listen for where the three voices agree, and where they pull apart.";

BuildTemperatureIntroText[] :=
  "Sweeping temperature at a fixed energy, chemical potential zero. Listen " <>
  "for all three voices converging quietly at low temperature, then " <>
  "Bose-Einstein pulling away and growing loud as temperature rises — " <>
  "quantum statistics deviating most strongly from the classical limit at " <>
  "high temperature, not low, for this fixed chemical potential.";

BuildFermiSeaIntroText[] :=
  "The Fermi sea. Fermi-Dirac occupation only, swept from cold to warm. " <>
  "Listen for a bright, sharply defined chord at the coldest temperature " <>
  "— the textbook step function — smoothing into a duller, more even " <>
  "texture as temperature rises and the step blurs.";

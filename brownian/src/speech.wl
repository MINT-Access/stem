(* ========================================================
   brownian/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* BuildWalkIntroText *)
BuildWalkIntroText[D_?NumericQ, nSteps_Integer] :=
  "Brownian motion. A single random walk, " <> ToString[nSteps] <> " steps, " <>
  "diffusion coefficient " <> ToString[NumberForm[D, {3, 2}]] <> " square metres per second. " <>
  "In 1827, Robert Brown watched pollen grains jiggle erratically in water. " <>
  "Einstein showed in 1905 that the jiggling was the visible signature of " <>
  "countless collisions with individual water molecules. Listen for the stereo " <>
  "position tracking the walk, and the volume tracking how far it has wandered " <>
  "from where it started.";


(* BuildEnsembleIntroText *)
BuildEnsembleIntroText[nWalkers_Integer] :=
  "Ensemble of " <> ToString[nWalkers] <> " independent random walkers, all " <>
  "starting from the same point. A single walker's distance from the origin is " <>
  "too noisy to reveal the underlying law, but the average over many walkers " <>
  "follows it cleanly: root mean square displacement grows as the square root " <>
  "of time, not linearly. Listen for the rising tone slowing its climb over " <>
  "time — that slowing is the square root law, made audible.";


(* BuildTemperatureIntroText *)
BuildTemperatureIntroText[tMin_?NumericQ, tMax_?NumericQ] :=
  "Temperature sweep, " <> ToString[NumberForm[tMin, {3, 0}]] <> " to " <>
  ToString[NumberForm[tMax, {3, 0}]] <> " kelvin. The Stokes-Einstein relation " <>
  "predicts the diffusion coefficient rises with temperature. Listen for the " <>
  "jiggling becoming more agitated as the sweep proceeds toward higher " <>
  "temperature, and calmer toward lower temperature.";

(* ========================================================
   quantum_tunnelling/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro/outro text builders, one per mode ─────────────────────── *)

BuildBarrierIntroText[model_Association] :=
  "Quantum tunnelling, " <> model["preset"] <> " preset: a particle at " <>
  ToString[NumberForm[model["E"], {5, 3}]] <> " electronvolts approaches a barrier " <>
  ToString[NumberForm[model["V0"], {5, 3}]] <> " electronvolts high, " <>
  ToString[NumberForm[model["L"], {5, 6}]] <> " nanometres wide. Classically, this " <>
  "particle cannot cross. Listen for the incoming tone, a marker at the barrier, then " <>
  "two simultaneous outcomes: a reflected tone bouncing back, and a transmitted tone " <>
  "passing through -- both genuinely happen, in proportion to their probability.";

BuildBarrierOutroText[model_Association] :=
  "Transmission probability " <> ToString[NumberForm[model["T"] * 100.0, {6, 4}]] <>
  " percent. Reflection probability " <> ToString[NumberForm[model["R"] * 100.0, {6, 4}]] <>
  " percent. The particle had zero classical chance of crossing, and yet quantum " <>
  "mechanically, sometimes, it does.";

BuildSweepIntroText[model_Association] :=
  "Barrier width swept from " <> ToString[NumberForm[model["widthMin"], {5, 3}]] <>
  " to " <> ToString[NumberForm[model["widthMax"], {5, 3}]] <>
  " nanometres, at a fixed particle energy below the barrier height. Listen for the " <>
  "tunnelling probability fading toward silence as the barrier grows thicker -- an " <>
  "exponential collapse, made audibly gradual across the whole sweep.";

BuildEnergyIntroText[model_Association] :=
  "Particle energy swept from " <> ToString[NumberForm[model["EMin"], {5, 3}]] <>
  " to " <> ToString[NumberForm[model["EMax"], {5, 3}]] <>
  " electronvolts, crossing the barrier height of " <> ToString[NumberForm[model["V0"], {5, 3}]] <>
  " electronvolts, marked by an accent tone. Below that mark, listen for the volume " <>
  "rising as tunnelling becomes easier. Above it, listen for a genuine wobble -- " <>
  "transmission oscillates with energy, reaching perfect, total transmission at " <>
  "specific resonant energies, the same standing-wave condition that quantizes a " <>
  "particle trapped in a box.";

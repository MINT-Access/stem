(* ========================================================
   compton/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro/outro text builders, one per mode ─────────────────────── *)

BuildScatterIntroText[model_Association] :=
  "Compton scattering, 1923: an X-ray photon at " <> ToString[NumberForm[model["lambdaPm"], {4, 1}]] <>
  " picometres, " <> ToString[NumberForm[model["EKeV"], {4, 1}]] <>
  " kiloelectronvolts, scatters through " <> ToString[Round[model["thetaDeg"]]] <>
  " degrees. Listen for the incoming photon, a collision click, then the outgoing photon " <>
  "at a measurably lower pitch, panned according to the scattering angle, and a soft low thud " <>
  "for the recoiling electron.";

BuildScatterOutroText[model_Association] :=
  "Outgoing energy " <> ToString[NumberForm[model["EPrimeKeV"], {4, 1}]] <>
  " kiloelectronvolts, down from " <> ToString[NumberForm[model["EKeV"], {4, 1}]] <>
  ". The electron recoiled with " <> ToString[NumberForm[model["TKeV"], {4, 2}]] <>
  " kiloelectronvolts of kinetic energy. This is the measurement that proved light carries " <>
  "momentum like a particle.";

BuildSweepIntroText[model_Association] :=
  "Angle sweep from " <> ToString[Round[model["angleMin"]]] <> " to " <> ToString[Round[model["angleMax"]]] <>
  " degrees, incident wavelength " <> ToString[NumberForm[model["lambdaPm"], {4, 1}]] <>
  " picometres. Listen for the pitch dropping fastest through the middle of the sweep, near " <>
  "90 degrees, and slowest near the two ends -- the sine of the angle in Compton's own formula.";

BuildEnergyIntroText[model_Association] :=
  "Incident photon energy swept from " <> ToString[NumberForm[model["EMinKev"], {4, 1}]] <>
  " to " <> ToString[NumberForm[model["EMaxKev"], {5, 0}]] <>
  " kiloelectronvolts at a fixed " <> ToString[Round[model["angleDeg"]]] <>
  " degree scattering angle. Listen for the incoming and outgoing pitches starting in near " <>
  "unison at low energy, and pulling apart as energy rises past the electron's own rest energy, " <>
  "511 kiloelectronvolts, marked by an accent tone.";

BuildDiscoveryIntroText[] :=
  "Compton's 1923 measurement, binaural. Left channel: the classical Thomson prediction -- " <>
  "elastic scattering, the outgoing pitch always equal to the incoming pitch, at every angle. " <>
  "Right channel: the real, quantum result -- the outgoing pitch measurably drops as the angle " <>
  "increases. The two channels start in unison and pull apart as the sweep proceeds -- that gap " <>
  "is the evidence that decided the wave-particle debate.";

BuildDiscoveryOutroText[] :=
  "The right channel's pitch drop has no classical explanation. Arthur Compton's 1923 " <>
  "measurement of exactly this effect won him the 1927 Nobel Prize in Physics.";

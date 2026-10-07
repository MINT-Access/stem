(* ========================================================
   thermo/src/speech.wl — Spoken introduction synthesis

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


(* ── Intro text builders, one per mode ───────────────────────────── *)

BuildDistributionIntroText[gasName_String, massAmu_?NumericQ, TStart_?NumericQ, TEnd_?NumericQ] :=
  "Maxwell-Boltzmann speed distribution for " <> gasName <> ", mass " <>
  ToString[NumberForm[N[massAmu], {3, 1}]] <> " atomic mass units. " <>
  "Temperature sweep from " <> ToString[Round[TStart]] <> " to " <> ToString[Round[TEnd]] <>
  " Kelvin. Listen for the spectrum broadening and rising in pitch as temperature increases. " <>
  "The three characteristic speeds -- most probable, mean, and R M S -- are marked by a soft " <>
  "triple-tap at each temperature step.";

BuildEnsembleIntroText[nParticles_Integer, gasName_String, T_?NumericQ] :=
  ToString[nParticles] <> " particles of " <> gasName <> " at " <> ToString[Round[T]] <>
  " Kelvin. Listen for the chord of " <> ToString[nParticles] <> " simultaneous tones, " <>
  "constantly reshuffling through elastic collisions while maintaining the same overall " <>
  "temperature. The whole is stable; the parts are restless.";

BuildCoolingIntroText[gasName_String, THot_?NumericQ, TCold_?NumericQ] :=
  gasName <> " cooling from " <> ToString[Round[THot]] <> " Kelvin to " <> ToString[Round[TCold]] <>
  " Kelvin. Listen for the sound contracting and darkening as molecules slow down, finally " <>
  "settling into a narrow low hum at thermal equilibrium.";

BuildEquipartitionIntroText[moleculeType_String, TStart_?NumericQ, TEnd_?NumericQ] :=
  "Equipartition theorem: " <> moleculeType <> " gas at " <> ToString[Round[TStart]] <> " to " <>
  ToString[Round[TEnd]] <> " Kelvin. Left channel: translational kinetic energy -- identical " <>
  "for all ideal gases at the same temperature. Right channel: rotational energy contribution " <>
  "-- present for diatomic gases, absent for monatomic. Listen for the right channel growing " <>
  "as temperature rises.";

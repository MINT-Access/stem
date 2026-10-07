(* ========================================================
   grover/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


BuildSearchIntroText[nItems_Integer, optimalK_Integer] :=
  "Grover's search algorithm. Searching " <> ToString[nItems] <> " items for one " <>
  "marked item. Listen for the pitch rising toward a peak at iteration " <>
  ToString[optimalK] <> ", marked by a bright accent, then falling again if " <>
  "iteration continues past it — more queries is not always better.";

BuildCompareIntroText[nItems_Integer, classicalQueries_Integer, quantumQueries_Integer] :=
  "Classical versus quantum search, racing to find one marked item among " <>
  ToString[nItems] <> ". Left channel: classical linear search, " <>
  ToString[classicalQueries] <> " queries on average. Right channel: Grover's " <>
  "algorithm, just " <> ToString[quantumQueries] <> " queries. Listen for which " <>
  "channel finishes first.";

BuildGeometryIntroText[nItems_Integer] :=
  "The geometry of Grover's algorithm. Each iteration rotates the state by a " <>
  "fixed angle within a two-dimensional subspace, searching " <> ToString[nItems] <>
  " items. Listen for a continuously rotating stereo position and a pitch that " <>
  "peaks each time the rotation passes closest to the marked state.";

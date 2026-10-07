(* ========================================================
   mandelbrot/src/speech.wl — Spoken orientation guidance

   Narration audio comes from stem-core's STEMSpeakToBuffer
   (SpeechSynthesize[] -> platform TTS -> text printed after a
   warning); this file holds only the app's narration text.
   ======================================================== *)


BuildMandelbrotIntroText[maxIter_Integer] :=
  "The Mandelbrot set. Iterating z equals z squared plus c, up to " <>
  ToString[maxIter] <> " times per point. Slow or never-escaping points " <>
  "play high; fast-escaping points play low. Listen for the boundary — " <>
  "where the pitch becomes rapid and chaotic — versus the deep interior " <>
  "and far exterior, both comparatively steady.";

BuildJuliaIntroText[cRe_?NumericQ, cIm_?NumericQ, cIsInterior_] :=
  "A Julia set, for the fixed point c equals " <>
  ToString[NumberForm[cRe, {4, 3}]] <> " plus " <> ToString[NumberForm[cIm, {4, 3}]] <>
  " i. This c is " <> If[TrueQ[cIsInterior], "inside", "outside"] <>
  " the Mandelbrot set, so this Julia set is " <>
  If[TrueQ[cIsInterior], "connected", "disconnected"] <>
  " — one point of the Mandelbrot set, and here is what that point actually means.";

BuildZoomIntroText[nLevels_Integer] :=
  "Zooming into the Mandelbrot boundary, " <> ToString[nLevels] <>
  " levels deep, all centred on the same point in the seahorse valley. " <>
  "Listen for the boundary's rapid, chaotic pitch variation sounding " <>
  "similarly rich at every level — self-similarity, made audible.";

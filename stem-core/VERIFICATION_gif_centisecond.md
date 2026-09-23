# GIF/WAV centisecond sync — verification report

- Date of all runs: 2026-09-23.
- Repository: stem, branch main, base commit e08170b, changes uncommitted.
- Engine: WolframScript 1.14.0 for Mac OS X ARM (64-bit).
- Baseline runs were made at e08170b in a separate git worktree (scratchpad), so before and after come from two real runs on the same day.
- Every duration in this file was measured from the written files, never taken from an app's own console line, unless a line says otherwise.
- GIF duration method: sum of Import[gif, "DisplayDurations"].
- WAV duration method: Import[wav, "Duration"].
- Difference convention: GIF duration minus WAV duration, in seconds; positive means the GIF is longer.

## Part 1 — Where frame rate, frame delay and frame count are chosen (at e08170b)

- There was one shared GIF writer, ExportGIF in stem-core/src/export.wl, which wrote DisplayDurations -> 1.0/frameRate and so left the rounding to whole centiseconds to Export.
- There was no shared helper for choosing the frame rate or the frame count.
- 32 app animate.wl files (every app) each chose the rate and count themselves, 71 GIF exports in total (69 ExportGIF calls plus 2 direct Export calls in waves).
- 24 of those files carried their own copy of $MinAnimationFps = 2 and $MaxAnimationFps = 30.
- 7 apps carried their own rate-helper function: fluid (FluidGifRate), grover (GroverGifRate), henon (HenonGifRate), hydrogen (HydrogenGifRate), images (ImagesGifRate), magnetic (MagAnimationRate), scattering (ScatAnimationRate).
- clt had a further copy, AnimationFrameRate, and rendered exactly nMax frames whatever the rounded delay was.
- waves did not use ExportGIF at all and called Export[..., "GIF", "DisplayDurations" -> ...] directly.
- asteroids was the only app that rounded the delay to whole centiseconds before deriving the frame count (its fix from e623bf9).
- pendulum used a fixed 25 fps with frames set by solution sampling, and primes ulam wrote a still single frame at the config fps (12 fps, 0.08 s).
- The standard copied pattern was: frameRate = Clip[budget/targetDuration, {2, 30}], then nFrames = Max[2, Round[frameRate*targetDuration]], then ExportGIF[frames, path, frameRate].
- Every such app printed "Rendering N frames at F fps (Xs, matching audio duration Ys)...", where X was N/F computed before export, not the file.

Full site list (file:line at e08170b, kind, code):
#### asteroids/src/animate.wl

- `asteroids/src/animate.wl:350` (frame rate): `nominalFrameRate = Clip[nFrames / targetDuration,`
- `asteroids/src/animate.wl:352` (frame rate): `quantDelay    = Round[100.0 / nominalFrameRate] / 100.0;`
- `asteroids/src/animate.wl:354` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `asteroids/src/animate.wl:388` (export): `ExportGIF[allFrames, filePath, frameRate];`

#### bayes/src/animate.wl

- `bayes/src/animate.wl:50` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `bayes/src/animate.wl:51` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `bayes/src/animate.wl:57` (export): `ExportGIF[frames, outGIF, frameRate];`
- `bayes/src/animate.wl:103` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `bayes/src/animate.wl:104` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `bayes/src/animate.wl:110` (export): `ExportGIF[frames, outGIF, frameRate];`
- `bayes/src/animate.wl:177` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `bayes/src/animate.wl:178` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `bayes/src/animate.wl:184` (export): `ExportGIF[frames, outGIF, frameRate];`

#### bell/src/animate.wl

- `bell/src/animate.wl:66` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `bell/src/animate.wl:67` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `bell/src/animate.wl:73` (export): `ExportGIF[frames, outGif, frameRate];`
- `bell/src/animate.wl:143` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `bell/src/animate.wl:144` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `bell/src/animate.wl:158` (export): `ExportGIF[frames, outGif, frameRate];`

#### blackbody/src/animate.wl

- `blackbody/src/animate.wl:122` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `blackbody/src/animate.wl:123` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `blackbody/src/animate.wl:129` (export): `ExportGIF[frames, outGIF, frameRate];`
- `blackbody/src/animate.wl:165` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `blackbody/src/animate.wl:166` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `blackbody/src/animate.wl:173` (export): `ExportGIF[frames, outGIF, frameRate];`
- `blackbody/src/animate.wl:271` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `blackbody/src/animate.wl:272` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `blackbody/src/animate.wl:285` (export): `ExportGIF[frames, outGIF, frameRate];`

#### brownian/src/animate.wl

- `brownian/src/animate.wl:82` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `brownian/src/animate.wl:83` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `brownian/src/animate.wl:91` (export): `ExportGIF[frames, filePath, frameRate];`

#### cellular/src/animate.wl

- `cellular/src/animate.wl:107` (frame rate): `frameRate = 1.0 / Max[targetDuration, 0.1];`
- `cellular/src/animate.wl:111` (export): `ExportGIF[{spacetimePlot}, outPath, frameRate];`
- `cellular/src/animate.wl:123` (frame rate): `frameRate = Clip[nGen / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `cellular/src/animate.wl:124` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `cellular/src/animate.wl:141` (export): `ExportGIF[frames, outPath, frameRate];`

#### clt/src/animate.wl

- `clt/src/animate.wl:41` (frame rate): `AnimationFrameRate[nMax_Integer, targetDuration_?NumericQ] :=`
- `clt/src/animate.wl:42` (frame rate): `Clip[N[nMax] / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `clt/src/animate.wl:85` (frame rate): `frameRate = AnimationFrameRate[nMax, targetDuration];`
- `clt/src/animate.wl:90` (export): `ExportGIF[frames, outGif, frameRate];`
- `clt/src/animate.wl:168` (frame rate): `frameRate = AnimationFrameRate[nMax, targetDuration];`
- `clt/src/animate.wl:175` (export): `ExportGIF[frames, outGif, frameRate];`
- `clt/src/animate.wl:253` (frame rate): `frameRate = AnimationFrameRate[nMax, targetDuration];`
- `clt/src/animate.wl:257` (export): `ExportGIF[frames, outGif, frameRate];`

#### compton/src/animate.wl

- `compton/src/animate.wl:116` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `compton/src/animate.wl:117` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `compton/src/animate.wl:120` (export): `ExportGIF[frames, outGif, frameRate];`
- `compton/src/animate.wl:146` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `compton/src/animate.wl:147` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `compton/src/animate.wl:156` (export): `ExportGIF[frames, outGif, frameRate];`
- `compton/src/animate.wl:198` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `compton/src/animate.wl:199` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `compton/src/animate.wl:206` (export): `ExportGIF[frames, outGif, frameRate];`

#### cosmology/src/animate.wl

- `cosmology/src/animate.wl:75` (frame rate): `frameRate  = Clip[frameBudget / targetDuration,`
- `cosmology/src/animate.wl:77` (frame count): `nGIFFrames = Max[2, Round[frameRate * targetDuration]];`
- `cosmology/src/animate.wl:116` (export): `ExportGIF[gifFrames, outGIF, frameRate];`

#### dynamical/src/animate.wl

- `dynamical/src/animate.wl:75` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `dynamical/src/animate.wl:77` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `dynamical/src/animate.wl:87` (export): `ExportGIF[frames, outGIF, frameRate];`
- `dynamical/src/animate.wl:131` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `dynamical/src/animate.wl:133` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `dynamical/src/animate.wl:143` (export): `ExportGIF[frames, outGIF, frameRate];`

#### fluid/src/animate.wl

- `fluid/src/animate.wl:24` (frame rate): `FluidGifRate[targetDuration_?NumericQ, nFrames_:$FluidGifFrameBudget] :=`
- `fluid/src/animate.wl:25` (frame rate): `Clip[nFrames / targetDuration, {$FluidMinGifFps, $FluidMaxGifFps}];`
- `fluid/src/animate.wl:61` (frame rate): `frameRate = FluidGifRate[targetDuration];`
- `fluid/src/animate.wl:62` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `fluid/src/animate.wl:73` (export): `ExportGIF[frames, outGIF, frameRate];`
- `fluid/src/animate.wl:137` (frame rate): `frameRate = FluidGifRate[targetDuration];`
- `fluid/src/animate.wl:138` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `fluid/src/animate.wl:149` (export): `ExportGIF[frames, outGIF, frameRate];`
- `fluid/src/animate.wl:217` (frame rate): `frameRate  = FluidGifRate[targetDuration];`
- `fluid/src/animate.wl:218` (frame count): `nFrames    = Max[2, Round[frameRate * targetDuration]];`
- `fluid/src/animate.wl:233` (export): `ExportGIF[frames, outGIF, frameRate];`

#### grover/src/animate.wl

- `grover/src/animate.wl:40` (frame rate): `GroverGifRate[targetDuration_?NumericQ, nFrames_:$GroverGifFrameBudget] :=`
- `grover/src/animate.wl:41` (frame rate): `Clip[nFrames / targetDuration, {$GroverMinGifFps, $GroverMaxGifFps}];`
- `grover/src/animate.wl:70` (frame rate): `frameRate = GroverGifRate[targetDuration];`
- `grover/src/animate.wl:71` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `grover/src/animate.wl:74` (export): `ExportGIF[frames, outGif, frameRate];`
- `grover/src/animate.wl:127` (frame rate): `frameRate = GroverGifRate[targetDuration];`
- `grover/src/animate.wl:128` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `grover/src/animate.wl:131` (export): `ExportGIF[frames, outGif, frameRate];`
- `grover/src/animate.wl:187` (frame rate): `frameRate = GroverGifRate[targetDuration];`
- `grover/src/animate.wl:188` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `grover/src/animate.wl:191` (export): `ExportGIF[frames, outGif, frameRate];`

#### henon/src/animate.wl

- `henon/src/animate.wl:45` (frame rate): `HenonGifRate[targetDuration_?NumericQ, nFrames_:$HenonGifFrameBudget] :=`
- `henon/src/animate.wl:46` (frame rate): `Clip[nFrames / targetDuration, {$HenonMinGifFps, $HenonMaxGifFps}];`
- `henon/src/animate.wl:100` (frame rate): `frameRate     = HenonGifRate[targetDuration, nFrames];`
- `henon/src/animate.wl:101` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `henon/src/animate.wl:108` (export): `ExportGIF[frames, filePath, frameRate];`
- `henon/src/animate.wl:181` (frame rate): `frameRate     = HenonGifRate[targetDuration, nFrames];`
- `henon/src/animate.wl:182` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `henon/src/animate.wl:190` (export): `ExportGIF[frames, filePath, frameRate];`

#### hydrogen/src/animate.wl

- `hydrogen/src/animate.wl:34` (frame rate): `HydrogenGifRate[targetDuration_?NumericQ, nFrames_:$HydrogenGifFrameBudget] :=`
- `hydrogen/src/animate.wl:35` (frame rate): `Clip[nFrames / targetDuration, {$HydrogenMinGifFps, $HydrogenMaxGifFps}];`
- `hydrogen/src/animate.wl:80` (frame rate): `frameRate  = HydrogenGifRate[targetDuration];`
- `hydrogen/src/animate.wl:81` (frame count): `nGIFFrames = Max[2, Round[frameRate * targetDuration]];`
- `hydrogen/src/animate.wl:96` (export): `ExportGIF[gifFrames, outGIF, frameRate];`
- `hydrogen/src/animate.wl:164` (frame rate): `frameRate  = HydrogenGifRate[targetDuration];`
- `hydrogen/src/animate.wl:165` (frame count): `nFrames    = Max[2, Round[frameRate * targetDuration]];`
- `hydrogen/src/animate.wl:171` (export): `ExportGIF[frames, outGIF, frameRate];`
- `hydrogen/src/animate.wl:232` (frame rate): `frameRate = HydrogenGifRate[targetDuration];`
- `hydrogen/src/animate.wl:233` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `hydrogen/src/animate.wl:239` (export): `ExportGIF[frames, outGIF, frameRate];`

#### images/src/animate.wl

- `images/src/animate.wl:20` (frame rate): `ImagesGifRate[targetDuration_?NumericQ, nFrames_:$ImagesGifFrameBudget] :=`
- `images/src/animate.wl:21` (frame rate): `Clip[nFrames / targetDuration, {$ImagesMinGifFps, $ImagesMaxGifFps}];`
- `images/src/animate.wl:40` (frame rate): `frameRate  = ImagesGifRate[targetDuration];`
- `images/src/animate.wl:41` (frame count): `nGIFFrames = Max[2, Round[frameRate * targetDuration]];`
- `images/src/animate.wl:59` (export): `ExportGIF[gifFrames, outGIF, frameRate];`
- `images/src/animate.wl:74` (frame rate): `frameRate  = ImagesGifRate[targetDuration];`
- `images/src/animate.wl:75` (frame count): `nGIFFrames = Max[2, Round[frameRate * targetDuration]];`
- `images/src/animate.wl:96` (export): `ExportGIF[gifFrames, outGIF, frameRate];`

#### lagrange/src/animate.wl

- `lagrange/src/animate.wl:88` (frame rate): `frameRate = Clip[nFrameBudget / targetDuration,`
- `lagrange/src/animate.wl:90` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `lagrange/src/animate.wl:99` (export): `ExportGIF[gifFrames, gifPath, frameRate];`
- `lagrange/src/animate.wl:145` (frame rate): `frameRate = Clip[nFrameBudget / targetDuration,`
- `lagrange/src/animate.wl:147` (frame count): `nFrames   = Max[2, Round[frameRate * targetDuration]];`
- `lagrange/src/animate.wl:156` (export): `ExportGIF[gifFrames, gifPath, frameRate];`

#### lorenz/src/animate.wl

- `lorenz/src/animate.wl:127` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `lorenz/src/animate.wl:129` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `lorenz/src/animate.wl:143` (export): `ExportGIF[frames, filePath, frameRate];`
- `lorenz/src/animate.wl:160` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `lorenz/src/animate.wl:162` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `lorenz/src/animate.wl:192` (export): `ExportGIF[frames, filePath, frameRate];`

#### magnetic/src/animate.wl

- `magnetic/src/animate.wl:29` (frame rate): `MagAnimationRate[targetDuration_?NumericQ] :=`
- `magnetic/src/animate.wl:30` (frame rate): `Clip[$MagFrameBudget / targetDuration, {$MagMinFps, $MagMaxFps}]`
- `magnetic/src/animate.wl:42` (frame rate): `frameRate = MagAnimationRate[targetDuration];`
- `magnetic/src/animate.wl:43` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `magnetic/src/animate.wl:88` (export): `ExportGIF[frames, outGif, frameRate];`
- `magnetic/src/animate.wl:101` (frame rate): `frameRate = MagAnimationRate[targetDuration];`
- `magnetic/src/animate.wl:102` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `magnetic/src/animate.wl:131` (export): `ExportGIF[frames, outGif, frameRate];`
- `magnetic/src/animate.wl:147` (frame rate): `frameRate = MagAnimationRate[targetDuration];`
- `magnetic/src/animate.wl:148` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `magnetic/src/animate.wl:188` (export): `ExportGIF[frames, outGif, frameRate];`
- `magnetic/src/animate.wl:201` (frame rate): `frameRate = MagAnimationRate[targetDuration];`
- `magnetic/src/animate.wl:202` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `magnetic/src/animate.wl:232` (export): `ExportGIF[frames, outGif, frameRate];`

#### mandelbrot/src/animate.wl

- `mandelbrot/src/animate.wl:252` (frame rate): `frameRate = Clip[nFrames / pacingDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `mandelbrot/src/animate.wl:253` (frame count): `actualNFrames = Max[2, Round[frameRate * pacingDuration]];`
- `mandelbrot/src/animate.wl:328` (export): `ExportGIF[gifFrames, outGIF, frameRate];`
- `mandelbrot/src/animate.wl:415` (frame rate): `frameRate = Clip[nFrames / pacingDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `mandelbrot/src/animate.wl:416` (frame count): `actualNFrames = Max[nLevels, Round[frameRate * pacingDuration]];`
- `mandelbrot/src/animate.wl:434` (export): `ExportGIF[gifFrames, outGIF, frameRate];`

#### montecarlo/src/animate.wl

- `montecarlo/src/animate.wl:70` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `montecarlo/src/animate.wl:72` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `montecarlo/src/animate.wl:90` (export): `ExportGIF[frames, outGIF, frameRate];`
- `montecarlo/src/animate.wl:103` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `montecarlo/src/animate.wl:105` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `montecarlo/src/animate.wl:118` (export): `ExportGIF[frames, outGIF, frameRate];`
- `montecarlo/src/animate.wl:131` (frame rate): `frameRate = Clip[nFrames / targetDuration,`
- `montecarlo/src/animate.wl:133` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `montecarlo/src/animate.wl:146` (export): `ExportGIF[frames, outGIF, frameRate];`

#### pendulum/src/animate.wl

- `pendulum/src/animate.wl:257` (frame rate): `frameRate = 25;`
- `pendulum/src/animate.wl:259` (frame count): `stride     = Max[1, Round[1.0 / (frameRate * dt)]];`
- `pendulum/src/animate.wl:302` (export): `ExportGIF[frames, outPath, frameRate];`
- `pendulum/src/animate.wl:326` (frame count): `stride = Max[1, Round[1.0 / (frameRate * dt * speedup)]];`
- `pendulum/src/animate.wl:360` (export): `ExportGIF[frames, filePath, frameRate];`

#### primes/src/animate.wl

- `primes/src/animate.wl:39` (frame rate): `fps    = GetCfg[cfg, {"animation","fps"},    12];`
- `primes/src/animate.wl:62` (export): `ExportGIF[{primePlot}, gifPath, fps];`
- `primes/src/animate.wl:130` (frame rate): `frameRate     = Clip[$GapsFrameBudget / targetDuration,`
- `primes/src/animate.wl:132` (frame count): `actualNFrames = Min[nGaps, Max[2, Round[frameRate * targetDuration]]];`
- `primes/src/animate.wl:192` (export): `ExportGIF[frames, gifPath, frameRate];`

#### quantum/src/animate.wl

- `quantum/src/animate.wl:61` (frame rate): `frameRate    = Clip[nt / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum/src/animate.wl:62` (frame count): `nFrames      = Max[2, Round[frameRate * targetDuration]];`
- `quantum/src/animate.wl:92` (export): `ExportGIF[frames, gifPath, frameRate];`

#### quantum_statistics/src/animate.wl

- `quantum_statistics/src/animate.wl:70` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_statistics/src/animate.wl:71` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_statistics/src/animate.wl:74` (export): `ExportGIF[frames, outGif, frameRate];`
- `quantum_statistics/src/animate.wl:132` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_statistics/src/animate.wl:133` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_statistics/src/animate.wl:136` (export): `ExportGIF[frames, outGif, frameRate];`
- `quantum_statistics/src/animate.wl:207` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_statistics/src/animate.wl:208` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_statistics/src/animate.wl:211` (export): `ExportGIF[frames, outGif, frameRate];`

#### quantum_tunnelling/src/animate.wl

- `quantum_tunnelling/src/animate.wl:114` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_tunnelling/src/animate.wl:115` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_tunnelling/src/animate.wl:118` (export): `ExportGIF[frames, outGif, frameRate];`
- `quantum_tunnelling/src/animate.wl:145` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_tunnelling/src/animate.wl:146` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_tunnelling/src/animate.wl:154` (export): `ExportGIF[frames, outGif, frameRate];`
- `quantum_tunnelling/src/animate.wl:192` (frame rate): `frameRate     = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `quantum_tunnelling/src/animate.wl:193` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `quantum_tunnelling/src/animate.wl:198` (export): `ExportGIF[frames, outGif, frameRate];`

#### qubit/src/animate.wl

- `qubit/src/animate.wl:86` (frame rate): `frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `qubit/src/animate.wl:87` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `qubit/src/animate.wl:94` (export): `ExportGIF[frames, filePath, frameRate];`

#### relativity/src/animate.wl

- `relativity/src/animate.wl:107` (frame rate): `fps     = Clip[nFramesBudget / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `relativity/src/animate.wl:108` (frame count): `nFrames = Max[2, Round[fps * targetDuration]];`
- `relativity/src/animate.wl:190` (export): `ExportGIF[frames, gifPath, fps];`
- `relativity/src/animate.wl:318` (frame rate): `fps           = Clip[nFramesBudget / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `relativity/src/animate.wl:319` (frame count): `nFrames       = Max[2, Round[fps * targetDuration]];`
- `relativity/src/animate.wl:357` (export): `ExportGIF[frames, gifPath, fps];`

#### resonance/src/animate.wl

- `resonance/src/animate.wl:97` (frame rate): `frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `resonance/src/animate.wl:98` (frame count): `actualNFrames = Max[2, Round[frameRate * targetDuration]];`
- `resonance/src/animate.wl:115` (export): `ExportGIF[frames, outGif, frameRate];`
- `resonance/src/animate.wl:162` (frame rate): `frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `resonance/src/animate.wl:166` (frame count): `actualNFrames = Min[model["nSteps"], Max[2, Round[frameRate * targetDuration]]];`
- `resonance/src/animate.wl:179` (export): `ExportGIF[frames, outGif, frameRate];`
- `resonance/src/animate.wl:228` (frame rate): `frameRate = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `resonance/src/animate.wl:229` (frame count): `actualNFrames = Min[model["nSteps"], Max[2, Round[frameRate * targetDuration]]];`
- `resonance/src/animate.wl:239` (export): `ExportGIF[frames, outGif, frameRate];`

#### scattering/src/animate.wl

- `scattering/src/animate.wl:30` (frame rate): `ScatAnimationRate[targetDuration_?NumericQ] :=`
- `scattering/src/animate.wl:31` (frame rate): `Clip[$ScatFrameBudget / targetDuration, {$ScatMinFps, $ScatMaxFps}]`
- `scattering/src/animate.wl:47` (frame rate): `frameRate = ScatAnimationRate[targetDuration];`
- `scattering/src/animate.wl:48` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `scattering/src/animate.wl:115` (export): `ExportGIF[frames, outGif, frameRate];`
- `scattering/src/animate.wl:127` (frame rate): `frameRate = ScatAnimationRate[targetDuration];`
- `scattering/src/animate.wl:128` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `scattering/src/animate.wl:161` (export): `ExportGIF[frames, outGif, frameRate];`
- `scattering/src/animate.wl:175` (frame rate): `frameRate = ScatAnimationRate[targetDuration];`
- `scattering/src/animate.wl:176` (frame count): `nFrames = Max[2, Round[frameRate * targetDuration]];`
- `scattering/src/animate.wl:205` (export): `ExportGIF[frames, outGif, frameRate];`

#### signal/src/animate.wl

- `signal/src/animate.wl:164` (frame rate): `fps       = Clip[GetCfg[cfg, {"animation","fps"}, 10],`
- `signal/src/animate.wl:166` (frame count): `nFrames   = Max[2, Round[fps * dur]];`
- `signal/src/animate.wl:234` (export): `ExportGIF[frames, gifPath, fps];`

#### thermo/src/animate.wl

- `thermo/src/animate.wl:32` (frame rate): `frameRate = Clip[n / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];`
- `thermo/src/animate.wl:33` (frame count): `desiredN  = Max[2, Round[frameRate * targetDuration]];`
- `thermo/src/animate.wl:39` (export): `ExportGIF[finalFrames, filePath, frameRate];`

#### waves/src/animate.wl

- `waves/src/animate.wl:39` (frame rate): `frameRateR  = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];` (two lines)
- `waves/src/animate.wl:41` (frame count): `nFramesR    = Max[2, Round[frameRateR * targetDuration]];`
- `waves/src/animate.wl:77` (export): `"DisplayDurations" -> ConstantArray[1.0 / frameRateR, nFramesR],`
- `waves/src/animate.wl:118` (frame rate): `frameRateI  = Clip[nFrames / targetDuration, {$MinAnimationFps, $MaxAnimationFps}];` (two lines)
- `waves/src/animate.wl:120` (frame count): `nFramesI    = Max[2, Round[frameRateI * targetDuration]];`
- `waves/src/animate.wl:156` (export): `"DisplayDurations" -> ConstantArray[1.0 / frameRateI, nFramesI],`

#### stem-core/src/export.wl

- `stem-core/src/export.wl:31` (export): `ExportGIF[frames_List, filePath_String, frameRate_:25] :=`
- `stem-core/src/export.wl:35` (export): `"DisplayDurations"     -> 1.0 / frameRate];`

## Part 2 — The shared helper and what changed

- New stem-core/src/export.wl function GIFFramePlan[audioDuration, desiredFps, opts] clamps the requested rate to 2–30 fps, rounds the frame delay to whole centiseconds, and then sets the frame count to Round[audioDuration / delay].
- GIFFramePlan returns the frame count, the delay in centiseconds and seconds, the actual frame rate, the GIF duration, the audio duration and their difference.
- GIFFramePlan options: "MinFrames"/"MaxFrames" bound the count and, when a bound applies, recompute the delay from the bounded count; "FrameCount" fixes the count for data-fixed frames (pendulum).
- ExportGIF[frames, path, plan] is the new export form; it writes the plan's delay on every frame and prints a warning line if the frame list length differs from the plan.
- The old ExportGIF[frames, path, fps] form is kept for compatibility and now rounds to whole centiseconds explicitly; no app calls it any more.
- All 71 GIF exports in the 32 apps now call ExportGIF with a plan, including the two in waves, which previously bypassed ExportGIF.
- The 24 copies of $MinAnimationFps/$MaxAnimationFps, the 7 per-app rate helpers and clt's AnimationFrameRate were removed or turned into thin wrappers that return a GIFFramePlan.
- New SyncWAVToGIF[gifPath, wavPath, opts] is called in every main.wl mode that writes a GIF, after both files exist (86 GIF/WAV pairs across the sweep).
- SyncWAVToGIF reads the frame delays from the GIF file (GIFFrameDelays) and the duration from the WAV header (WAVDuration).
- SyncWAVToGIF pads the WAV with silence to the GIF duration when the GIF is longer by more than one frame delay; padding is the existing project convention (tools/src/video_pipeline.wl PadAudioSilence), and audio is never trimmed.
- SyncWAVToGIF prints a warning sentence instead of padding when the audio is the longer file, or when the WAV has a spoken outro after the timed section.
- SyncWAVToGIF prints one sentence: "GIF/WAV sync: the GIF has N frames of D s each and plays for G s, the WAV plays for W s, and the GIF is X s longer than the WAV."
- For clt, quantum_tunnelling, resonance and scattering, whose GIFs were deliberately timed in v1.5.1 to the sonified section after the spoken intro, SyncWAVToGIF takes "IntroSeconds" (and "OutroSeconds" for quantum_tunnelling barrier and scattering discovery) and the sentence names that section.
- The "matching audio duration" console line was removed from every app; the pre-render line now reads "Rendering N frames at F fps (D s per frame, G s in total)."
- Padding was triggered in 0 of the 86 pairs, because after the fix every pair already agreed within one frame delay.
- Found and fixed during verification: resonance galilean timed its GIF to the 32 s orbit body but its audio has a 1.0 s release tail after it; the GIF was 1.08 s short, and it now holds the last frame through the tail (GalileanBodyDurationSec).
- Behaviour change: primes ulam's still GIF is now held for the 10 s scan audio instead of 0.08 s, the same treatment v1.5.1 gave cellular's Rule 110 still.
- Behaviour change: primes gaps now times its GIF to the WAV's real length, 30 s of onsets plus the 0.08 s last-tone tail.
- Behaviour change: clt now samples N = 1..nMax at the planned frame count; at the default 0.2 s frame_duration this is exactly 1..nMax, so default output is unchanged.
- New helper FmtDec[x, 3] in stem-core/src/utils.wl prints at most three decimals without trailing zeros.
- New test file stem-core/tests/test_gifsync.wl covers the plan arithmetic, the file readers against Import, padding, the no-trim rule, and intro/outro handling.

## Part 3 — Verification

### Commands

- Baseline worktree: `git worktree add --detach <scratchpad>/base HEAD` (HEAD = e08170b).
- Sweep runner, for each app and mode below: `wolframscript -file <app>/main.wl -- --simulation.mode=<mode> [--simulation.dynamical.preset=<name>]`, run from the repository root, once in the baseline worktree and once in the working tree.
- After each run the runner copied every GIF and WAV newer than the run's start into a per-run folder, so presets that share file names were measured separately.
- Measurement: `wolframscript -file measure.wl <sweepDir> <out.tsv>`, which pairs each GIF with its WAV by name and measures both with Import as described above.
- Test suites: `wolframscript -file <app>/tests/test_*.wl` for all 32 test files present, and `wolframscript -file stem-core/tests/test_gifsync.wl`.
- Demo: `wolframscript -file demo.wl`, then `wolframscript -file demo.wl -- --check-only`.
- There is no checked-in script for the v1.5.1 regression sweep; the commits bfde133 and e623bf9 describe it as every app's GIF/WAV pair measured from the files plus every test suite, which is what the sweep below does, across every mode of every app plus the dynamical presets (94 runs).
- asteroids used the live NASA NeoWs API (NASA_API_KEY was set) for the default 7-day range, which was 2026-09-17 to 2026-09-23 on both runs.

### Targeted runs: default mode of every app whose GIF rate was not a whole number of centiseconds

- Default-mode runs in this group: 19.
- cosmology's default mode (spectrum) writes no GIF; its GIF mode is sky, which is covered in the full sweep below.

#### bayes coin — coin.gif
- Command: `wolframscript -file bayes/main.wl -- --simulation.mode=coin`
- Frame rate the app requested before the fix: 4.1559 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (coin_audio.wav): 36.093 s
- Before, difference: -0.093 s
- After, frame count: 150
- After, frame delay: 0.24 s
- After, GIF duration: 36.000 s
- After, WAV duration (coin_audio.wav): 36.093 s
- After, difference: -0.093 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.24 s each and plays for 36 s, the WAV plays for 36.093 s, and the GIF is 0.093 s shorter than the WAV.`

#### bell correlations — bell_correlations.gif
- Command: `wolframscript -file bell/main.wl -- --simulation.mode=correlations`
- Frame rate the app requested before the fix: 6.25012 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.16 s
- Before, GIF duration: 24.000 s
- Before, WAV duration (bell_correlations.wav): 24.000 s
- Before, difference: +0.000 s
- After, frame count: 150
- After, frame delay: 0.16 s
- After, GIF duration: 24.000 s
- After, WAV duration (bell_correlations.wav): 24.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.16 s each and plays for 24 s, the WAV plays for 24 s, and the GIF and the WAV have the same duration to the millisecond.`

#### blackbody spectrum — spectrum.gif
- Command: `wolframscript -file blackbody/main.wl -- --simulation.mode=spectrum`
- Frame rate the app requested before the fix: 3.52607 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.28 s
- Before, GIF duration: 42.000 s
- Before, WAV duration (spectrum_audio.wav): 42.540 s
- Before, difference: -0.540 s
- After, frame count: 152
- After, frame delay: 0.28 s
- After, GIF duration: 42.560 s
- After, WAV duration (spectrum_audio.wav): 42.540 s
- After, difference: +0.020 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.28 s each and plays for 42.56 s, the WAV plays for 42.54 s, and the GIF is 0.02 s longer than the WAV.`

#### brownian walk — brownian_walk.gif
- Command: `wolframscript -file brownian/main.wl -- --simulation.mode=walk`
- Frame rate the app requested before the fix: 3.93998 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.25 s
- Before, GIF duration: 37.500 s
- Before, WAV duration (brownian_walk.wav): 38.071 s
- Before, difference: -0.571 s
- After, frame count: 152
- After, frame delay: 0.25 s
- After, GIF duration: 38.000 s
- After, WAV duration (brownian_walk.wav): 38.071 s
- After, difference: -0.071 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.25 s each and plays for 38 s, the WAV plays for 38.071 s, and the GIF is 0.071 s shorter than the WAV.`

#### fluid karman — karman.gif
- Command: `wolframscript -file fluid/main.wl -- --simulation.mode=karman`
- Frame rate the app requested before the fix: 3.28616 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.30 s
- Before, GIF duration: 45.000 s
- Before, WAV duration (karman_audio.wav): 45.646 s
- Before, difference: -0.646 s
- After, frame count: 152
- After, frame delay: 0.30 s
- After, GIF duration: 45.600 s
- After, WAV duration (karman_audio.wav): 45.646 s
- After, difference: -0.046 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.3 s each and plays for 45.6 s, the WAV plays for 45.646 s, and the GIF is 0.046 s shorter than the WAV.`

#### grover search — grover_search.gif
- Command: `wolframscript -file grover/main.wl -- --simulation.mode=search`
- Frame rate the app requested before the fix: 8.03543 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.12 s
- Before, GIF duration: 18.000 s
- Before, WAV duration (grover_search.wav): 18.667 s
- Before, difference: -0.667 s
- After, frame count: 156
- After, frame delay: 0.12 s
- After, GIF duration: 18.720 s
- After, WAV duration (grover_search.wav): 18.667 s
- After, difference: +0.053 s
- App's sync line: `GIF/WAV sync: the GIF has 156 frames of 0.12 s each and plays for 18.72 s, the WAV plays for 18.667 s, and the GIF is 0.053 s longer than the WAV.`

#### henon attractor — henon_attractor.gif
- Command: `wolframscript -file henon/main.wl -- --simulation.mode=attractor`
- Frame rate the app requested before the fix: 5.25108 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.19 s
- Before, GIF duration: 28.500 s
- Before, WAV duration (henon_attractor.wav): 28.566 s
- Before, difference: -0.066 s
- After, frame count: 150
- After, frame delay: 0.19 s
- After, GIF duration: 28.500 s
- After, WAV duration (henon_attractor.wav): 28.566 s
- After, difference: -0.066 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.19 s each and plays for 28.5 s, the WAV plays for 28.566 s, and the GIF is 0.066 s shorter than the WAV.`

#### lagrange l4 — l4.gif
- Command: `wolframscript -file lagrange/main.wl -- --simulation.mode=l4`
- Frame rate the app requested before the fix: 7.95775 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.13 s
- Before, GIF duration: 19.500 s
- Before, WAV duration (l4_audio.wav): 18.849 s
- Before, difference: +0.651 s
- After, frame count: 145
- After, frame delay: 0.13 s
- After, GIF duration: 18.850 s
- After, WAV duration (l4_audio.wav): 18.849 s
- After, difference: +0.001 s
- App's sync line: `GIF/WAV sync: the GIF has 145 frames of 0.13 s each and plays for 18.85 s, the WAV plays for 18.85 s, and the GIF and the WAV have the same duration to the millisecond.`

#### lorenz lorenz — lorenz_animation.gif
- Command: `wolframscript -file lorenz/main.wl -- --simulation.mode=lorenz`
- Frame rate the app requested before the fix: 3.75 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.27 s
- Before, GIF duration: 40.500 s
- Before, WAV duration (lorenz_audio.wav): 40.000 s
- Before, difference: +0.500 s
- After, frame count: 148
- After, frame delay: 0.27 s
- After, GIF duration: 39.960 s
- After, WAV duration (lorenz_audio.wav): 40.000 s
- After, difference: -0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.27 s each and plays for 39.96 s, the WAV plays for 40 s, and the GIF is 0.04 s shorter than the WAV.`

#### magnetic cyclotron — cyclotron.gif
- Command: `wolframscript -file magnetic/main.wl -- --simulation.mode=cyclotron`
- Frame rate the app requested before the fix: 2.8532 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.35 s
- Before, GIF duration: 52.500 s
- Before, WAV duration (cyclotron_audio.wav): 52.573 s
- Before, difference: -0.073 s
- After, frame count: 150
- After, frame delay: 0.35 s
- After, GIF duration: 52.500 s
- After, WAV duration (cyclotron_audio.wav): 52.573 s
- After, difference: -0.073 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.35 s each and plays for 52.5 s, the WAV plays for 52.573 s, and the GIF is 0.073 s shorter than the WAV.`

#### primes ulam — ulam_spiral.gif
- Command: `wolframscript -file primes/main.wl -- --simulation.mode=ulam`
- Frame rate the app requested before the fix: 12 fps (not a whole number of centiseconds).
- Before, frame count: 1
- Before, frame delay: 0.08 s
- Before, GIF duration: 0.080 s
- Before, WAV duration (ulam_audio.wav): 10.000 s
- Before, difference: -9.920 s
- After, frame count: 1
- After, frame delay: 10.00 s
- After, GIF duration: 10.000 s
- After, WAV duration (ulam_audio.wav): 10.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 1 frame of 10 s and plays for 10 s, the WAV plays for 10 s, and the GIF and the WAV have the same duration to the millisecond.`

#### quantum qho — qho_density.gif
- Command: `wolframscript -file quantum/main.wl -- --simulation.mode=qho`
- Frame rate the app requested before the fix: 20.0797 fps (not a whole number of centiseconds).
- Before, frame count: 252
- Before, frame delay: 0.05 s
- Before, GIF duration: 12.600 s
- Before, WAV duration (qho_audio.wav): 12.550 s
- Before, difference: +0.050 s
- After, frame count: 251
- After, frame delay: 0.05 s
- After, GIF duration: 12.550 s
- After, WAV duration (qho_audio.wav): 12.550 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 251 frames of 0.05 s each and plays for 12.55 s, the WAV plays for 12.55 s, and the GIF and the WAV have the same duration to the millisecond.`

#### quantum_tunnelling barrier — barrier.gif
- Command: `wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=barrier`
- Frame rate the app requested before the fix: 15.6863 fps (not a whole number of centiseconds).
- Before, frame count: 40
- Before, frame delay: 0.06 s
- Before, GIF duration: 2.400 s
- Before, WAV duration (barrier_audio.wav): 47.233 s
- Before, difference: -44.833 s
- After, frame count: 43
- After, frame delay: 0.06 s
- After, GIF duration: 2.580 s
- After, WAV duration (barrier_audio.wav): 47.233 s
- After, difference: -44.653 s
- Spoken intro before the timed section, reported by the app: 30.026 s
- Spoken outro after the timed section, reported by the app: 14.657 s
- Timed section of the WAV (file duration minus intro and outro): 2.550 s
- After, difference against the timed section: +0.030 s
- App's sync line: `GIF/WAV sync: the GIF has 43 frames of 0.06 s each and plays for 2.58 s, the WAV plays for 47.233 s, of which the part between the 30.026 s spoken intro and the 14.657 s spoken outro lasts 2.55 s, and the GIF is 0.03 s longer than that part.`

#### qubit gates — qubit_gates.gif
- Command: `wolframscript -file qubit/main.wl -- --simulation.mode=gates`
- Frame rate the app requested before the fix: 3.26475 fps (not a whole number of centiseconds).
- Before, frame count: 80
- Before, frame delay: 0.31 s
- Before, GIF duration: 24.800 s
- Before, WAV duration (qubit_gates.wav): 24.504 s
- Before, difference: +0.296 s
- After, frame count: 79
- After, frame delay: 0.31 s
- After, GIF duration: 24.490 s
- After, WAV duration (qubit_gates.wav): 24.504 s
- After, difference: -0.014 s
- App's sync line: `GIF/WAV sync: the GIF has 79 frames of 0.31 s each and plays for 24.49 s, the WAV plays for 24.504 s, and the GIF is 0.014 s shorter than the WAV.`

#### relativity chirp — chirp.gif
- Command: `wolframscript -file relativity/main.wl -- --simulation.mode=chirp`
- Frame rate the app requested before the fix: 16.7594 fps (not a whole number of centiseconds).
- Before, frame count: 60
- Before, frame delay: 0.06 s
- Before, GIF duration: 3.600 s
- Before, WAV duration (chirp.wav): 3.580 s
- Before, difference: +0.020 s
- After, frame count: 60
- After, frame delay: 0.06 s
- After, GIF duration: 3.600 s
- After, WAV duration (chirp.wav): 3.580 s
- After, difference: +0.020 s
- App's sync line: `GIF/WAV sync: the GIF has 60 frames of 0.06 s each and plays for 3.6 s, the WAV plays for 3.58 s, and the GIF is 0.02 s longer than the WAV.`

#### resonance galilean — galilean.gif
- Command: `wolframscript -file resonance/main.wl -- --simulation.mode=galilean`
- Frame rate the app requested before the fix: 4.6875 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.21 s
- Before, GIF duration: 31.500 s
- Before, WAV duration (galilean_audio.wav): 57.022 s
- Before, difference: -25.522 s
- After, frame count: 150
- After, frame delay: 0.22 s
- After, GIF duration: 33.000 s
- After, WAV duration (galilean_audio.wav): 57.022 s
- After, difference: -24.022 s
- Spoken intro before the timed section, reported by the app: 24.022 s
- Timed section of the WAV (file duration minus intro): 33.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.22 s each and plays for 33 s, the WAV plays for 57.022 s, of which the part after the 24.022 s spoken intro lasts 33 s, and the GIF and that part have the same duration to the millisecond.`

#### scattering scatter — scatter.gif
- Command: `wolframscript -file scattering/main.wl -- --simulation.mode=scatter`
- Frame rate the app requested before the fix: 7.5 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.13 s
- Before, GIF duration: 19.500 s
- Before, WAV duration (scatter_audio.wav): 40.550 s
- Before, difference: -21.050 s
- After, frame count: 154
- After, frame delay: 0.13 s
- After, GIF duration: 20.020 s
- After, WAV duration (scatter_audio.wav): 40.550 s
- After, difference: -20.530 s
- Spoken intro before the timed section, reported by the app: 20.550 s
- Timed section of the WAV (file duration minus intro): 20.000 s
- After, difference against the timed section: +0.020 s
- App's sync line: `GIF/WAV sync: the GIF has 154 frames of 0.13 s each and plays for 20.02 s, the WAV plays for 40.55 s, of which the part after the 20.55 s spoken intro lasts 20 s, and the GIF is 0.02 s longer than that part.`

#### thermo distribution — distribution.gif
- Command: `wolframscript -file thermo/main.wl -- --simulation.mode=distribution`
- Frame rate the app requested before the fix: 3.20299 fps (not a whole number of centiseconds).
- Before, frame count: 100
- Before, frame delay: 0.31 s
- Before, GIF duration: 31.000 s
- Before, WAV duration (distribution_audio.wav): 31.221 s
- Before, difference: -0.221 s
- After, frame count: 101
- After, frame delay: 0.31 s
- After, GIF duration: 31.310 s
- After, WAV duration (distribution_audio.wav): 31.221 s
- After, difference: +0.089 s
- App's sync line: `GIF/WAV sync: the GIF has 101 frames of 0.31 s each and plays for 31.31 s, the WAV plays for 31.221 s, and the GIF is 0.089 s longer than the WAV.`

#### waves ripple — ripple.gif
- Command: `wolframscript -file waves/main.wl -- --simulation.mode=ripple`
- Frame rate the app requested before the fix: 7.5 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.13 s
- Before, GIF duration: 19.500 s
- Before, WAV duration (ripple_audio.wav): 20.000 s
- Before, difference: -0.500 s
- After, frame count: 154
- After, frame delay: 0.13 s
- After, GIF duration: 20.020 s
- After, WAV duration (ripple_audio.wav): 20.000 s
- After, difference: +0.020 s
- App's sync line: `GIF/WAV sync: the GIF has 154 frames of 0.13 s each and plays for 20.02 s, the WAV plays for 20 s, and the GIF is 0.02 s longer than the WAV.`

### dynamical, both modes and the five iterate presets

#### dynamical sweep — sweep.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 688
- Before, frame delay: 0.50 s
- Before, GIF duration: 344.000 s
- Before, WAV duration (sweep_audio.wav): 344.112 s
- Before, difference: -0.112 s
- After, frame count: 688
- After, frame delay: 0.50 s
- After, GIF duration: 344.000 s
- After, WAV duration (sweep_audio.wav): 344.112 s
- After, difference: -0.112 s
- App's sync line: `GIF/WAV sync: the GIF has 688 frames of 0.5 s each and plays for 344 s, the WAV plays for 344.112 s, and the GIF is 0.112 s shorter than the WAV.`

#### dynamical iterate — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate`
- Frame rate the app requested before the fix: 4.60783 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.22 s
- Before, GIF duration: 33.000 s
- Before, WAV duration (iterate_audio.wav): 32.553 s
- Before, difference: +0.447 s
- After, frame count: 148
- After, frame delay: 0.22 s
- After, GIF duration: 32.560 s
- After, WAV duration (iterate_audio.wav): 32.553 s
- After, difference: +0.007 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.22 s each and plays for 32.56 s, the WAV plays for 32.553 s, and the GIF is 0.007 s longer than the WAV.`

#### dynamical iterate fixed_point — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=fixed_point`
- Frame rate the app requested before the fix: 4.19354 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (iterate_audio.wav): 35.769 s
- Before, difference: +0.231 s
- After, frame count: 149
- After, frame delay: 0.24 s
- After, GIF duration: 35.760 s
- After, WAV duration (iterate_audio.wav): 35.769 s
- After, difference: -0.009 s
- App's sync line: `GIF/WAV sync: the GIF has 149 frames of 0.24 s each and plays for 35.76 s, the WAV plays for 35.769 s, and the GIF is 0.009 s shorter than the WAV.`

#### dynamical iterate period2 — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period2`
- Frame rate the app requested before the fix: 4.15043 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (iterate_audio.wav): 36.141 s
- Before, difference: -0.141 s
- After, frame count: 151
- After, frame delay: 0.24 s
- After, GIF duration: 36.240 s
- After, WAV duration (iterate_audio.wav): 36.141 s
- After, difference: +0.099 s
- App's sync line: `GIF/WAV sync: the GIF has 151 frames of 0.24 s each and plays for 36.24 s, the WAV plays for 36.141 s, and the GIF is 0.099 s longer than the WAV.`

#### dynamical iterate period4 — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period4`
- Frame rate the app requested before the fix: 4.21957 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (iterate_audio.wav): 35.549 s
- Before, difference: +0.451 s
- After, frame count: 148
- After, frame delay: 0.24 s
- After, GIF duration: 35.520 s
- After, WAV duration (iterate_audio.wav): 35.549 s
- After, difference: -0.029 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.24 s each and plays for 35.52 s, the WAV plays for 35.549 s, and the GIF is 0.029 s shorter than the WAV.`

#### dynamical iterate period3_window — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=period3_window`
- Frame rate the app requested before the fix: 4.11475 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (iterate_audio.wav): 36.454 s
- Before, difference: -0.454 s
- After, frame count: 152
- After, frame delay: 0.24 s
- After, GIF duration: 36.480 s
- After, WAV duration (iterate_audio.wav): 36.454 s
- After, difference: +0.026 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.24 s each and plays for 36.48 s, the WAV plays for 36.454 s, and the GIF is 0.026 s longer than the WAV.`

#### dynamical iterate chaos — iterate.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=iterate --simulation.dynamical.preset=chaos`
- Frame rate the app requested before the fix: 4.30534 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.23 s
- Before, GIF duration: 34.500 s
- Before, WAV duration (iterate_audio.wav): 34.840 s
- Before, difference: -0.340 s
- After, frame count: 151
- After, frame delay: 0.23 s
- After, GIF duration: 34.730 s
- After, WAV duration (iterate_audio.wav): 34.840 s
- After, difference: -0.111 s
- App's sync line: `GIF/WAV sync: the GIF has 151 frames of 0.23 s each and plays for 34.73 s, the WAV plays for 34.84 s, and the GIF is 0.11 s shorter than the WAV.`


### Round-rate apps: identical to before

#### dynamical sweep — sweep.gif
- Command: `wolframscript -file dynamical/main.wl -- --simulation.mode=sweep`
- Frame count before: 688
- Frame count after: 688
- Frame delay before: 0.50 s
- Frame delay after: 0.50 s
- GIF duration before: 344.000 s
- GIF duration after: 344.000 s
- GIF file byte-identical to before: yes
- Frame count and duration unchanged: yes

#### pendulum simple — simple_animation.gif
- Command: `wolframscript -file pendulum/main.wl -- --simulation.mode=simple`
- Frame count before: 501
- Frame count after: 501
- Frame delay before: 0.04 s
- Frame delay after: 0.04 s
- GIF duration before: 20.040 s
- GIF duration after: 20.040 s
- GIF file byte-identical to before: yes
- Frame count and duration unchanged: yes

#### pendulum double — double_animation.gif
- Command: `wolframscript -file pendulum/main.wl -- --simulation.mode=double`
- Frame count before: 501
- Frame count after: 501
- Frame delay before: 0.04 s
- Frame delay after: 0.04 s
- GIF duration before: 20.040 s
- GIF duration after: 20.040 s
- GIF file byte-identical to before: yes
- Frame count and duration unchanged: yes

#### cellular life — life_rpentomino_animation.gif
- Command: `wolframscript -file cellular/main.wl -- --simulation.mode=life`
- Frame count before: 300
- Frame count after: 300
- Frame delay before: 0.06 s
- Frame delay after: 0.06 s
- GIF duration before: 18.000 s
- GIF duration after: 18.000 s
- GIF file byte-identical to before: yes
- Frame count and duration unchanged: yes

#### signal chord — chord_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=chord`
- Frame count before: 30
- Frame count after: 30
- Frame delay before: 0.10 s
- Frame delay after: 0.10 s
- GIF duration before: 3.000 s
- GIF duration after: 3.000 s
- GIF file byte-identical to before: no
- Why the bytes differ: signal's noise is unseeded (RandomVariate in signal/src/model.wl), so its noisy WAV and the frames drawn from it differ on every run; its clean WAV is byte-identical before and after.
- Frame count and duration unchanged: yes

#### signal sweep — sweep_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=sweep`
- Frame count before: 40
- Frame count after: 40
- Frame delay before: 0.10 s
- Frame delay after: 0.10 s
- GIF duration before: 4.000 s
- GIF duration after: 4.000 s
- GIF file byte-identical to before: no
- Why the bytes differ: signal's noise is unseeded (RandomVariate in signal/src/model.wl), so its noisy WAV and the frames drawn from it differ on every run; its clean WAV is byte-identical before and after.
- Frame count and duration unchanged: yes

#### signal am — am_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=am`
- Frame count before: 30
- Frame count after: 30
- Frame delay before: 0.10 s
- Frame delay after: 0.10 s
- GIF duration before: 3.000 s
- GIF duration after: 3.000 s
- GIF file byte-identical to before: no
- Why the bytes differ: signal's noise is unseeded (RandomVariate in signal/src/model.wl), so its noisy WAV and the frames drawn from it differ on every run; its clean WAV is byte-identical before and after.
- Frame count and duration unchanged: yes

#### cellular rule110 — rule110_animation.gif
- Command: `wolframscript -file cellular/main.wl -- --simulation.mode=rule110`
- Frame count before: 1
- Frame count after: 1
- Frame delay before: 20.00 s
- Frame delay after: 20.00 s
- GIF duration before: 20.000 s
- GIF duration after: 20.000 s
- GIF file byte-identical to before: yes
- Frame count and duration unchanged: yes

### Full regression sweep: every app and mode (94 runs)

- Runs: 94.
- Runs with a non-zero exit code: 0.
- Runs whose console log contains a Wolfram message (`::`): 0.
- The same count for the baseline runs: 0.
- GIF/WAV pairs measured: 86.
- resonance galilean, cellular rule110 and primes ulam were run a second time after the last two code changes (the galilean tail fix and the "1 frame" wording); their rows come from that second run.
- Pairs within half a frame delay of the audio they are timed to: 84 of 86.
- The 2 pairs outside half a frame delay are pendulum simple and double, each exactly one 0.04 s frame longer than the WAV, as before; the pendulum frame count is fixed by its 25 fps sampling and was deliberately left unchanged.
- Pairs within one frame delay: 86 of 86.
- Pairs within one centisecond: 26 of 86.
- Baseline pairs that were more than one frame delay off: 36 of 86.
- Baseline pairs within one centisecond: 11 of 86.
- Largest absolute difference after the fix: 0.240 s (images colour, at a 0.5 s frame delay).
- Largest absolute difference before the fix, excluding primes ulam: 1.500 s (resonance galilean, against the section after its intro).
- primes ulam before the fix: its one still frame played for 0.080 s against a 10.000 s WAV.
- Modes that write no GIF, so have no sync result: bell measurement, brownian ensemble, brownian temperature, compton discovery, cosmology spectrum, henon reverse, qubit measurement, qubit rabi.

Per-app sync results, one pair per block:

- bayes coin: see the targeted or dynamical runs above.
#### bayes gaussian — gaussian.gif
- Command: `wolframscript -file bayes/main.wl -- --simulation.mode=gaussian`
- Frame rate the app requested before the fix: 4.18471 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.24 s
- Before, GIF duration: 36.000 s
- Before, WAV duration (gaussian_audio.wav): 35.845 s
- Before, difference: +0.155 s
- After, frame count: 149
- After, frame delay: 0.24 s
- After, GIF duration: 35.760 s
- After, WAV duration (gaussian_audio.wav): 35.845 s
- After, difference: -0.085 s
- App's sync line: `GIF/WAV sync: the GIF has 149 frames of 0.24 s each and plays for 35.76 s, the WAV plays for 35.845 s, and the GIF is 0.085 s shorter than the WAV.`

#### bayes model — model.gif
- Command: `wolframscript -file bayes/main.wl -- --simulation.mode=model`
- Frame rate the app requested before the fix: 3.75381 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.27 s
- Before, GIF duration: 40.500 s
- Before, WAV duration (model_audio.wav): 39.959 s
- Before, difference: +0.541 s
- After, frame count: 148
- After, frame delay: 0.27 s
- After, GIF duration: 39.960 s
- After, WAV duration (model_audio.wav): 39.959 s
- After, difference: +0.001 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.27 s each and plays for 39.96 s, the WAV plays for 39.959 s, and the GIF is 0.001 s longer than the WAV.`

#### bell chsh — bell_chsh.gif
- Command: `wolframscript -file bell/main.wl -- --simulation.mode=chsh`
- Frame rate the app requested before the fix: 7.87995 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.13 s
- Before, GIF duration: 19.500 s
- Before, WAV duration (bell_chsh.wav): 19.036 s
- Before, difference: +0.464 s
- After, frame count: 146
- After, frame delay: 0.13 s
- After, GIF duration: 18.980 s
- After, WAV duration (bell_chsh.wav): 19.036 s
- After, difference: -0.056 s
- App's sync line: `GIF/WAV sync: the GIF has 146 frames of 0.13 s each and plays for 18.98 s, the WAV plays for 19.036 s, and the GIF is 0.056 s shorter than the WAV.`

- bell correlations: see the targeted or dynamical runs above.
- blackbody spectrum: see the targeted or dynamical runs above.
#### blackbody star — star.gif
- Command: `wolframscript -file blackbody/main.wl -- --simulation.mode=star`
- Frame rate the app requested before the fix: 9.93199 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.10 s
- Before, GIF duration: 15.000 s
- Before, WAV duration (star_audio.wav): 15.103 s
- Before, difference: -0.103 s
- After, frame count: 151
- After, frame delay: 0.10 s
- After, GIF duration: 15.100 s
- After, WAV duration (star_audio.wav): 15.103 s
- After, difference: -0.003 s
- App's sync line: `GIF/WAV sync: the GIF has 151 frames of 0.1 s each and plays for 15.1 s, the WAV plays for 15.103 s, and the GIF is 0.003 s shorter than the WAV.`

#### blackbody temperature — temperature.gif
- Command: `wolframscript -file blackbody/main.wl -- --simulation.mode=temperature`
- Frame rate the app requested before the fix: 4.61255 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.22 s
- Before, GIF duration: 33.000 s
- Before, WAV duration (temperature_audio.wav): 32.520 s
- Before, difference: +0.480 s
- After, frame count: 148
- After, frame delay: 0.22 s
- After, GIF duration: 32.560 s
- After, WAV duration (temperature_audio.wav): 32.520 s
- After, difference: +0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.22 s each and plays for 32.56 s, the WAV plays for 32.52 s, and the GIF is 0.04 s longer than the WAV.`

- brownian walk: see the targeted or dynamical runs above.
#### cellular life — life_rpentomino_animation.gif
- Command: `wolframscript -file cellular/main.wl -- --simulation.mode=life`
- Frame rate the app requested before the fix: 16.6667 fps (a whole number of centiseconds).
- Before, frame count: 300
- Before, frame delay: 0.06 s
- Before, GIF duration: 18.000 s
- Before, WAV duration (life_rpentomino_audio.wav): 18.000 s
- Before, difference: +0.000 s
- After, frame count: 300
- After, frame delay: 0.06 s
- After, GIF duration: 18.000 s
- After, WAV duration (life_rpentomino_audio.wav): 18.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 300 frames of 0.06 s each and plays for 18 s, the WAV plays for 18 s, and the GIF and the WAV have the same duration to the millisecond.`

#### cellular rule110 — rule110_animation.gif
- Command: `wolframscript -file cellular/main.wl -- --simulation.mode=rule110`
- Frame rate the app requested before the fix: 0.05 fps (a whole number of centiseconds).
- Before, frame count: 1
- Before, frame delay: 20.00 s
- Before, GIF duration: 20.000 s
- Before, WAV duration (rule110_audio.wav): 20.000 s
- Before, difference: +0.000 s
- After, frame count: 1
- After, frame delay: 20.00 s
- After, GIF duration: 20.000 s
- After, WAV duration (rule110_audio.wav): 20.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 1 frame of 20 s and plays for 20 s, the WAV plays for 20 s, and the GIF and the WAV have the same duration to the millisecond.`

#### clt sweep — sweep.gif
- Command: `wolframscript -file clt/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 5 fps (a whole number of centiseconds).
- Before, frame count: 30
- Before, frame delay: 0.20 s
- Before, GIF duration: 6.000 s
- Before, WAV duration (sweep_audio.wav): 23.781 s
- Before, difference: -17.781 s
- After, frame count: 30
- After, frame delay: 0.20 s
- After, GIF duration: 6.000 s
- After, WAV duration (sweep_audio.wav): 23.781 s
- After, difference: -17.781 s
- Spoken intro before the timed section, reported by the app: 17.781 s
- Timed section of the WAV (file duration minus intro): 6.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 30 frames of 0.2 s each and plays for 6 s, the WAV plays for 23.781 s, of which the part after the 17.781 s spoken intro lasts 6 s, and the GIF and that part have the same duration to the millisecond.`

#### clt compare — compare.gif
- Command: `wolframscript -file clt/main.wl -- --simulation.mode=compare`
- Frame rate the app requested before the fix: 5 fps (a whole number of centiseconds).
- Before, frame count: 30
- Before, frame delay: 0.20 s
- Before, GIF duration: 6.000 s
- Before, WAV duration (compare_audio.wav): 26.624 s
- Before, difference: -20.624 s
- After, frame count: 30
- After, frame delay: 0.20 s
- After, GIF duration: 6.000 s
- After, WAV duration (compare_audio.wav): 26.624 s
- After, difference: -20.624 s
- Spoken intro before the timed section, reported by the app: 20.624 s
- Timed section of the WAV (file duration minus intro): 6.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 30 frames of 0.2 s each and plays for 6 s, the WAV plays for 26.624 s, of which the part after the 20.624 s spoken intro lasts 6 s, and the GIF and that part have the same duration to the millisecond.`

#### clt dice — dice.gif
- Command: `wolframscript -file clt/main.wl -- --simulation.mode=dice`
- Frame rate the app requested before the fix: 5 fps (a whole number of centiseconds).
- Before, frame count: 10
- Before, frame delay: 0.20 s
- Before, GIF duration: 2.000 s
- Before, WAV duration (dice_audio.wav): 24.320 s
- Before, difference: -22.320 s
- After, frame count: 10
- After, frame delay: 0.20 s
- After, GIF duration: 2.000 s
- After, WAV duration (dice_audio.wav): 24.320 s
- After, difference: -22.320 s
- Spoken intro before the timed section, reported by the app: 22.320 s
- Timed section of the WAV (file duration minus intro): 2.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 10 frames of 0.2 s each and plays for 2 s, the WAV plays for 24.32 s, of which the part after the 22.32 s spoken intro lasts 2 s, and the GIF and that part have the same duration to the millisecond.`

#### compton scatter — scatter.gif
- Command: `wolframscript -file compton/main.wl -- --simulation.mode=scatter`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 78
- Before, frame delay: 0.50 s
- Before, GIF duration: 39.000 s
- Before, WAV duration (scatter_audio.wav): 39.115 s
- Before, difference: -0.115 s
- After, frame count: 78
- After, frame delay: 0.50 s
- After, GIF duration: 39.000 s
- After, WAV duration (scatter_audio.wav): 39.115 s
- After, difference: -0.115 s
- App's sync line: `GIF/WAV sync: the GIF has 78 frames of 0.5 s each and plays for 39 s, the WAV plays for 39.115 s, and the GIF is 0.115 s shorter than the WAV.`

#### compton sweep — sweep.gif
- Command: `wolframscript -file compton/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 44
- Before, frame delay: 0.50 s
- Before, GIF duration: 22.000 s
- Before, WAV duration (sweep_audio.wav): 22.093 s
- Before, difference: -0.093 s
- After, frame count: 44
- After, frame delay: 0.50 s
- After, GIF duration: 22.000 s
- After, WAV duration (sweep_audio.wav): 22.093 s
- After, difference: -0.093 s
- App's sync line: `GIF/WAV sync: the GIF has 44 frames of 0.5 s each and plays for 22 s, the WAV plays for 22.093 s, and the GIF is 0.093 s shorter than the WAV.`

#### compton energy — energy.gif
- Command: `wolframscript -file compton/main.wl -- --simulation.mode=energy`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 60
- Before, frame delay: 0.50 s
- Before, GIF duration: 30.000 s
- Before, WAV duration (energy_audio.wav): 30.029 s
- Before, difference: -0.029 s
- After, frame count: 60
- After, frame delay: 0.50 s
- After, GIF duration: 30.000 s
- After, WAV duration (energy_audio.wav): 30.029 s
- After, difference: -0.029 s
- App's sync line: `GIF/WAV sync: the GIF has 60 frames of 0.5 s each and plays for 30 s, the WAV plays for 30.029 s, and the GIF is 0.029 s shorter than the WAV.`

#### cosmology sky — cmb_sky.gif
- Command: `wolframscript -file cosmology/main.wl -- --simulation.mode=sky`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 66
- Before, frame delay: 0.50 s
- Before, GIF duration: 33.000 s
- Before, WAV duration (cmb_sky_audio.wav): 32.787 s
- Before, difference: +0.213 s
- After, frame count: 66
- After, frame delay: 0.50 s
- After, GIF duration: 33.000 s
- After, WAV duration (cmb_sky_audio.wav): 32.787 s
- After, difference: +0.213 s
- App's sync line: `GIF/WAV sync: the GIF has 66 frames of 0.5 s each and plays for 33 s, the WAV plays for 32.787 s, and the GIF is 0.213 s longer than the WAV.`

- dynamical sweep: see the targeted or dynamical runs above.
- dynamical iterate: see the targeted or dynamical runs above.
- fluid karman: see the targeted or dynamical runs above.
#### fluid strouhal — strouhal.gif
- Command: `wolframscript -file fluid/main.wl -- --simulation.mode=strouhal`
- Frame rate the app requested before the fix: 3.17283 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.32 s
- Before, GIF duration: 48.000 s
- Before, WAV duration (strouhal_audio.wav): 47.276 s
- Before, difference: +0.724 s
- After, frame count: 148
- After, frame delay: 0.32 s
- After, GIF duration: 47.360 s
- After, WAV duration (strouhal_audio.wav): 47.276 s
- After, difference: +0.084 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.32 s each and plays for 47.36 s, the WAV plays for 47.276 s, and the GIF is 0.084 s longer than the WAV.`

#### fluid flag — flag.gif
- Command: `wolframscript -file fluid/main.wl -- --simulation.mode=flag`
- Frame rate the app requested before the fix: 3.76897 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.27 s
- Before, GIF duration: 40.500 s
- Before, WAV duration (flag_audio.wav): 39.799 s
- Before, difference: +0.701 s
- After, frame count: 147
- After, frame delay: 0.27 s
- After, GIF duration: 39.690 s
- After, WAV duration (flag_audio.wav): 39.799 s
- After, difference: -0.109 s
- App's sync line: `GIF/WAV sync: the GIF has 147 frames of 0.27 s each and plays for 39.69 s, the WAV plays for 39.799 s, and the GIF is 0.109 s shorter than the WAV.`

- grover search: see the targeted or dynamical runs above.
#### grover compare — grover_compare.gif
- Command: `wolframscript -file grover/main.wl -- --simulation.mode=compare`
- Frame rate the app requested before the fix: 7.05851 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.14 s
- Before, GIF duration: 21.000 s
- Before, WAV duration (grover_compare.wav): 21.251 s
- Before, difference: -0.251 s
- After, frame count: 152
- After, frame delay: 0.14 s
- After, GIF duration: 21.280 s
- After, WAV duration (grover_compare.wav): 21.251 s
- After, difference: +0.029 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.14 s each and plays for 21.28 s, the WAV plays for 21.251 s, and the GIF is 0.029 s longer than the WAV.`

#### grover geometry — grover_geometry.gif
- Command: `wolframscript -file grover/main.wl -- --simulation.mode=geometry`
- Frame rate the app requested before the fix: 5.62024 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.18 s
- Before, GIF duration: 27.000 s
- Before, WAV duration (grover_geometry.wav): 26.689 s
- Before, difference: +0.311 s
- After, frame count: 148
- After, frame delay: 0.18 s
- After, GIF duration: 26.640 s
- After, WAV duration (grover_geometry.wav): 26.689 s
- After, difference: -0.049 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.18 s each and plays for 26.64 s, the WAV plays for 26.689 s, and the GIF is 0.049 s shorter than the WAV.`

- henon attractor: see the targeted or dynamical runs above.
#### henon sweep — henon_sweep.gif
- Command: `wolframscript -file henon/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 281
- Before, frame delay: 0.50 s
- Before, GIF duration: 140.500 s
- Before, WAV duration (henon_sweep.wav): 140.330 s
- Before, difference: +0.170 s
- After, frame count: 281
- After, frame delay: 0.50 s
- After, GIF duration: 140.500 s
- After, WAV duration (henon_sweep.wav): 140.330 s
- After, difference: +0.170 s
- App's sync line: `GIF/WAV sync: the GIF has 281 frames of 0.5 s each and plays for 140.5 s, the WAV plays for 140.33 s, and the GIF is 0.17 s longer than the WAV.`

#### hydrogen orbitals — orbitals.gif
- Command: `wolframscript -file hydrogen/main.wl -- --simulation.mode=orbitals`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 211
- Before, frame delay: 0.50 s
- Before, GIF duration: 105.500 s
- Before, WAV duration (orbitals_audio.wav): 105.606 s
- Before, difference: -0.106 s
- After, frame count: 211
- After, frame delay: 0.50 s
- After, GIF duration: 105.500 s
- After, WAV duration (orbitals_audio.wav): 105.606 s
- After, difference: -0.106 s
- App's sync line: `GIF/WAV sync: the GIF has 211 frames of 0.5 s each and plays for 105.5 s, the WAV plays for 105.606 s, and the GIF is 0.106 s shorter than the WAV.`

#### hydrogen spectrum — spectrum.gif
- Command: `wolframscript -file hydrogen/main.wl -- --simulation.mode=spectrum`
- Frame rate the app requested before the fix: 3.41184 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.29 s
- Before, GIF duration: 43.500 s
- Before, WAV duration (spectrum_audio.wav): 43.965 s
- Before, difference: -0.465 s
- After, frame count: 152
- After, frame delay: 0.29 s
- After, GIF duration: 44.080 s
- After, WAV duration (spectrum_audio.wav): 43.965 s
- After, difference: +0.115 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.29 s each and plays for 44.08 s, the WAV plays for 43.965 s, and the GIF is 0.115 s longer than the WAV.`

#### hydrogen transitions — transitions.gif
- Command: `wolframscript -file hydrogen/main.wl -- --simulation.mode=transitions`
- Frame rate the app requested before the fix: 2.8677 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.35 s
- Before, GIF duration: 52.500 s
- Before, WAV duration (transitions_audio.wav): 52.307 s
- Before, difference: +0.193 s
- After, frame count: 148
- After, frame delay: 0.37 s
- After, GIF duration: 54.760 s
- After, WAV duration (transitions_audio.wav): 54.867 s
- After, difference: -0.107 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.37 s each and plays for 54.76 s, the WAV plays for 54.867 s, and the GIF is 0.107 s shorter than the WAV.`

#### images brightness — images_brightness.gif
- Command: `wolframscript -file images/main.wl -- --simulation.mode=brightness`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 198
- Before, frame delay: 0.50 s
- Before, GIF duration: 99.000 s
- Before, WAV duration (images_brightness_audio.wav): 98.925 s
- Before, difference: +0.075 s
- After, frame count: 198
- After, frame delay: 0.50 s
- After, GIF duration: 99.000 s
- After, WAV duration (images_brightness_audio.wav): 98.925 s
- After, difference: +0.075 s
- App's sync line: `GIF/WAV sync: the GIF has 198 frames of 0.5 s each and plays for 99 s, the WAV plays for 98.925 s, and the GIF is 0.075 s longer than the WAV.`

#### images colour — images_colour.gif
- Command: `wolframscript -file images/main.wl -- --simulation.mode=colour`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 211
- Before, frame delay: 0.50 s
- Before, GIF duration: 105.500 s
- Before, WAV duration (images_colour_audio.wav): 105.740 s
- Before, difference: -0.240 s
- After, frame count: 211
- After, frame delay: 0.50 s
- After, GIF duration: 105.500 s
- After, WAV duration (images_colour_audio.wav): 105.740 s
- After, difference: -0.240 s
- App's sync line: `GIF/WAV sync: the GIF has 211 frames of 0.5 s each and plays for 105.5 s, the WAV plays for 105.74 s, and the GIF is 0.24 s shorter than the WAV.`

#### images hsb — images_hsb.gif
- Command: `wolframscript -file images/main.wl -- --simulation.mode=hsb`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 202
- Before, frame delay: 0.50 s
- Before, GIF duration: 101.000 s
- Before, WAV duration (images_hsb_audio.wav): 100.771 s
- Before, difference: +0.229 s
- After, frame count: 202
- After, frame delay: 0.50 s
- After, GIF duration: 101.000 s
- After, WAV duration (images_hsb_audio.wav): 100.771 s
- After, difference: +0.229 s
- App's sync line: `GIF/WAV sync: the GIF has 202 frames of 0.5 s each and plays for 101 s, the WAV plays for 100.771 s, and the GIF is 0.229 s longer than the WAV.`

#### images scan_horizontal — images_scan_horizontal.gif
- Command: `wolframscript -file images/main.wl -- --simulation.mode=scan_horizontal`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 200
- Before, frame delay: 0.50 s
- Before, GIF duration: 100.000 s
- Before, WAV duration (images_scan_horizontal_audio.wav): 99.854 s
- Before, difference: +0.146 s
- After, frame count: 200
- After, frame delay: 0.50 s
- After, GIF duration: 100.000 s
- After, WAV duration (images_scan_horizontal_audio.wav): 99.854 s
- After, difference: +0.146 s
- App's sync line: `GIF/WAV sync: the GIF has 200 frames of 0.5 s each and plays for 100 s, the WAV plays for 99.854 s, and the GIF is 0.146 s longer than the WAV.`

- lagrange l4: see the targeted or dynamical runs above.
#### lagrange l5 — l5.gif
- Command: `wolframscript -file lagrange/main.wl -- --simulation.mode=l5`
- Frame rate the app requested before the fix: 7.95775 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.13 s
- Before, GIF duration: 19.500 s
- Before, WAV duration (l5_audio.wav): 18.849 s
- Before, difference: +0.651 s
- After, frame count: 145
- After, frame delay: 0.13 s
- After, GIF duration: 18.850 s
- After, WAV duration (l5_audio.wav): 18.849 s
- After, difference: +0.001 s
- App's sync line: `GIF/WAV sync: the GIF has 145 frames of 0.13 s each and plays for 18.85 s, the WAV plays for 18.85 s, and the GIF and the WAV have the same duration to the millisecond.`

#### lagrange l1 — l1.gif
- Command: `wolframscript -file lagrange/main.wl -- --simulation.mode=l1`
- Frame rate the app requested before the fix: 18.75 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.05 s
- Before, GIF duration: 7.500 s
- Before, WAV duration (l1_audio.wav): 8.000 s
- Before, difference: -0.500 s
- After, frame count: 160
- After, frame delay: 0.05 s
- After, GIF duration: 8.000 s
- After, WAV duration (l1_audio.wav): 8.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 160 frames of 0.05 s each and plays for 8 s, the WAV plays for 8 s, and the GIF and the WAV have the same duration to the millisecond.`

- lorenz lorenz: see the targeted or dynamical runs above.
#### lorenz rossler — rossler_animation.gif
- Command: `wolframscript -file lorenz/main.wl -- --simulation.mode=rossler`
- Frame rate the app requested before the fix: 3.75 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.27 s
- Before, GIF duration: 40.500 s
- Before, WAV duration (rossler_audio.wav): 40.000 s
- Before, difference: +0.500 s
- After, frame count: 148
- After, frame delay: 0.27 s
- After, GIF duration: 39.960 s
- After, WAV duration (rossler_audio.wav): 40.000 s
- After, difference: -0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.27 s each and plays for 39.96 s, the WAV plays for 40 s, and the GIF is 0.04 s shorter than the WAV.`

- magnetic cyclotron: see the targeted or dynamical runs above.
#### magnetic drift — drift.gif
- Command: `wolframscript -file magnetic/main.wl -- --simulation.mode=drift`
- Frame rate the app requested before the fix: 3.08408 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.32 s
- Before, GIF duration: 48.000 s
- Before, WAV duration (drift_audio.wav): 48.637 s
- Before, difference: -0.637 s
- After, frame count: 152
- After, frame delay: 0.32 s
- After, GIF duration: 48.640 s
- After, WAV duration (drift_audio.wav): 48.637 s
- After, difference: +0.003 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.32 s each and plays for 48.64 s, the WAV plays for 48.637 s, and the GIF is 0.003 s longer than the WAV.`

#### magnetic mirror — mirror.gif
- Command: `wolframscript -file magnetic/main.wl -- --simulation.mode=mirror`
- Frame rate the app requested before the fix: 3.13378 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.32 s
- Before, GIF duration: 48.000 s
- Before, WAV duration (mirror_audio.wav): 47.866 s
- Before, difference: +0.134 s
- After, frame count: 150
- After, frame delay: 0.32 s
- After, GIF duration: 48.000 s
- After, WAV duration (mirror_audio.wav): 47.866 s
- After, difference: +0.134 s
- App's sync line: `GIF/WAV sync: the GIF has 150 frames of 0.32 s each and plays for 48 s, the WAV plays for 47.866 s, and the GIF is 0.134 s longer than the WAV.`

#### magnetic multi — multi.gif
- Command: `wolframscript -file magnetic/main.wl -- --simulation.mode=multi`
- Frame rate the app requested before the fix: 2.42787 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.41 s
- Before, GIF duration: 61.500 s
- Before, WAV duration (multi_audio.wav): 61.783 s
- Before, difference: -0.283 s
- After, frame count: 151
- After, frame delay: 0.41 s
- After, GIF duration: 61.910 s
- After, WAV duration (multi_audio.wav): 61.783 s
- After, difference: +0.127 s
- App's sync line: `GIF/WAV sync: the GIF has 151 frames of 0.41 s each and plays for 61.91 s, the WAV plays for 61.783 s, and the GIF is 0.127 s longer than the WAV.`

#### mandelbrot mandelbrot — mandelbrot_mandelbrot.gif
- Command: `wolframscript -file mandelbrot/main.wl -- --simulation.mode=mandelbrot`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 162
- Before, frame delay: 0.50 s
- Before, GIF duration: 81.000 s
- Before, WAV duration (mandelbrot_mandelbrot.wav): 81.231 s
- Before, difference: -0.231 s
- After, frame count: 162
- After, frame delay: 0.50 s
- After, GIF duration: 81.000 s
- After, WAV duration (mandelbrot_mandelbrot.wav): 81.231 s
- After, difference: -0.231 s
- App's sync line: `GIF/WAV sync: the GIF has 162 frames of 0.5 s each and plays for 81 s, the WAV plays for 81.231 s, and the GIF is 0.231 s shorter than the WAV.`

#### mandelbrot julia — mandelbrot_julia.gif
- Command: `wolframscript -file mandelbrot/main.wl -- --simulation.mode=julia`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 156
- Before, frame delay: 0.50 s
- Before, GIF duration: 78.000 s
- Before, WAV duration (mandelbrot_julia.wav): 77.895 s
- Before, difference: +0.105 s
- After, frame count: 156
- After, frame delay: 0.50 s
- After, GIF duration: 78.000 s
- After, WAV duration (mandelbrot_julia.wav): 77.895 s
- After, difference: +0.105 s
- App's sync line: `GIF/WAV sync: the GIF has 156 frames of 0.5 s each and plays for 78 s, the WAV plays for 77.895 s, and the GIF is 0.105 s longer than the WAV.`

#### mandelbrot zoom — mandelbrot_zoom.gif
- Command: `wolframscript -file mandelbrot/main.wl -- --simulation.mode=zoom`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 231
- Before, frame delay: 0.50 s
- Before, GIF duration: 115.500 s
- Before, WAV duration (mandelbrot_zoom.wav): 115.311 s
- Before, difference: +0.189 s
- After, frame count: 231
- After, frame delay: 0.50 s
- After, GIF duration: 115.500 s
- After, WAV duration (mandelbrot_zoom.wav): 115.311 s
- After, difference: +0.189 s
- App's sync line: `GIF/WAV sync: the GIF has 231 frames of 0.5 s each and plays for 115.5 s, the WAV plays for 115.311 s, and the GIF is 0.189 s longer than the WAV.`

#### montecarlo sweep — sweep.gif
- Command: `wolframscript -file montecarlo/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 163
- Before, frame delay: 0.50 s
- Before, GIF duration: 81.500 s
- Before, WAV duration (sweep_audio.wav): 81.414 s
- Before, difference: +0.086 s
- After, frame count: 163
- After, frame delay: 0.50 s
- After, GIF duration: 81.500 s
- After, WAV duration (sweep_audio.wav): 81.414 s
- After, difference: +0.086 s
- App's sync line: `GIF/WAV sync: the GIF has 163 frames of 0.5 s each and plays for 81.5 s, the WAV plays for 81.414 s, and the GIF is 0.086 s longer than the WAV.`

#### montecarlo critical — critical.gif
- Command: `wolframscript -file montecarlo/main.wl -- --simulation.mode=critical`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 152
- Before, frame delay: 0.50 s
- Before, GIF duration: 76.000 s
- Before, WAV duration (critical_audio.wav): 76.097 s
- Before, difference: -0.097 s
- After, frame count: 152
- After, frame delay: 0.50 s
- After, GIF duration: 76.000 s
- After, WAV duration (critical_audio.wav): 76.097 s
- After, difference: -0.097 s
- App's sync line: `GIF/WAV sync: the GIF has 152 frames of 0.5 s each and plays for 76 s, the WAV plays for 76.097 s, and the GIF is 0.097 s shorter than the WAV.`

#### montecarlo quench — quench.gif
- Command: `wolframscript -file montecarlo/main.wl -- --simulation.mode=quench`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 155
- Before, frame delay: 0.50 s
- Before, GIF duration: 77.500 s
- Before, WAV duration (quench_audio.wav): 77.629 s
- Before, difference: -0.129 s
- After, frame count: 155
- After, frame delay: 0.50 s
- After, GIF duration: 77.500 s
- After, WAV duration (quench_audio.wav): 77.629 s
- After, difference: -0.129 s
- App's sync line: `GIF/WAV sync: the GIF has 155 frames of 0.5 s each and plays for 77.5 s, the WAV plays for 77.629 s, and the GIF is 0.129 s shorter than the WAV.`

#### pendulum simple — simple_animation.gif
- Command: `wolframscript -file pendulum/main.wl -- --simulation.mode=simple`
- Frame rate the app requested before the fix: 25 fps (a whole number of centiseconds).
- Before, frame count: 501
- Before, frame delay: 0.04 s
- Before, GIF duration: 20.040 s
- Before, WAV duration (simple_audio.wav): 20.000 s
- Before, difference: +0.040 s
- After, frame count: 501
- After, frame delay: 0.04 s
- After, GIF duration: 20.040 s
- After, WAV duration (simple_audio.wav): 20.000 s
- After, difference: +0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 501 frames of 0.04 s each and plays for 20.04 s, the WAV plays for 20 s, and the GIF is 0.04 s longer than the WAV.`

#### pendulum double — double_animation.gif
- Command: `wolframscript -file pendulum/main.wl -- --simulation.mode=double`
- Frame rate the app requested before the fix: 25 fps (a whole number of centiseconds).
- Before, frame count: 501
- Before, frame delay: 0.04 s
- Before, GIF duration: 20.040 s
- Before, WAV duration (double_audio.wav): 20.000 s
- Before, difference: +0.040 s
- After, frame count: 501
- After, frame delay: 0.04 s
- After, GIF duration: 20.040 s
- After, WAV duration (double_audio.wav): 20.000 s
- After, difference: +0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 501 frames of 0.04 s each and plays for 20.04 s, the WAV plays for 20 s, and the GIF is 0.04 s longer than the WAV.`

- primes ulam: see the targeted or dynamical runs above.
#### primes gaps — gaps_animation.gif
- Command: `wolframscript -file primes/main.wl -- --simulation.mode=gaps`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 60
- Before, frame delay: 0.50 s
- Before, GIF duration: 30.000 s
- Before, WAV duration (gaps_audio.wav): 30.080 s
- Before, difference: -0.080 s
- After, frame count: 60
- After, frame delay: 0.50 s
- After, GIF duration: 30.000 s
- After, WAV duration (gaps_audio.wav): 30.080 s
- After, difference: -0.080 s
- App's sync line: `GIF/WAV sync: the GIF has 60 frames of 0.5 s each and plays for 30 s, the WAV plays for 30.08 s, and the GIF is 0.08 s shorter than the WAV.`

- quantum qho: see the targeted or dynamical runs above.
#### quantum box — box_density.gif
- Command: `wolframscript -file quantum/main.wl -- --simulation.mode=box`
- Frame rate the app requested before the fix: 20.05 fps (not a whole number of centiseconds).
- Before, frame count: 401
- Before, frame delay: 0.05 s
- Before, GIF duration: 20.050 s
- Before, WAV duration (box_audio.wav): 20.000 s
- Before, difference: +0.050 s
- After, frame count: 400
- After, frame delay: 0.05 s
- After, GIF duration: 20.000 s
- After, WAV duration (box_audio.wav): 20.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 400 frames of 0.05 s each and plays for 20 s, the WAV plays for 20 s, and the GIF and the WAV have the same duration to the millisecond.`

#### quantum_statistics spectrum — quantum_statistics_spectrum.gif
- Command: `wolframscript -file quantum_statistics/main.wl -- --simulation.mode=spectrum`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 61
- Before, frame delay: 0.50 s
- Before, GIF duration: 30.500 s
- Before, WAV duration (quantum_statistics_spectrum.wav): 30.622 s
- Before, difference: -0.122 s
- After, frame count: 61
- After, frame delay: 0.50 s
- After, GIF duration: 30.500 s
- After, WAV duration (quantum_statistics_spectrum.wav): 30.622 s
- After, difference: -0.122 s
- App's sync line: `GIF/WAV sync: the GIF has 61 frames of 0.5 s each and plays for 30.5 s, the WAV plays for 30.622 s, and the GIF is 0.122 s shorter than the WAV.`

#### quantum_statistics temperature — quantum_statistics_temperature.gif
- Command: `wolframscript -file quantum_statistics/main.wl -- --simulation.mode=temperature`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 59
- Before, frame delay: 0.50 s
- Before, GIF duration: 29.500 s
- Before, WAV duration (quantum_statistics_temperature.wav): 29.687 s
- Before, difference: -0.187 s
- After, frame count: 59
- After, frame delay: 0.50 s
- After, GIF duration: 29.500 s
- After, WAV duration (quantum_statistics_temperature.wav): 29.687 s
- After, difference: -0.187 s
- App's sync line: `GIF/WAV sync: the GIF has 59 frames of 0.5 s each and plays for 29.5 s, the WAV plays for 29.687 s, and the GIF is 0.187 s shorter than the WAV.`

#### quantum_statistics fermi_sea — quantum_statistics_fermi_sea.gif
- Command: `wolframscript -file quantum_statistics/main.wl -- --simulation.mode=fermi_sea`
- Frame rate the app requested before the fix: 2 fps (a whole number of centiseconds).
- Before, frame count: 46
- Before, frame delay: 0.50 s
- Before, GIF duration: 23.000 s
- Before, WAV duration (quantum_statistics_fermi_sea.wav): 22.972 s
- Before, difference: +0.028 s
- After, frame count: 46
- After, frame delay: 0.50 s
- After, GIF duration: 23.000 s
- After, WAV duration (quantum_statistics_fermi_sea.wav): 22.972 s
- After, difference: +0.028 s
- App's sync line: `GIF/WAV sync: the GIF has 46 frames of 0.5 s each and plays for 23 s, the WAV plays for 22.972 s, and the GIF is 0.028 s longer than the WAV.`

- quantum_tunnelling barrier: see the targeted or dynamical runs above.
#### quantum_tunnelling sweep — sweep.gif
- Command: `wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 6.66667 fps (a whole number of centiseconds).
- Before, frame count: 40
- Before, frame delay: 0.15 s
- Before, GIF duration: 6.000 s
- Before, WAV duration (sweep_audio.wav): 23.877 s
- Before, difference: -17.877 s
- After, frame count: 40
- After, frame delay: 0.15 s
- After, GIF duration: 6.000 s
- After, WAV duration (sweep_audio.wav): 23.877 s
- After, difference: -17.877 s
- Spoken intro before the timed section, reported by the app: 17.877 s
- Timed section of the WAV (file duration minus intro): 6.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 40 frames of 0.15 s each and plays for 6 s, the WAV plays for 23.877 s, of which the part after the 17.877 s spoken intro lasts 6 s, and the GIF and that part have the same duration to the millisecond.`

#### quantum_tunnelling energy — energy.gif
- Command: `wolframscript -file quantum_tunnelling/main.wl -- --simulation.mode=energy`
- Frame rate the app requested before the fix: 5 fps (a whole number of centiseconds).
- Before, frame count: 40
- Before, frame delay: 0.20 s
- Before, GIF duration: 8.000 s
- Before, WAV duration (energy_audio.wav): 38.005 s
- Before, difference: -30.005 s
- After, frame count: 40
- After, frame delay: 0.20 s
- After, GIF duration: 8.000 s
- After, WAV duration (energy_audio.wav): 38.005 s
- After, difference: -30.005 s
- Spoken intro before the timed section, reported by the app: 30.005 s
- Timed section of the WAV (file duration minus intro): 8.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 40 frames of 0.2 s each and plays for 8 s, the WAV plays for 38.005 s, of which the part after the 30.005 s spoken intro lasts 8 s, and the GIF and that part have the same duration to the millisecond.`

- qubit gates: see the targeted or dynamical runs above.
- relativity chirp: see the targeted or dynamical runs above.
#### relativity geodesic — geodesic.gif
- Command: `wolframscript -file relativity/main.wl -- --simulation.mode=geodesic`
- Frame rate the app requested before the fix: 6 fps (not a whole number of centiseconds).
- Before, frame count: 60
- Before, frame delay: 0.17 s
- Before, GIF duration: 10.200 s
- Before, WAV duration (geodesic.wav): 10.000 s
- Before, difference: +0.200 s
- After, frame count: 59
- After, frame delay: 0.17 s
- After, GIF duration: 10.030 s
- After, WAV duration (geodesic.wav): 10.000 s
- After, difference: +0.030 s
- App's sync line: `GIF/WAV sync: the GIF has 59 frames of 0.17 s each and plays for 10.03 s, the WAV plays for 10 s, and the GIF is 0.03 s longer than the WAV.`

- resonance galilean: see the targeted or dynamical runs above.
#### resonance kirkwood — kirkwood.gif
- Command: `wolframscript -file resonance/main.wl -- --simulation.mode=kirkwood`
- Frame rate the app requested before the fix: 10.4167 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.10 s
- Before, GIF duration: 15.000 s
- Before, WAV duration (kirkwood_audio.wav): 36.950 s
- Before, difference: -21.950 s
- After, frame count: 144
- After, frame delay: 0.10 s
- After, GIF duration: 14.400 s
- After, WAV duration (kirkwood_audio.wav): 36.950 s
- After, difference: -22.550 s
- Spoken intro before the timed section, reported by the app: 22.550 s
- Timed section of the WAV (file duration minus intro): 14.400 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 144 frames of 0.1 s each and plays for 14.4 s, the WAV plays for 36.95 s, of which the part after the 22.55 s spoken intro lasts 14.4 s, and the GIF and that part have the same duration to the millisecond.`

#### resonance saturn — saturn.gif
- Command: `wolframscript -file resonance/main.wl -- --simulation.mode=saturn`
- Frame rate the app requested before the fix: 10.4167 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.10 s
- Before, GIF duration: 15.000 s
- Before, WAV duration (saturn_audio.wav): 34.435 s
- Before, difference: -19.435 s
- After, frame count: 144
- After, frame delay: 0.10 s
- After, GIF duration: 14.400 s
- After, WAV duration (saturn_audio.wav): 34.435 s
- After, difference: -20.035 s
- Spoken intro before the timed section, reported by the app: 20.035 s
- Timed section of the WAV (file duration minus intro): 14.400 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 144 frames of 0.1 s each and plays for 14.4 s, the WAV plays for 34.435 s, of which the part after the 20.035 s spoken intro lasts 14.4 s, and the GIF and that part have the same duration to the millisecond.`

- scattering scatter: see the targeted or dynamical runs above.
#### scattering distribution — distribution.gif
- Command: `wolframscript -file scattering/main.wl -- --simulation.mode=distribution`
- Frame rate the app requested before the fix: 9.20245 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.11 s
- Before, GIF duration: 16.500 s
- Before, WAV duration (distribution_audio.wav): 36.131 s
- Before, difference: -19.631 s
- After, frame count: 148
- After, frame delay: 0.11 s
- After, GIF duration: 16.280 s
- After, WAV duration (distribution_audio.wav): 36.131 s
- After, difference: -19.851 s
- Spoken intro before the timed section, reported by the app: 19.831 s
- Timed section of the WAV (file duration minus intro): 16.300 s
- After, difference against the timed section: -0.020 s
- App's sync line: `GIF/WAV sync: the GIF has 148 frames of 0.11 s each and plays for 16.28 s, the WAV plays for 36.131 s, of which the part after the 19.831 s spoken intro lasts 16.3 s, and the GIF is 0.02 s shorter than that part.`

#### scattering discovery — discovery.gif
- Command: `wolframscript -file scattering/main.wl -- --simulation.mode=discovery`
- Frame rate the app requested before the fix: 18.75 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.05 s
- Before, GIF duration: 7.500 s
- Before, WAV duration (discovery_audio.wav): 41.344 s
- Before, difference: -33.844 s
- After, frame count: 160
- After, frame delay: 0.05 s
- After, GIF duration: 8.000 s
- After, WAV duration (discovery_audio.wav): 41.344 s
- After, difference: -33.344 s
- Spoken intro before the timed section, reported by the app: 25.281 s
- Spoken outro after the timed section, reported by the app: 8.063 s
- Timed section of the WAV (file duration minus intro and outro): 8.000 s
- After, difference against the timed section: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 160 frames of 0.05 s each and plays for 8 s, the WAV plays for 41.344 s, of which the part between the 25.281 s spoken intro and the 8.063 s spoken outro lasts 8 s, and the GIF and that part have the same duration to the millisecond.`

#### signal chord — chord_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=chord`
- Frame rate the app requested before the fix: 10 fps (a whole number of centiseconds).
- Before, frame count: 30
- Before, frame delay: 0.10 s
- Before, GIF duration: 3.000 s
- Before, WAV duration (chord_clean.wav): 3.000 s
- Before, difference: +0.000 s
- After, frame count: 30
- After, frame delay: 0.10 s
- After, GIF duration: 3.000 s
- After, WAV duration (chord_clean.wav): 3.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 30 frames of 0.1 s each and plays for 3 s, the WAV plays for 3 s, and the GIF and the WAV have the same duration to the millisecond.`

#### signal sweep — sweep_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=sweep`
- Frame rate the app requested before the fix: 10 fps (a whole number of centiseconds).
- Before, frame count: 40
- Before, frame delay: 0.10 s
- Before, GIF duration: 4.000 s
- Before, WAV duration (sweep_clean.wav): 4.000 s
- Before, difference: +0.000 s
- After, frame count: 40
- After, frame delay: 0.10 s
- After, GIF duration: 4.000 s
- After, WAV duration (sweep_clean.wav): 4.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 40 frames of 0.1 s each and plays for 4 s, the WAV plays for 4 s, and the GIF and the WAV have the same duration to the millisecond.`

#### signal am — am_animation.gif
- Command: `wolframscript -file signal/main.wl -- --simulation.mode=am`
- Frame rate the app requested before the fix: 10 fps (a whole number of centiseconds).
- Before, frame count: 30
- Before, frame delay: 0.10 s
- Before, GIF duration: 3.000 s
- Before, WAV duration (am_clean.wav): 3.000 s
- Before, difference: +0.000 s
- After, frame count: 30
- After, frame delay: 0.10 s
- After, GIF duration: 3.000 s
- After, WAV duration (am_clean.wav): 3.000 s
- After, difference: +0.000 s
- App's sync line: `GIF/WAV sync: the GIF has 30 frames of 0.1 s each and plays for 3 s, the WAV plays for 3 s, and the GIF and the WAV have the same duration to the millisecond.`

- thermo distribution: see the targeted or dynamical runs above.
#### thermo ensemble — ensemble.gif
- Command: `wolframscript -file thermo/main.wl -- --simulation.mode=ensemble`
- Frame rate the app requested before the fix: 5.94383 fps (not a whole number of centiseconds).
- Before, frame count: 201
- Before, frame delay: 0.17 s
- Before, GIF duration: 34.170 s
- Before, WAV duration (ensemble_audio.wav): 33.817 s
- Before, difference: +0.353 s
- After, frame count: 199
- After, frame delay: 0.17 s
- After, GIF duration: 33.830 s
- After, WAV duration (ensemble_audio.wav): 33.817 s
- After, difference: +0.013 s
- App's sync line: `GIF/WAV sync: the GIF has 199 frames of 0.17 s each and plays for 33.83 s, the WAV plays for 33.817 s, and the GIF is 0.013 s longer than the WAV.`

#### thermo cooling — cooling.gif
- Command: `wolframscript -file thermo/main.wl -- --simulation.mode=cooling`
- Frame rate the app requested before the fix: 3.13036 fps (not a whole number of centiseconds).
- Before, frame count: 50
- Before, frame delay: 0.32 s
- Before, GIF duration: 16.000 s
- Before, WAV duration (cooling_audio.wav): 15.973 s
- Before, difference: +0.027 s
- After, frame count: 50
- After, frame delay: 0.32 s
- After, GIF duration: 16.000 s
- After, WAV duration (cooling_audio.wav): 15.973 s
- After, difference: +0.027 s
- App's sync line: `GIF/WAV sync: the GIF has 50 frames of 0.32 s each and plays for 16 s, the WAV plays for 15.973 s, and the GIF is 0.027 s longer than the WAV.`

#### thermo equipartition — equipartition.gif
- Command: `wolframscript -file thermo/main.wl -- --simulation.mode=equipartition`
- Frame rate the app requested before the fix: 3.27814 fps (not a whole number of centiseconds).
- Before, frame count: 100
- Before, frame delay: 0.31 s
- Before, GIF duration: 31.000 s
- Before, WAV duration (equipartition_audio.wav): 30.505 s
- Before, difference: +0.495 s
- After, frame count: 98
- After, frame delay: 0.31 s
- After, GIF duration: 30.380 s
- After, WAV duration (equipartition_audio.wav): 30.505 s
- After, difference: -0.125 s
- App's sync line: `GIF/WAV sync: the GIF has 98 frames of 0.31 s each and plays for 30.38 s, the WAV plays for 30.505 s, and the GIF is 0.125 s shorter than the WAV.`

- waves ripple: see the targeted or dynamical runs above.
#### waves interference — interference.gif
- Command: `wolframscript -file waves/main.wl -- --simulation.mode=interference`
- Frame rate the app requested before the fix: 9.375 fps (not a whole number of centiseconds).
- Before, frame count: 150
- Before, frame delay: 0.11 s
- Before, GIF duration: 16.500 s
- Before, WAV duration (interference_audio.wav): 16.000 s
- Before, difference: +0.500 s
- After, frame count: 145
- After, frame delay: 0.11 s
- After, GIF duration: 15.950 s
- After, WAV duration (interference_audio.wav): 16.000 s
- After, difference: -0.050 s
- App's sync line: `GIF/WAV sync: the GIF has 145 frames of 0.11 s each and plays for 15.95 s, the WAV plays for 16 s, and the GIF is 0.05 s shorter than the WAV.`

- dynamical iterate fixed_point: see the targeted or dynamical runs above.
- dynamical iterate period2: see the targeted or dynamical runs above.
- dynamical iterate period4: see the targeted or dynamical runs above.
- dynamical iterate period3_window: see the targeted or dynamical runs above.
- dynamical iterate chaos: see the targeted or dynamical runs above.
#### asteroids default — asteroids_2026-09-17_2026-09-23.gif
- Command: `wolframscript -file asteroids/main.wl`
- Frame rate the app requested before the fix: 6.25 fps (a whole number of centiseconds).
- Before, frame count: 151
- Before, frame delay: 0.16 s
- Before, GIF duration: 24.160 s
- Before, WAV duration (asteroids_2026-09-17_2026-09-23.wav): 24.120 s
- Before, difference: +0.040 s
- After, frame count: 151
- After, frame delay: 0.16 s
- After, GIF duration: 24.160 s
- After, WAV duration (asteroids_2026-09-17_2026-09-23.wav): 24.120 s
- After, difference: +0.040 s
- App's sync line: `GIF/WAV sync: the GIF has 151 frames of 0.16 s each and plays for 24.16 s, the WAV plays for 24.12 s, and the GIF is 0.04 s longer than the WAV.`


### Test suites

- `asteroids/tests/test_analyse.wl`: exit 0, "Results: 29 passed, 0 failed."
- `bayes/tests/test_model.wl`: exit 0, "Results: 23 passed, 0 failed."
- `bell/tests/test_model.wl`: exit 0, "Results: 35 passed, 0 failed."
- `blackbody/tests/test_model.wl`: exit 0, "Results: 23 passed, 0 failed."
- `brownian/tests/test_model.wl`: exit 0, "Results: 24 passed, 0 failed."
- `cellular/tests/test_model.wl`: exit 0, "Results: 16 passed, 0 failed."
- `clt/tests/test_model.wl`: exit 0, "Results: 23 passed, 0 failed."
- `compton/tests/test_model.wl`: exit 0, "Results: 25 passed, 0 failed."
- `cosmology/tests/test_model.wl`: exit 0, "Results: 27 passed, 0 failed."
- `dynamical/tests/test_model.wl`: exit 0, "Results: 36 passed, 0 failed."
- `fluid/tests/test_model.wl`: exit 0, "Results: 5 passed, 0 failed."
- `grover/tests/test_model.wl`: exit 0, "Results: 24 passed, 0 failed."
- `henon/tests/test_model.wl`: exit 0, "Results: 39 passed, 0 failed."
- `hydrogen/tests/test_model.wl`: exit 0, "Results: 23 passed, 0 failed."
- `images/tests/test_model.wl`: exit 0, "Results: 51 passed, 0 failed."
- `lagrange/tests/test_model.wl`: exit 0, "Failed: 0"
- `lorenz/tests/test_model.wl`: exit 0, "Results: 26 passed, 0 failed."
- `magnetic/tests/test_model.wl`: exit 0, "Failed: 0"
- `mandelbrot/tests/test_model.wl`: exit 0, "Results: 27 passed, 0 failed."
- `montecarlo/tests/test_model.wl`: exit 0, "Results: 19 passed, 0 failed."
- `pendulum/tests/test_model.wl`: exit 0, "Results: 18 passed, 0 failed."
- `primes/tests/test_model.wl`: exit 0, "Results: 17 passed, 0 failed."
- `quantum/tests/test_model.wl`: exit 0, "Results: 14 passed, 0 failed."
- `quantum_statistics/tests/test_model.wl`: exit 0, "Results: 26 passed, 0 failed."
- `quantum_tunnelling/tests/test_model.wl`: exit 0, "Results: 20 passed, 0 failed."
- `qubit/tests/test_model.wl`: exit 0, "Results: 33 passed, 0 failed."
- `relativity/tests/test_model.wl`: exit 0, "Results: 16 passed, 0 failed."
- `resonance/tests/test_model.wl`: exit 0, "Failed: 0"
- `scattering/tests/test_model.wl`: exit 0, "Failed: 0"
- `signal/tests/test_model.wl`: exit 0, "Results: 13 passed, 0 failed."
- `stem-core/tests/test_gifsync.wl`: exit 0, "Results: 31 passed, 0 failed."
- `thermo/tests/test_model.wl`: exit 0, "Results: 28 passed, 0 failed."
- `waves/tests/test_model.wl`: exit 0, "Results: 23 passed, 0 failed."

### demo.wl

- `wolframscript -file demo.wl`: Passed 33/33 runs.
- demo.wl total elapsed: 575.7 s.
- `wolframscript -file demo.wl -- --check-only`: Passed 33/33 runs.

## Part 4 — Number formatting in the animation lines

- Animation and sync lines checked after the fix: 227.
- Of those, lines with a number printed to more than three decimals: 0.
- The same count in the baseline logs: 46 of 140.
- Change: STEMDescribeGIF and every animation line now format fps, frame delay and duration with FmtDec (at most three decimals, no trailing zeros); henon, which used N[] and printed full precision, is included.
- henon attractor line before: `Rendering 150 frames at 5.251083556924445 fps (28.565532879818594s, matching audio duration 28.565532879818594s)...`
- henon attractor line after: `Rendering 150 frames at 5.263 fps (0.19 s per frame, 28.5 s in total).`
- henon attractor summary line before: `Animation: 150 frames at 5.251083556924445 fps`
- henon attractor summary line after: `Animation: 150 frames at 5.263 fps`
- Lines containing "matching audio duration" or "matching signal duration" after the fix: 0.

## Not done, and open points

- experiments.wl / experiment.wl scripts were not run; they call the same Animate* functions, so their GIFs use the plan, but they do not call SyncWAVToGIF and so print no sync line.
- Per-app AGENTS.md files still describe the old Clip/Round formula in their GIF/WAV sync sections; only stem-core/AGENTS.md, stem-core/README.md and the root AGENTS.md were updated.
- The intro-offset design (clt, quantum_tunnelling, resonance, scattering) was kept as v1.5.1 documented it: their GIFs match the section after the spoken intro, so the whole-file differences in the rows above are the intro length by design.
- signal's unseeded noise makes its noisy WAV and GIF frames differ on every run; this predates the change and was left alone.
- STEMDescribeGIF still prints "1 frames" for single-frame GIFs; only the new sync sentence was given singular wording.

## Files changed

- `AGENTS.md` (modified)
- `asteroids/main.wl` (modified)
- `asteroids/src/animate.wl` (modified)
- `bayes/main.wl` (modified)
- `bayes/src/animate.wl` (modified)
- `bell/main.wl` (modified)
- `bell/src/animate.wl` (modified)
- `blackbody/main.wl` (modified)
- `blackbody/src/animate.wl` (modified)
- `brownian/main.wl` (modified)
- `brownian/src/animate.wl` (modified)
- `cellular/main.wl` (modified)
- `cellular/src/animate.wl` (modified)
- `clt/main.wl` (modified)
- `clt/src/animate.wl` (modified)
- `compton/main.wl` (modified)
- `compton/src/animate.wl` (modified)
- `cosmology/main.wl` (modified)
- `cosmology/src/animate.wl` (modified)
- `dynamical/main.wl` (modified)
- `dynamical/src/animate.wl` (modified)
- `fluid/main.wl` (modified)
- `fluid/src/animate.wl` (modified)
- `grover/main.wl` (modified)
- `grover/src/animate.wl` (modified)
- `henon/main.wl` (modified)
- `henon/src/animate.wl` (modified)
- `hydrogen/main.wl` (modified)
- `hydrogen/src/animate.wl` (modified)
- `images/main.wl` (modified)
- `images/src/animate.wl` (modified)
- `lagrange/main.wl` (modified)
- `lagrange/src/animate.wl` (modified)
- `lorenz/experiment.wl` (modified)
- `lorenz/main.wl` (modified)
- `lorenz/src/animate.wl` (modified)
- `magnetic/main.wl` (modified)
- `magnetic/src/animate.wl` (modified)
- `mandelbrot/main.wl` (modified)
- `mandelbrot/src/animate.wl` (modified)
- `montecarlo/main.wl` (modified)
- `montecarlo/src/animate.wl` (modified)
- `pendulum/main.wl` (modified)
- `pendulum/src/animate.wl` (modified)
- `primes/main.wl` (modified)
- `primes/src/animate.wl` (modified)
- `primes/src/sonify.wl` (modified)
- `quantum/main.wl` (modified)
- `quantum/src/animate.wl` (modified)
- `quantum_statistics/main.wl` (modified)
- `quantum_statistics/src/animate.wl` (modified)
- `quantum_tunnelling/main.wl` (modified)
- `quantum_tunnelling/src/animate.wl` (modified)
- `qubit/main.wl` (modified)
- `qubit/src/animate.wl` (modified)
- `relativity/main.wl` (modified)
- `relativity/src/animate.wl` (modified)
- `resonance/main.wl` (modified)
- `resonance/src/animate.wl` (modified)
- `resonance/src/sonify.wl` (modified)
- `scattering/main.wl` (modified)
- `scattering/src/animate.wl` (modified)
- `scattering/src/sonify.wl` (modified)
- `signal/main.wl` (modified)
- `signal/src/animate.wl` (modified)
- `stem-core/AGENTS.md` (modified)
- `stem-core/README.md` (modified)
- `stem-core/init.wl` (modified)
- `stem-core/src/accessibility.wl` (modified)
- `stem-core/src/export.wl` (modified)
- `stem-core/src/utils.wl` (modified)
- `thermo/main.wl` (modified)
- `thermo/src/animate.wl` (modified)
- `waves/main.wl` (modified)
- `waves/src/animate.wl` (modified)
- `stem-core/VERIFICATION_gif_centisecond.md` (new)
- `stem-core/tests/test_gifsync.wl` (new)
- `stem-core/VERIFICATION_gif_centisecond.md` (new, this file)

## Follow-up answers (2026-09-23)

### 1. hydrogen transitions WAV: 52.307 s before, 54.867 s after

- Cause: the audio length is nondeterministic; the change did not alter it.
- Code path: hydrogen/main.wl:241 builds cascadesList = Table[SimulateCascade[nStart, lStart, maxSteps], {nReal}].
- SimulateCascade (hydrogen/src/model.wl:262) picks each decay branch with r = RandomReal[{0.0, totalW}] (hydrogen/src/model.wl:269), and nothing in hydrogen seeds the random generator.
- SonifyCascades (hydrogen/src/sonify.wl:144) gives each cascade step a note of Clip[$CascadeDurationScale / einstein_A, {0.08, 1.2}] seconds (hydrogen/src/sonify.wl:165), so the WAV length depends on which branches were drawn and how many steps each cascade took.
- The change touched hydrogen/main.wl only to add SyncWAVToGIF calls after each WAV is written, and hydrogen/src/animate.wl only in GIF timing; hydrogen/src/model.wl and hydrogen/src/sonify.wl are unchanged (`git diff --stat -- hydrogen/` lists only main.wl and src/animate.wl).
- SyncWAVToGIF did not pad this WAV: the sweep log has no "padded" line, and the GIF was the shorter file (-0.107 s), which is never padded.
- The console line "Path lengths: ... mean=" differs between the runs, which shows that the cascades differed: baseline mean 2.1, post-change sweep mean 2.3.
- Verdict: the audio length change is not a regression and needs no fix; the nondeterminism predates this work.
- Command for both runs below: `wolframscript -file hydrogen/main.wl -- --simulation.mode=transitions`, run twice in a row on the working tree.
- Run 1, exit code: 0
- Run 1, cascade path-length mean printed: 2.1
- Run 1, GIF frame count: 149
- Run 1, GIF frame delay: 0.35 s
- Run 1, GIF duration: 52.150 s
- Run 1, WAV duration: 52.307 s
- Run 1, difference (GIF minus WAV): -0.157 s
- Run 2, exit code: 0
- Run 2, cascade path-length mean printed: 2.2
- Run 2, GIF frame count: 149
- Run 2, GIF frame delay: 0.36 s
- Run 2, GIF duration: 53.640 s
- Run 2, WAV duration: 53.587 s
- Run 2, difference (GIF minus WAV): +0.053 s
- Measurement method for both runs: GIF = sum of Import[gif, "DisplayDurations"], WAV = Import[wav, "Duration"].
- Run 1 happened to land on the same WAV length as the baseline (52.307 s); two runs with the same path-length mean can give the same length, which does not mean they had the same cascades.
- In each of the three post-change runs (sweep, run 1, run 2) the GIF was within half a frame delay of its own WAV, which is the property this work is about.
- The WAV in hydrogen/output/ is now run 2's (53.587 s).

### 2. "GENTS.md" in the files list

- Command: `find . -name "GENTS.md" -not -path "./.git/*"` from the repository root returned no files.
- No stray file exists, so nothing was removed.
- Cause: the report generator stripped the whole `git status --short` output, which removed the leading space of the first line (" M AGENTS.md"), and then cut the first three characters, which dropped the "A".
- The entry was the root AGENTS.md, and the files list above now reads `AGENTS.md` (modified).

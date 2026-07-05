#!/usr/bin/env wolframscript
(* experiments.wl — curated preset runs for scattering/
   Each block can be copied to a terminal and run directly.

   All runs write to scattering/output/.
   Estimated wall-clock per run: 5-40 seconds (NDSolve/sampling + GIF).
*)

$app = "wolframscript -file " <>
       FileNameJoin[{DirectoryName[$InputFileName], "main.wl"}] <> " --";

(* ── 1. Scatter, default (moderate, b=1.0, theta=90 deg) ────────── *)
Run[$app <> " --simulation.mode=scatter"];

(* ── 2. Scatter, glancing (b=5.0, small deflection) ──────────────── *)
Run[$app <> " --simulation.mode=scatter --simulation.scattering.preset=glancing"];

(* ── 3. Scatter, near head-on (b=0.1, ~169 deg) ──────────────────── *)
Run[$app <> " --simulation.mode=scatter --simulation.scattering.preset=headon"];

(* ── 4. Scatter, perfect backscatter (b=0.0, 180 deg) ────────────── *)
(* Purely radial motion -- the cleanest possible approach-peak-retreat
   audio shape, and the historically decisive case: a particle that
   bounces straight back is impossible under the Thomson model. *)
Run[$app <> " --simulation.mode=scatter --simulation.scattering.preset=backscatter"];

(* ── 5. Scatter, custom impact parameter ─────────────────────────── *)
Run[$app <> " --simulation.mode=scatter --simulation.scattering.b=2.0"];

(* ── 6. Distribution, default (200 particles, b_max=8.0) ─────────── *)
Run[$app <> " --simulation.mode=distribution"];

(* ── 7. Distribution, larger beam ────────────────────────────────── *)
Run[$app <> " --simulation.mode=distribution --simulation.scattering.n_particles=500"];

(* ── 8. Distribution, wider beam (rarer backscatter events) ──────── *)
Run[$app <> " --simulation.mode=distribution --simulation.scattering.b_max=12.0"];

(* ── 9. Discovery, default (Thomson vs Rutherford, 100 per model) ── *)
(* The historically decisive comparison: the Thomson (left) channel
   never produces a large-angle event; the Rutherford (right) channel
   does -- audibly, not just statistically. *)
Run[$app <> " --simulation.mode=discovery"];

(* ── 10. Discovery, wider beam (fewer but still present outliers) ── *)
Run[$app <> " --simulation.mode=discovery --simulation.scattering.b_max=12.0"];

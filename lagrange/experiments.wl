#!/usr/bin/env wolframscript
(* experiments.wl — curated preset runs for lagrange/
   Each block can be copied to a terminal and run directly.

   All runs write to lagrange/output/.
   Estimated wall-clock per run: 15-90 seconds (NDSolve + GIF).
*)

$app = "wolframscript -file " <>
       FileNameJoin[{DirectoryName[$InputFileName], "main.wl"}] <> " --";

(* ── 1. L4 libration, Sun-Jupiter (default) ────────────────────── *)
(* Small perturbation, 6 orbital periods.  Stable tadpole orbit. *)
Run[$app <> " --simulation.mode=l4"];

(* ── 2. L5 libration, Sun-Jupiter ──────────────────────────────── *)
(* Mirror of experiment 1 — same dynamics by symmetry. *)
Run[$app <> " --simulation.mode=l5"];

(* ── 3. L1 escape, Sun-Jupiter (default) ───────────────────────── *)
(* Saddle point: particle departs on unstable manifold. *)
Run[$app <> " --simulation.mode=l1"];

(* ── 4. L4 libration, Earth-Moon system ────────────────────────── *)
(* mu = 0.01215 (much larger) — libration orbit stays bounded but more asymmetric. *)
Run[$app <> " --simulation.mode=l4 --simulation.lagrange.preset=earth_moon"];

(* ── 5. L1 escape, Earth-Moon system ───────────────────────────── *)
(* Larger mu shifts L1 closer to Moon, escape dynamics differ. *)
Run[$app <> " --simulation.mode=l1 --simulation.lagrange.preset=earth_moon"];

(* ── 6. L4 libration, large perturbation ───────────────────────── *)
(* pert=0.12 — near the edge of the Hill stability region.
   Orbit is a larger horseshoe; check c3Pass for bounded libration. *)
Run[$app <> " --simulation.mode=l4 --simulation.lagrange.perturbation=0.12"];

(* ── 7. L4 libration, Sun-Jupiter, extended (12 periods) ───────── *)
(* Longer run to see slow precession of the guiding centre. *)
Run[$app <> " --simulation.mode=l4 --simulation.lagrange.duration_periods=12"];

(* ── 8. L4 libration, Sun-Earth system ─────────────────────────── *)
(* mu = 3.003e-6, very small.  L4 almost exactly at (1/2, sqrt(3)/2).
   Demonstrates the near-equilateral geometry of Earth's Trojan region. *)
Run[$app <> " --simulation.mode=l4 --simulation.lagrange.preset=sun_earth"];

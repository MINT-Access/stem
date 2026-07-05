#!/usr/bin/env wolframscript
(* experiments.wl — curated preset runs for resonance/
   Each block can be copied to a terminal and run directly.

   All runs write to resonance/output/.
   Estimated wall-clock per run: 5-25 seconds (synthesis + GIF).
*)

$app = "wolframscript -file " <>
       FileNameJoin[{DirectoryName[$InputFileName], "main.wl"}] <> " --";

(* ── 1. Galilean, default (8 Ganymede periods) ───────────────────── *)
Run[$app <> " --simulation.mode=galilean"];

(* ── 2. Galilean, shorter (4 Ganymede periods) ───────────────────── *)
Run[$app <> " --simulation.mode=galilean --simulation.resonance.n_periods=4"];

(* ── 3. Galilean, longer (16 Ganymede periods, more repetitions) ─── *)
Run[$app <> " --simulation.mode=galilean --simulation.resonance.n_periods=16"];

(* ── 4. Kirkwood, default (5 resonance gaps, 0.05 AU width) ──────── *)
Run[$app <> " --simulation.mode=kirkwood"];

(* ── 5. Kirkwood, narrower gaps (sharper silences) ───────────────── *)
Run[$app <> " --simulation.mode=kirkwood --simulation.resonance.gap_width_AU=0.02"];

(* ── 6. Kirkwood, wider gaps (softer, broader dips) ──────────────── *)
Run[$app <> " --simulation.mode=kirkwood --simulation.resonance.gap_width_AU=0.1"];

(* ── 7. Saturn, default (Cassini Division + Encke gap) ───────────── *)
Run[$app <> " --simulation.mode=saturn"];

(* ── 8. Saturn, finer resolution sweep ───────────────────────────── *)
Run[$app <> " --simulation.mode=saturn --simulation.resonance.n_steps=500"];

(* ── 9. Kirkwood, finer resolution sweep ─────────────────────────── *)
Run[$app <> " --simulation.mode=kirkwood --simulation.resonance.n_steps=400"];

(* ── 10. Galilean, --config-dump (verify merged config) ──────────── *)
Run[$app <> " --config-dump"];

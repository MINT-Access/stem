#!/usr/bin/env wolframscript
(* experiments.wl — curated preset runs for resonance/
   Each run is loaded in this kernel with stem-core STEMRunApp (as
   demo.wl does) and followed by one sentence saying what it wrote.
   Run: wolframscript -file resonance/experiments.wl

   All runs write to resonance/output/.
   Estimated wall-clock per run: 5-25 seconds (synthesis + GIF).
*)

$CharacterEncoding = "UTF8";
$experimentsRoot = DirectoryName[$InputFileName];
Get[FileNameJoin[{$experimentsRoot, "..", "stem-core", "init.wl"}]];

$experimentRuns = {

  (* ── 1. Galilean, default (8 Ganymede periods) ───────────────────── *)
  {"Galilean, default (8 Ganymede periods)", {"--simulation.mode=galilean"}},

  (* ── 2. Galilean, shorter (4 Ganymede periods) ───────────────────── *)
  {"Galilean, shorter (4 Ganymede periods)", {"--simulation.mode=galilean", "--simulation.resonance.n_periods=4"}},

  (* ── 3. Galilean, longer (16 Ganymede periods, more repetitions) ─── *)
  {"Galilean, longer (16 Ganymede periods, more repetitions)", {"--simulation.mode=galilean", "--simulation.resonance.n_periods=16"}},

  (* ── 4. Kirkwood, default (5 resonance gaps, 0.05 AU width) ──────── *)
  {"Kirkwood, default (5 resonance gaps, 0.05 AU width)", {"--simulation.mode=kirkwood"}},

  (* ── 5. Kirkwood, narrower gaps (sharper silences) ───────────────── *)
  {"Kirkwood, narrower gaps (sharper silences)", {"--simulation.mode=kirkwood", "--simulation.resonance.gap_width_AU=0.02"}},

  (* ── 6. Kirkwood, wider gaps (softer, broader dips) ──────────────── *)
  {"Kirkwood, wider gaps (softer, broader dips)", {"--simulation.mode=kirkwood", "--simulation.resonance.gap_width_AU=0.1"}},

  (* ── 7. Saturn, default (Cassini Division + Encke gap) ───────────── *)
  {"Saturn, default (Cassini Division + Encke gap)", {"--simulation.mode=saturn"}},

  (* ── 8. Saturn, finer resolution sweep ───────────────────────────── *)
  {"Saturn, finer resolution sweep", {"--simulation.mode=saturn", "--simulation.resonance.n_steps=500"}},

  (* ── 9. Kirkwood, finer resolution sweep ─────────────────────────── *)
  {"Kirkwood, finer resolution sweep", {"--simulation.mode=kirkwood", "--simulation.resonance.n_steps=400"}},

  (* ── 10. Galilean, --config-dump (verify merged config) ──────────── *)
  {"Galilean, --config-dump (verify merged config)", {"--config-dump"}}
};

Exit[STEMRunExperiments[$experimentsRoot, $experimentRuns]];

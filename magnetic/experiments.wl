#!/usr/bin/env wolframscript
(* experiments.wl — curated preset runs for magnetic/
   Each run is loaded in this kernel with stem-core STEMRunApp (as
   demo.wl does) and followed by one sentence saying what it wrote.
   Run: wolframscript -file magnetic/experiments.wl

   All runs write to magnetic/output/.
   Estimated wall-clock per run: 10-60 seconds (NDSolve + GIF).
*)

$CharacterEncoding = "UTF8";
$experimentsRoot = DirectoryName[$InputFileName];
Get[FileNameJoin[{$experimentsRoot, "..", "stem-core", "init.wl"}]];

$experimentRuns = {

  (* ── 1. Cyclotron, default (pure circular orbit) ───────────────── *)
  (* B_z=1, charge_mass_ratio=1 -> omega_c=1, T_c=2*Pi. Steady tone. *)
  {"Cyclotron, default (pure circular orbit)", {"--simulation.mode=cyclotron"}},

  (* ── 2. Cyclotron, helix (v_parallel != 0) ─────────────────────── *)
  (* Same perpendicular motion, but drifts along z -- slow pitch glide
     superimposed on the steady cyclotron tone. *)
  {"Cyclotron, helix (v_parallel != 0)", {"--simulation.mode=cyclotron", "--simulation.magnetic.v_parallel=0.5"}},

  (* ── 3. Cyclotron, stronger field ──────────────────────────────── *)
  (* B_z=2 doubles omega_c -- an octave higher, and half the period. *)
  {"Cyclotron, stronger field", {"--simulation.mode=cyclotron", "--simulation.magnetic.B_z=2.0"}},

  (* ── 4. E x B drift, default ────────────────────────────────────── *)
  (* E_x=0.5, B_z=1 -> drift velocity magnitude 0.5. Classic cycloid. *)
  {"E x B drift, default", {"--simulation.mode=drift"}},

  (* ── 5. E x B drift, faster ─────────────────────────────────────── *)
  (* E_x=1.0 doubles the drift speed -- the stereo pan sweeps twice as fast. *)
  {"E x B drift, faster", {"--simulation.mode=drift", "--simulation.magnetic.E_x=1.0"}},

  (* ── 6. Magnetic mirror, default (trapped particle) ────────────── *)
  (* v_perp=1.5, v_parallel=0.8 -> sin^2(theta_0) ~ 0.78 > 0.1: trapped.
     Several bounces audible within the 30 time-unit window. *)
  {"Magnetic mirror, default (trapped particle)", {"--simulation.mode=mirror"}},

  (* ── 7. Magnetic mirror, stronger (steeper gradient) ───────────── *)
  (* alpha=1.0 -- shorter, steeper mirror; bounces come faster. *)
  {"Magnetic mirror, stronger (steeper gradient)", {"--simulation.mode=mirror", "--simulation.magnetic.alpha=1.0"}},

  (* ── 8. Magnetic mirror, escaping particle ─────────────────────── *)
  (* Mostly-parallel initial velocity (small pitch angle) -- sin^2(theta_0)
     falls below the 0.1 trapping threshold, so the particle escapes.
     Uses a gentler gradient (alpha=0.08) than the default: shallow-pitch
     trajectories cross the mirror region quickly, and a steep gradient
     there would violate the adiabatic-invariant assumption the trapping
     formula itself relies on (see AGENTS.md design decision 9). *)
  {"Magnetic mirror, escaping particle", {"--simulation.mode=mirror", "--simulation.magnetic.v_perp=0.4", "--simulation.magnetic.v_parallel=2.0", "--simulation.magnetic.alpha=0.08"}},

  (* ── 9. Multi-particle chord, default ───────────────────────────── *)
  (* Proton (A2, 110 Hz, left), alpha (A1, 55 Hz, centre),
     electron (A5, 880 Hz, right, frequency-scaled). *)
  {"Multi-particle chord, default", {"--simulation.mode=multi"}},

  (* ── 10. Multi-particle chord, higher base pitch ───────────────── *)
  (* base_freq_hz=220 shifts the whole chord up an octave. *)
  {"Multi-particle chord, higher base pitch", {"--simulation.mode=multi", "--simulation.magnetic.base_freq_hz=220"}}
};

Exit[STEMRunExperiments[$experimentsRoot, $experimentRuns]];

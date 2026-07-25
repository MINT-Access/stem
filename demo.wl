#!/usr/bin/env wolframscript

(* ================================================================
   demo.wl  —  STEM project showcase and regression test

   Runs all 29 apps with their most compelling presets, collects
   all outputs into demo/, and writes demo/demo-report.md.

   Each app is loaded inline via Get+Block rather than spawning
   a child wolframscript process — this avoids license conflicts
   that arise when a running kernel tries to launch a second one.

   Usage:
     wolframscript -file demo.wl                        full run
     STEM_SPEAK=1 wolframscript -file demo.wl           with speech
     NASA_API_KEY=... wolframscript -file demo.wl       include asteroids
     wolframscript -file demo.wl -- --check-only        verify previous run
   ================================================================ *)

(* ── Load stem-core (outer demo context) ─────────────────────── *)
$demoProjectRoot = DirectoryName[$InputFileName];
$stemCoreRoot    = FileNameJoin[{$demoProjectRoot, "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

(* ── CLI ─────────────────────────────────────────────────────── *)
$demoRawArgs  = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$checkOnly    = MemberQ[$demoRawArgs, "--check-only"];

(* ── Demo output directory ───────────────────────────────────── *)
$demoDir = FileNameJoin[{$demoProjectRoot, "demo"}];
If[!DirectoryQ[$demoDir], CreateDirectory[$demoDir]];

(* ── Helpers ─────────────────────────────────────────────────── *)

FormatBytes[n_Integer] :=
  Which[
    n >= 1024^2, ToString[Round[n / 1024.0^2, 0.1]] <> " MB",
    n >= 1024,   ToString[Round[n / 1024.0,   0.1]] <> " KB",
    True,        ToString[n] <> " B"
  ];
FormatBytes[_] := "0 B";

TruncPad[s_String, n_Integer] :=
  StringPadRight[
    If[StringLength[s] > n, StringTake[s, n - 1] <> "\[Ellipsis]", s],
    n];

(* ── App definitions ─────────────────────────────────────────── *)
(* cliArgs    — $ScriptCommandLine value while loading the app's main.wl
                (first element is the script name; remaining are the CLI args)
   expected   — output paths relative to <app>/ checked for existence
   listenFor  — one-line audio guide for the report *)

$demoApps = {
  <|
    "name"      -> "pendulum",
    "preset"    -> "double pendulum, chaotic initial angles",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=double"},
    "expected"  -> {"output/double_audio.wav",
                    "output/double_animation.gif",
                    "output/double_results.csv"},
    "listenFor" -> "Two bobs in binaural stereo — hear chaotic divergence between channels"
  |>,
  <|
    "name"      -> "lorenz",
    "preset"    -> "Rossler attractor, 40 s",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=rossler"},
    "expected"  -> {"output/rossler_audio.wav",
                    "output/rossler_animation.gif",
                    "output/rossler_trajectory.csv"},
    "listenFor" -> "Melodic chaos — smoother than Lorenz, almost improvisational but never repeating"
  |>,
  <|
    "name"      -> "dynamical",
    "preset"    -> "logistic map sweep, r 2.5 to 4.0, period-doubling route to chaos",
    "cliArgs"   -> {"main.wl", "--", "--simulation.dynamical.r_steps=150"},
    "expected"  -> {"output/sweep_audio.wav",
                    "output/sweep.gif",
                    "output/sweep_data.csv"},
    "listenFor" -> "The rhythm doubling at r=3, doubling again, dissolving into chaos near " <>
                   "r=3.57, then a surprising return to a clean three-note rhythm at the " <>
                   "period-3 window near r=3.83"
  |>,
  <|
    "name"      -> "dynamical",
    "preset"    -> "logistic map iterate, r=3.830 (period-3 window)",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=iterate",
                    "--simulation.dynamical.preset=period3_window"},
    "expected"  -> {"output/iterate_audio.wav",
                    "output/iterate.gif",
                    "output/iterate_data.csv"},
    "listenFor" -> "A clean, repeating three-note rhythm \[LongDash] the period-3 window, a " <>
                   "surprising island of order inside the chaotic region, heard here by " <>
                   "iterating the map at a single fixed r rather than sweeping through it"
  |>,
  <|
    "name"      -> "henon",
    "preset"    -> "attractor mode, canonical a=1.4, b=0.3",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/henon_attractor.wav",
                    "output/henon_attractor.gif",
                    "output/henon_attractor.png",
                    "output/henon_attractor.csv"},
    "listenFor" -> "The Hénon map's strange attractor \[LongDash] Michel Hénon's simplified " <>
                   "model of a Poincar\[EAcute] section through the Lorenz attractor. Pan " <>
                   "tracks x, pitch tracks y, and accent tones mark each turning point where " <>
                   "the trajectory folds back on itself"
  |>,
  <|
    "name"      -> "asteroids",
    "preset"    -> "last 7 days, live NASA data with orbital elements",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {},  (* date-stamped filenames vary; verified by checking output/ contents *)
    "listenFor" -> "Each asteroid is one note — pitch = miss distance, bright timbre = hazardous"
  |>,
  <|
    "name"      -> "lagrange",
    "preset"    -> "L4 libration, Sun-Jupiter \[Mu]=0.000954, 6 orbital periods",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=l4"},
    "expected"  -> {"output/l4_audio.wav", "output/l4.gif",
                    "output/l4.png", "output/l4_trajectory.csv"},
    "listenFor" -> "l4_audio.wav \[LongDash] pitch follows angular velocity as the test " <>
                   "particle librates around Jupiter's L4 Trojan point; pan sweeps with " <>
                   "x-position in the co-rotating frame; accent tones mark each closest approach"
  |>,
  (* Inserted immediately after "lagrange" per its build spec's own
     instruction -- not literally "before asteroids" as that spec text
     also said, since "asteroids" already sits earlier in this array
     (position 5, before "lagrange" at position 6); the same kind of
     "before X" mismatch bayes/thermo/montecarlo/magnetic's own build
     notes hit, resolved the same way (see docs/PRE_RELEASE_REFINEMENTS.md). *)
  <|
    "name"      -> "resonance",
    "preset"    -> "galilean moons, 4:2:1 Laplace resonance, 8 Ganymede periods",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/galilean_audio.wav",
                    "output/galilean.gif",
                    "output/galilean_data.csv"},
    "listenFor" -> "galilean_audio.wav \[LongDash] Ganymede plays C3, Europa plays C4, Io " <>
                   "plays C5 \[LongDash] a two-octave chord locked in place by gravity for " <>
                   "billions of years; count exactly 4 Io notes and 2 Europa notes between " <>
                   "each Ganymede note"
  |>,
  <|
    "name"      -> "cellular",
    "preset"    -> "Game of Life, R-pentomino (300 generations)",
    "cliArgs"   -> {"main.wl", "--", "--simulation.life.starting_pattern=rpentomino"},
    "expected"  -> {"output/life_rpentomino_audio.wav",
                    "output/life_rpentomino_animation.gif",
                    "output/life_rpentomino_stats.csv"},
    "listenFor" -> "Five cells grow chaotically for 300 generations — hear population rise and settle"
  |>,
  <|
    "name"      -> "signal",
    "preset"    -> "chord mode (C major, Fourier analysis + narrative WAV)",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=chord"},
    "expected"  -> {"output/chord_clean.wav", "output/chord_noisy.wav",
                    "output/chord_recovered.wav", "output/chord_narrative_full.wav"},
    "listenFor" -> "chord_narrative_full.wav — spoken guide to Fourier analysis; " <>
                   "hear the chord buried in noise then recovered by the DFT"
  |>,
  <|
    "name"      -> "waves",
    "preset"    -> "ripple mode, 6 listening points, circular membrane",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=ripple"},
    "expected"  -> {"output/ripple_audio.wav",
                    "output/ripple.gif",
                    "output/ripple.png",
                    "output/ripple_data.csv"},
    "listenFor" -> "ripple_audio.wav \[LongDash] four wavefront arrivals sweep left-to-right " <>
                   "in stereo as the expanding ring reaches each listening point in sequence; " <>
                   "reflected waves return from the boundary shortly after"
  |>,
  (* Inserted immediately after "waves" per its build spec's own instruction --
     not literally "before pendulum" as that spec text also said, since
     "pendulum" already sits first in this array (before "waves" at position
     10); same "before X" mismatch resonance/lagrange/bayes/thermo/montecarlo/
     magnetic's own build notes hit, resolved the same way (see
     docs/PRE_RELEASE_REFINEMENTS.md and the "resonance" entry's comment above). *)
  <|
    "name"      -> "fluid",
    "preset"    -> "Karman vortex street, Re=150, Strouhal frequency sonified",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/karman_audio.wav",
                    "output/karman.gif",
                    "output/karman_data.csv"},
    "listenFor" -> "karman_audio.wav \[LongDash] a steady tone at the Strouhal frequency with " <>
                   "clicks alternating 330 Hz / 220 Hz marking each vortex shed from the top and " <>
                   "bottom of the cylinder -- the same pitch a wire or flagpole sings in the wind"
  |>,
  <|
    "name"      -> "quantum",
    "preset"    -> "QHO coherent state, alpha=3.0 (large amplitude)",
    "cliArgs"   -> {"main.wl", "--", "--simulation.qho.alpha=3.0"},
    "expected"  -> {"output/qho_audio.wav", "output/qho_density.gif"},
    "listenFor" -> "Smooth sinusoidal pitch — the quantum wave packet riding the harmonic potential"
  |>,
  <|
    "name"      -> "qubit",
    "preset"    -> "rabi mode, continuous Rabi oscillation, Omega=1.5",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=rabi"},
    "expected"  -> {"output/qubit_rabi.wav",
                    "output/qubit_rabi.png",
                    "output/qubit_rabi.csv"},
    "listenFor" -> "qubit_rabi.wav \[LongDash] a continuously bending pitch tracing " <>
                   "P(1)(t) = sin^2(\[CapitalOmega]t/2) \[LongDash] the oscillation " <>
                   "rate itself made audible, the same driven two-level system quantum/'s own " <>
                   "coherent state sonifies from a different angle"
  |>,
  <|
    "name"      -> "bell",
    "preset"    -> "chsh mode, derived-optimal angles, S=2*Sqrt[2]",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=chsh"},
    "expected"  -> {"output/bell_chsh.wav",
                    "output/bell_chsh.gif",
                    "output/bell_chsh.png",
                    "output/bell_chsh.csv"},
    "listenFor" -> "bell_chsh.wav \[LongDash] four notes build up the CHSH value term by term, " <>
                   "then a sustained two-tone verdict \[LongDash] left holds the classical " <>
                   "limit (S=2), right holds the actual measured S (2.83) \[LongDash] the " <>
                   "audible gap is Bell's theorem, the result that won the 2022 Nobel Prize " <>
                   "in Physics"
  |>,
  <|
    "name"      -> "hydrogen",
    "preset"    -> "full emission spectrum, n=2 to n=8, chord then UV-to-IR sweep",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=spectrum"},
    "expected"  -> {"output/spectrum_audio.wav",
                    "output/spectrum.gif",
                    "output/spectrum_data.csv"},
    "listenFor" -> "spectrum_audio.wav — the chord of all 28 lines first, then a sweep from " <>
                   "ultraviolet through the four bell-marked Balmer lines (the actual colour " <>
                   "of hydrogen) to infrared; the same Rydberg formula behind every hydrogen " <>
                   "spectrum ever measured, in any star or lab"
  |>,
  <|
    "name"      -> "thermo",
    "preset"    -> "Maxwell-Boltzmann distribution sweep, helium, 100K to 1000K",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=distribution",
                    "--simulation.thermo.preset=helium"},
    "expected"  -> {"output/distribution_audio.wav",
                    "output/distribution.gif",
                    "output/distribution_data.csv"},
    "listenFor" -> "The spectrum broadening and rising in pitch as temperature climbs from " <>
                   "100K to 1000K, with a soft triple-tap at each step marking the most " <>
                   "probable, mean, and RMS speeds"
  |>,
  <|
    "name"      -> "montecarlo",
    "preset"    -> "2D Ising model sweep, 32x32 lattice, T 4.0 to 0.5",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=sweep"},
    "expected"  -> {"output/sweep_audio.wav",
                    "output/sweep.gif",
                    "output/sweep_data.csv"},
    "listenFor" -> "The loudest, most turbulent moment of the sweep is the phase transition " <>
                   "itself — the system crossing from disordered noise into a steady, " <>
                   "high-pitched ferromagnetic tone as it cools through T_c \[TildeEqual] 2.269"
  |>,
  <|
    "name"      -> "magnetic",
    "preset"    -> "magnetic mirror, trapped particle bouncing between reflection points",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=mirror"},
    "expected"  -> {"output/mirror_audio.wav",
                    "output/mirror.gif",
                    "output/mirror_data.csv"},
    "listenFor" -> "mirror_audio.wav \[LongDash] pitch rises as the particle approaches each " <>
                   "mirror point and falls as it retreats, with a sharp accent at every " <>
                   "reflection \[LongDash] the same physics that traps solar-wind particles " <>
                   "in Earth's Van Allen belts"
  |>,
  (* Inserted immediately after "magnetic" per its build spec's own
     instruction -- not literally "before resonance" as an alternate
     spec text suggested, since "resonance" already sits earlier in
     this array (position 7, before "magnetic" at position 16); same
     "before X" mismatch resonance/fluid/bayes/thermo/montecarlo/
     magnetic's own build notes hit, resolved the same way (see
     docs/PRE_RELEASE_REFINEMENTS.md). "before primes" (the spec's own
     fallback) IS honoured literally: "primes" already immediately
     follows "magnetic" here. *)
  <|
    "name"      -> "scattering",
    "preset"    -> "Rutherford scattering discovery mode, Thomson vs Rutherford binaural comparison",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=discovery"},
    "expected"  -> {"output/discovery_audio.wav",
                    "output/discovery.gif",
                    "output/discovery_data.csv"},
    "listenFor" -> "discovery_audio.wav \[LongDash] binaural: left channel Thomson (quiet, " <>
                   "confined to under one degree), right channel Rutherford (same background " <>
                   "plus rare loud backscatter events) \[LongDash] the 1909-1911 experiment " <>
                   "that discovered the atomic nucleus"
  |>,
  <|
    "name"      -> "primes",
    "preset"    -> "prime gap rhythm, 5000 primes",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=gaps"},
    "expected"  -> {"output/gaps_audio.wav", "output/gaps_slow.wav",
                    "output/gaps_animation.gif", "output/gaps_stats.csv"},
    "listenFor" -> "gaps_slow.wav at quarter tempo — twin-prime pairs as double-attacks; " <>
                   "large gaps leave audible rests"
  |>,
  <|
    "name"      -> "bayes",
    "preset"    -> "coin bias inference, theta_true=0.7, 100 flips (uniform prior)",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/coin_audio.wav", "output/coin.gif", "output/coin_data.csv"},
    "listenFor" -> "coin_audio.wav \[LongDash] the sound begins broad, every bias equally " <>
                   "plausible, then narrows to a focused tone as 100 flips accumulate \[LongDash] " <>
                   "probability updating made directly audible"
  |>,
  <|
    "name"      -> "images",
    "preset"    -> "brightness mode, 2D Gaussian test image (64x64)",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=brightness"},
    "expected"  -> {"output/images_brightness_audio.wav",
                    "output/images_brightness.gif",
                    "output/images_brightness_data.csv"},
    "listenFor" -> "A smooth sweep from low pitch (dark edges) to high pitch " <>
                   "(bright Gaussian peak) \[LongDash] the Hilbert curve makes " <>
                   "spatially adjacent pixels adjacent in time"
  |>,
  <|
    "name"      -> "relativity",
    "preset"    -> "GW150914 chirp, 36+29 solar masses, 4x time stretch",
    "cliArgs"   -> {"main.wl", "--", "--simulation.chirp.preset=gw150914",
                    "--sonification.chirp.time_stretch=4"},
    "expected"  -> {"output/chirp.wav", "output/chirp.gif"},
    "listenFor" -> "chirp.wav — rising pitch and amplitude, abrupt merger, fading ringdown; " <>
                   "this is what LIGO heard on 14 September 2015"
  |>,
  <|
    "name"      -> "cosmology",
    "preset"    -> "CMB acoustic peaks, spectrum mode, simulated LCDM",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=spectrum",
                    "--simulation.cosmology.source=simulated"},
    "expected"  -> {"output/cmb_spectrum_audio.wav",
                    "output/cmb_spectrum.png",
                    "output/cmb_spectrum_data.csv"},
    "listenFor" -> "cmb_spectrum_audio.wav — hear the Sachs-Wolfe plateau give way " <>
                   "to the first acoustic peak swell at l\[TildeEqual]220, then the " <>
                   "second and third harmonics fading into the Silk damping tail"
  |>,
  <|
    "name"      -> "blackbody",
    "preset"    -> "Planck spectrum, solar T=5778K, chord then radio-to-X-ray sweep",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/spectrum_audio.wav",
                    "output/spectrum.gif",
                    "output/spectrum.png",
                    "output/spectrum_data.csv"},
    "listenFor" -> "spectrum_audio.wav \[LongDash] the full radio-to-X-ray curve as a single " <>
                   "chord, two soft taps marking the narrow visible-light window, then a " <>
                   "sweep through the same curve one bin at a time \[LongDash] notice how " <>
                   "briefly the taps land relative to the whole sweep"
  |>,
  <|
    "name"      -> "compton",
    "preset"    -> "Compton scattering, discovery mode, Thomson vs Compton binaural",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=discovery"},
    "expected"  -> {"output/discovery_audio.wav",
                    "output/discovery.png",
                    "output/discovery_data.csv"},
    "listenFor" -> "discovery_audio.wav \[LongDash] binaural: left channel Thomson (flat, no " <>
                   "shift at any angle), right channel Compton (pitch measurably drops as " <>
                   "angle increases) \[LongDash] the 1923 measurement that decided the " <>
                   "wave/particle debate"
  |>,
  <|
    "name"      -> "quantum_tunnelling",
    "preset"    -> "barrier, default preset, electron at 1eV vs a 2eV barrier",
    "cliArgs"   -> {"main.wl"},
    "expected"  -> {"output/barrier_audio.wav",
                    "output/barrier.gif",
                    "output/barrier.png",
                    "output/barrier_data.csv"},
    "listenFor" -> "barrier_audio.wav \[LongDash] incoming tone, a marker click at the barrier, " <>
                   "then a reflected tone and a transmitted tone sounding simultaneously, loud " <>
                   "in proportion to probability \[LongDash] a classically impossible crossing, " <>
                   "made audible"
  |>,
  <|
    "name"      -> "clt",
    "preset"    -> "dice mode, sum of up to 10 fair six-sided dice",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=dice"},
    "expected"  -> {"output/dice_audio.wav",
                    "output/dice.gif",
                    "output/dice.png",
                    "output/dice_data.csv"},
    "listenFor" -> "dice_audio.wav \[LongDash] a single die's flat, jagged, six-outcome sound " <>
                   "smoothing into an unmistakable bell shape purely from summing more dice " <>
                   "\[LongDash] the Central Limit Theorem's most recognisable illustration"
  |>,
  <|
    "name"      -> "brownian",
    "preset"    -> "ensemble mode, 150 walkers, sqrt(t) law",
    "cliArgs"   -> {"main.wl", "--", "--simulation.mode=ensemble"},
    "expected"  -> {"output/brownian_ensemble.wav",
                    "output/brownian_ensemble.png",
                    "output/brownian_ensemble.csv"},
    "listenFor" -> "brownian_ensemble.wav \[LongDash] a single rising tone tracking the ensemble's " <>
                   "average distance from the origin, its climb visibly slowing over time " <>
                   "\[LongDash] displacement growing as the square root of time, not linearly, the " <>
                   "same running-sum-of-random-steps setup as clt/, here embodied in real 2D space"
  |>
};

$nTotal      = Length[$demoApps];
$nUniqueApps = Length[DeleteDuplicates[Map[#["name"] &, $demoApps]]];

(* ── Announce ────────────────────────────────────────────────── *)
Print[""];
STEMHeading["STEM Demo \[LongDash] " <> If[$checkOnly, "Check Only", "Full Run"]];
Print["  Apps:   ", $nUniqueApps, " (", $nTotal,
      " runs \[LongDash] dynamical runs twice: sweep and period-3 window iterate)"];
Print["  Output: ", $demoDir];
If[$checkOnly,
  Print["  Mode:   --check-only (checking previous run outputs)"],
  Print["  Mode:   full run (inline; each app loaded via Get+Block)"]
];
Print[""];

(* ── Main loop ───────────────────────────────────────────────── *)
(* Open the null sink once so all 8 inline Get calls can share it;
   /dev/null can only be opened once per wolframscript session. *)
$nullSink      = If[!$checkOnly, OpenWrite["/dev/null"], Null];
$demoResults   = {};
$demoStartTime = AbsoluteTime[];

Scan[
  Function[app,
    Module[{
      appName, preset, cliArgs, expected, listenFor,
      appDir, appOutputDir, demoAppDir, demoAppOutputDir, appMainWl,
      t0, duration,
      outputFiles, copiedFiles, fileInfo,
      missing, failed, status, note,
      apiKey, demoFiles
    },

      appName      = app["name"];
      preset       = app["preset"];
      cliArgs      = app["cliArgs"];
      expected     = app["expected"];
      listenFor    = app["listenFor"];
      appDir           = FileNameJoin[{$demoProjectRoot, appName}];
      appOutputDir     = FileNameJoin[{appDir, "output"}];
      demoAppDir       = FileNameJoin[{$demoDir, appName}];
      demoAppOutputDir = FileNameJoin[{demoAppDir, "output"}];
      appMainWl        = FileNameJoin[{appDir, "main.wl"}];

      If[$checkOnly,

        (* ── CHECK-ONLY BRANCH ──────────────────────────────── *)
        STEMHeading["Check: " <> appName];
        demoFiles = If[DirectoryQ[demoAppOutputDir],
          Select[FileNames["*", demoAppOutputDir], !DirectoryQ[#] &],
          {}
        ];
        With[{allOk = Length[demoFiles] > 0 &&
                      AllTrue[demoFiles, FileByteCount[#] > 0 &]},
          status = If[allOk, "PASS", "FAIL"];
          note   = If[allOk,
            ToString[Length[demoFiles]] <> " file(s) in demo/" <> appName <> "/output/",
            "demo/" <> appName <> "/output/ is missing or empty"
          ];
          Print["  ", status, "  ", appName, " \[LongDash] ", note];
          AppendTo[$demoResults,
            <| "name"      -> appName,  "preset"    -> preset,
               "duration"  -> 0,        "exitCode"  -> 0,
               "files"     -> Map[<| "path" -> #, "bytes" -> FileByteCount[#] |> &,
                                  demoFiles],
               "status"    -> status,   "note"      -> note,
               "listenFor" -> listenFor |>]
        ]

      , (* ── FULL-RUN BRANCH ───────────────────────────────── *)

        (* Asteroids: skip if NASA_API_KEY not set *)
        apiKey = If[appName === "asteroids", Environment["NASA_API_KEY"], "ok"];

        If[appName === "asteroids" && (apiKey === $Failed || apiKey === ""),

          (* ── SKIP ─────────────────────────────────────────── *)
          Print["[WARNING] NASA_API_KEY not set \[LongDash] skipping asteroids."];
          Print["[WARNING] Set NASA_API_KEY and re-run to include live asteroid data."];
          AppendTo[$demoResults,
            <| "name" -> appName, "preset" -> preset,
               "duration" -> 0, "exitCode" -> -1,
               "files" -> {}, "status" -> "SKIPPED",
               "note" -> "NASA_API_KEY not set", "listenFor" -> listenFor |>]

        , (* ── RUN INLINE VIA Get + Block ─────────────────── *)

          If[!DirectoryQ[demoAppDir],       CreateDirectory[demoAppDir]];
          If[!DirectoryQ[demoAppOutputDir], CreateDirectory[demoAppOutputDir]];

          Print[""];
          STEMHeading["Demo " <> ToString[Length[$demoResults] + 1] <>
                      "/" <> ToString[$nTotal] <> ": " <> appName];
          Print["  Preset: ", preset];

          failed = False;
          t0     = AbsoluteTime[];

          (* Load the app in a protected Block:
             - $ScriptCommandLine is overridden to match the app's expected CLI
             - $projectRoot and other common globals are shielded from the demo's scope
             - $Output is silenced so app output does not interleave with demo's status lines *)
          Block[{
            $projectRoot, $stemCoreRoot,
            $cliArgs, $rawArgs,
            cfg, mode, params, sol, model,
            $noOrbitalElements,
            $ScriptCommandLine = cliArgs,
            $Output            = {$nullSink}
          },
            Quiet[
              Check[Get[appMainWl], failed = True],
              General::stop
            ]
          ];

          duration = AbsoluteTime[] - t0;

          (* 5-minute warning *)
          If[duration > 300.0,
            Print["  [WARNING] ", appName, " took ",
                  FmtN[duration, {6, 1}], " s (exceeded 5-minute threshold)"]
          ];

          If[failed, Print["  [FAIL] App encountered an error during execution"]];

          (* Verify expected output files *)
          missing = If[Length[expected] === 0,
            {},
            Select[expected,
              (With[{p = FileNameJoin[{appDir, #}]},
                !FileExistsQ[p] || FileByteCount[p] === 0]) &
            ]
          ];

          (* Collect all files from the app's output/ *)
          outputFiles = If[DirectoryQ[appOutputDir],
            Select[FileNames["*", appOutputDir], !DirectoryQ[#] &],
            {}
          ];

          (* Copy to demo/<appname>/output/ — mirrors the structure of a normal run *)
          copiedFiles = {};
          Scan[
            Function[srcFile,
              With[{dest = FileNameJoin[{demoAppOutputDir, FileNameTake[srcFile]}]},
                If[FileExistsQ[dest], DeleteFile[dest]];
                CopyFile[srcFile, dest];
                AppendTo[copiedFiles, dest]
              ]
            ],
            outputFiles
          ];

          fileInfo = Map[(<| "path" -> #, "bytes" -> FileByteCount[#] |>) &, copiedFiles];

          With[{allOk = !failed && Length[missing] === 0},
            status = If[allOk, "PASS", "FAIL"];
            note   = Which[
              failed,              "error during execution",
              Length[missing] > 0, "missing: " <> StringRiffle[FileNameTake /@ missing, ", "],
              True,                ""
            ]
          ];

          Print[""];
          STEMPrintN["Duration",        duration,              "s", {6, 1}];
          STEMPrintN["Files collected", Length[copiedFiles], "",    3];
          Print["  Status: ", status, If[note =!= "", "  (" <> note <> ")", ""]];

          AppendTo[$demoResults,
            <| "name"      -> appName,  "preset"    -> preset,
               "duration"  -> duration, "exitCode"  -> If[failed, 1, 0],
               "files"     -> fileInfo, "status"    -> status,
               "note"      -> note,     "listenFor" -> listenFor |>];

          (* Estimated remaining time *)
          With[{nDone = Length[$demoResults],
                elapsed = AbsoluteTime[] - $demoStartTime},
            If[nDone > 0 && nDone < $nTotal,
              With[{estRem = elapsed / nDone * ($nTotal - nDone)},
                Print["  Estimated remaining: ", FmtN[estRem, {6, 1}],
                      " s  (", $nTotal - nDone, " app(s) left)"]
              ]
            ]
          ]

        ]  (* end skip/run *)
      ]    (* end checkOnly/fullrun *)
    ]      (* end Module *)
  ],       (* end Function *)
  $demoApps
];         (* end Scan *)

If[$nullSink =!= Null, Close[$nullSink]];

(* ── Totals ──────────────────────────────────────────────────── *)
$totalElapsed = AbsoluteTime[] - $demoStartTime;
$nPassed  = Length[Select[$demoResults, #["status"] === "PASS"    &]];
$nFailed  = Length[Select[$demoResults, #["status"] === "FAIL"    &]];
$nSkipped = Length[Select[$demoResults, #["status"] === "SKIPPED" &]];

(* ── Summary table ───────────────────────────────────────────── *)
Print[""];
STEMHeading["Demo Summary"];
Print[""];
$sep = "+-------------+----------------------------------------------+----------+-------+---------+";
Print[$sep];
Print["| App         | Preset                                       | Duration | Files | Status  |"];
Print[$sep];
Scan[
  Function[r,
    With[{
      col1 = TruncPad[r["name"],   11],
      col2 = TruncPad[r["preset"], 44],
      col3 = StringPadLeft[
               If[r["duration"] === 0, "\[LongDash]",
                  With[{d = r["duration"]},
                    ToString[Floor[d]] <> "." <>
                    ToString[Floor[FractionalPart[d] * 10]] <> " s"]], 8],
      col4 = StringPadLeft[ToString[Length[r["files"]]], 5],
      col5 = StringPadLeft[r["status"], 7]
    },
      Print["| ", col1, " | ", col2, " | ", col3, " | ", col4, " | ", col5, "  |"]
    ]],
  $demoResults];
Print[$sep];
Print[""];
Print["Total elapsed:  ", FmtN[$totalElapsed, {7, 1}], " s"];
Print["Passed:         ", $nPassed, "/", $nTotal, " runs (", $nUniqueApps, " unique apps)"];
If[$nFailed  > 0, Print["Failed:         ", $nFailed]];
If[$nSkipped > 0, Print["Skipped:        ", $nSkipped]];

(* ── Write demo/demo-report.md and demo/README.md ────────────── *)
If[!$checkOnly,

  $reportPath = FileNameJoin[{$demoDir, "demo-report.md"}];
  $osVersion  = Switch[$OperatingSystem,
    "MacOSX",
      StringTrim[RunProcess[{"sw_vers", "-productVersion"}, "StandardOutput"]],
    "Unix",
      StringTrim[RunProcess[{"uname", "-sr"}, "StandardOutput"]],
    "Windows",
      StringTrim[RunProcess[{"powershell", "-NoProfile", "-Command",
        "[System.Environment]::OSVersion.VersionString"}, "StandardOutput"]],
    _,
      $SystemID
  ];

  $rl = {};
  rl[s_] := AppendTo[$rl, s];

  rl["# STEM Demo Report"]; rl[""];
  rl["Generated: " <> DateString[]]; rl[""];
  rl["## System"]; rl[""];
  rl["- Wolfram Language: " <> ToString[$VersionNumber]];
  rl["- macOS: " <> $osVersion]; rl[""];
  rl["## Summary"]; rl[""];
  rl["| App | Preset | Duration | Files | Status |"];
  rl["|-----|--------|----------|-------|--------|"];
  Scan[
    Function[r,
      rl["| " <> r["name"] <> " | " <> r["preset"] <> " | " <>
         If[r["duration"] === 0, "\[LongDash]",
            With[{d = r["duration"]},
              ToString[Floor[d]] <> "." <> ToString[Floor[FractionalPart[d] * 10]] <> " s"]] <> " | " <>
         ToString[Length[r["files"]]] <> " | " <>
         Which[r["status"] === "PASS",    "\[Checkmark] PASS",
               r["status"] === "SKIPPED", "\[LongDash] SKIPPED",
               True,                      "\[Times] FAIL"] <> " |"]],
    $demoResults];
  rl[""];
  rl["**Total elapsed:** " <> ToString[Round[$totalElapsed, 0.1]] <> " s  |  " <>
     ToString[$nPassed] <> " passed" <>
     If[$nFailed  > 0, "  |  " <> ToString[$nFailed]  <> " failed",  ""] <>
     If[$nSkipped > 0, "  |  " <> ToString[$nSkipped] <> " skipped", ""]]; rl[""];
  rl["## App Results"]; rl[""];
  Scan[
    Function[r,
      rl["### " <> r["name"]]; rl[""];
      rl["- **Preset:** " <> r["preset"]];
      rl["- **Status:** " <> r["status"]];
      If[r["duration"] =!= 0,
         rl["- **Duration:** " <> ToString[Round[r["duration"], 0.1]] <> " s"]];
      If[r["note"] =!= "", rl["- **Note:** " <> r["note"]]];
      rl["- **Listen for:** " <> r["listenFor"]]; rl[""];
      If[Length[r["files"]] > 0,
        rl["**Output files:**"]; rl[""];
        rl["| File | Size |"]; rl["|------|------|"];
        Scan[Function[f,
               rl["| `" <> FileNameTake[f["path"]] <> "` | " <>
                  FormatBytes[f["bytes"]] <> " |"]],
             r["files"]]; rl[""]]],
    $demoResults];
  rl["## Audio Guide"]; rl[""];
  rl["All audio files are in `demo/<app>/output/`. Play them with:"]; rl[""];
  rl["- macOS: `afplay demo/<app>/output/<file>.wav`"];
  rl["- Linux: `aplay demo/<app>/output/<file>.wav`"];
  rl["- Windows: `Start-Process wmplayer demo\\<app>\\output\\<file>.wav`"]; rl[""];
  rl["```sh"];
  Scan[
    Function[r,
      If[r["status"] === "PASS",
        Scan[Function[f,
               If[StringEndsQ[f["path"], ".wav"],
                  rl["afplay demo/" <> r["name"] <> "/output/" <> FileNameTake[f["path"]]]]],
             r["files"]]]],
    $demoResults];
  rl["```"]; rl[""];
  rl["### Most interesting file per app"]; rl[""];
  Scan[Function[r,
         If[r["status"] === "PASS",
            rl["- **" <> r["name"] <> "**: " <> r["listenFor"]]]],
       $demoResults];
  rl[""];
  rl["## Re-running"]; rl[""];
  rl["```sh"];
  rl["wolframscript -file demo.wl                                    # full run"];
  rl["# macOS / Linux:"];
  rl["NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl         # with asteroids"];
  rl["# Windows PowerShell:"];
  rl["# $env:NASA_API_KEY='your_key'; wolframscript -file demo.wl"];
  rl["wolframscript -file demo.wl -- --check-only                    # verify outputs"];
  rl["```"];
  Export[$reportPath, StringRiffle[$rl, "\n"], "Text"];
  Print[""];
  Print["  Report:  ", $reportPath];

  (* ── demo/README.md ──────────────────────────────────────── *)
  $demoReadmePath = FileNameJoin[{$demoDir, "README.md"}];
  $dl = {};
  dl[s_] := AppendTo[$dl, s];

  dl["# STEM Demo"]; dl[""];
  dl["This directory contains outputs from a single run of `../demo.wl`,"];
  dl["which exercises all 29 STEM apps with their most scientifically and"];
  dl["acoustically compelling presets."]; dl[""];
  dl["Generated: " <> DateString[]]; dl[""];
  dl["## Contents"]; dl[""];
  Scan[Function[r,
         dl["- `" <> r["name"] <> "/` \[LongDash] " <> r["preset"] <>
            If[r["status"] === "PASS",
               " (" <> ToString[Length[r["files"]]] <> " files)",
               " (" <> r["status"] <> ")"]]],
       $demoResults];
  dl["- `demo-report.md` \[LongDash] machine-generated run report"]; dl[""];
  dl["## Recommended listening order"]; dl[""];
  dl["For the best narrative experience, listen in this order:"]; dl[""];
  dl["1. **signal** \[LongDash] `chord_narrative_full.wav`"];
  dl["   A spoken guide that explains Fourier analysis while you hear it happen."];
  dl["   Start here to understand what sonification means before the physics apps."]; dl[""];
  dl["2. **waves** \[LongDash] `ripple_audio.wav`"];
  dl["   The spatial companion to signal: where signal covers the frequency domain,"];
  dl["   waves covers spatial propagation. Four wavefront arrivals sweep left-to-right"];
  dl["   in stereo as an expanding ring crosses each listening point in sequence."]; dl[""];
  dl["3. **fluid** \[LongDash] `karman_audio.wav`"];
  dl["   From waves' conservative, non-dissipative wave equation to viscous,"];
  dl["   dissipative flow: a Karman vortex street at Re=150. A steady tone at the"];
  dl["   Strouhal frequency with clicks alternating top/bottom at each vortex shed \[LongDash]"];
  dl["   the same pitch a wire or flagpole sings in the wind."]; dl[""];
  dl["4. **pendulum** \[LongDash] `double_audio.wav`"];
  dl["   Two pendulum bobs in binaural stereo. Deterministic physics that sounds"];
  dl["   chaotic \[LongDash] the double pendulum cannot be predicted long-term."]; dl[""];
  dl["5. **cellular** \[LongDash] `life_rpentomino_audio.wav`"];
  dl["   The R-pentomino starts with 5 cells and grows chaotically for 300 generations."];
  dl["   Hear population rise, stabilise, and settle."]; dl[""];
  dl["6. **primes** \[LongDash] `gaps_slow.wav`"];
  dl["   5000 prime gaps at quarter tempo. Twin-prime pairs (gap=2) sound as"];
  dl["   near-simultaneous double-attacks; large gaps leave audible rests."]; dl[""];
  dl["7. **bayes** \[LongDash] `coin_audio.wav`"];
  dl["   From number theory to probability: a coin's bias updated flip by flip via"];
  dl["   Bayes' theorem. The sound begins broad and uncertain \[LongDash] every bias"];
  dl["   equally plausible \[LongDash] and narrows to a focused tone as evidence"];
  dl["   accumulates. No differential equations here, just belief updating, heard"];
  dl["   directly."]; dl[""];
  dl["8. **quantum** \[LongDash] `qho_audio.wav`"];
  dl["   A coherent-state wave packet oscillating in a harmonic potential."];
  dl["   Pitch follows mean position \[LongDash] smooth, periodic, and exact."]; dl[""];
  dl["9. **qubit** \[LongDash] `qubit_rabi.wav`"];
  dl["   From a coherent wave packet to the simplest quantum system of all: a single"];
  dl["   qubit driven on resonance. A continuously bending pitch traces"];
  dl["   P(1)(t) = sin^2(\[CapitalOmega]t/2) \[LongDash] the oscillation rate itself made"];
  dl["   audible, the same driven two-level system quantum/ sonifies from a different"];
  dl["   angle."]; dl[""];
  dl["10. **bell** \[LongDash] `bell_chsh.wav`"];
  dl["   From one driven qubit to two entangled ones: four notes build up the CHSH"];
  dl["   value term by term, then a sustained two-tone verdict \[LongDash] left holds"];
  dl["   the classical limit (S=2), right holds the actual measured S (2.83) \[LongDash]"];
  dl["   the audible gap is Bell's theorem, the 2022 Nobel-winning result that no"];
  dl["   local hidden-variable theory can reproduce."]; dl[""];
  dl["11. **scattering** \[LongDash] `discovery_audio.wav`"];
  dl["   Before the atom's internal structure comes the discovery of its nucleus:"];
  dl["   the 1909-1911 Geiger-Marsden experiment, replayed in binaural stereo."];
  dl["   Left channel is Thomson's plum-pudding model (quiet, confined to under one"];
  dl["   degree); right channel is Rutherford's nuclear model (same background plus"];
  dl["   rare loud backscatter events the left channel cannot produce)."]; dl[""];
  dl["12. **hydrogen** \[LongDash] `spectrum_audio.wav`"];
  dl["   From the nucleus to the exact quantum atom built around it: hydrogen's full"];
  dl["   emission spectrum, chord first then a sweep from ultraviolet through the"];
  dl["   four bell-marked Balmer lines \[LongDash] the actual colour of hydrogen \[LongDash]"];
  dl["   to infrared."]; dl[""];
  dl["13. **blackbody** \[LongDash] `spectrum_audio.wav`"];
  dl["   From one atom's discrete spectral lines to the continuous glow every hot"];
  dl["   object emits: Planck's black body curve at the Sun's own temperature,"];
  dl["   chord first then a radio-to-X-ray sweep. Two soft taps mark the narrow"];
  dl["   visible-light window \[LongDash] notice how briefly they land relative to"];
  dl["   the whole sweep."]; dl[""];
  dl["14. **compton** \[LongDash] `discovery_audio.wav`"];
  dl["   From a star's continuous glow to a single photon-electron collision:"];
  dl["   Compton's 1923 measurement, binaural. Left channel is the classical Thomson"];
  dl["   prediction, flat, no shift at any angle; right channel is the real result,"];
  dl["   pitch measurably dropping as angle increases \[LongDash] the gap between them"];
  dl["   is the evidence that decided the wave/particle debate."]; dl[""];
  dl["15. **quantum_tunnelling** \[LongDash] `barrier_audio.wav`"];
  dl["   From one photon-electron collision to a particle crossing a barrier it"];
  dl["   classically cannot cross: an incoming tone, a marker click, then a reflected"];
  dl["   and a transmitted tone sounding simultaneously, loud in proportion to"];
  dl["   probability \[LongDash] not a coin flip, the same wave splitting into two"];
  dl["   real outcomes at once."]; dl[""];
  dl["16. **clt** \[LongDash] `dice_audio.wav`"];
  dl["   From one particle crossing a barrier to the statistics of many dice: the"];
  dl["   Central Limit Theorem's most familiar illustration, a single die's flat,"];
  dl["   jagged sound smoothing into an unmistakable bell shape purely from summing"];
  dl["   more dice \[LongDash] no physics background needed, just probability."]; dl[""];
  dl["17. **brownian** \[LongDash] `brownian_ensemble.wav`"];
  dl["   From an abstract sum of dice to a physical embodiment of the same law: a"];
  dl["   pollen grain's random walk, averaged over 150 walkers. A single rising tone"];
  dl["   whose climb visibly slows over time \[LongDash] displacement growing as the"];
  dl["   square root of time, the observational proof (Einstein, 1905) that atoms"];
  dl["   are real."]; dl[""];
  dl["18. **thermo** \[LongDash] `distribution_audio.wav`"];
  dl["   From dice sums to the statistics of many classical gas"];
  dl["   particles: the Maxwell-Boltzmann speed distribution swept from 100K to"];
  dl["   1000K. Hear the spectrum broaden and rise in pitch as the gas heats up."]; dl[""];
  dl["19. **montecarlo** \[LongDash] `sweep_audio.wav`"];
  dl["   The 2D Ising model's ferromagnetic phase transition, swept from T=4.0"];
  dl["   down through T_c \[TildeEqual] 2.269 to T=0.5. The loudest, most turbulent"];
  dl["   moment of the sweep is the phase transition itself."]; dl[""];
  dl["20. **magnetic** \[LongDash] `mirror_audio.wav`"];
  dl["   A charged particle bouncing inside a magnetic bottle. Pitch rises as it"];
  dl["   approaches each mirror point and falls as it retreats, with a sharp accent"];
  dl["   at every reflection \[LongDash] the same physics that traps solar-wind"];
  dl["   particles in Earth's Van Allen belts."]; dl[""];
  dl["21. **lorenz** \[LongDash] `rossler_audio.wav`"];
  dl["   The R\[ODoubleDot]ssler attractor sonified. More melodic than Lorenz, almost"];
  dl["   improvisational \[LongDash] structured but never repeating."]; dl[""];
  dl["22. **dynamical** \[LongDash] `sweep_audio.wav`"];
  dl["   The logistic map's period-doubling route to chaos. Hear the rhythm double"];
  dl["   at r=3, double again, dissolve into chaos near r=3.57, then snap back into"];
  dl["   a clean three-note rhythm at the period-3 window near r=3.83."]; dl[""];
  dl["23. **henon** \[LongDash] `henon_attractor.wav`"];
  dl["   From a 1D map to a genuinely 2D, invertible one: the H\[EAcute]non attractor,"];
  dl["   Michel H\[EAcute]non's simplified model of a Poincar\[EAcute] section through the"];
  dl["   Lorenz attractor heard a few entries up. Pan tracks x, pitch tracks y, and"];
  dl["   accent tones mark each fold in the fractal structure."]; dl[""];
  dl["24. **asteroids** \[LongDash] any `asteroids_*.wav`"];
  dl["   Each note is one asteroid this week: pitch = miss distance,"];
  dl["   bright timbre = hazardous. Live data, always different."]; dl[""];
  dl["25. **lagrange** \[LongDash] `l4_audio.wav`"];
  dl["   A test particle librating around Jupiter's L4 Trojan point in the Sun-Jupiter"];
  dl["   co-rotating frame. Pitch follows angular velocity; pan sweeps with x-position."];
  dl["   Accent tones mark the libration rhythm. The particle stays bounded \[LongDash]"];
  dl["   the reason real Trojan asteroids exist at L4 and L5 but not L1."]; dl[""];
  dl["26. **resonance** \[LongDash] `galilean_audio.wav`"];
  dl["   From the L4/L5 1:1 resonance to an exact 4:2:1 lock: Io, Europa, and Ganymede"];
  dl["   playing C3, C4, and C5 \[LongDash] a two-octave chord held in place by gravity"];
  dl["   for billions of years. Count 4 Io notes and 2 Europa notes between each"];
  dl["   Ganymede note."]; dl[""];
  dl["27. **images** \[LongDash] `images_brightness_audio.wav`"];
  dl["   A 2D Gaussian cloud sonified via Hilbert curve traversal."];
  dl["   Dark edges map to low pitch; the bright central peak maps to high pitch."];
  dl["   Spatial structure becomes temporal structure \[LongDash] the Hilbert"];
  dl["   locality property means nearby pixels sound nearby in time."]; dl[""];
  dl["28. **relativity** \[LongDash] `chirp.wav`"];
  dl["   Binary black hole merger (GW150914). Rising pitch and amplitude,"];
  dl["   abrupt merger, fading ringdown. This is what LIGO heard on 14 Sep 2015."]; dl[""];
  dl["29. **cosmology** \[LongDash] `cmb_spectrum_audio.wav`"];
  dl["   The CMB angular power spectrum from l=2 to l=2000. Hear the"];
  dl["   Sachs-Wolfe plateau give way to the first acoustic peak (l\[TildeEqual]220),"];
  dl["   then the second and third harmonics fading into the Silk damping tail."];
  dl["   The oldest light in the universe \[LongDash] the Big Bang's afterglow."]; dl[""];
  dl["## Playing audio"]; dl[""];
  dl["From the project root (macOS):"]; dl[""];
  dl["```sh"];
  dl["afplay demo/signal/output/chord_narrative_full.wav"];
  dl["afplay demo/waves/output/ripple_audio.wav"];
  dl["afplay demo/fluid/output/karman_audio.wav"];
  dl["afplay demo/pendulum/output/double_audio.wav"];
  dl["afplay demo/cellular/output/life_rpentomino_audio.wav"];
  dl["afplay demo/primes/output/gaps_slow.wav"];
  dl["afplay demo/bayes/output/coin_audio.wav"];
  dl["afplay demo/quantum/output/qho_audio.wav"];
  dl["afplay demo/qubit/output/qubit_rabi.wav"];
  dl["afplay demo/bell/output/bell_chsh.wav"];
  dl["afplay demo/scattering/output/discovery_audio.wav"];
  dl["afplay demo/hydrogen/output/spectrum_audio.wav"];
  dl["afplay demo/blackbody/output/spectrum_audio.wav"];
  dl["afplay demo/compton/output/discovery_audio.wav"];
  dl["afplay demo/quantum_tunnelling/output/barrier_audio.wav"];
  dl["afplay demo/clt/output/dice_audio.wav"];
  dl["afplay demo/brownian/output/brownian_ensemble.wav"];
  dl["afplay demo/thermo/output/distribution_audio.wav"];
  dl["afplay demo/montecarlo/output/sweep_audio.wav"];
  dl["afplay demo/magnetic/output/mirror_audio.wav"];
  dl["afplay demo/lorenz/output/rossler_audio.wav"];
  dl["afplay demo/dynamical/output/sweep_audio.wav"];
  dl["afplay demo/henon/output/henon_attractor.wav"];
  dl["afplay demo/asteroids/output/*.wav"];
  dl["afplay demo/lagrange/output/l4_audio.wav"];
  dl["afplay demo/resonance/output/galilean_audio.wav"];
  dl["afplay demo/images/output/images_brightness_audio.wav"];
  dl["afplay demo/relativity/output/chirp.wav"];
  dl["afplay demo/cosmology/output/cmb_spectrum_audio.wav"];
  dl["```"]; dl[""];
  dl["Linux: replace `afplay` with `aplay`. " <>
     "Windows PowerShell: `Start-Process wmplayer demo\\signal\\output\\chord_narrative_full.wav`"]; dl[""];
  dl["## Re-running"]; dl[""];
  dl["```sh"];
  dl["# Full demo (re-runs all apps, overwrites this directory)"];
  dl["wolframscript -file demo.wl"]; dl[""];
  dl["# With NASA asteroid data (macOS / Linux)"];
  dl["NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl"]; dl[""];
  dl["# Windows PowerShell"];
  dl["# $env:NASA_API_KEY='your_key'; wolframscript -file demo.wl"]; dl[""];
  dl["# Verify outputs from a previous run without re-running"];
  dl["wolframscript -file demo.wl -- --check-only"];
  dl["```"];
  Export[$demoReadmePath, StringRiffle[$dl, "\n"], "Text"];
  Print["  README:  ", $demoReadmePath]
];

(* ── Final STEMSay ───────────────────────────────────────────── *)
STEMSay[
  "Demo " <> If[$checkOnly, "check", "run"] <> " complete. " <>
  ToString[$nPassed] <> " of " <> ToString[$nTotal] <> " apps passed. " <>
  If[!$checkOnly,
     "Total time: " <> ToString[Round[$totalElapsed, 0.1]] <> " seconds. ",
     ""] <>
  "Outputs in demo/."
];
Print[""];

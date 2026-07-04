#!/usr/bin/env wolframscript

(* ================================================================
   demo_html.wl  —  Accessible HTML demo page generator

   Standalone generator: reads the outputs of a completed `demo.wl`
   run from demo/<app>/output/ and writes a single self-contained,
   offline-capable page: demo/demo.html. Runs no simulations — only
   reads existing files and writes HTML.

   Usage:
     wolframscript -file demo.wl                 run the full demo first
     wolframscript -file demo_html.wl             then generate the page
     open demo/demo.html                          (macOS; xdg-open on
                                                    Linux, start on Windows)

   If outputs for an app are missing or incomplete, a warning is
   printed and the page is generated anyway with a placeholder note
   for that app's content rather than aborting.
   ================================================================ *)

(* ── Load stem-core (for STEMHeading / STEMSection / STEMPrintN etc.) *)
$demoHtmlRoot = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$demoHtmlRoot, "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

$demoDir     = FileNameJoin[{$demoHtmlRoot, "demo"}];
$demoHtmlOut = FileNameJoin[{$demoDir, "demo.html"}];
$genDate     = DateString[];

(* ── Demo listening order (mirrors demo.wl / demo/README.md) ─── *)
$appOrder = {
  "signal", "waves", "pendulum", "cellular", "primes", "quantum",
  "lorenz", "dynamical", "asteroids", "lagrange", "images", "relativity", "cosmology"
};

(* ── App metadata ─────────────────────────────────────────────
   "primary_wav" / "gif" are literal filenames for every app except
   "asteroids", where output filenames are date-stamped and vary
   from run to run — those are resolved dynamically below by
   picking the most recently modified asteroids_*.wav/.gif pair
   in demo/asteroids/output/ (see $asteroidsPrimary).
   "gif_static" marks apps (cosmology) whose primary visual on disk
   is a static PNG rather than an animated GIF. *)

appMeta = <|

  "signal" -> <|
    "title" -> "Signal \[LongDash] Fourier Analysis",
    "description" ->
      "The discrete Fourier transform decomposes any signal \[LongDash] sound, " <>
      "light, a radio wave \[LongDash] into a sum of pure frequencies. This app " <>
      "builds a chord from three pure tones, buries it in random noise, then " <>
      "uses the Fourier transform to find and recover the original notes. Unlike " <>
      "every other app in this project, the audio is the phenomenon itself: you " <>
      "are not hearing a translation of something else, you are hearing the " <>
      "actual signal being analysed.",
    "listening_guide" ->
      "Press play and listen for four stages, introduced by a spoken guide: " <>
      "first the clean chord (three notes ringing together), then the same " <>
      "chord swallowed by noise, then the moment the Fourier transform sweeps " <>
      "the noise away and the three notes ring out clearly again. The " <>
      "improvement is dramatic and immediate \[LongDash] no prior knowledge of " <>
      "Fourier analysis is needed to hear it happen.",
    "primary_wav" -> "chord_narrative_full.wav",
    "primary_wav_label" -> "Full narrative (recommended)",
    "secondary_wavs" -> {
      <| "file" -> "chord_clean.wav",     "label" -> "Clean chord (no noise)" |>,
      <| "file" -> "chord_noisy.wav",     "label" -> "Noisy chord (signal buried in noise)" |>,
      <| "file" -> "chord_recovered.wav", "label" -> "Recovered chord (after Fourier filtering)" |>
    },
    "gif" -> "chord_animation.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "Animated frequency spectrum for a C major chord: three sharp peaks at " <>
      "261.63, 329.63, and 392.00 Hz emerge from a noisy broadband spectrum as " <>
      "a comb filter isolates them.",
    "cli" -> "wolframscript -file signal/main.wl -- --simulation.mode=chord",
    "github_path" -> "signal"
  |>,

  "waves" -> <|
    "title" -> "Waves \[LongDash] 2D Wave Propagation",
    "description" ->
      "The wave equation describes every ripple on a pond, every sound wave " <>
      "in air, every tremor moving through rock. This app drops a single " <>
      "pulse at the centre of a circular drum membrane and solves, " <>
      "numerically, how the resulting ripple spreads outward and reflects " <>
      "off the rim.",
    "listening_guide" ->
      "Six listening points are arranged left-to-right in the stereo field, " <>
      "from nearest the source (hard left) to farthest (hard right). Listen " <>
      "for a wave of short bursts sweeping left to right as the ripple's " <>
      "leading edge passes each point in turn \[LongDash] then, after a " <>
      "pause, the reflected wave sweeping back right to left off the " <>
      "boundary.",
    "primary_wav" -> "ripple_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] ripple propagation",
    "secondary_wavs" -> {},
    "gif" -> "ripple.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "Top-down view of a circular drum membrane with a Gaussian pulse at " <>
      "the centre: a ring-shaped wavefront expands outward, reflects off " <>
      "the circular boundary, and converges back toward the centre.",
    "cli" -> "wolframscript -file waves/main.wl -- --simulation.mode=ripple",
    "github_path" -> "waves"
  |>,

  "pendulum" -> <|
    "title" -> "Pendulum \[LongDash] Chaotic Double Pendulum",
    "description" ->
      "A single pendulum is one of the first equations students learn to " <>
      "solve. Attach a second rod to the end of the first and the motion " <>
      "becomes chaotic: two starting angles that differ by a fraction of a " <>
      "degree eventually produce completely different swings. This app " <>
      "simulates a double pendulum and gives each bob its own stereo " <>
      "channel \[LongDash] the upper bob on the left, the lower bob on the " <>
      "right.",
    "listening_guide" ->
      "Each half-swing produces one note; louder, higher notes come from " <>
      "wider, faster swings. At first the two channels swing together, " <>
      "roughly in rhythm. Listen for the moment the left and right channels " <>
      "drift out of sync with each other \[LongDash] that drift, impossible " <>
      "to predict in advance, is chaos becoming audible.",
    "primary_wav" -> "double_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] double pendulum (binaural stereo)",
    "secondary_wavs" -> {},
    "gif" -> "double_animation.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A double pendulum swinging chaotically: two connected rods and " <>
      "bobs, the lower bob tracing a rapidly changing, unpredictable path " <>
      "beneath the upper one.",
    "cli" -> "wolframscript -file pendulum/main.wl -- --simulation.mode=double",
    "github_path" -> "pendulum"
  |>,

  "cellular" -> <|
    "title" -> "Cellular \[LongDash] Conway's Game of Life",
    "description" ->
      "Conway's Game of Life is a grid of cells that live or die each " <>
      "generation according to one simple rule: a dead cell with exactly " <>
      "three living neighbours is born, a living cell with two or three " <>
      "neighbours survives, and all others die. From that single rule, " <>
      "complex behaviour emerges. This app starts from a five-cell seed " <>
      "called the R-pentomino, which grows chaotically for hundreds of " <>
      "generations before settling down.",
    "listening_guide" ->
      "Population size controls pitch, the left/right balance of living " <>
      "cells controls stereo pan, and sudden jumps in population trigger " <>
      "short high or low accent tones. Listen for the colony's population " <>
      "rising in a rush of activity, briefly stabilising, then erupting " <>
      "again \[LongDash] population explosions and collapses are audible as " <>
      "distinct bursts.",
    "primary_wav" -> "life_rpentomino_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] Game of Life, R-pentomino",
    "secondary_wavs" -> {},
    "gif" -> "life_rpentomino_animation.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "The R-pentomino, a five-cell seed on a black-and-white grid, " <>
      "exploding into a chaotic sprawl of cells over 300 generations " <>
      "before settling into stable, oscillating patterns.",
    "cli" ->
      "wolframscript -file cellular/main.wl -- " <>
      "--simulation.life.starting_pattern=rpentomino",
    "github_path" -> "cellular"
  |>,

  "primes" -> <|
    "title" -> "Primes \[LongDash] Prime Gap Rhythm",
    "description" ->
      "Prime numbers (2, 3, 5, 7, 11, \[Ellipsis]) become more spread out as " <>
      "numbers grow larger, but the gaps between them are irregular \[LongDash] " <>
      "sometimes two primes sit right next to each other (twin primes), " <>
      "sometimes a gap stretches on for thirty numbers or more. This app " <>
      "turns the first 5000 prime gaps into a percussive rhythm, played at " <>
      "quarter speed so individual gaps are easy to count by ear.",
    "listening_guide" ->
      "Each prime triggers a short tone. Listen for pairs of " <>
      "near-simultaneous double-taps \[LongDash] those are twin primes, " <>
      "gap = 2 \[LongDash] and for stretches of silence, which are the " <>
      "larger gaps. The rhythm is irregular but never random: it is " <>
      "arithmetic, made audible.",
    "primary_wav" -> "gaps_slow.wav",
    "primary_wav_label" -> "Listen \[LongDash] prime gap rhythm (quarter speed)",
    "secondary_wavs" -> {
      <| "file" -> "gaps_audio.wav", "label" -> "Full-speed rhythm (gaps_audio.wav)" |>
    },
    "gif" -> "gaps_animation.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A bar-chart-style animation of consecutive prime gaps for the first " <>
      "5000 primes, showing frequent small gaps and occasional tall spikes " <>
      "for larger gaps.",
    "cli" -> "wolframscript -file primes/main.wl -- --simulation.mode=gaps",
    "github_path" -> "primes"
  |>,

  "quantum" -> <|
    "title" -> "Quantum \[LongDash] Quantum Harmonic Oscillator",
    "description" ->
      "In quantum mechanics, a particle doesn't have one definite position " <>
      "\[LongDash] it is spread across a cloud of probability. A \"coherent " <>
      "state\" is a special quantum state whose probability cloud sloshes " <>
      "back and forth as smoothly and predictably as a classical pendulum. " <>
      "This app solves the Schr\[ODoubleDot]dinger equation exactly for a " <>
      "large-amplitude coherent state and sonifies the result.",
    "listening_guide" ->
      "Pitch tracks how spread out the probability cloud is, and stereo " <>
      "position tracks its average location as it oscillates back and " <>
      "forth. Listen for an almost perfectly smooth, periodic tone " <>
      "drifting left and right \[LongDash] that smoothness is precisely " <>
      "what makes this quantum state behave \"as classically as quantum " <>
      "mechanics allows.\"",
    "primary_wav" -> "qho_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] quantum harmonic oscillator",
    "secondary_wavs" -> {},
    "gif" -> "qho_density.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A smooth, bell-shaped probability density curve for a quantum " <>
      "harmonic oscillator coherent state, oscillating rhythmically back " <>
      "and forth along the position axis without spreading or distorting.",
    "cli" -> "wolframscript -file quantum/main.wl -- --simulation.qho.alpha=3.0",
    "github_path" -> "quantum"
  |>,

  "lorenz" -> <|
    "title" -> "Lorenz \[LongDash] Strange Attractors",
    "description" ->
      "A strange attractor is a shape that a system's trajectory is drawn " <>
      "toward, but never repeats or escapes. The Lorenz equations, " <>
      "published in 1963, were the first rigorous proof that a system with " <>
      "no randomness at all can still be practically unpredictable \[LongDash] " <>
      "the origin of the phrase \"the butterfly effect.\" This app plays " <>
      "the R\[OSlash]ssler attractor, a cousin of Lorenz with a simpler, " <>
      "single-loop geometry, producing a smoother, less jagged sonification.",
    "listening_guide" ->
      "Each turning point of the trajectory triggers one note, mapped to a " <>
      "minor pentatonic scale. Listen for phrases that sound almost like a " <>
      "recurring melody \[LongDash] then notice how they never quite repeat " <>
      "exactly. That near-repetition without ever truly repeating is what " <>
      "deterministic chaos sounds like.",
    "primary_wav" -> "rossler_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] R\[OSlash]ssler attractor",
    "secondary_wavs" -> {},
    "gif" -> "rossler_animation.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A single-loop trajectory of the R\[OSlash]ssler attractor tracing a " <>
      "continuous ribbon-like path in three dimensions, colour-graded from " <>
      "blue (early) to orange and red (recent), circling and drifting " <>
      "without ever closing on itself.",
    "cli" -> "wolframscript -file lorenz/main.wl -- --simulation.mode=rossler",
    "github_path" -> "lorenz"
  |>,

  "dynamical" -> <|
    "title" -> "Logistic Map \[LongDash] Period-Doubling Route to Chaos",
    "description" ->
      "The logistic map x_{n+1} = r\[CenterDot]x_n\[CenterDot](1-x_n) is one " <>
      "of the simplest equations in mathematics that produces chaos. As the " <>
      "growth parameter r increases, the long-term behaviour transitions " <>
      "from a single stable value through a cascade of period-doublings " <>
      "\[LongDash] one note becomes two, then four, then eight \[LongDash] " <>
      "before dissolving into chaos. This period-doubling cascade is " <>
      "governed by the Feigenbaum constant (\[TildeTilde]4.669), a universal " <>
      "number that appears in any smooth one-dimensional map, not just this " <>
      "one. The sweep mode traverses the full route from r=2.5 to r=4.0 in " <>
      "a single audio file.",
    "listening_guide" ->
      "Listen for the rhythm doubling \[LongDash] one repeating note " <>
      "becomes two alternating notes, then four, then eight, each doubling " <>
      "faster than the last. After the chaos begins, listen for a sudden " <>
      "return to a clear three-note rhythm near the end: that is the " <>
      "period-3 window near r\[TildeTilde]3.83, an island of order whose " <>
      "existence is guaranteed by a mathematical theorem. The event " <>
      "markers (accent tones) mark the first bifurcation, the onset of " <>
      "chaos, and the period-3 window.",
    "primary_wav" -> "sweep_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] logistic map bifurcation sweep, r = 2.5 \[RightArrow] 4.0",
    "secondary_wavs" -> {
      <| "file" -> "iterate_audio.wav",
         "label" -> "Listen \[LongDash] period-3 window (three-note rhythm in chaos)" |>
    },
    "gif" -> "sweep.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A bifurcation diagram progressively drawn as r sweeps from 2.5 to " <>
      "4.0: a single line splits into two, then four, then eight branches, " <>
      "fracturing into a dense chaotic band with a visible gap \[LongDash] " <>
      "the period-3 window \[LongDash] near the right edge.",
    "cli" -> "wolframscript -file dynamical/main.wl",
    "github_path" -> "dynamical"
  |>,

  "asteroids" -> <|
    "title" -> "Asteroids \[LongDash] Live NASA Near-Earth Object Data",
    "description" ->
      "Every day, dozens of asteroids pass near Earth. This app fetches " <>
      "live close-approach data from NASA's Near-Earth Object Web Service " <>
      "for the last seven days and turns every asteroid into a single " <>
      "tone. Because the data is live, this is the only " <>
      "simulation in the project whose output is different every single " <>
      "time it runs.",
    "listening_guide" ->
      "Pitch reflects how close each asteroid came to Earth; louder, " <>
      "brighter notes with a harsher timbre mark potentially hazardous " <>
      "asteroids, while calmer, warmer tones mark safe ones. Notes play in " <>
      "order from the farthest asteroid to the closest, so listen for the " <>
      "texture thickening and sharpening as the sequence builds toward the " <>
      "nearest approach.",
    (* Resolved dynamically at generation time — see $asteroidsPrimary. *)
    "primary_wav" -> Automatic,
    "primary_wav_label" -> "Listen \[LongDash] near-Earth asteroids (last 7 days)",
    "secondary_wavs" -> {},
    "gif" -> Automatic,
    "gif_static" -> False,
    "gif_alt" ->
      "Top-down solar system view with Earth at the centre and concentric " <>
      "reference rings; asteroid dots appear one by one at increasing " <>
      "distance, coloured cyan for safe and red for potentially hazardous.",
    "cli" -> "wolframscript -file asteroids/main.wl",
    "github_path" -> "asteroids"
  |>,

  "lagrange" -> <|
    "title" -> "Lagrange \[LongDash] Lagrange Point Stability",
    "description" ->
      "In the rotating frame of two orbiting bodies \[LongDash] the Sun and " <>
      "Jupiter, say \[LongDash] there are five special positions where a " <>
      "third, much smaller object can sit in equilibrium. Two of them, " <>
      "called L4 and L5, are genuinely stable: more than ten thousand real " <>
      "\"Trojan\" asteroids have been orbiting at Jupiter's L4 and L5 " <>
      "points for billions of years. This app places a test particle near " <>
      "L4 and tracks its motion.",
    "listening_guide" ->
      "Pitch follows the particle's angular velocity as it slowly loops " <>
      "around L4; stereo position sweeps left and right as it drifts " <>
      "toward the Sun and back toward Jupiter; short accent tones mark " <>
      "each closest pass. Listen for a tone that drifts and undulates " <>
      "gently forever without ever resolving or escaping \[LongDash] that " <>
      "endless, unchanging quality is exactly what orbital stability " <>
      "sounds like.",
    "primary_wav" -> "l4_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] L4 tadpole orbit, Sun-Jupiter",
    "secondary_wavs" -> {},
    "gif" -> "l4.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A test particle's path in the Sun-Jupiter co-rotating frame, " <>
      "tracing a small looping (\"tadpole\") orbit around the L4 point 60 " <>
      "degrees ahead of Jupiter, never drifting away.",
    "cli" -> "wolframscript -file lagrange/main.wl -- --simulation.mode=l4",
    "github_path" -> "lagrange"
  |>,

  "images" -> <|
    "title" -> "Images \[LongDash] Image Sonification via Hilbert Curve",
    "description" ->
      "A two-dimensional image \[LongDash] a scientific plot, a false-colour " <>
      "map, a photograph \[LongDash] is hard to describe in sound because a " <>
      "simple left-to-right, row-by-row scan makes neighbouring pixels " <>
      "jump around unpredictably in time. This app instead traverses the " <>
      "image along a Hilbert curve, a path that guarantees pixels close " <>
      "together in the image stay close together in the resulting sound. " <>
      "A colour mode maps each pixel to a pitch by position in the visible " <>
      "spectrum \[LongDash] violet is the lowest pitch, red is the highest " <>
      "\[LongDash] and a pedagogical scan_horizontal mode traverses the same " <>
      "image in simple row-by-row order, so a listener can hear the " <>
      "Hilbert curve's locality benefit directly by comparison.",
    "listening_guide" ->
      "In brightness mode, dark pixels produce low tones and bright " <>
      "pixels produce high tones, with logarithmic scaling matching how " <>
      "human hearing perceives frequency. Listen for the smooth sweep " <>
      "from dark corners to the bright centre of the test image.",
    "primary_wav" -> "images_brightness_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] Hilbert curve brightness scan (log scale)",
    "secondary_wavs" -> {},
    "gif" -> "images_brightness.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A 64\[Times]64 Gaussian brightness image with a Hilbert curve traced " <>
      "across it, sweeping from the dark corners inward toward the bright " <>
      "central peak in a continuous, space-filling path.",
    "cli" -> "wolframscript -file images/main.wl -- --simulation.mode=brightness",
    "github_path" -> "images",
    "listening_guide_note" ->
      "New to image sonification? See images/LISTENING_GUIDE.md for the " <>
      "recommended listening sequence."
  |>,

  "relativity" -> <|
    "title" -> "Relativity \[LongDash] Gravitational Waves (LIGO Chirp)",
    "description" ->
      "On 14 September 2015, LIGO detected two black holes \[LongDash] 36 " <>
      "and 29 times the mass of the Sun \[LongDash] spiralling together and " <>
      "merging, 1.3 billion years after the event happened. As the black " <>
      "holes lost energy to gravitational waves, their orbit shrank and " <>
      "the signal's pitch and volume rose, right up until the moment of " <>
      "merger. This app reproduces that signal, the GW150914 event, " <>
      "stretched four times slower so the sub-second chirp becomes clearly " <>
      "audible.",
    "listening_guide" ->
      "Listen for a steadily rising pitch and swelling volume \[LongDash] " <>
      "the classic \"chirp\" \[LongDash] followed by an abrupt cutoff at the " <>
      "instant of merger, and then a brief, fading ringdown as the newly " <>
      "merged black hole settles. This is, note for note, what LIGO's own " <>
      "scientists listened to when they first confirmed the detection.",
    "primary_wav" -> "chirp.wav",
    "primary_wav_label" -> "Listen \[LongDash] GW150914 gravitational wave chirp",
    "secondary_wavs" -> {},
    "gif" -> "chirp.gif",
    "gif_static" -> False,
    "gif_alt" ->
      "A gravitational wave strain waveform for GW150914: oscillations " <>
      "that grow steadily in frequency and amplitude, culminating in an " <>
      "abrupt merger spike followed by a rapidly damped ringdown.",
    "cli" ->
      "wolframscript -file relativity/main.wl -- " <>
      "--simulation.chirp.preset=gw150914 --sonification.chirp.time_stretch=4",
    "github_path" -> "relativity"
  |>,

  "cosmology" -> <|
    "title" -> "Cosmology \[LongDash] CMB Power Spectrum",
    "description" ->
      "The Cosmic Microwave Background is the oldest light in the " <>
      "universe: radiation released 380,000 years after the Big Bang, " <>
      "when the universe first became transparent. Tiny temperature " <>
      "variations in this light, one part in a hundred thousand, encode a " <>
      "precise record of the early universe's structure. This app " <>
      "sonifies the CMB's angular power spectrum \[LongDash] a plot of how " <>
      "much temperature variation exists at each angular scale on the sky " <>
      "\[LongDash] from the largest scales down to the smallest.",
    "listening_guide" ->
      "Listen for a quiet, steady drone at the start (the large-scale " <>
      "plateau), building to a loud swell at the first acoustic peak " <>
      "\[LongDash] the single loudest, highest moment in the file \[LongDash] " <>
      "followed by two smaller swells, then a long, gradually quietening " <>
      "fade as fine structure washes out. The loudness of that first " <>
      "peak, and how much quieter the second one is, is the sound of a " <>
      "flat universe made mostly of ordinary and dark matter.",
    "primary_wav" -> "cmb_spectrum_audio.wav",
    "primary_wav_label" -> "Listen \[LongDash] CMB angular power spectrum",
    "secondary_wavs" -> {},
    (* No animated GIF is produced in spectrum mode — cmb_spectrum.png
       is the static plot; see "gif_static". *)
    "gif" -> "cmb_spectrum.png",
    "gif_static" -> True,
    "gif_alt" ->
      "Static plot of the CMB angular power spectrum from multipole " <>
      "l=2 to l=2000, showing a flat plateau at large scales, a tall " <>
      "first acoustic peak near l\[TildeEqual]220, two smaller peaks at " <>
      "finer scales, and a gradually declining damping tail.",
    "cli" ->
      "wolframscript -file cosmology/main.wl -- --simulation.mode=spectrum " <>
      "--simulation.cosmology.source=simulated",
    "github_path" -> "cosmology"
  |>
|>;

(* ── Helpers ─────────────────────────────────────────────────── *)

EscapeHTML[s_String] := StringReplace[s, {
  "&" -> "&amp;", "<" -> "&lt;", ">" -> "&gt;",
  "\"" -> "&quot;", "'" -> "&#39;"
}];

OutputPath[appName_String, fileName_String] :=
  FileNameJoin[{$demoDir, appName, "output", fileName}];

RelPath[appName_String, fileName_String] :=
  appName <> "/output/" <> fileName;

OpenHtmlCmd[path_String] :=
  Switch[$OperatingSystem,
    "MacOSX",  "open " <> path,
    "Unix",    "xdg-open " <> path,
    "Windows", "start " <> path,
    _,         "open " <> path
  ];

(* Newest asteroids_*.wav/.gif pair in demo/asteroids/output/ — asteroid
   filenames are date-stamped and change on every demo.wl run, while
   older leftover presets (hazardous_only, phrygian_*, etc.) stay stale.
   The file with the most recent modification time is the one this
   demo actually produced. *)
$asteroidsOutDir = OutputPath["asteroids", ""];
$asteroidsPrimary = Module[{wavs, newestWav, base, gifName},
  wavs = If[DirectoryQ[$asteroidsOutDir], FileNames["asteroids_*.wav", $asteroidsOutDir], {}];
  If[Length[wavs] === 0,
    <| "wav" -> Missing["NotFound"], "gif" -> Missing["NotFound"] |>,
    newestWav = First[SortBy[wavs, -AbsoluteTime[FileDate[#]] &]];
    base    = FileBaseName[newestWav];
    gifName = base <> ".gif";
    <|
      "wav" -> FileNameTake[newestWav],
      "gif" -> If[FileExistsQ[FileNameJoin[{$asteroidsOutDir, gifName}]],
                  gifName, Missing["NotFound"]]
    |>
  ]
];

(* ── HTML fragment builders ───────────────────────────────────── *)

MissingNote[label_String] :=
  "<p class=\"missing\">Output not found \[LongDash] run demo.wl first (" <>
  EscapeHTML[label] <> ")</p>\n";

AudioFigure[appName_String, label_String, fileNameOrMissing_] :=
  Module[{fileName, exists, rel},
    If[MissingQ[fileNameOrMissing],
      Return[{MissingNote[label], False}]];
    fileName = fileNameOrMissing;
    exists   = FileExistsQ[OutputPath[appName, fileName]];
    If[!exists, Return[{MissingNote[fileName], False}]];
    rel = RelPath[appName, fileName];
    {
      "<figure>\n" <>
      "<figcaption>" <> EscapeHTML[label] <> "</figcaption>\n" <>
      "<audio controls style=\"width:100%\">\n" <>
      "<source src=\"" <> rel <> "\" type=\"audio/wav\">\n" <>
      "Your browser does not support the audio element.\n" <>
      "<a href=\"" <> rel <> "\">Download WAV</a>\n" <>
      "</audio>\n" <>
      "</figure>\n",
      True
    }
  ];

GifFigure[appName_String, fileNameOrMissing_, altText_String, isStatic_] :=
  Module[{fileName, exists, rel, caption},
    If[MissingQ[fileNameOrMissing], Return[{MissingNote["animation"], False}]];
    fileName = fileNameOrMissing;
    exists   = FileExistsQ[OutputPath[appName, fileName]];
    If[!exists, Return[{MissingNote[fileName], False}]];
    rel     = RelPath[appName, fileName];
    caption = If[isStatic,
      "Static plot (this mode does not produce an animation)",
      "Animated visualisation of the simulation"
    ];
    {
      "<figure>\n" <>
      "<img src=\"" <> rel <> "\" alt=\"" <> EscapeHTML[altText] <>
      "\" width=\"400\" loading=\"lazy\">\n" <>
      "<figcaption>" <> caption <> "</figcaption>\n" <>
      "</figure>\n",
      True
    }
  ];

BuildAppSection[appName_String, index_Integer] := Module[{
    meta, primaryWav, gifFile, secondaryWavs,
    primaryFig, primaryOk, gifFig, gifOk,
    secondaryHtml, secondaryAnyOk, allOk, missingList
  },
  meta          = appMeta[appName];
  primaryWav    = If[appName === "asteroids", $asteroidsPrimary["wav"], meta["primary_wav"]];
  gifFile       = If[appName === "asteroids", $asteroidsPrimary["gif"], meta["gif"]];
  secondaryWavs = meta["secondary_wavs"];

  {primaryFig, primaryOk} = AudioFigure[appName, meta["primary_wav_label"], primaryWav];
  {gifFig, gifOk}         = GifFigure[appName, gifFile, meta["gif_alt"], meta["gif_static"]];

  secondaryAnyOk = True;
  secondaryHtml = If[Length[secondaryWavs] === 0, "",
    Module[{items},
      items = Map[
        Function[sw,
          Module[{fig, ok},
            {fig, ok} = AudioFigure[appName, sw["label"], sw["file"]];
            If[!ok, secondaryAnyOk = False];
            fig
          ]
        ],
        secondaryWavs
      ];
      "<details>\n<summary>More audio outputs</summary>\n" <>
      StringJoin[items] <>
      "</details>\n"
    ]
  ];

  allOk = primaryOk && gifOk && secondaryAnyOk;
  missingList = Select[{
    If[!primaryOk, "primary audio", Nothing],
    If[!gifOk, "visual (gif/png)", Nothing],
    If[!secondaryAnyOk, "secondary audio", Nothing]
  }, # =!= Nothing &];

  STEMSection[appName];
  If[allOk,
    Print["  OK \[LongDash] all outputs present"],
    Print["[WARNING] ", appName, ": missing ", StringRiffle[missingList, ", "],
          " \[LongDash] using placeholder(s)"]
  ];

  {
    "<section id=\"" <> appName <> "\" aria-labelledby=\"" <> appName <> "-heading\">\n" <>
    "<h2 id=\"" <> appName <> "-heading\">" <> ToString[index] <> ". " <>
    EscapeHTML[meta["title"]] <> "</h2>\n" <>
    "<div class=\"app-layout\">\n" <>
    "<div class=\"app-visual\">\n" <> gifFig <> "</div>\n" <>
    "<div class=\"app-audio\">\n" <>
    "<h3>Listen</h3>\n" <>
    "<p>" <> EscapeHTML[meta["listening_guide"]] <> "</p>\n" <>
    primaryFig <>
    secondaryHtml <>
    "</div>\n" <>
    "</div>\n" <>
    "<div class=\"app-info\">\n" <>
    "<h3>About this simulation</h3>\n" <>
    "<p>" <> EscapeHTML[meta["description"]] <> "</p>\n" <>
    "<h3>Run it yourself</h3>\n" <>
    "<pre><code>" <> EscapeHTML[meta["cli"]] <> "</code></pre>\n" <>
    If[Lookup[meta, "listening_guide_note", ""] =!= "",
      "<p>" <> EscapeHTML[meta["listening_guide_note"]] <> "</p>\n",
      ""
    ] <>
    "<p><a href=\"https://github.com/MINT-Access/stem/tree/main/" <>
    meta["github_path"] <> "\">View source on GitHub \[RightArrow]</a></p>\n" <>
    "</div>\n" <>
    "</section>\n",
    allOk
  }
];

(* ── CSS (all inline; no external dependencies) ────────────────── *)

$css = "
  :root {
    color-scheme: light;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto,
                 Helvetica, Arial, sans-serif;
    color: #111111;
    background: #ffffff;
    line-height: 1.55;
  }
  .skip-link {
    position: absolute;
    left: -999px;
    top: auto;
    width: 1px;
    height: 1px;
    overflow: hidden;
    background: #ffffff;
  }
  .skip-link:focus {
    position: fixed;
    left: 1rem;
    top: 1rem;
    width: auto;
    height: auto;
    padding: 0.75rem 1.25rem;
    background: #003366;
    color: #ffffff;
    font-weight: bold;
    border-radius: 4px;
    z-index: 100;
  }
  header, main, footer {
    max-width: 960px;
    margin: 0 auto;
    padding: 1.5rem 1.25rem;
  }
  header {
    border-bottom: 3px solid #003366;
  }
  header h1 {
    margin: 0 0 0.25rem 0;
    font-size: 2rem;
    color: #003366;
  }
  header p {
    margin: 0.25rem 0;
  }
  header .links a {
    margin-right: 1.25rem;
  }
  a {
    color: #0353a4;
  }
  a:hover, a:focus {
    color: #012a4a;
  }
  nav[aria-label=\"Simulations\"] {
    background: #f4f7fa;
    border: 1px solid #d0d7de;
    border-radius: 6px;
    padding: 1rem 1.25rem;
    margin: 1.5rem 0;
  }
  nav[aria-label=\"Simulations\"] h2 {
    margin-top: 0;
    font-size: 1.1rem;
  }
  nav[aria-label=\"Simulations\"] ol {
    columns: 2;
    padding-left: 1.25rem;
  }
  nav[aria-label=\"Simulations\"] li {
    margin-bottom: 0.4rem;
    break-inside: avoid;
  }
  section {
    padding: 2rem 0;
    border-bottom: 1px solid #d0d7de;
  }
  section h2 {
    font-size: 1.5rem;
    color: #003366;
  }
  .app-layout {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    align-items: start;
    margin: 1rem 0;
  }
  @media (max-width: 700px) {
    .app-layout { grid-template-columns: 1fr; }
    nav[aria-label=\"Simulations\"] ol { columns: 1; }
  }
  figure {
    margin: 0 0 1rem 0;
  }
  figure img {
    max-width: 100%;
    height: auto;
    border: 1px solid #d0d7de;
    border-radius: 4px;
  }
  figcaption {
    font-size: 0.9rem;
    color: #444444;
    margin-top: 0.35rem;
  }
  audio {
    width: 100%;
    margin-bottom: 0.5rem;
  }
  details {
    margin-top: 0.75rem;
  }
  summary {
    cursor: pointer;
    font-weight: bold;
    color: #003366;
  }
  .app-info pre {
    background: #f4f7fa;
    border: 1px solid #d0d7de;
    border-radius: 4px;
    padding: 0.75rem 1rem;
    overflow-x: auto;
  }
  p.missing {
    background: #fff4e5;
    border: 1px solid #cc8b00;
    color: #6b4a00;
    padding: 0.6rem 0.9rem;
    border-radius: 4px;
  }
  footer {
    border-top: 3px solid #003366;
    font-size: 0.9rem;
    color: #444444;
  }
  @media print {
    .skip-link { display: none; }
    nav[aria-label=\"Simulations\"] { display: none; }
    audio { display: none; }
    section { break-inside: avoid; }
  }
";

(* ── Build the page ─────────────────────────────────────────── *)

STEMHeading["STEM Demo HTML Generator"];
Print["  Reading from: ", $demoDir];
Print["  Writing to:   ", $demoHtmlOut];
Print[""];

$navItems = StringJoin[MapIndexed[
  Function[{name, idx},
    "<li><a href=\"#" <> name <> "\">" <> ToString[First[idx]] <> ". " <>
    EscapeHTML[appMeta[name]["title"]] <> "</a></li>\n"
  ],
  $appOrder
]];

$sectionResults = MapIndexed[
  BuildAppSection[#1, First[#2]] &,
  $appOrder
];
$sectionsHtml = StringJoin[$sectionResults[[All, 1]]];
$nComplete    = Count[$sectionResults[[All, 2]], True];
$nIncomplete  = Length[$appOrder] - $nComplete;

$html = "<!doctype html>\n" <>
"<!-- TODO: German version \[LongDash] see mint-access-blogpost-v1.1.0-de.md for translated content -->\n" <>
"<html lang=\"en\">\n" <>
"<head>\n" <>
"<meta charset=\"UTF-8\">\n" <>
"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" <>
"<title>MINT Access stem \[LongDash] Accessible STEM Simulations</title>\n" <>
"<style>" <> $css <> "</style>\n" <>
"</head>\n" <>
"<body>\n" <>
"<a href=\"#main-content\" class=\"skip-link\">Skip to content</a>\n" <>
"<header>\n" <>
"<h1>MINT Access stem</h1>\n" <>
"<p><strong>Accessible STEM Simulations \[LongDash] v1.2.0</strong></p>\n" <>
"<p>Thirteen physics, mathematics, and cosmology simulations, each producing " <>
"an animated visualisation and an audio sonification of the underlying " <>
"physics, designed to be fully accessible to blind and low-vision users.</p>\n" <>
"<p class=\"links\">" <>
"<a href=\"https://github.com/MINT-Access/stem\">GitHub repository</a>" <>
"<a href=\"https://www.mintaccess.ch/\">MINT Access</a>" <>
"</p>\n" <>
"</header>\n" <>
"<main id=\"main-content\">\n" <>
"<section id=\"intro\">\n" <>
"<h2>About this demo</h2>\n" <>
"<p>Each simulation below pairs a visual animation with a sonification " <>
"of the same underlying physics or mathematics. Use the " <>
"jump list to go directly to any simulation, or scroll through all " <>
"thirteen in the recommended listening order. No installation is " <>
"required \[LongDash] everything on this page plays directly in your " <>
"browser.</p>\n" <>
"</section>\n" <>
"<nav aria-label=\"Simulations\">\n" <>
"<h2>Jump to a simulation</h2>\n" <>
"<ol>\n" <> $navItems <> "</ol>\n" <>
"</nav>\n" <>
$sectionsHtml <>
"</main>\n" <>
"<footer>\n" <>
"<p>Generated by MINT Access stem v1.2.0 on " <> $genDate <> "</p>\n" <>
"<p class=\"links\">" <>
"<a href=\"https://github.com/MINT-Access/stem\">GitHub</a> \[Bullet] " <>
"<a href=\"https://www.mintaccess.ch/\">mintaccess.ch</a>" <>
"</p>\n" <>
"<p>Physics simulations by MINT Access GmbH. Developed with Claude Code " <>
"(Anthropic). Asteroid data: NASA NeoWs API and JPL Small Body Database. " <>
"CMB data: Planck Legacy Archive.</p>\n" <>
"</footer>\n" <>
"</body>\n" <>
"</html>\n";

Export[$demoHtmlOut, $html, "Text"];

(* ── Summary ──────────────────────────────────────────────────── *)

Print[""];
STEMHeading["Summary"];
STEMPrintN["Apps with complete outputs", $nComplete, "", 2];
If[$nIncomplete > 0,
  STEMPrintN["Apps with missing outputs", $nIncomplete, "", 2];
  Print["  (see [WARNING] lines above for which files were missing per app)"]
];
Print["  File:   ", $demoHtmlOut];
Print["  Size:   ", Round[FileByteCount[$demoHtmlOut] / 1024., 0.1], " KB"];
Print[""];
Print["  Open it with:"];
Print["    ", OpenHtmlCmd["demo/demo.html"], "   (macOS)"];
Print["    xdg-open demo/demo.html            (Linux)"];
Print["    start demo/demo.html               (Windows)"];
Print[""];

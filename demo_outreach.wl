#!/usr/bin/env wolframscript

(* ================================================================
   demo_outreach.wl  —  Curated outreach demo page generator

   Standalone generator for small, audience-specific outreach pages —
   a curated handful of apps with hand-written prose, not the full
   32-app demo.html. Distinct from demo.wl (runs all 32 apps) and
   demo_html.wl (builds demo.html from a completed demo.wl run): this
   script runs no simulations and does NOT depend on demo.wl having
   been run first. For each curated app it reads directly from that
   app's OWN output/ directory (the files its own "Run it yourself"
   CLI command produces) and copies whatever it finds into
   demo/<app>/output/ — the same asset-mirror convention demo.html
   already relies on, so the generated page's relative links resolve
   correctly when opened from demo/. Anything not yet generated is
   reported with a clear warning rather than silently linked as a
   broken image or audio source.

   The curated app selection and ALL hand-written prose ("About this
   simulation", "As a figure supplement", "Run it yourself") live in
   $CuratedApps below as plain, easy-to-edit data — adding a sixth
   app means adding one association there, not touching any
   generation logic. This prose is bespoke, written for a specific
   outreach purpose; it is not, and should not be, mechanically
   derived from each app's README/AGENTS.md on every run.

   Reverse-engineered from a hand-authored, one-off page built for a
   Springer-Nature outreach conversation (July 2026):
   demo/springer-nature-demo.html — see that file's own header
   comment. That page was a dead end: well-built, but with no way to
   reliably reproduce or update it. This script turns its content and
   structure into something regenerable on demand, for this
   conversation or a future one with different apps, a different
   publisher, or refreshed output files.

   Usage:
     wolframscript -file demo_outreach.wl
       Regenerates demo/springer-nature-demo.html with the current
       Springer-Nature content (the script's default) from whatever
       output files the five curated apps currently have.

     wolframscript -file demo_outreach.wl -- \
       --audience="Nature Publishing" --date="March 2027" \
       --title="Accessible Figure Supplements" \
       --output=nature-demo.html
       Regenerates for a different audience/date/title, written to
       demo/nature-demo.html, still using $CuratedApps below (edit
       that list to curate a different set of apps for a different
       conversation).
   ================================================================ *)

(* ── Load stem-core (for STEMHeading / STEMSection / STEMPrintN) ─ *)
$outreachRoot = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$outreachRoot, "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

$demoDir = FileNameJoin[{$outreachRoot, "demo"}];
If[!DirectoryQ[$demoDir], CreateDirectory[$demoDir]];

(* ── CLI overrides ───────────────────────────────────────────────
   Minimal --key=value parser (this tool has no per-app config.json
   to route through LoadConfig — it is not itself an "app"). Absent
   flags keep GenerateOutreachHTML's own defaults, which reproduce
   the Springer-Nature page byte-for-content-identical. *)
$outreachRawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$outreachCliOpts = Association @ Cases[
  $outreachRawArgs,
  s_String /; StringStartsQ[s, "--"] :>
    With[{kv = StringSplit[StringDrop[s, 2], "=", 2]},
      First[kv] -> Last[kv]
    ]
];

(* ── Curated apps ─────────────────────────────────────────────────
   One association per app, in display order. Fields:
     "id"        — anchor id; also the app's directory name (used to
                   find <id>/output/<file>, link demo/<id>/output/<file>,
                   and build the GitHub source link)
     "title"     — section heading (nav list gets "N. " prefixed automatically)
     "image"     — <| "file", "alt", "static" |>. "static" -> True for a
                   plain plot (no animation produced by this preset)
     "audio"     — <| "file", "caption" |>. "caption" is the figcaption
                   shown above the <audio> control
     "about"             — "About this simulation" prose (2-4 sentences)
     "figureSupplement"  — "As a figure supplement" prose, making the
                            accessibility case specific to this app
     "figureCaption"     — suggested academic figure caption (shown in
                            quotes, already phrased as "Audio S1: ...")
     "cli"       — exact CLI command to regenerate this app's own output
   ------------------------------------------------------------------ *)

$CuratedApps = {

  <|
    "id"    -> "signal",
    "title" -> "Signal \[LongDash] Fourier Analysis",
    "image" -> <|
      "file"   -> "chord_animation.gif",
      "alt"    -> "Animated frequency spectrum for a C major chord: three " <>
                  "sharp peaks at 261.63, 329.63, and 392.00 Hz emerge from " <>
                  "a noisy broadband spectrum as a comb filter isolates them.",
      "static" -> False
    |>,
    "audio" -> <|
      "file"    -> "chord_narrative_full.wav",
      "caption" -> "Full narrative \[LongDash] spoken guide to Fourier " <>
                   "filtering (recommended first listen)"
    |>,
    "about" ->
      "The discrete Fourier transform decomposes any signal into pure " <>
      "frequencies. This app generates a C major chord, buries it in " <>
      "noise, recovers it via frequency-domain filtering, and chains the " <>
      "complete demonstration \[LongDash] spoken introduction, clean " <>
      "chord, noisy chord, recovered chord \[LongDash] into a single " <>
      "audio file. A listener who has never encountered the Fourier " <>
      "transform can follow the complete demonstration from start to " <>
      "finish without reading a word.",
    "figureSupplement" ->
      "A paper presenting a signal processing method typically includes " <>
      "a figure showing input spectrum, noise floor, and recovered " <>
      "spectrum as overlapping curves. The audio supplement chains " <>
      "these three stages in sequence with spoken transitions, making " <>
      "the filtering effect directly perceptible \[LongDash] the " <>
      "dramatic improvement in signal quality is heard rather than " <>
      "inferred from comparing two spectral plots.",
    "figureCaption" ->
      "Audio S1: Spoken demonstration of the frequency-domain filtering " <>
      "procedure. The three stages \[LongDash] clean signal, corrupted " <>
      "signal, and recovered signal \[LongDash] are presented " <>
      "sequentially with spoken transitions.",
    "cli" -> "wolframscript -file signal/main.wl -- --simulation.mode=chord"
  |>,

  <|
    "id"    -> "relativity",
    "title" -> "Relativity \[LongDash] Gravitational Waves (GW150914)",
    "image" -> <|
      "file"   -> "chirp.gif",
      "alt"    -> "A gravitational wave strain waveform for GW150914: " <>
                  "oscillations that grow steadily in frequency and " <>
                  "amplitude, culminating in an abrupt merger spike " <>
                  "followed by a rapidly damped ringdown.",
      "static" -> False
    |>,
    "audio" -> <|
      "file"    -> "chirp.wav",
      "caption" -> "Listen \[LongDash] GW150914 gravitational wave chirp, " <>
                   "4\[Times] time stretch"
    |>,
    "about" ->
      "On 14 September 2015, LIGO detected two black holes \[LongDash] " <>
      "36 and 29 solar masses \[LongDash] merging 1.3 billion years ago. " <>
      "As the orbit shrank, the gravitational wave frequency and " <>
      "amplitude rose until the merger. This simulation reproduces the " <>
      "post-Newtonian strain h(t) and exports it as audio at 4\[Times] " <>
      "time stretch, making the sub-second chirp clearly audible.",
    "figureSupplement" ->
      "Gravitational wave papers routinely include strain versus time " <>
      "plots and time-frequency spectrograms. These are meaningful to " <>
      "specialists but convey little to a blind reader. The audio " <>
      "supplement plays the strain h(t) directly \[LongDash] the rising " <>
      "pitch, swelling amplitude, abrupt merger, and fading ringdown " <>
      "are immediately perceptible without any domain knowledge. LIGO " <>
      "researchers have listened to detections since GW150914; the " <>
      "audio IS the detection.",
    "figureCaption" ->
      "Audio S1: Gravitational wave strain h(t) for GW150914, " <>
      "time-stretched 4\[Times] for audibility. Rising pitch indicates " <>
      "increasing orbital frequency; the abrupt cutoff marks merger.",
    "cli" -> "wolframscript -file relativity/main.wl -- " <>
             "--simulation.chirp.preset=gw150914 " <>
             "--sonification.chirp.time_stretch=4"
  |>,

  <|
    "id"    -> "hydrogen",
    "title" -> "Hydrogen \[LongDash] Emission Spectrum",
    "image" -> <|
      "file"   -> "spectrum.gif",
      "alt"    -> "A growing stem plot of hydrogen emission-line " <>
                  "frequencies with a sweeping cursor moving from " <>
                  "ultraviolet through the visible Balmer lines to " <>
                  "infrared, each line's height proportional to its " <>
                  "Einstein A coefficient.",
      "static" -> False
    |>,
    "audio" -> <|
      "file"    -> "spectrum_audio.wav",
      "caption" -> "Listen \[LongDash] hydrogen emission spectrum: Balmer " <>
                   "series chord and sweep"
    |>,
    "about" ->
      "The hydrogen atom has an exact analytic solution to the " <>
      "Schr\[ODoubleDot]dinger equation. Its emission lines \[LongDash] " <>
      "the Lyman, Balmer, and Paschen series \[LongDash] arise from " <>
      "electron transitions between energy levels. This app maps each " <>
      "photon frequency to an audio frequency via logarithmic scaling " <>
      "and presents the spectrum as a simultaneous chord followed by a " <>
      "sweep from UV to IR. The four Balmer lines (visible hydrogen " <>
      "spectrum) are marked with soft bell tones.",
    "figureSupplement" ->
      "Spectroscopy papers present emission spectra as line plots " <>
      "\[LongDash] position on x-axis, intensity on y-axis. A blind " <>
      "reader cannot perceive the relative positions and intensities " <>
      "of spectral lines from such a plot. The audio supplement " <>
      "presents the same information as pitch and amplitude: the chord " <>
      "makes the relative frequencies of all lines simultaneously " <>
      "perceptible, and the sweep makes the progression from series to " <>
      "series audible. The Balmer bell tones identify the visible " <>
      "lines without requiring colour vision.",
    "figureCaption" ->
      "Audio S1: Hydrogen emission spectrum sonified as a chord and " <>
      "frequency sweep. Pitch encodes photon frequency; amplitude " <>
      "encodes line intensity. Bell tones mark the four Balmer series " <>
      "lines.",
    "cli" -> "wolframscript -file hydrogen/main.wl -- --simulation.mode=spectrum"
  |>,

  <|
    "id"    -> "cosmology",
    "title" -> "Cosmology \[LongDash] CMB Power Spectrum",
    "image" -> <|
      "file"   -> "cmb_spectrum.png",
      "alt"    -> "Static plot of the CMB angular power spectrum from " <>
                  "multipole l=2 to l=2000, showing a flat plateau at " <>
                  "large scales, a tall first acoustic peak near " <>
                  "l\[TildeEqual]220, two smaller peaks at finer scales, " <>
                  "and a gradually declining damping tail.",
      "static" -> True
    |>,
    "audio" -> <|
      "file"    -> "cmb_spectrum_audio.wav",
      "caption" -> "Listen \[LongDash] CMB angular power spectrum, " <>
                   "acoustic peaks"
    |>,
    "about" ->
      "The Cosmic Microwave Background temperature anisotropy power " <>
      "spectrum encodes the universe's geometry, baryon density, and " <>
      "dark matter density in the positions and heights of its acoustic " <>
      "peaks. This app sweeps angular scale from large to small, " <>
      "mapping power to pitch and amplitude. The first acoustic peak " <>
      "near \[ScriptL]\[TildeTilde]220 is the loudest moment; subsequent " <>
      "peaks are progressively quieter due to Silk damping.",
    "figureSupplement" ->
      "CMB papers present C(\[ScriptL]) vs \[ScriptL] plots \[LongDash] " <>
      "a highly technical figure whose key features (peak positions, " <>
      "relative heights, damping tail) encode fundamental cosmological " <>
      "parameters. A blind reader cannot extract this information from " <>
      "a description. The audio supplement makes the peak structure " <>
      "directly perceptible as a sequence of swells \[LongDash] the " <>
      "first peak is unmistakably the loudest moment, and the damping " <>
      "of subsequent peaks is audible as decreasing amplitude.",
    "figureCaption" ->
      "Audio S1: CMB angular power spectrum sonified from " <>
      "\[ScriptL]=2 to \[ScriptL]=2000. The first acoustic peak near " <>
      "\[ScriptL]\[TildeTilde]220 corresponds to the loudest swell; " <>
      "subsequent peaks are progressively damped.",
    "cli" -> "wolframscript -file cosmology/main.wl -- " <>
             "--simulation.mode=spectrum " <>
             "--simulation.cosmology.source=simulated"
  |>,

  <|
    "id"    -> "scattering",
    "title" -> "Scattering \[LongDash] Rutherford Discovery Mode",
    "image" -> <|
      "file"   -> "discovery.gif",
      "alt"    -> "Side-by-side growing angular-distribution histograms " <>
                  "for the Thomson and Rutherford models: the Thomson " <>
                  "histogram stays confined to a narrow band near zero " <>
                  "degrees, while the Rutherford histogram shows a long " <>
                  "tail reaching to large angles.",
      "static" -> False
    |>,
    "audio" -> <|
      "file"    -> "discovery_audio.wav",
      "caption" -> "Listen \[LongDash] Thomson vs Rutherford: binaural " <>
                   "comparison (use headphones)"
    |>,
    "about" ->
      "In 1909, Geiger and Marsden observed large-angle scattering of " <>
      "alpha particles from gold foil \[LongDash] impossible under " <>
      "Thomson's plum-pudding model, explained by Rutherford's nuclear " <>
      "model in 1911. This app plays both model predictions " <>
      "simultaneously in binaural stereo: the left channel represents " <>
      "the Thomson prediction (all small angles, quiet and uniform), " <>
      "the right represents the Rutherford prediction (same background " <>
      "plus occasional large-angle events). The large-angle events " <>
      "present in the right channel and absent in the left are the " <>
      "experimental discovery.",
    "figureSupplement" ->
      "Papers presenting scattering experiments typically include " <>
      "angular distribution plots comparing data to theoretical " <>
      "predictions. A blind reader cannot perceive the crucial " <>
      "difference between two overlapping curves. The binaural audio " <>
      "supplement makes this comparison immediately perceptible: the " <>
      "left channel (one model) is quiet and uniform; the right " <>
      "channel (the other model) has dramatic outliers. The difference " <>
      "between the two channels IS the experimental result \[LongDash] " <>
      "no domain knowledge required to hear it.",
    "figureCaption" ->
      "Audio S1: Binaural comparison of Thomson and Rutherford " <>
      "scattering predictions. Left channel: Thomson model (uniform " <>
      "small-angle scattering). Right channel: Rutherford nuclear " <>
      "model (same background plus large-angle events). Use " <>
      "headphones.",
    "cli" -> "wolframscript -file scattering/main.wl -- --simulation.mode=discovery"
  |>

};

(* ── Default framing text (Springer-Nature, July 2026) ───────────
   The prose here does not itself name the audience (only the
   header badge and footer credit line do, both driven by the
   Audience/Date options below) — so regenerating for a different
   publisher or a university conversation only requires different
   option values, not different paragraph text. Override via
   "IntroText"/"ClosingParagraphs" options if a future audience
   genuinely needs different wording here too. *)

$DefaultIntroText =
  "Scientific figures in journals \[LongDash] spectra, waveforms, phase " <>
  "diagrams, probability distributions \[LongDash] are almost entirely " <>
  "inaccessible to blind and low-vision readers. Alt-text can describe " <>
  "what a figure looks like; it cannot convey what a gravitational wave " <>
  "chirp sounds like, or make the acoustic peaks of the CMB power " <>
  "spectrum perceptible. The simulations below demonstrate a different " <>
  "approach: audio files generated from the same underlying data as " <>
  "the figures, conveying the same scientific content through sound. " <>
  "Each example is paired with a brief note on how it would function " <>
  "as a figure supplement in a published paper.";

$DefaultClosingParagraphs = {
  "stem is open-source software (MIT licence) developed by MINT " <>
  "Access GmbH, a Swiss organisation supporting accessible STEM " <>
  "education. It requires only the free Wolfram Engine and runs on " <>
  "macOS, Linux, and Windows from the terminal. The full project " <>
  "\[LongDash] 32 simulations, complete documentation, and a demo " <>
  "script \[LongDash] is available at " <>
  "<a href=\"https://github.com/MINT-Access/stem\">github.com/MINT-Access/stem</a>.",

  "The simulations presented here represent five of the thirty-two " <>
  "scientific domains currently covered, chosen to illustrate the " <>
  "range of figure types that benefit from audio supplements: " <>
  "time-series waveforms (gravitational waves), spectral data " <>
  "(hydrogen, CMB), comparative data (scattering), and narrative " <>
  "demonstrations (Fourier analysis). We are interested in discussing " <>
  "pilot programmes with publishers willing to explore accessible " <>
  "figure supplements as a publishing standard. Please contact Werner " <>
  "Haenggi at MINT Access GmbH."
};

(* ── Helpers ───────────────────────────────────────────────────── *)

EscapeHTML[s_String] := StringReplace[s, {
  "&" -> "&amp;", "<" -> "&lt;", ">" -> "&gt;",
  "\"" -> "&quot;", "'" -> "&#39;"
}];

(* Source of truth: the curated app's OWN output/ directory (what its
   "Run it yourself" CLI command actually produces) — not demo/, which
   is only a link-target mirror this script itself maintains. *)
SourcePath[appId_String, fileName_String] :=
  FileNameJoin[{$outreachRoot, appId, "output", fileName}];

MirrorPath[appId_String, fileName_String] :=
  FileNameJoin[{$demoDir, appId, "output", fileName}];

RelPath[appId_String, fileName_String] :=
  appId <> "/output/" <> fileName;

OpenHtmlCmd[path_String] :=
  Switch[$OperatingSystem,
    "MacOSX",  "open " <> path,
    "Unix",    "xdg-open " <> path,
    "Windows", "start " <> path,
    _,         "open " <> path
  ];

(* EnsureMirrored
   Copies <appId>/output/<fileName> into demo/<appId>/output/<fileName>
   (creating directories as needed) so the generated page's relative
   links resolve when opened from demo/, matching demo.html's own
   asset-mirror convention. Returns True if the file is now available
   at the mirror path, False (with the caller responsible for warning)
   if the source doesn't exist. Always re-copies when the source
   exists, so a stale mirror never masks a freshly regenerated output. *)
EnsureMirrored[appId_String, fileName_String] :=
  Module[{src, dst},
    src = SourcePath[appId, fileName];
    If[!FileExistsQ[src], Return[False]];
    dst = MirrorPath[appId, fileName];
    If[!DirectoryQ[DirectoryName[dst]],
      CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True]
    ];
    CopyFile[src, dst, OverwriteTarget -> True];
    True
  ];

MissingNote[label_String] :=
  "<p class=\"missing\">Output not found \[LongDash] run the app's CLI " <>
  "command first (" <> EscapeHTML[label] <> ")</p>\n";

BuildImageFigure[appId_String, image_Association] :=
  Module[{fileName, ok, rel, caption},
    fileName = image["file"];
    ok = EnsureMirrored[appId, fileName];
    If[!ok, Return[{MissingNote[fileName], False}]];
    rel = RelPath[appId, fileName];
    caption = If[TrueQ[image["static"]],
      "Static plot (this mode does not produce an animation)",
      "Animated visualisation of the simulation"
    ];
    {
      "<figure>\n" <>
      "<img src=\"" <> rel <> "\" alt=\"" <> EscapeHTML[image["alt"]] <>
      "\" width=\"400\" loading=\"lazy\">\n" <>
      "<figcaption>" <> caption <> "</figcaption>\n" <>
      "</figure>\n",
      True
    }
  ];

BuildAudioFigure[appId_String, audio_Association] :=
  Module[{fileName, ok, rel},
    fileName = audio["file"];
    ok = EnsureMirrored[appId, fileName];
    If[!ok, Return[{MissingNote[fileName], False}]];
    rel = RelPath[appId, fileName];
    {
      "<figure>\n" <>
      "<figcaption>" <> EscapeHTML[audio["caption"]] <> "</figcaption>\n" <>
      "<audio controls style=\"width:100%\">\n" <>
      "<source src=\"" <> rel <> "\" type=\"audio/wav\">\n" <>
      "Your browser does not support the audio element.\n" <>
      "<a href=\"" <> rel <> "\">Download WAV</a>\n" <>
      "</audio>\n" <>
      "</figure>\n",
      True
    }
  ];

BuildAppSection[app_Association, index_Integer] :=
  Module[{appId, imgFig, imgOk, audFig, audOk, allOk},
    appId = app["id"];
    {imgFig, imgOk} = BuildImageFigure[appId, app["image"]];
    {audFig, audOk} = BuildAudioFigure[appId, app["audio"]];
    allOk = imgOk && audOk;

    STEMSection[appId];
    If[allOk,
      Print["  OK \[LongDash] image and audio present"],
      Print["[WARNING] ", appId, ": missing ",
        StringRiffle[
          Select[{If[!imgOk, "image", Nothing], If[!audOk, "audio", Nothing]},
            # =!= Nothing &],
          ", "
        ],
        " \[LongDash] run: ", app["cli"]]
    ];

    {
      "<section id=\"" <> appId <> "\" aria-labelledby=\"" <> appId <> "-heading\">\n" <>
      "<h2 id=\"" <> appId <> "-heading\">" <> ToString[index] <> ". " <>
      EscapeHTML[app["title"]] <> "</h2>\n" <>
      "<div class=\"app-layout\">\n" <>
      "<div class=\"app-visual\">\n" <> imgFig <> "</div>\n" <>
      "<div class=\"app-audio\">\n" <>
      "<h3>Listen</h3>\n" <>
      audFig <>
      "</div>\n" <>
      "</div>\n" <>
      "<div class=\"app-info\">\n" <>
      "<h3>About this simulation</h3>\n" <>
      "<p>" <> EscapeHTML[app["about"]] <> "</p>\n" <>
      "<div class=\"figure-supplement\">\n" <>
      "<h3>As a figure supplement</h3>\n" <>
      "<p>" <> EscapeHTML[app["figureSupplement"]] <> "</p>\n" <>
      "<p><em>Caption: \"" <> EscapeHTML[app["figureCaption"]] <> "\"</em></p>\n" <>
      "</div>\n" <>
      "<h3>Run it yourself</h3>\n" <>
      "<pre><code>" <> EscapeHTML[app["cli"]] <> "</code></pre>\n" <>
      "<p><a href=\"https://github.com/MINT-Access/stem/tree/main/" <> appId <>
      "\">View source on GitHub \[RightArrow]</a></p>\n" <>
      "</div>\n" <>
      "</section>\n",
      allOk
    }
  ];

(* ── CSS (all inline; reused verbatim from the original hand-authored
   page — purpose-built, distinct from demo.html's own visual identity) *)

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
  .audience-badge {
    display: inline-block;
    background: #eef1f4;
    color: #444444;
    border: 1px solid #d0d7de;
    border-radius: 4px;
    padding: 0.25rem 0.6rem;
    font-size: 0.8rem;
    font-weight: bold;
    letter-spacing: 0.03em;
    margin-bottom: 0.75rem;
  }
  header h1 {
    margin: 0 0 0.25rem 0;
    font-size: 2rem;
    color: #003366;
  }
  header p {
    margin: 0.25rem 0;
  }
  header .subtitle {
    font-size: 1.15rem;
    font-weight: bold;
    color: #003366;
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
  .figure-supplement {
    background: #f4f7fa;
    border-left: 3px solid #003366;
    padding: 0.75rem 1rem;
    margin: 0.75rem 0;
    border-radius: 0 4px 4px 0;
  }
  .figure-supplement h3 {
    margin-top: 0;
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

(* ── GenerateOutreachHTML ──────────────────────────────────────────
   apps — list of curated-app associations (see $CuratedApps above)
   Options default to the proven Springer-Nature, July 2026 content;
   pass overrides (or use the CLI flags below) to reuse this same
   generator for a different audience/date/title/output file without
   touching this script. *)

Options[GenerateOutreachHTML] = {
  "Audience"          -> "Springer-Nature",
  "Date"              -> "July 2026",
  "PageTitle"         -> "Accessible Figure Supplements: A Proof of Concept",
  "Subtitle"          -> "MINT Access stem \[LongDash] Open-Source Scientific Sonification",
  "IntroText"         -> $DefaultIntroText,
  "ClosingParagraphs" -> $DefaultClosingParagraphs,
  "OutputFile"        -> "springer-nature-demo.html"
};

GenerateOutreachHTML[apps_List, OptionsPattern[]] :=
  Module[
    {audience, date, pageTitle, subtitle, introText, closingParas,
     outFile, outPath, badge, navItems, sectionResults, sectionsHtml,
     nComplete, nIncomplete, closingHtml, html},

    audience     = OptionValue["Audience"];
    date         = OptionValue["Date"];
    pageTitle    = OptionValue["PageTitle"];
    subtitle     = OptionValue["Subtitle"];
    introText    = OptionValue["IntroText"];
    closingParas = OptionValue["ClosingParagraphs"];
    outFile      = OptionValue["OutputFile"];
    outPath      = FileNameJoin[{$demoDir, outFile}];

    badge = "PREPARED FOR " <> ToUpperCase[audience] <> " \[LongDash] " <>
            ToUpperCase[date];

    STEMHeading["Outreach Demo HTML Generator"];
    Print["  Audience: ", audience, "   Date: ", date];
    Print["  Apps:     ", Length[apps]];
    Print["  Writing to: ", outPath];
    Print[""];

    navItems = StringJoin[MapIndexed[
      Function[{app, idx},
        "<li><a href=\"#" <> app["id"] <> "\">" <> ToString[First[idx]] <> ". " <>
        EscapeHTML[app["title"]] <> "</a></li>\n"
      ],
      apps
    ]];

    sectionResults = MapIndexed[BuildAppSection[#1, First[#2]] &, apps];
    sectionsHtml   = StringJoin[sectionResults[[All, 1]]];
    nComplete      = Count[sectionResults[[All, 2]], True];
    nIncomplete    = Length[apps] - nComplete;

    closingHtml = StringJoin[Map["<p>" <> # <> "</p>\n" &, closingParas]];

    html = "<!doctype html>\n" <>
"<!-- Generated by demo_outreach.wl for " <> EscapeHTML[audience] <> ", " <>
EscapeHTML[date] <> " \[LongDash] regenerate via wolframscript, do not " <>
"hand-edit. Not committed to the repository (see demo/ in .gitignore). -->\n" <>
"<html lang=\"en\">\n" <>
"<head>\n" <>
"<meta charset=\"UTF-8\">\n" <>
"<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" <>
"<title>" <> EscapeHTML[pageTitle] <> " \[LongDash] MINT Access stem</title>\n" <>
"<style>" <> $css <> "</style>\n" <>
"</head>\n" <>
"<body>\n" <>
"<a href=\"#main-content\" class=\"skip-link\">Skip to content</a>\n" <>
"<header>\n" <>
"<p class=\"audience-badge\">" <> EscapeHTML[badge] <> "</p>\n" <>
"<h1>" <> EscapeHTML[pageTitle] <> "</h1>\n" <>
"<p class=\"subtitle\">" <> EscapeHTML[subtitle] <> "</p>\n" <>
"<p>Thirty-two physics and mathematics simulations, each producing an " <>
"audio file that conveys the same scientific content as the " <>
"corresponding visual figure \[LongDash] for blind and low-vision " <>
"researchers, students, and readers.</p>\n" <>
"<p class=\"links\">" <>
"<a href=\"https://github.com/MINT-Access/stem\">GitHub repository</a>" <>
"<a href=\"https://www.mintaccess.ch/\">MINT Access</a>" <>
"</p>\n" <>
"</header>\n" <>
"<main id=\"main-content\">\n" <>
"<section id=\"intro\">\n" <>
"<h2>About this demonstration</h2>\n" <>
"<p>" <> EscapeHTML[introText] <> "</p>\n" <>
"</section>\n" <>
"<nav aria-label=\"Simulations\">\n" <>
"<h2>Jump to a simulation</h2>\n" <>
"<ol>\n" <> navItems <> "</ol>\n" <>
"</nav>\n" <>
sectionsHtml <>
"<section id=\"about-mint-access\">\n" <>
"<h2>About MINT Access stem</h2>\n" <>
closingHtml <>
"</section>\n" <>
"</main>\n" <>
"<footer>\n" <>
"<p>MINT Access GmbH \[LongDash] mintaccess.ch \[LongDash] github.com/MINT-Access/stem</p>\n" <>
"<p>Demonstration prepared for " <> EscapeHTML[audience] <> ", " <> EscapeHTML[date] <> "</p>\n" <>
"</footer>\n" <>
"</body>\n" <>
"</html>\n";

    Export[outPath, html, "Text"];

    Print[""];
    STEMHeading["Summary"];
    STEMPrintN["Apps with complete outputs", nComplete, "", 2];
    If[nIncomplete > 0,
      STEMPrintN["Apps with missing outputs", nIncomplete, "", 2];
      Print["  (see [WARNING] lines above for which files were missing per app)"]
    ];
    Print["  File: ", outPath];
    Print["  Size: ", Round[FileByteCount[outPath] / 1024., 0.1], " KB"];
    Print[""];
    Print["  Open it with:"];
    Print["    ", OpenHtmlCmd["demo/" <> outFile], "   (macOS)"];
    Print["    xdg-open demo/" <> outFile, "            (Linux)"];
    Print["    start demo/" <> outFile, "               (Windows)"];
    Print[""];

    outPath
  ];

(* ── Run, applying any CLI overrides ─────────────────────────────── *)

(* Maps a CLI flag name to its GenerateOutreachHTML option name; flags
   not listed here (typos, unrecognised keys) are silently ignored
   rather than crashing the run. *)
$outreachCliOptionKey = <|
  "audience" -> "Audience", "date"   -> "Date",   "title"  -> "PageTitle",
  "subtitle" -> "Subtitle", "output" -> "OutputFile"
|>;

$outreachOptOverrides = Select[
  KeyValueMap[
    Function[{flag, val},
      If[KeyExistsQ[$outreachCliOptionKey, flag],
        $outreachCliOptionKey[flag] -> val,
        Nothing
      ]
    ],
    $outreachCliOpts
  ],
  # =!= Nothing &
];

GenerateOutreachHTML[$CuratedApps, Sequence @@ $outreachOptOverrides];

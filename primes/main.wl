#!/usr/bin/env wolframscript

(* ========================================================
   Prime Number Patterns — Entry Point

   Usage:
     wolframscript -file main.wl [-- [--key=value ...]]
     wolframscript -file main.wl -- --config-dump
     wolframscript -file main.wl -- --simulation.mode ulam
     wolframscript -file main.wl -- --simulation.mode gaps
     wolframscript -file main.wl -- --simulation.ulam.size 201
     wolframscript -file main.wl -- --simulation.gaps.count 10000

   Modes:
     ulam — Ulam spiral: size×size prime/composite grid
     gaps — Prime gap rhythm: percussive audio + animated gap chart
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

(* Pre-process CLI args: convert "--key value" pairs to "--key=value"
   so both conventions work (ParseCliOverrides in stem-core requires =). *)
$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$cliArgs = Module[{result = {}, i = 1, arg, next},
  While[i <= Length[$rawArgs],
    arg = $rawArgs[[i]];
    If[StringStartsQ[arg, "--"] && !StringContainsQ[arg, "="] &&
       arg =!= "--config-dump" &&
       i < Length[$rawArgs] &&
       !StringStartsQ[$rawArgs[[i + 1]], "--"],
      next = $rawArgs[[i + 1]];
      AppendTo[result, arg <> "=" <> next];
      i += 2,
      AppendTo[result, arg];
      i += 1
    ]
  ];
  result
];

cfg  = LoadConfig["primes", $cliArgs];
mode = GetCfg[cfg, {"simulation","mode"}, "ulam"];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

Which[

  (* ══════════════════════════════════════════════════════
     ULAM MODE — Ulam spiral prime grid
     ══════════════════════════════════════════════════════ *)
  mode === "ulam",

    With[{
      size           = GetCfg[cfg, {"simulation","ulam","size"},           101],
      colorPrimes    = GetCfg[cfg, {"simulation","ulam","color_primes"},    "white"],
      colorComposite = GetCfg[cfg, {"simulation","ulam","color_composite"}, "black"]
    },
    STEMHeading["Prime Numbers: Ulam Spiral"];
    Print["  Grid size:        ", size, " x ", size,
          If[EvenQ[size], " (will be adjusted to odd)", ""]];
    Print["  Primes colour:    ", colorPrimes];
    Print["  Composite colour: ", colorComposite];
    Print[""]];

    Print["[1/4] Computing Ulam spiral..."];
    STEMSay["Computing Ulam spiral"];
    model = UlamModel[cfg];
    Print["  Grid:         ", model["size"], " x ", model["size"]];
    Print["  Primes found: ", model["prime_count"]];
    Print["  Density:      ",
      FmtN[N[model["prime_density"]] * 100.0, 4], " %"];
    Print[""];

    Print["[2/4] Exporting CSV..."];
    With[{
      n       = model["size"],
      csvPath = FileNameJoin[{$outDir, "ulam_spiral.csv"}]},
      ExportCSV[
        Join[
          {{"integer", "row", "col", "is_prime"}},
          Flatten[
            Table[
              If[PrimeQ[k],
                {{k, model["coords"][[k, 1]], model["coords"][[k, 2]], 1}},
                {}
              ],
              {k, 1, n * n}
            ],
            1
          ]
        ],
        csvPath];
      STEMDescribeCSV[csvPath, model["prime_count"], 4]];
    Print[""];

    Print["[3/4] Rendering image..."];
    STEMSay["Rendering Ulam spiral image"];
    AnimatePrimes[model, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    SonifyPrimes[model, cfg, $outDir];
    Print[""],


  (* ══════════════════════════════════════════════════════
     GAPS MODE — Prime gap rhythm
     ══════════════════════════════════════════════════════ *)
  mode === "gaps",

    With[{
      count        = GetCfg[cfg, {"simulation","gaps","count"},        5000],
      maxGapDisp   = GetCfg[cfg, {"simulation","gaps","max_gap_display"}, 72],
      tempoBpm     = GetCfg[cfg, {"sonification","gaps","tempo_bpm"},  120],
      toneDurMs    = GetCfg[cfg, {"sonification","gaps","tone_duration_ms"}, 80]
    },
    STEMHeading["Prime Numbers: Gap Rhythm"];
    Print["  Prime count:       ", count];
    Print["  Max gap display:   ", maxGapDisp];
    Print["  Base tempo:        ", tempoBpm, " bpm"];
    Print["  Tone duration:     ", toneDurMs, " ms"];
    Print[""]];

    Print["[1/4] Computing prime gaps..."];
    STEMSay["Computing prime gaps"];
    model = GapsModel[cfg];
    Print["  Primes computed: ", Length[model["primes"]]];
    Print["  Largest prime:   ", Last[model["primes"]]];
    Print["  Mean gap:        ", FmtN[model["mean_gap"], 5]];
    Print["  Largest gap:     ", model["max_gap"]];
    Print["  Twin prime pairs:", model["twin_prime_count"]];
    Print[""];

    Print["[2/4] Exporting CSV..."];
    With[{
      gaps     = model["gaps"],
      primes   = model["primes"],
      csvPath  = FileNameJoin[{$outDir, "gaps_stats.csv"}]},
      ExportCSV[
        Join[
          {{"n", "prime", "next_prime", "gap", "cumulative_gap", "is_twin_prime"}},
          Table[
            {i,
             primes[[i]],
             primes[[i + 1]],
             gaps[[i]],
             primes[[i + 1]] - primes[[1]],
             If[gaps[[i]] === 2, 1, 0]},
            {i, 1, Length[gaps]}
          ]
        ],
        csvPath];
      STEMDescribeCSV[csvPath, Length[gaps], 6]];
    Print[""];

    Print["[3/4] Rendering animation..."];
    STEMSay["Rendering prime gap animation"];
    AnimatePrimes[model, cfg, $outDir];
    Print[""];

    Print["[4/4] Sonifying..."];
    SonifyPrimes[model, cfg, $outDir];
    Print[""],


  (* Unknown mode *)
  True,
    Print["Error: unknown simulation.mode \"", mode,
          "\" — expected \"ulam\" or \"gaps\"."];
    Exit[1]
];

STEMHeading["Done"];
STEMSay["Complete. Play audio: afplay " <> FileNameJoin[{$outDir, mode <> "_audio.wav"}]]

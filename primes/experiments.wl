#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Prime number patterns parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its GIF/PNG, CSV, and WAV to output/
   with a named prefix so results are easy to compare.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];


(* --- Helper: run one Ulam experiment --- *)

RunUlamExperiment[label_String, cfg_Association] :=
  Module[{model},
    Print[""];
    Print[">>> Experiment: ulam_spiral  — ", label];
    model = UlamModel[cfg];
    Print["  Grid:         ", model["size"], " x ", model["size"]];
    Print["  Primes:       ", model["prime_count"]];
    Print["  Density:      ", FmtN[N[model["prime_density"]] * 100.0, 4], " %"];
    AnimatePrimes[model, cfg, $outDir];
    SonifyPrimes[model, cfg, $outDir];
    Print["    Output: output/ulam_*"]
  ]


(* --- Helper: run one Gaps experiment --- *)

RunGapsExperiment[label_String, cfg_Association] :=
  Module[{model, csvPath, gaps, primes},
    Print[""];
    Print[">>> Experiment: prime_gaps  — ", label];
    model = GapsModel[cfg];
    Print["  Primes:        ", Length[model["primes"]]];
    Print["  Largest prime: ", Last[model["primes"]]];
    Print["  Mean gap:      ", FmtN[model["mean_gap"], 5]];
    Print["  Max gap:       ", model["max_gap"]];
    Print["  Twin pairs:    ", model["twin_prime_count"]];

    gaps   = model["gaps"];
    primes = model["primes"];
    csvPath = FileNameJoin[{$outDir, "gaps_stats.csv"}];
    ExportCSV[
      Join[
        {{"n", "prime", "next_prime", "gap", "cumulative_gap", "is_twin_prime"}},
        Table[
          {i, primes[[i]], primes[[i+1]], gaps[[i]],
           primes[[i+1]] - primes[[1]],
           If[gaps[[i]] === 2, 1, 0]},
          {i, 1, Length[gaps]}
        ]
      ],
      csvPath];
    Print["    CSV -> ", csvPath];

    AnimatePrimes[model, cfg, $outDir];
    SonifyPrimes[model, cfg, $outDir];
    Print["    Output: output/gaps_*"]
  ]


(* ================================================================
   EXPERIMENT DEFINITIONS
   ================================================================ *)

(* --- ulam_small: 51x51 grid — clear diagonal structure visible at small size --- *)
(* A small Ulam spiral makes the diagonal prime alignments visible as
   dense white streaks even without zooming. At 51x51 all integers up to
   2601 are covered; prime density is about 12%. *)
RunUlamExperiment["51x51 grid — diagonals clearly visible",
  <| "simulation" -> <| "mode" -> "ulam",
    "ulam" -> <| "size" -> 51, "color_primes" -> "white", "color_composite" -> "black" |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 120, "max_hz" -> 1000 |> |> |>
];


(* --- ulam_large: 201x201 grid — macro diagonal patterns emerge --- *)
(* The large spiral reveals macro-scale diagonal corridors that are
   invisible at smaller sizes. At 201x201 about 40000 integers are covered;
   prime density drops to ~8%. The audio spans the full 30 rows used in
   row-scan sonification. *)
RunUlamExperiment["201x201 grid — macro diagonal corridors",
  <| "simulation" -> <| "mode" -> "ulam",
    "ulam" -> <| "size" -> 201, "color_primes" -> "white", "color_composite" -> "black" |>
  |>,
  "sonification" -> <| "pitch" -> <| "min_hz" -> 120, "max_hz" -> 1000 |> |> |>
];


(* --- gaps_first_thousand: first 1000 prime gaps --- *)
(* Covers primes up to 7919. All prime gaps are even except 2→3.
   The gap chart shows that large gaps are rare; twin primes (gap=2) are
   the most common. Sonification: fast tempo highlights the irregular rhythm. *)
RunGapsExperiment["first 1000 primes (up to 7919)",
  <| "simulation" -> <| "mode" -> "gaps",
    "gaps" -> <| "count" -> 1000, "max_gap_display" -> 36 |>
  |>,
  "sonification" -> <| "gaps" -> <| "tempo_bpm" -> 120, "tone_duration_ms" -> 80 |> |> |>
];


(* --- gaps_ten_thousand: first 10000 prime gaps --- *)
(* Covers primes up to 104729. As count grows, mean gap ~ ln(p) increases
   and the largest gap grows too. The audio at default tempo is ~30 s;
   the slow version is ~120 s and lets you count individual gap events. *)
RunGapsExperiment["first 10000 primes (up to ~104729)",
  <| "simulation" -> <| "mode" -> "gaps",
    "gaps" -> <| "count" -> 10000, "max_gap_display" -> 72 |>
  |>,
  "sonification" -> <| "gaps" -> <| "tempo_bpm" -> 120, "tone_duration_ms" -> 80 |> |> |>
];


(* --- twin_primes: focus on twin prime structure in 5000 primes --- *)
(* Same data as the default run but with a slow tempo (60 bpm) so the
   rhythm of twin-prime pairs (back-to-back attacks separated by 2/total_range)
   is perceptible to the ear. *)
RunGapsExperiment["5000 primes at slow tempo — twin-prime rhythm audible",
  <| "simulation" -> <| "mode" -> "gaps",
    "gaps" -> <| "count" -> 5000, "max_gap_display" -> 72 |>
  |>,
  "sonification" -> <| "gaps" -> <| "tempo_bpm" -> 60, "tone_duration_ms" -> 120 |> |> |>
];


Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

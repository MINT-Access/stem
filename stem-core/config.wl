(* ========================================================
   stem-core/config.wl — Configuration loading and merging

   Public API:
     LoadConfig[appName, cliArgs]
       Deep-merges: hardcoded defaults → config/config.json
                    → appName/config.json → CLI key=value args.
       If "--config-dump" is present in cliArgs, prints the
       merged config as JSON and exits — useful for debugging
       and for blind users who want to inspect active settings.
       Returns the merged config as a nested Association.

     DeepMerge[base, override]
       Merges two Associations recursively: nested Associations
       at the same key are merged; scalar values in override
       win; keys only in base are preserved.

   Locates the project root (stem/) from $InputFileName at
   load time — no hardcoded paths.

   Load order: this file must be loaded after utils.wl because
   it relies on nothing from utils.wl itself, but it must be
   loaded before any project code that calls LoadConfig.
   ======================================================== *)


(* ── Derive stem root from this file's own path ──────────── *)
(*
   At Get-load time $InputFileName = .../stem-core/config.wl.
   DirectoryName strips the filename  → .../stem-core
   DirectoryName again strips stem-core → .../stem           *)

$StemRoot = DirectoryName[DirectoryName[$InputFileName]];


(* ── ConfigToAssoc ───────────────────────────────────────── *)
(*
   Recursively converts the list-of-rules that WL's JSON
   importer may return into a proper nested Association.
   Named ConfigToAssoc to avoid shadowing the local toAssoc
   in asteroids/src/fetch.wl.                               *)

ConfigToAssoc[l : {__Rule}] :=
  Association[Map[(First[#] -> ConfigToAssoc[Last[#]]) &, l]];
ConfigToAssoc[l_List] := Map[ConfigToAssoc, l];
ConfigToAssoc[x_]     := x;


(* ── DeepMerge ───────────────────────────────────────────── *)
(*
   Merge two Associations.  Where both have the same key and
   both values are Associations, recurse.  Otherwise the
   override value wins.  Keys present only in base survive.
   Non-Association arguments fall through to the last clause. *)

DeepMerge[base_Association, override_Association] :=
  Module[{allKeys},
    allKeys = Union[Keys[base], Keys[override]];
    Association[Map[
      Function[k,
        k -> Which[
          KeyExistsQ[base, k] && KeyExistsQ[override, k] &&
            AssociationQ[base[k]] && AssociationQ[override[k]],
          DeepMerge[base[k], override[k]],

          KeyExistsQ[override, k],
          override[k],

          True,
          base[k]
        ]
      ],
      allKeys
    ]]
  ]

DeepMerge[base_Association, <||>]          := base
DeepMerge[<||>, override_Association]      := override
DeepMerge[_,    override_]                 := override


(* ── GetCfg ──────────────────────────────────────────────── *)
(*
   Public helper for safe nested key-path lookup — available to
   all app code after init.wl loads config.wl.  Identical logic
   to the private CfgAt in sonification.wl but in Global context.

   Usage:
     GetCfg[cfg, {"sonification","pitch","min_hz"}, 110]
     GetCfg[cfg, {"simulation","lorenz","sigma"}, 10.0]   *)

GetCfg[cfg_Association, keys_List, default_] :=
  If[Length[keys] === 0, default,
    With[{inner = Fold[Lookup[#1, #2, <||>] &, cfg, Most[keys]]},
      Lookup[inner, Last[keys], default]
    ]
  ]


(* ── LoadJsonConfig ──────────────────────────────────────── *)
(*
   Loads a JSON file and returns an Association.
   Returns an empty Association if the file is absent so that
   Fold[DeepMerge, ...] silently skips missing layers.       *)

LoadJsonConfig[path_String] :=
  Module[{raw},
    If[!FileExistsQ[path], Return[<||>]];
    raw = Import[path, "JSON"];
    If[raw === $Failed,
      Print["[WARNING] Could not parse JSON: ", path, " — skipping."];
      Return[<||>]
    ];
    ConfigToAssoc[raw]
  ]


(* ── ParseCliOverrides ───────────────────────────────────── *)
(*
   Parses "--key=value" and "--section.key=value" CLI strings
   into a nested Association suitable for DeepMerge.

   Value coercion rules:
     "true"  → True   "false" → False
     numeric (including negative) → number   otherwise → string as-is

   "--config-dump" and bare "--key" flags (no "=") are ignored
   here; "--config-dump" is handled separately in LoadConfig.
   Unrecognised flags print a [WARNING] but are still passed through
   so that app-specific bare flags (e.g. --no-orbital-elements) are
   not accidentally silenced.

   Example:
     "--sonification.scale=Phrygian"
       → <| "sonification" -> <| "scale" -> "Phrygian" |> |>
     "--simulation.simple.angle_deg=-30"
       → <| "simulation" -> <| "simple" -> <| "angle_deg" -> -30 |> |> |>  *)

$numericPattern = ("-" | "") ~~ NumberString;

ParseCliOverrides[args_List] :=
  Module[{kvArgs, bareFlags, parsed},
    kvArgs    = Select[args, StringStartsQ[#, "--"] && StringContainsQ[#, "="] &];
    bareFlags = Select[args,
      StringStartsQ[#, "--"] && !StringContainsQ[#, "="] &&
      # =!= "--config-dump" &];
    If[Length[bareFlags] > 0,
      Scan[
        Print["[WARNING] Unrecognised CLI flag (no value): ", #] &,
        bareFlags
      ]
    ];
    parsed = Map[
      Function[arg,
        Module[{stripped, parts, keyPath, rawVal, value, keys},
          stripped = StringDrop[arg, 2];
          parts    = StringSplit[stripped, "=", 2];
          keyPath  = parts[[1]];
          rawVal   = If[Length[parts] > 1, parts[[2]], "true"];
          value    = Which[
            rawVal === "true",                       True,
            rawVal === "false",                      False,
            StringMatchQ[rawVal, $numericPattern],   ToExpression[rawVal],
            True,                                    rawVal
          ];
          (* Build a nested Association from dot-separated path *)
          keys = StringSplit[keyPath, "."];
          Fold[
            Function[{inner, k}, <|k -> inner|>],
            value,
            Reverse[keys]
          ]
        ]
      ],
      kvArgs
    ];
    Fold[DeepMerge, <||>, parsed]
  ]


(* ── $HardcodedDefaults ──────────────────────────────────── *)
(*
   Baseline values that apply even when both JSON config files
   are absent.  These mirror config/config.json so that the
   JSON file is the canonical human-editable source while
   this Association acts as a compile-time safety net.       *)

$HardcodedDefaults = <|
  "version" -> "1.0.0",
  "output" -> <|
    "directory" -> "output",
    "csv"       -> True,
    "gif"       -> True,
    "wav"       -> True,
    "overwrite" -> True,
    "manifest"  -> True
  |>,
  "accessibility" -> <|
    "speak"     -> False,
    "verbosity" -> "normal",
    "voiceover" -> True,
    "language"  -> "en-GB",
    "announce"  -> True,
    "voice"     -> "Daniel",
    "rate"      -> 180
  |>,
  "animation" -> <|
    "frameRate"   -> 10,
    "imageWidth"  -> 400,
    "imageHeight" -> 400,
    "holdSeconds" -> 3,
    "background"  -> "dark",
    "colorScheme" -> "accessible"
  |>,
  "sonification" -> <|
    "scale"    -> "MinorPentatonic",
    "duration" -> 10.0,
    "motion"   -> <| "noteDuration" -> 0.55, "gapDuration" -> 0.12 |>
  |>,
  "data" -> <|
    "logErrors"    -> True,
    "logPath"      -> "output/errors.log",
    "csvDelimiter" -> ",",
    "decimalPlaces" -> 6
  |>
|>;


(* ── LoadConfig ──────────────────────────────────────────── *)
(*
   Builds the fully merged configuration for an app.

   Priority (lowest → highest):
     $HardcodedDefaults
       → config/config.json           (project-level)
         → appName/config.json        (app-specific overrides)
           → cliArgs key=value pairs  (per-run overrides)

   Special flags in cliArgs:
     --config-dump   Print merged config as JSON then Exit[0].
                     Tip: pipe to jq for formatted output:
                       wolframscript -file main.wl -- --config-dump | jq

   Arguments:
     appName  — directory name of the calling app, e.g. "pendulum"
     cliArgs  — list of CLI argument strings, typically from
                Select[Rest[$ScriptCommandLine], # =!= "--" &]  *)

LoadConfig[appName_String, cliArgs_List : {}] :=
  Module[{globalPath, appPath, globalCfg, appCfg, cliOverrides, merged},

    globalPath   = FileNameJoin[{$StemRoot, "config", "config.json"}];
    appPath      = FileNameJoin[{$StemRoot, appName, "config.json"}];

    globalCfg    = LoadJsonConfig[globalPath];
    appCfg       = LoadJsonConfig[appPath];
    cliOverrides = ParseCliOverrides[cliArgs];

    merged = Fold[DeepMerge, $HardcodedDefaults,
               {globalCfg, appCfg, cliOverrides}];

    If[MemberQ[cliArgs, "--config-dump"],
      Print[ExportString[merged, "JSON"]];
      Exit[0]
    ];

    merged
  ]

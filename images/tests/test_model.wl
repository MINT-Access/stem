#!/usr/bin/env wolframscript

(* images/tests/test_model.wl — Unit tests for model.wl *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label]; failed++
  ];

Print["=== images/src/model.wl unit tests ==="];
Print[""];

(* ── Palette tests ─────────────────────────────────────────────────── *)
Print["-- Spectral colour palette --"];
AssertTrue["palette has 9 entries (8 spectral colours + black)", Length[$imgPalette] === 9];
AssertTrue["each entry has name key",  AllTrue[$imgPalette, KeyExistsQ[#, "name"] &]];
AssertTrue["each entry has rgb key",   AllTrue[$imgPalette, KeyExistsQ[#, "rgb"] &]];
AssertTrue["each entry has freq key",  AllTrue[$imgPalette, KeyExistsQ[#, "freq"] &]];
AssertTrue["each entry has spectral_position key",
  AllTrue[$imgPalette, KeyExistsQ[#, "spectral_position"] &]];
AssertTrue["all rgb values in [0,1]",
  AllTrue[$imgPalette, AllTrue[#["rgb"], 0 <= # <= 1 &] &]];
AssertTrue["all freqs are non-negative (black = 0 = silence)",
  AllTrue[$imgPalette, #["freq"] >= 0 &]];
AssertTrue["black is the only silent (freq=0) entry",
  Length[Select[$imgPalette, #["freq"] === 0.0 &]] === 1];
Print[""];

(* ── Spectral palette Lab-distance lookup ───────────────────────────── *)
Print["-- NearestPaletteIndex (Lab ColorDistance) --"];
Module[{violetIdx, redIdx, blueIdx, whiteIdx},
  violetIdx = NearestPaletteIndex[{0.50, 0.00, 0.50}, $imgPalette];
  AssertTrue["exact violet RGB maps to violet entry",
    $imgPalette[[violetIdx]]["name"] === "violet"];
  AssertTrue["violet maps to C3 (130.81 Hz)",
    Abs[$imgPalette[[violetIdx]]["freq"] - 130.81] < 0.01];

  redIdx = NearestPaletteIndex[{1.00, 0.00, 0.00}, $imgPalette];
  AssertTrue["exact red RGB maps to red entry",
    $imgPalette[[redIdx]]["name"] === "red"];
  AssertTrue["red maps to D4 (293.66 Hz)",
    Abs[$imgPalette[[redIdx]]["freq"] - 293.66] < 0.01];

  (* Slightly perturbed colours should still resolve to the nearest
     palette entry, not just exact matches. *)
  blueIdx = NearestPaletteIndex[{0.05, 0.02, 0.92}, $imgPalette];
  AssertTrue["near-blue RGB still maps to blue entry",
    $imgPalette[[blueIdx]]["name"] === "blue"];

  whiteIdx = NearestPaletteIndex[{0.95, 0.97, 0.93}, $imgPalette];
  AssertTrue["near-white RGB still maps to white entry",
    $imgPalette[[whiteIdx]]["name"] === "white"];
];
Print[""];

(* ── BrightnessToFreq scaling ─────────────────────────────────────────── *)
Print["-- BrightnessToFreq --"];
AssertTrue["log scale: b=0 -> freqMin exactly",
  Abs[BrightnessToFreq[0.0, 200.0, 2000.0, "log", 1.0] - 200.0] < 10^-9];
AssertTrue["log scale: b=1 -> freqMax exactly",
  Abs[BrightnessToFreq[1.0, 200.0, 2000.0, "log", 1.0] - 2000.0] < 10^-9];
AssertTrue["linear scale: b=0 -> freqMin exactly",
  Abs[BrightnessToFreq[0.0, 200.0, 2000.0, "linear"] - 200.0] < 10^-9];
AssertTrue["linear scale: b=1 -> freqMax exactly",
  Abs[BrightnessToFreq[1.0, 200.0, 2000.0, "linear"] - 2000.0] < 10^-9];
AssertTrue["linear scale: b=0.5 -> midpoint",
  Abs[BrightnessToFreq[0.5, 200.0, 2000.0, "linear"] - 1100.0] < 10^-9];
AssertTrue["log scale is monotonically increasing in b",
  With[{f0 = BrightnessToFreq[0.2, 200.0, 2000.0, "log", 1.0],
        f1 = BrightnessToFreq[0.5, 200.0, 2000.0, "log", 1.0],
        f2 = BrightnessToFreq[0.8, 200.0, 2000.0, "log", 1.0]},
    f0 < f1 < f2]];
AssertTrue["gamma > 1 compresses highlights (lower freq at b=0.5 than gamma=1)",
  BrightnessToFreq[0.5, 200.0, 2000.0, "log", 2.5] <
  BrightnessToFreq[0.5, 200.0, 2000.0, "log", 1.0]];
AssertTrue["default args equal explicit log/gamma=1",
  BrightnessToFreq[0.5, 200.0, 2000.0] === BrightnessToFreq[0.5, 200.0, 2000.0, "log", 1.0]];
Print[""];

(* ── Run-length encoding ─────────────────────────────────────────────── *)
Print["-- ColourRunsFromIndices (run-length encoding) --"];
AssertTrue["a uniform-colour sequence produces exactly one run",
  Length[ColourRunsFromIndices[{3, 3, 3, 3, 3, 3, 3, 3}]] === 1];
AssertTrue["the single run contains every element",
  First[ColourRunsFromIndices[{5, 5, 5, 5}]] === {5, 5, 5, 5}];
AssertTrue["alternating colours produce one run per pixel",
  Length[ColourRunsFromIndices[{1, 2, 1, 2, 1}]] === 5];
AssertTrue["a mixed sequence groups only consecutive equal runs",
  ColourRunsFromIndices[{1, 1, 2, 2, 2, 1}] === {{1, 1}, {2, 2, 2}, {1}}];
Print[""];

(* ── Raster traversal ─────────────────────────────────────────────────── *)
Print["-- RasterTraversalOrder --"];
Module[{raster4},
  raster4 = RasterTraversalOrder[4];  (* order 4 -> 16x16 = 256 pixels *)
  AssertTrue["raster traversal has 256 entries", Length[raster4] === 256];
  AssertTrue["raster traversal visits each pixel once",
    Length[DeleteDuplicates[raster4]] === 256];
  AssertTrue["raster traversal starts at {1,1}", First[raster4] === {1, 1}];
  AssertTrue["raster traversal is row-major (2nd pixel is {2,1})",
    raster4[[2]] === {2, 1}];
  AssertTrue["raster traversal wraps to next row after 16 pixels",
    raster4[[17]] === {1, 2}];
  AssertTrue["raster traversal ends at {16,16}", Last[raster4] === {16, 16}];
];
Print[""];

(* ── LoadSourceImage tests ─────────────────────────────────────────── *)
Print["-- LoadSourceImage --"];
{imgG, descG} = LoadSourceImage["", "gaussian", 16];
AssertTrue["gaussian returns Image",          ImageQ[imgG]];
AssertTrue["gaussian has correct dimensions", ImageDimensions[imgG] === {16, 16}];
AssertTrue["gaussian description is string",  StringQ[descG]];

{imgT, descT} = LoadSourceImage["", "temperature", 16];
AssertTrue["temperature returns Image",       ImageQ[imgT]];

{imgQ, descQ} = LoadSourceImage["", "quantum", 16];
AssertTrue["quantum returns Image",           ImageQ[imgQ]];
Print[""];

(* ── ComputeImageTraversal tests ──────────────────────────────────── *)
Print["-- ComputeImageTraversal --"];
model = ComputeImageTraversal[imgG, 4];  (* order 4 -> 16x16 = 256 pixels *)
AssertTrue["model is Association",          AssociationQ[model]];
AssertTrue["nPixels = 16^2 = 256",         model["nPixels"] === 256];
AssertTrue["traversal has 256 entries",    Length[model["traversal"]] === 256];
AssertTrue["imgSize key is 16",            model["imgSize"] === 16];
AssertTrue["imgN key is 4",               model["imgN"] === 4];
AssertTrue["traversal col in [1,16]",
  AllTrue[model["traversal"][[All,1]], 1 <= # <= 16 &]];
AssertTrue["traversal row in [1,16]",
  AllTrue[model["traversal"][[All,2]], 1 <= # <= 16 &]];
AssertTrue["traversal visits each pixel once",
  Length[DeleteDuplicates[model["traversal"]]] === 256];
AssertTrue["pixBright has 256 values",    Length[model["pixBright"]] === 256];
AssertTrue["pixHue has 256 values",       Length[model["pixHue"]]    === 256];
AssertTrue["pixSat has 256 values",       Length[model["pixSat"]]    === 256];
AssertTrue["pixBright values in [0,1]",
  AllTrue[model["pixBright"], 0.0 <= # <= 1.0 &]];
AssertTrue["pixHue values in [0,1]",
  AllTrue[model["pixHue"], 0.0 <= # <= 1.0 &]];
AssertTrue["img key is Image",            ImageQ[model["img"]]];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]]

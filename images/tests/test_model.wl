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
Print["-- Colour palette --"];
AssertTrue["palette has 10 entries", Length[$imgPalette] === 10];
AssertTrue["each entry has name key",  AllTrue[$imgPalette, KeyExistsQ[#, "name"] &]];
AssertTrue["each entry has rgb key",   AllTrue[$imgPalette, KeyExistsQ[#, "rgb"] &]];
AssertTrue["each entry has freq key",  AllTrue[$imgPalette, KeyExistsQ[#, "freq"] &]];
AssertTrue["all rgb values in [0,1]",
  AllTrue[$imgPalette, AllTrue[#["rgb"], 0 <= # <= 1 &] &]];
AssertTrue["all freqs are positive",
  AllTrue[$imgPalette, #["freq"] > 0 &]];
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

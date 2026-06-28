#!/usr/bin/env wolframscript

(* ========================================================
   tests/test_model.wl — Unit tests for the relativity model
   Usage: wolframscript -file tests/test_model.wl
   ======================================================== *)

$projectRoot  = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];

passed = 0;
failed = 0;

AssertTrue[label_String, condition_] :=
  If[TrueQ[condition],
    Print["  PASS  ", label];
    passed++,
    Print["  FAIL  ", label];
    failed++
  ]

Print["Running tests..."];
Print[""];

(* --- ChirpModel tests --- *)

chirpCfg = <|
  "simulation" -> <| "mode" -> "chirp",
    "chirp" -> <|
      "mass1_solar"       -> 30.0,
      "mass2_solar"       -> 30.0,
      "distance_mpc"      -> 400.0,
      "sample_rate"       -> 1024,
      "frequency_min_hz"  -> 20.0,
      "frequency_max_hz"  -> 500.0,
      "ringdown_duration" -> 0.02,
      "preset"            -> ""
    |>
  |>,
  "sonification" -> <| "chirp" -> <| "time_stretch" -> 4.0 |> |>
|>;

model = ChirpModel[chirpCfg];

(* Test 1: returns Association with required keys *)
AssertTrue["ChirpModel returns required keys",
  AssociationQ[model] &&
  AllTrue[{"time","strain","frequency","amplitude","chirp_mass_solar",
           "coalescence_time","peak_frequency","mode"}, KeyExistsQ[model, #] &]];

(* Test 2: mode is "chirp" *)
AssertTrue["ChirpModel mode field is \"chirp\"",
  model["mode"] === "chirp"];

(* Test 3: all arrays have the same length *)
AssertTrue["time/strain/frequency/amplitude arrays all have equal length",
  Length[model["time"]] === Length[model["strain"]] &&
  Length[model["strain"]] === Length[model["frequency"]]];

(* Test 4: frequency starts near fMin = 20 Hz *)
AssertTrue["Initial GW frequency is within 25% of 20 Hz",
  Abs[First[model["frequency"]] - 20.0] < 5.0];

(* Test 5: chirp mass is positive and less than total mass *)
totalMass = 60.0;
AssertTrue["Chirp mass is positive and less than total mass",
  0.0 < model["chirp_mass_solar"] < totalMass];

(* Test 6: equal masses give chirp mass = m * 2^(-1/5) *)
(* For m1=m2=m: Mchirp = (m*m)^(3/5) * (2m)^(2/5) = m * 2^(-1/5) *)
expectedChirp = 30.0 * 2.0^(-1/5);
AssertTrue["Equal-mass chirp mass matches m * 2^(-1/5) within 0.1%",
  Abs[model["chirp_mass_solar"] - expectedChirp] / expectedChirp < 0.001];

(* Test 7: frequency monotonically increases through inspiral
   Use merger_index to delimit the inspiral portion exactly — the ringdown
   appends a constant QNM frequency that is lower than the inspiral peak,
   so any threshold search on the full array would cross the boundary. *)
With[{freqs = model["frequency"], mIdx = model["merger_index"]},
  inspiral = freqs[[;; mIdx]];
  AssertTrue["GW frequency is monotonically increasing through inspiral",
    Min[Differences[inspiral]] >= -0.1]];

(* Test 8: strain has non-zero amplitude *)
AssertTrue["Strain signal has non-zero peak amplitude",
  Max[Abs[model["strain"]]] > 0.0];

(* Test 9: coalescence time is positive *)
AssertTrue["Coalescence time is positive",
  model["coalescence_time"] > 0.0];

(* --- GeodesicModel tests --- *)

geodesicCfg = <|
  "simulation" -> <| "mode" -> "geodesic",
    "geodesic" -> <|
      "mass_solar"   -> 10.0,
      "orbit_type"   -> "bound",
      "tau_max_m"    -> 500.0,
      "n_steps"      -> 1000,
      "bound" -> <|
        "r_start_rs"              -> 10.0,
        "angular_momentum_factor" -> 0.85
      |>
    |>
  |>,
  "sonification" -> <| "geodesic" -> <| "pitch_base_hz" -> 220.0, "duration_s" -> 5.0 |> |>
|>;

geo = GeodesicModel[geodesicCfg];

(* Test 10: returns Association with required keys *)
AssertTrue["GeodesicModel returns required keys",
  AssociationQ[geo] &&
  AllTrue[{"tau","r","phi","x","y","redshift","mode"}, KeyExistsQ[geo, #] &]];

(* Test 11: mode is "geodesic" *)
AssertTrue["GeodesicModel mode field is \"geodesic\"",
  geo["mode"] === "geodesic"];

(* Test 12: all arrays have same length *)
AssertTrue["tau/r/phi arrays all have equal length",
  Length[geo["tau"]] === Length[geo["r"]] &&
  Length[geo["r"]]   === Length[geo["phi"]]];

(* Test 13: first radial value matches r_start_rs * 2 (in units of M) *)
AssertTrue["Initial radius is r_start_rs * 2 M",
  Abs[First[geo["r"]] - 20.0] < 0.1];

(* Test 14: r_min is above the event horizon (r̃ > 2) for a bound orbit *)
AssertTrue["Bound orbit r_min stays above the event horizon",
  geo["r_min"] > 2.0];

(* Test 15: redshift factor is between 0 and 1 everywhere *)
AssertTrue["Gravitational redshift factor is in [0,1]",
  Min[geo["redshift"]] >= 0.0 && Max[geo["redshift"]] <= 1.0];

(* Test 16: Cartesian coords satisfy x^2 + y^2 = r^2 *)
With[{
  xArr = geo["x"], yArr = geo["y"], rArr = geo["r"],
  sample = {1, 100, 500, 1000}},
  residuals = Map[
    Abs[xArr[[#]]^2 + yArr[[#]]^2 - rArr[[#]]^2] &,
    Select[sample, # <= Length[rArr] &]
  ];
  AssertTrue["x^2 + y^2 = r^2 holds at sampled points",
    Max[residuals] < 1*^-6]];

(* --- Summary --- *)
Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

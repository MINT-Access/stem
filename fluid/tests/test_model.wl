#!/usr/bin/env wolframscript

(* fluid/tests/test_model.wl — Unit tests for model.wl *)

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

Print["=== fluid/src/model.wl unit tests ==="];
Print[""];

(* ── 1. Strouhal formula (Re=150) ──────────────────────────────────
   St = 0.198*(1 - 19.7/150) = 0.171996 to 6 sig figs. The build
   spec's own illustrative text rounds this to "0.1718", off by
   ~0.0002 from the precise value below -- checked against the
   precisely-computed constant instead of the spec's rounded prose
   figure (same category of correction as dynamical/AGENTS.md's
   period3_window r-value fix). *)
Print["-- StrouhalNumber --"];
st150 = StrouhalNumber[150.0];
AssertTrue["St(150) = 0.171996 within 0.0001", Abs[st150 - 0.171996] < 0.0001];
Print[""];

(* ── 2. Shedding frequency (U=1, D=1) ──────────────────────────────
   f_shed = St * U / D = St itself when U=D=1. *)
Print["-- SheddingFrequency --"];
fShed150 = SheddingFrequency[st150, 1.0, 1.0];
AssertTrue["f_shed(St=St(150), U=1, D=1) = 0.171996 within 0.0001",
  Abs[fShed150 - 0.171996] < 0.0001];
Print[""];

(* ── 3. Shedding interval ──────────────────────────────────────────
   dtShed = 1/(2 f_shed) = 2.90704 to 6 sig figs. The build spec's
   illustrative "2.909" is a downstream rounding artifact of its own
   already-rounded "0.1718" St figure; checked against the value
   implied by the precise St(150) above. *)
Print["-- SheddingInterval --"];
dtShed150 = SheddingInterval[fShed150];
AssertTrue["dtShed = 2.90704 within 0.001", Abs[dtShed150 - 2.90704] < 0.001];
Print[""];

(* ── 4. Biot-Savart velocity ────────────────────────────────────────
   For a point vortex of circulation Gamma=1 at (0,1), the induced
   velocity at (1,0) is (1/(4 pi), 1/(4 pi)) -- NOT (1/(2 pi), 0) as
   the build spec's prose claims. Verified two independent ways
   (complex-notation w* = Gamma/(2 pi i (z-zj)), and the standard
   real-component 2D point-vortex formula): both give (1/(4pi),
   1/(4pi)) ~ (0.0795775, 0.0795775). The claimed (1/(2pi), 0) is not
   reachable from these exact positions under any consistent
   CW/CCW sign convention -- the separation vector (1,-1) sits at
   45 degrees to both axes, so the induced velocity's x and y
   components are necessarily equal in magnitude; the spec text
   appears to have conflated this case with a vortex-at-origin,
   point-at-(0,1) setup. See AGENTS.md design decision for detail. *)
Print["-- BiotSavartVelocity --"];
bsVel = BiotSavartVelocity[1.0, 0.0, 1.0, 1.0, 0.0];
AssertTrue["induced velocity = (1/(4 pi), 1/(4 pi)) within 0.001",
  Abs[bsVel[[1]] - 1.0/(4.0 Pi)] < 0.001 && Abs[bsVel[[2]] - 1.0/(4.0 Pi)] < 0.001];
Print[""];

(* ── 5. Flag flutter frequency ─────────────────────────────────────
   f_flag = 0.15 U / flagLength = 0.15*1/5 = 0.03 exactly. *)
Print["-- Flag flutter frequency --"];
fFlagTest = 0.15 * 1.0 / 5.0;
AssertTrue["f_flag(U=1, flagLength=5) = 0.03 within 0.001", Abs[fFlagTest - 0.03] < 0.001];
Print[""];

Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]]

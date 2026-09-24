#!/usr/bin/env wolframscript

(* ========================================================
   dynamical/prototype_lyapunov.wl — LISTENING PROTOTYPE

   Three candidate sonifications of the Lyapunov exponent lambda(r)
   of the logistic map, modelled on example S15.4 (Grond & Berger,
   The Sonification Handbook, ch. 15): a continuous lambda tone, a
   fixed reference tone at lambda = 0, and bifurcation marker tones.

   Standalone: reuses stem-core and the app's model.wl / sonify.wl
   but changes nothing in the app itself.

     wolframscript -file dynamical/prototype_lyapunov.wl

   Common to all variants
     r = 3.40 -> 3.90, 500 equal steps, 40 s of audio at 44100 Hz.
     lambda(r): orbit from x0 = 0.5 (AttractorPoints, so the app's
       SafeX0 nudge to 0.500001 applies), 500 transient iterations
       discarded, mean of Log|r (1 - 2x)| over the next 2000;
       clipped at a floor of -1.0.
     lambda tone: f = 220 * 2^lambda, lambda linearly interpolated
       between steps and phase-accumulated, so it glides without clicks.
     Markers: r = 3.449 / 3.570 / 3.828, using sweep mode's own
       OverlayEvent sounds (660 Hz bifurcation, 440 Hz chaos onset,
       528 Hz period-3 window).
     Loudness: one common gain for all three files, set so variant A
       meets the project's -17 LUFS target (0.97 peak ceiling enforced
       across all three). A shared gain keeps the lambda tone and markers
       sample-identical across files; B and C land near, not exactly at,
       -17 LUFS.

   Variants
     A  lambda sine + reference sine at equal level
     B  as A, lambda tone gains 2nd and 3rd harmonics (0.25, 0.12);
        the fundamental is unchanged
     C  as A, reference gain is 1 for |lambda| <= 0.10, 0 for
        |lambda| >= 0.15, raised-cosine in between

   Outputs (dynamical/output/)
     prototype_lyapunov_A.wav / _B.wav / _C.wav
     prototype_lyapunov.png
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];

$params = <|
  "rStart" -> 3.40, "rEnd" -> 3.90, "rSteps" -> 500, "durSec" -> 40.0,
  "x0" -> 0.5, "nTransient" -> 500, "nAverage" -> 2000, "lambdaFloor" -> -1.0,
  "refHz" -> 220.0, "toneAmp" -> 0.3, "edgeFadeSec" -> 0.02,
  "harmonicsB" -> {0.25, 0.12}, "approachOn" -> 0.10, "approachOff" -> 0.15,
  "targetLUFS" -> -17.0, "peakCeiling" -> 0.97, "sr" -> $StemSampleRate
|>;

(* Markers: r value, and the sweep-mode event whose sound it borrows. *)
$markers = {
  <|"r" -> 3.449, "label" -> "period-4 bifurcation", "freq" -> 660.0, "dur" -> 0.08|>,
  <|"r" -> 3.570, "label" -> "onset of chaos",       "freq" -> 440.0, "dur" -> 0.12|>,
  <|"r" -> 3.828, "label" -> "period-3 window",      "freq" -> 528.0, "dur" -> 0.10|>
};


(* ── Model ─────────────────────────────────────────────────────── *)

LyapunovAt[r_?NumericQ, p_Association] :=
  Mean[Log[Max[Abs[r * (1.0 - 2.0 * #)], $MinMachineNumber]] & /@
    AttractorPoints[p["x0"], r, p["nTransient"], p["nAverage"]]];

(* Time in the audio at which the sweep passes r (linear r -> t). *)
TimeOfR[r_?NumericQ, p_Association] :=
  (r - p["rStart"]) / (p["rEnd"] - p["rStart"]) * p["durSec"];

(* Zero crossings by linear interpolation between grid points — the same
   interpolation the audio uses, so the crossing time is exact for the audio. *)
ZeroCrossings[rs_List, lams_List] :=
  Module[{idx},
    idx = Flatten @ Position[Sign[Most[lams]] * Sign[Rest[lams]], -1];
    Map[
      <|"r" -> rs[[#]] - lams[[#]] * (rs[[# + 1]] - rs[[#]]) / (lams[[# + 1]] - lams[[#]]),
        "dir" -> If[lams[[# + 1]] > lams[[#]], "rising", "falling"]|> &,
      idx]
  ];


(* ── Synthesis ─────────────────────────────────────────────────── *)

(* Per-sample lambda, linearly interpolated between the step control
   points, which sit at t_k = (k-1) * durSec / (rSteps - 1). *)
LambdaPerSample[lams_List, nS_Integer, p_Association] :=
  Module[{dt, pos, i0, fr},
    dt  = p["durSec"] / (Length[lams] - 1);
    pos = N[Range[0, nS - 1] / p["sr"]] / dt;
    i0  = Clip[Floor[pos], {0, Length[lams] - 2}];
    fr  = pos - i0;
    lams[[i0 + 1]] * (1.0 - fr) + lams[[i0 + 2]] * fr
  ];

EdgeFade[nS_Integer, p_Association] :=
  Module[{nF = Round[p["edgeFadeSec"] * p["sr"]], ramp},
    ramp = 0.5 * (1.0 - Cos[Pi * Range[0, nF - 1] / nF]);
    Join[ramp, ConstantArray[1.0, nS - 2 nF], Reverse[ramp]]
  ];

ApproachGain[lamS_List, p_Association] :=
  Module[{u},
    u = Clip[(p["approachOff"] - Abs[lamS]) / (p["approachOff"] - p["approachOn"]), {0.0, 1.0}];
    0.5 * (1.0 - Cos[Pi * u])
  ];

MarkerBuffer[nS_Integer, p_Association] :=
  Module[{lb = ConstantArray[0.0, nS], rb = ConstantArray[0.0, nS]},
    Scan[
      ({lb, rb} = OverlayEvent[lb, rb, #["freq"], #["dur"], 0.7, TimeOfR[#["r"], p], p["sr"]]) &,
      $markers];
    {lb, rb}
  ];

ToStereo[mono_List] := {mono, mono};


(* ── Measurement ───────────────────────────────────────────────── *)

ReadWAV[path_String] :=
  Module[{data = Import[path, "Data"], sr = Import[path, "SampleRate"]},
    <|"data" -> If[Depth[data] == 3, data, {data}], "sr" -> sr|>
  ];


(* ── Run ───────────────────────────────────────────────────────── *)

Module[{p = $params, sr, rs, lamRaw, lams, nS, lamS, phase, fade, lamVoiceA,
        harmOverlay, lamVoiceB, ref, refC, markers, mixes, gainA, gain, peakMax,
        paths, crossings, plot, pngPath, files, residuals, lamVoiceSame,
        lamPass, sR},

  sr = p["sr"];
  STEMHeading["Lyapunov exponent listening prototype"];

  (* lambda(r) *)
  rs     = N @ Subdivide[p["rStart"], p["rEnd"], p["rSteps"] - 1];
  lamRaw = LyapunovAt[#, p] & /@ rs;
  lams   = Clip[lamRaw, {p["lambdaFloor"], Infinity}];

  (* Voices *)
  nS    = Round[p["durSec"] * sr];
  lamS  = LambdaPerSample[lams, nS, p];
  phase = 2.0 Pi * Accumulate[p["refHz"] * 2.0^lamS] / sr;
  fade  = EdgeFade[nS, p];

  lamVoiceA   = p["toneAmp"] * fade * Sin[phase];
  harmOverlay = p["toneAmp"] * fade *
                  Total[MapIndexed[#1 * Sin[(#2[[1]] + 1) * phase] &, p["harmonicsB"]]];
  lamVoiceB   = lamVoiceA + harmOverlay;
  ref         = p["toneAmp"] * fade * Sin[2.0 Pi * p["refHz"] * N[Range[0, nS - 1] / sr]];
  refC        = ref * ApproachGain[lamS, p];
  markers     = MarkerBuffer[nS, p];

  (* Pre-gain stereo mixes; same lambda tone and markers in all three *)
  mixes = <|
    "A" -> ToStereo[lamVoiceA + ref]  + markers,
    "B" -> ToStereo[lamVoiceB + ref]  + markers,
    "C" -> ToStereo[lamVoiceA + refC] + markers
  |>;

  (* One shared gain: A to target LUFS, then the peak ceiling across all three *)
  gainA   = 10.0^((p["targetLUFS"] - MeasureIntegratedLoudness[Audio[mixes["A"], SampleRate -> sr]]) / 20.0);
  peakMax = Max[Max[Abs[Flatten[#]]] & /@ Values[mixes]];
  gain    = Min[gainA, p["peakCeiling"] / peakMax];

  paths = AssociationMap[FileNameJoin[{$outDir, "prototype_lyapunov_" <> # <> ".wav"}] &, Keys[mixes]];
  KeyValueMap[
    Function[{k, mix}, EnsureDir[paths[k]];
      Export[paths[k], Sound[SampledSoundList[gain * mix, sr]], "WAV"]],
    mixes];

  (* Plot *)
  crossings = ZeroCrossings[rs, lams];
  pngPath   = FileNameJoin[{$outDir, "prototype_lyapunov.png"}];
  plot = ListLinePlot[Transpose[{rs, lams}],
    PlotStyle -> Directive[RGBColor[0.13, 0.35, 0.65], Thickness[0.0022]],
    PlotRange -> {{p["rStart"], p["rEnd"]}, {p["lambdaFloor"] - 0.08, Max[lams] + 0.12}},
    Frame -> True, FrameLabel -> {"r", "\[Lambda](r)  (clipped at \[Minus]1)"},
    PlotLabel -> "Lyapunov exponent of the logistic map, r = 3.40 \[Rule] 3.90  (x0 = 0.5, 500 transient + 2000 averaged)",
    Epilog -> {
      {Black, Thickness[0.002], Line[{{p["rStart"], 0}, {p["rEnd"], 0}}]},
      {GrayLevel[0.5], Dashed, Line[{{p["rStart"], p["lambdaFloor"]}, {p["rEnd"], p["lambdaFloor"]}}]},
      Table[{RGBColor[0.8, 0.3, 0.1], Dashed, Line[{{m["r"], -2}, {m["r"], 2}}],
             Text[Style[m["label"] <> "\nr = " <> ToString[m["r"]], 11, RGBColor[0.8, 0.3, 0.1]],
                  {m["r"], Max[lams] + 0.06}, {-1.05, 0}]}, {m, $markers}],
      {Red, PointSize[0.008], Point[{#["r"], 0} & /@ crossings]}
    },
    ImageSize -> {1100, 520}];
  Export[pngPath, plot, "PNG"];

  (* Measure the written files *)
  files = AssociationMap[ReadWAV[paths[#]] &, Keys[mixes]];
  residuals = AssociationMap[
    Max[Abs[Flatten[files[#]["data"] - gain * mixes[#]]]] &, Keys[mixes]];
  lamVoiceSame = SameQ[lamVoiceA, lamVoiceB - harmOverlay] || Max[Abs[lamVoiceA - (lamVoiceB - harmOverlay)]] < 10^-12;

  (* ── Report ── *)
  STEMSection["Zero crossings of lambda"];
  Print["  count: ", Length[crossings]];
  Do[
    Print["  crossing ", i, " (", crossings[[i]]["dir"], "): r = ",
      ToString[NumberForm[crossings[[i]]["r"], {4, 3}], OutputForm],
      "  at t = ", ToString[NumberForm[TimeOfR[crossings[[i]]["r"], p], {4, 2}], OutputForm], " s"],
    {i, Length[crossings]}];

  STEMSection["lambda range"];
  STEMPrintN["minimum lambda before clipping", Min[lamRaw], "", 4];
  STEMPrintN["minimum lambda in the audio (after clipping)", Min[lams], "", 4];
  STEMPrintN["maximum lambda", Max[lams], "", 4];
  Print["  steps clipped at the floor: ", Count[lamRaw, x_ /; x < p["lambdaFloor"]]];

  STEMSection["Files"];
  STEMPrintN["shared gain", 20 Log10[gain], "dB", 4];
  Do[
    sR = files[k]["sr"];
    Print["  ", k, ": ", FileNameTake[paths[k]]];
    STEMPrintN["    duration", Length[First[files[k]["data"]]] / N[sR], "s", 6];
    STEMPrintN["    peak", 20 Log10[Max[Abs[Flatten[files[k]["data"]]]]], "dBFS", 4];
    STEMPrintN["    integrated loudness",
      MeasureIntegratedLoudness[Audio[files[k]["data"], SampleRate -> sR]], "LUFS", 4],
    {k, Keys[mixes]}];
  Print["  plot: ", pngPath];

  STEMSection["Identity check"];
  Do[STEMPrintN["  max |file " <> k <> " - (gain x its declared mix)|", residuals[k], "", 3], {k, Keys[mixes]}];
  lamPass = lamVoiceSame && Max[Values[residuals]] < 2.0 / 32768;
  Print[If[lamPass, "  [PASS] ", "  [FAIL] "],
    "The three files differ only in the reference and timbre treatment: each file equals ",
    "the shared gain times (the same lambda-tone fundamental + the same markers + its reference), ",
    "plus B's harmonic overlay, to within 16-bit quantisation."];
  If[!lamPass, Exit[1]];
];

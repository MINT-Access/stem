(* ========================================================
   quantum/src/sonify.wl — Sonification for quantum density

   Public API:
     DensityToTrajectory[solution]
       Converts |psi(x,t)|^2 density field to a {t,x,y,z,speed}
       trajectory matrix for SonifyTrajectory.
         x     -> <x>(t)    stereo pan
         y     -> Var(x)(t) pitch (apex detection at variance extremes)
         z     -> 0
         speed -> |d<x>/dt| volume dynamics

     SonifyQuantum[solution, cfg, outDir]
       Runs the full audio pipeline. Outputs:
         {mode}_audio.wav        — sonification via SonifyTrajectory
         {mode}_description.wav  — spoken description (macOS say)
   ======================================================== *)


DensityToTrajectory[solution_Association] :=
  Module[{density, xVals, xVals2, tVals, nt, dx,
          meanX, meanX2, varX, speed, varRange},

    density = solution["density"];
    xVals   = solution["x"];
    xVals2  = xVals^2;
    tVals   = solution["t"];
    nt      = Length[tVals];
    dx      = solution["dx"];

    (* Expectation values via quadrature sum (density rows are nx-vectors) *)
    meanX  = density . xVals  * dx;   (* {nt} *)
    meanX2 = density . xVals2 * dx;   (* {nt} *)
    varX   = meanX2 - meanX^2;        (* {nt} *)

    (* Speed: |d<x>/dt| via central differences; boundary points set to 0 *)
    speed = Table[
      If[it === 1 || it === nt,
        0.0,
        Abs[(meanX[[it + 1]] - meanX[[it - 1]]) /
            (tVals[[it + 1]] - tVals[[it - 1]])]
      ],
      {it, nt}
    ];

    (* Guard: if variance is nearly flat (e.g. QHO coherent state), add a tiny
       sinusoidal component so SonifyTrajectory's pitch Rescale is non-degenerate *)
    varRange = Max[varX] - Min[varX];
    If[varRange < 1.0*^-4 * (Mean[Abs[varX]] + $MachineEpsilon),
      varX = varX +
        0.001 * Mean[Abs[varX]] * Table[Sin[2.0 * Pi * it / nt], {it, nt}]
    ];

    Transpose[{tVals, meanX, varX, ConstantArray[0.0, nt], speed}]
  ]


SonifyQuantum[solution_Association, cfg_Association, outDir_String] :=
  Module[{mode, traj, tEnd, cfgSon, audioPath, descPath,
          descText, descBuf, sr},

    mode  = solution["mode"];
    traj  = DensityToTrajectory[solution];
    tEnd  = Last[solution["t"]];
    sr    = 44100;

    (* Override sonification duration to match simulation time span *)
    cfgSon = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> N[tEnd] |> |>];

    audioPath = FileNameJoin[{outDir, mode <> "_audio.wav"}];
    STEMSay["Sonifying " <> mode <> " density trajectory"];
    EnsureDir[audioPath];
    SonifyTrajectory[traj, cfgSon, audioPath, {"apex", "crossing"}];
    STEMDescribeWAV[audioPath, N[tEnd]];

    (* Spoken description WAV using macOS say *)
    descPath = FileNameJoin[{outDir, mode <> "_description.wav"}];
    descText = Switch[mode,
      "qho",
        "Quantum harmonic oscillator, coherent state. " <>
        "Mean energy " <>
        ToString[NumberForm[solution["mean_energy"], {4, 3}]] <>
        " natural units. " <>
        "The wave packet oscillates classically without spreading. " <>
        "Stereo pan follows mean position. " <>
        "Volume follows instantaneous speed. " <>
        "Pitch encodes the position variance.",
      "box",
        "Particle in a box. " <>
        "Equal superposition of ground state and first excited state. " <>
        "Mean energy " <>
        ToString[NumberForm[solution["mean_energy"], {4, 3}]] <>
        " natural units. " <>
        "The wave packet oscillates between the walls. " <>
        "Stereo pan follows mean position. " <>
        "Volume follows instantaneous speed. " <>
        "Pitch encodes the position variance.",
      _,
        "Quantum simulation. Mean energy " <>
        ToString[NumberForm[solution["mean_energy"], {4, 3}]] <>
        " natural units."
    ];

    descBuf = SpeakToBuffer[descText, sr];
    EnsureDir[descPath];
    ExportAudioBuffer[NormalizeBuffer[descBuf, 0.95], descPath, sr];
    STEMDescribeWAV[descPath, N[Length[descBuf]] / sr]
  ]


(* SpeakToBuffer
   Calls macOS `say` to synthesise speech and returns a mono PCM list
   at targetSr. Falls back to 0.5 s silence on any error.
   Upsamples 22050 -> 44100 Hz by linear interpolation. *)

SpeakToBuffer[text_String, targetSr_Integer] :=
  Module[{tmpPath, result, snd, data, rawSr, upsampled,
          silence = ConstantArray[0.0, Round[targetSr * 0.5]]},

    tmpPath = FileNameJoin[{$TemporaryDirectory,
      "stem_q_" <> ToString[RandomInteger[999999]] <> ".aiff"}];

    result = Quiet[RunProcess[{"say", "-o", tmpPath, text}]];
    If[!AssociationQ[result] || result["ExitCode"] =!= 0 ||
       !FileExistsQ[tmpPath], Return[silence]];

    snd = Quiet[Import[tmpPath]];
    Quiet[DeleteFile[tmpPath]];

    If[Head[snd] =!= Sound || Length[snd] < 1 ||
       Head[snd[[1]]] =!= SampledSoundList,
      Return[silence]];

    data  = Flatten[N[snd[[1, 1]]]];
    rawSr = snd[[1, 2]];
    If[!ListQ[data] || Length[data] === 0, Return[silence]];

    If[rawSr < targetSr,
      With[{ratio = Round[targetSr / rawSr]},
        If[ratio === 2,
          upsampled = Flatten[
            Transpose[{Most[data], (Most[data] + Rest[data]) / 2.0}]];
          Append[upsampled, Last[data]],
          data]],
      data]
  ]

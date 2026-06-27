(* ========================================================
   primes/sonify.wl — Audio export for prime number patterns

   Public API:
     SonifyPrimes[model, cfg, outDir]
       Dispatches on model["mode"]:
         "ulam" → SonifyUlam  (row-scan trajectory via SonifyTrajectory)
         "gaps" → SonifyGaps  (direct percussive WAV + slow version)

   Ulam sonification:
     Scans the grid row by row.  Each row maps to one trajectory
     point: left/right prime asymmetry → pan, row density → pitch,
     |density change| → volume envelope.

   Gaps sonification:
     Each prime produces a short sine burst whose attack time is set
     by the cumulative gap (distance from the first prime), normalised
     to a target duration.  Pitch maps prime value to [min_hz, max_hz].
     Twin primes (gap = 2) produce near-simultaneous attacks that are
     perceptually distinct.  A second WAV at quarter tempo stretches
     the rhythm so individual gap lengths become easier to count.
   ======================================================== *)


(* ── SonifyUlam ──────────────────────────────────────────
   Row-by-row spatial scan.
   Trajectory columns: {t, x, y, z, speed}
     t     — row index mapped to [0, scanDuration]
     x     — left/right prime density asymmetry  (pan)
     y     — row prime density                   (pitch)
     z     — 0.0
     speed — |density change from previous row|  (volume)
   ──────────────────────────────────────────────────────── *)

SonifyUlam[model_Association, cfg_Association, outPath_String] :=
  Module[{grid, n, halfCols, scanDuration,
          rowDensity, leftDensity, rightDensity,
          pan, speed, tVals, traj, cfgSon},

    grid     = model["grid"];
    n        = model["size"];
    halfCols = Floor[n / 2];

    (* Row-level statistics *)
    rowDensity   = N[Total[grid, {2}] / n];
    leftDensity  = N[Total[grid[[All, 1 ;; halfCols]], {2}] / halfCols];
    rightDensity = N[Total[grid[[All, halfCols + 1 ;; n]], {2}] / (n - halfCols)];

    (* Pan: right minus left asymmetry, clipped to [-1, +1] *)
    pan   = Clip[2.0 * (rightDensity - leftDensity), {-1.0, 1.0}];

    (* Volume: absolute row-to-row density change; first row = 0 *)
    speed = Prepend[Abs[Differences[rowDensity]], 0.0];

    (* Map row indices to a 10-second scan *)
    scanDuration = 10.0;
    tVals        = N[Rescale[Range[n], {1, n}, {0.0, scanDuration}]];

    traj = N[Transpose[{
      tVals,
      pan,
      rowDensity,
      ConstantArray[0.0, n],
      speed
    }]];

    cfgSon = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> scanDuration |> |>];

    STEMSay["Sonifying Ulam spiral row scan"];
    EnsureDir[outPath];
    SonifyTrajectory[traj, cfgSon, outPath, {"apex"}];
    STEMDescribeWAV[outPath, scanDuration]
  ]


(* ── SonifyGaps ──────────────────────────────────────────
   Direct percussive WAV: each prime generates a short sine burst.

   Attack time for prime p_n:
     t_n = (p_n - p_1) / (p_count - p_1) * baseDuration
   This normalises the full prime range to baseDuration seconds,
   preserving all relative gap ratios exactly.

   baseDuration = 30 * 120 / tempo_bpm  (30 s at default 120 bpm)

   A second WAV at quarter tempo (slow) stretches baseDuration 4x,
   making individual gap lengths easier to count by ear.
   ──────────────────────────────────────────────────────── *)

SonifyGaps[model_Association, cfg_Association, outDir_String] :=
  Module[{primes, gaps, count,
          tempoBpm, toneDurMs, minHz, maxHz,
          sr, totalSpan, baseDuration, slowDuration,
          timeUnit, slowTimeUnit, toneSamples,
          cumGaps, attackTimes, slowAttackTimes, pitchHz,
          nBase, nSlow, baseAudio, slowAudio,
          audioPath, slowPath},

    primes   = model["primes"];
    gaps     = model["gaps"];
    count    = Length[primes];

    tempoBpm  = GetCfg[cfg, {"sonification","gaps","tempo_bpm"},        120];
    toneDurMs = GetCfg[cfg, {"sonification","gaps","tone_duration_ms"},  80];
    minHz     = GetCfg[cfg, {"sonification","pitch","min_hz"},          120];
    maxHz     = GetCfg[cfg, {"sonification","pitch","max_hz"},         1000];
    sr        = 44100;

    totalSpan    = N[Last[primes] - First[primes]];
    baseDuration = 30.0 * 120.0 / N[tempoBpm];   (* 30 s at 120 bpm *)
    slowDuration = baseDuration * 4.0;

    timeUnit     = baseDuration / totalSpan;
    slowTimeUnit = slowDuration / totalSpan;
    toneSamples  = Round[N[toneDurMs] / 1000.0 * sr];

    (* cumGaps[[n]] = p_n - p_1: distance of each prime from the first *)
    cumGaps          = N[primes - First[primes]];
    attackTimes      = cumGaps * timeUnit;
    slowAttackTimes  = cumGaps * slowTimeUnit;

    (* Pitch: map prime value linearly to [minHz, maxHz] *)
    pitchHz = N[Rescale[primes, {First[primes], Last[primes]}, {minHz, maxHz}]];

    (* ── Base audio ── *)
    nBase     = Round[(baseDuration + N[toneDurMs] / 1000.0) * sr];
    baseAudio = ConstantArray[0.0, nBase];
    Print["  Base audio: ", count, " tones over ", FmtN[baseDuration, 4], " s"];

    Do[
      With[{start = Clip[Round[attackTimes[[i]] * sr] + 1, {1, nBase}],
            freq  = pitchHz[[i]]},
        With[{len = Min[toneSamples, nBase - start + 1]},
          If[len > 0,
            baseAudio[[start ;; start + len - 1]] +=
              0.3 * N[Table[
                Sin[2.0 Pi * freq * k / sr] * Exp[-5.0 k / toneSamples],
                {k, 0, len - 1}]]
          ]
        ]
      ],
      {i, count}
    ];

    audioPath = FileNameJoin[{outDir, "gaps_audio.wav"}];
    EnsureDir[audioPath];
    ExportAudioBuffer[NormalizeBuffer[baseAudio, 0.95], audioPath, sr];
    STEMDescribeWAV[audioPath, baseDuration];

    (* ── Slow audio (quarter tempo = 4× duration) ── *)
    nSlow     = Round[(slowDuration + N[toneDurMs] / 1000.0) * sr];
    slowAudio = ConstantArray[0.0, nSlow];
    Print["  Slow audio: ", count, " tones over ", FmtN[slowDuration, 4], " s"];

    Do[
      With[{start = Clip[Round[slowAttackTimes[[i]] * sr] + 1, {1, nSlow}],
            freq  = pitchHz[[i]]},
        With[{len = Min[toneSamples, nSlow - start + 1]},
          If[len > 0,
            slowAudio[[start ;; start + len - 1]] +=
              0.3 * N[Table[
                Sin[2.0 Pi * freq * k / sr] * Exp[-5.0 k / toneSamples],
                {k, 0, len - 1}]]
          ]
        ]
      ],
      {i, count}
    ];

    slowPath = FileNameJoin[{outDir, "gaps_slow.wav"}];
    ExportAudioBuffer[NormalizeBuffer[slowAudio, 0.95], slowPath, sr];
    STEMDescribeWAV[slowPath, slowDuration]
  ]


SonifyPrimes[model_Association, cfg_Association, outDir_String] :=
  If[model["mode"] === "ulam",
    SonifyUlam[model, cfg, FileNameJoin[{outDir, "ulam_audio.wav"}]],
    SonifyGaps[model, cfg, outDir]
  ]

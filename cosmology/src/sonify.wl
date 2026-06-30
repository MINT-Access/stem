(* cosmology/src/sonify.wl — CMB audio synthesis *)

(* Sonify the CMB angular power spectrum.
   Each multipole l becomes one note; pitch and volume follow D_l so
   the listener hears swells at each acoustic peak. *)
SonifySpectrum[lArr_List, dlArr_List, peakData_Association,
               cfg_Association, outWAV_String] :=
  Module[{tStr, noteDur, freqLo = 80.0, freqHi = 2000.0,
          volLo = 0.25, volHi = 1.0,
          sr, nL, dlMin, dlMax, dlNorm, peakIdxs, peakAccentSet,
          audioBuffer},
    tStr    = N @ GetCfg[cfg, {"simulation", "cosmology", "time_stretch"}, 1.0];
    sr      = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    noteDur = tStr * 0.025;
    nL      = Length[lArr];
    peakIdxs = peakData["peakIdxs"];

    dlMin  = N @ Min[dlArr];
    dlMax  = N @ Max[dlArr];
    dlNorm = N[(dlArr - dlMin) / (dlMax - dlMin)];

    peakAccentSet = If[Length[peakIdxs] >= 3,
      peakIdxs[[1 ;; 3]],
      peakIdxs
    ];

    audioBuffer = Flatten @ Table[
      With[{
        f      = N[freqLo * (freqHi / freqLo)^dlNorm[[i]]],
        v      = N[volLo + dlNorm[[i]] * (volHi - volLo)],
        isPeak = MemberQ[peakAccentSet, i]
      },
        If[isPeak,
          StemSynthNote[f, noteDur, Min[1.0, v * 1.4],
                        {1.0, 0.6, 0.4, 0.2}, 0.55, sr],
          StemSynthNote[f, noteDur, v, {1.0, 0.3}, 0.30, sr]
        ]
      ],
      {i, nL}
    ];

    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[nL * noteDur]];
    Print["  Pitch: D_l min -> ", FmtN[freqLo, 4], " Hz  |  ",
          "D_l max -> ", FmtN[freqHi, 5], " Hz  (log-mapped)"];
    Print["  Peak accents at l ~ ",
          StringRiffle[Map[ToString, Take[peakData["peakLVals"],
                           Min[3, Length[peakData["peakLVals"]]]]], ", "]];
    Print[""];

    Do[
      STEMSay["Acoustic peak " <> ToString[k] <> ": l equals " <>
        ToString[peakData["peakLVals"][[k]]] <> ", angular scale " <>
        FmtN[180.0 / peakData["peakLVals"][[k]], {4, 1}] <> " degrees. " <>
        "Power " <> FmtN[peakData["peakDlVals"][[k]], 5] <> " microkelvin squared."],
      {k, Min[3, Length[peakData["peakLVals"]]]}
    ]
  ];

(* Sonify the simulated CMB sky map via Hilbert traversal.
   Cold pixels -> low pitch; hot pixels -> high pitch. *)
SonifySkyMap[skyModel_Association, cfg_Association, outWAV_String] :=
  Module[{sr, nPix, tNorm, noteDur, freqLo, freqHi, audioBuffer},
    sr      = GetCfg[cfg, {"sonification", "sample_rate"}, 44100];
    nPix    = skyModel["nPix"];
    tNorm   = skyModel["tNorm"];
    noteDur = skyModel["noteDur"];
    freqLo  = skyModel["freqLo"];
    freqHi  = skyModel["freqHi"];

    audioBuffer = Flatten @ Table[
      StemSynthNote[
        N[freqLo * (freqHi / freqLo)^tNorm[[i]]],
        noteDur, 0.75, {1.0, 0.25}, 0.15, sr],
      {i, nPix}
    ];

    ExportAudioBuffer[NormalizeBuffer[audioBuffer, 0.92], outWAV, sr];
    STEMDescribeWAV[outWAV, N[nPix * noteDur]];
    Print["  Pitch: cold pixels -> ", FmtN[freqLo, 4], " Hz  |  ",
          "hot pixels -> ", FmtN[freqHi, 5], " Hz"]
  ];

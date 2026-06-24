(* ========================================================
   src/sonify.wl — Musical sonification of the pendulum

   Uses explicit waveform synthesis (no MIDI / SoundNote)
   so it works correctly in headless wolframscript.

   Sonification design:
     Pitch    — angle mapped to an A minor pentatonic scale.
                Centre (theta=0) plays the tonic A4 (440 Hz).
                Swinging out raises or lowers pitch by scale step.
     Duration — each note lasts one half-swing (zero crossing
                to zero crossing), matching the physical period.
     Volume   — angular velocity at each crossing sets amplitude.
     Timbre   — a soft sine wave with a short exponential decay
                envelope, giving a mellow bell-like quality.

   Scale, synthesis, and export helpers come from stem-core.
   Usage:
     Get["src/sonify.wl"]
     ExportSonification[solution, params, "data/pendulum_audio.wav"]
   ======================================================== *)


(* FindZeroCrossings
   Returns a list of Associations, one per zero crossing,
   with keys Time, Velocity, Direction. *)

FindZeroCrossings[solution_List] :=
  Module[{pairs, crossings},
    pairs = Partition[solution, 2, 1];
    crossings = Select[pairs,
      (#[[1, 2]] >= 0 && #[[2, 2]] < 0) ||
      (#[[1, 2]] <  0 && #[[2, 2]] >= 0) &
    ];
    <|
      "Time"      -> Mean[{#[[1,1]], #[[2,1]]}],
      "Velocity"  -> Mean[{#[[1,3]], #[[2,3]]}],
      "Angle"     -> Mean[{#[[1,2]], #[[2,2]]}],
      "Direction" -> Sign[#[[2,2]] - #[[1,2]]]
    |> & /@ crossings
  ]


(* ExportSonification
   Builds audio sample by sample and exports to WAV.

   Parameters:
     solution  — output of SolvePendulum
     params    — the simulation parameters Association
     filePath  — destination path, e.g. "data/pendulum_audio.wav" *)

ExportSonification[solution_List, params_Association, filePath_String] :=
  Module[
    {crossings, maxAngle, maxVelocity,
     totalDuration, nTotalSamples, audioBuffer,
     pairs, startSample, endSample, freq, vol, noteSamples, len},

    Print["  Finding zero crossings (beat events)..."];
    crossings = FindZeroCrossings[solution];

    If[Length[crossings] < 2,
      Print["  Warning: fewer than 2 zero crossings found. ",
            "Try a longer TimeEnd in params."];
      Return[$Failed]
    ];

    Print["  Found ", Length[crossings], " crossings \[Rule] ",
          Length[crossings] - 1, " notes."];

    maxAngle    = Max[Abs[solution[[All, 2]]]];
    If[maxAngle < 0.001, maxAngle = 0.001];

    maxVelocity = Max[Abs[crossings[[All, "Velocity"]]]];
    If[maxVelocity < 0.001, maxVelocity = 0.001];

    totalDuration  = crossings[[-1]]["Time"];
    nTotalSamples  = Round[totalDuration * $StemSampleRate];

    Print["  Synthesizing audio at ", $StemSampleRate, " Hz, ",
          NumberForm[totalDuration, 3], " s total..."];

    (* Pre-allocate audio buffer with silence *)
    audioBuffer = ConstantArray[0.0, nTotalSamples];

    (* Render each note into the buffer (additive mixing) *)
    pairs = Partition[crossings, 2, 1];

    Do[
      Module[{c1, c2, tStart, tEnd, duration, velocity, angle},
        c1       = pairs[[k, 1]];
        c2       = pairs[[k, 2]];
        tStart   = c1["Time"];
        tEnd     = c2["Time"];
        duration = tEnd - tStart;

        (* Sample the angle midway through the half-swing *)
        angle    = solution[[ Clip[Round[(tStart + duration/2) /
                     params["TimeStep"]] + 1,
                     {1, Length[solution]}], 2]];

        velocity = Abs[c1["Velocity"]];
        vol      = 0.3 + 0.7 * (velocity / maxVelocity);
        freq     = ScaleLookup[angle, -maxAngle, maxAngle,
                     $StemScales["MinorPentatonic"], 220.0];

        noteSamples = StemSynthNote[freq, duration, vol,
                        {1.0}, 1/3, $StemSampleRate];
        len         = Length[noteSamples];

        startSample = Clip[Round[tStart * $StemSampleRate] + 1,
                           {1, nTotalSamples}];
        endSample   = Clip[startSample + len - 1, {1, nTotalSamples}];
        len         = endSample - startSample + 1;

        audioBuffer[[startSample ;; endSample]] +=
          noteSamples[[1 ;; len]];
      ],
      {k, 1, Length[pairs]}
    ];

    audioBuffer = NormalizeBuffer[audioBuffer];

    Print["  Writing WAV file..."];
    ExportAudioBuffer[audioBuffer, filePath, $StemSampleRate]
  ]

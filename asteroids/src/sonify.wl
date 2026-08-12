(* ========================================================
   src/sonify.wl — Sonification via stem-core SonifyTrajectory

   Builds a synthetic {t, x, y, z, speed} trajectory matrix
   from the list of asteroid Associations, sorted farthest → closest
   to build dramatically toward the nearest miss.

   Column mapping:
     t     — evenly spaced; stepDur = noteDuration + gapDuration per object
     x     — missDistanceKm normalised to [-1, +1]  (pan: far=+1, close=-1)
     y     — missDistanceKm in km                    (pitch: far=high, close=low)
     z     — diamMeanKm                              (size, passive)
     speed — velocityKmS                             (volume: fast=louder)

   Event type: "approach"
     Passed through to EventLayer; no detection is implemented
     for this type — the spatial and motion layers carry the
     full sonification character.
   ======================================================== *)


(* SonificationDuration
   Total WAV duration in seconds for n asteroids, given the configured
   note/gap durations — the exact formula ExportSonification uses
   internally to size the audio. Factored out so callers (namely the
   GIF animation, which must render for exactly this long to stay in
   sync with the audio) can compute it up front without having to
   synthesise audio first. *)

SonificationDuration[n_Integer, cfg_Association] :=
  Module[{noteDur, gapDur},
    noteDur = GetCfg[cfg, {"sonification","motion","noteDuration"}, 0.55];
    gapDur  = GetCfg[cfg, {"sonification","motion","gapDuration"},  0.12];
    n * (noteDur + gapDur)
  ]


ExportSonification[asteroids_List, cfg_Association, filePath_String] :=
  Module[
    {n, noteDur, gapDur, stepDur,
     sorted, missKm, velocity, diameter,
     minKm, maxKm, times, trajectory,
     trajDuration, cfgWithDuration},

    n = Length[asteroids];
    If[n === 0,
      Print["  No asteroids to sonify."];
      Return[$Failed]
    ];

    noteDur = GetCfg[cfg, {"sonification","motion","noteDuration"}, 0.55];
    gapDur  = GetCfg[cfg, {"sonification","motion","gapDuration"},  0.12];
    stepDur = noteDur + gapDur;

    (* Farthest → closest: dramatic build toward the near miss *)
    sorted   = Reverse[SortBy[asteroids, #["missDistanceKm"] &]];
    missKm   = #["missDistanceKm"] & /@ sorted;
    velocity = #["velocityKmS"]    & /@ sorted;
    diameter = #["diamMeanKm"]     & /@ sorted;

    minKm = Min[missKm];
    maxKm = Max[missKm] + $MachineEpsilon;
    times = N[Table[(i - 1) * stepDur, {i, n}]];

    trajectory = N[Table[
      {times[[i]],
       Rescale[missKm[[i]], {minKm, maxKm}, {-1.0, 1.0}],   (* x: pan *)
       missKm[[i]],                                            (* y: pitch *)
       diameter[[i]],                                          (* z: size *)
       velocity[[i]]},                                         (* speed: volume *)
      {i, n}
    ]];

    trajDuration    = Last[times] + stepDur;
    cfgWithDuration = DeepMerge[cfg,
      <| "sonification" -> <| "duration" -> trajDuration |> |>];

    EnsureDir[filePath];
    Print["  Trajectory: ", n, " asteroids, ",
      FmtN[trajDuration, 3], " s total"];

    SonifyTrajectory[trajectory, cfgWithDuration, filePath, {"approach"}];
    trajDuration
  ]

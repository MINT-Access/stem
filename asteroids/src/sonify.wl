(* ========================================================
   src/sonify.wl — Sonification via stem-core SonifyTrajectory

   Builds a synthetic {t, x, y, z, speed} trajectory matrix
   from the list of asteroid Associations, sorted farthest → closest
   to build dramatically toward the nearest miss.

   Column mapping:
     t     — evenly spaced; stepDur from SonificationStepDuration (below) —
             noteDuration+gapDuration per object, scaled down for large n
             so total duration stays bounded (see maxTotalDuration)
     x     — missDistanceKm normalised to [-1, +1]  (pan: far=+1, close=-1)
     y     — missDistanceKm in km                    (pitch: far=high, close=low)
     z     — diamMeanKm                              (size, passive)
     speed — velocityKmS                             (volume: fast=louder)

   Event type: "approach"
     Passed through to EventLayer; no detection is implemented
     for this type — the spatial and motion layers carry the
     full sonification character.
   ======================================================== *)


(* SonificationStepDuration
   Per-asteroid time step (noteDuration+gapDuration), scaled DOWN for
   busy date ranges so total duration stays bounded rather than growing
   unboundedly with n. At or below the "comfortable" asteroid count
   (maxTotalDuration/ceilingStep, ~134 asteroids at the defaults below),
   this returns the full, unscaled ceilingStep — small/typical presets
   (a week, a month) are completely unaffected. Above that count, the
   step shrinks toward minStepDuration so that n*step stays close to
   maxTotalDuration even as n grows (the busiest realistic case, a
   full year at ~1800 asteroids, lands almost exactly on the cap — see
   AGENTS.md "GIF/WAV duration sync" for the measured numbers).

   This is the SAME value ExportAnimation's targetDuration and
   ExportSonification's own note spacing must use — factored out to a
   single function (rather than each computing "n*(noteDur+gapDur)"
   independently) specifically so they cannot drift apart the way the
   original GIF/WAV desync bug happened. *)

SonificationStepDuration[n_Integer, cfg_Association] :=
  Module[{noteDur, gapDur, ceilingStep, maxTotal, minStep},
    noteDur     = GetCfg[cfg, {"sonification","motion","noteDuration"}, 0.55];
    gapDur      = GetCfg[cfg, {"sonification","motion","gapDuration"},  0.12];
    ceilingStep = noteDur + gapDur;
    maxTotal    = GetCfg[cfg, {"sonification","motion","maxTotalDuration"}, 90.0];
    minStep     = GetCfg[cfg, {"sonification","motion","minStepDuration"},  0.03];
    Clip[maxTotal / Max[n, 1], {minStep, ceilingStep}]
  ]


(* SonificationDuration
   Total WAV duration in seconds for n asteroids, using
   SonificationStepDuration — the exact formula ExportSonification uses
   internally to size the audio. Factored out so callers (namely the
   GIF animation, which must render for exactly this long to stay in
   sync with the audio) can compute it up front without having to
   synthesise audio first. *)

SonificationDuration[n_Integer, cfg_Association] :=
  n * SonificationStepDuration[n, cfg]


ExportSonification[asteroids_List, cfg_Association, filePath_String] :=
  Module[
    {n, stepDur,
     sorted, missKm, velocity, diameter,
     minKm, maxKm, times, trajectory,
     trajDuration, cfgWithDuration},

    n = Length[asteroids];
    If[n === 0,
      Print["  No asteroids to sonify."];
      Return[$Failed]
    ];

    stepDur = SonificationStepDuration[n, cfg];

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

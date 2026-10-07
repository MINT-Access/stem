(* ========================================================
   stem-core/src/export.wl — CSV and GIF file export helpers,
   plus GIF/WAV duration sync

   Requires: utils.wl (for EnsureDir, FmtDec)
   ======================================================== *)


(* ExportCSV
   Writes a list of rows (including header) to a CSV file.
   Creates the output directory if it does not exist.
   Returns filePath on success.

   rows     — list of lists, first element is the header row
   filePath — destination path, e.g. "output/results.csv" *)

ExportCSV[rows_List, filePath_String] :=
  (EnsureDir[filePath];
   Export[filePath, rows, "CSV", CharacterEncoding -> "UTF8"];
   filePath)


(* GIFFramePlan
   Chooses the frame delay and frame count for a GIF that must play
   for as long as its matching audio.

   GIF frame delays are stored as whole centiseconds, so a requested
   frame rate such as 4.6078 fps (0.217 s) is written as 0.22 s, and a
   frame count derived from the requested rate (Round[fps*duration])
   then plays for count*0.22 s, not for the audio's duration: measured
   drift was 0.4-1.4% (dynamical iterate: GIF 33.000 s vs WAV 32.553 s;
   lorenz: 40.5 s vs 40.0 s). This helper therefore rounds the delay to
   whole centiseconds FIRST and derives the frame count from that
   delay, so frameCount*delay is the closest achievable match to the
   audio (within half a frame delay).

   audioDuration — seconds the GIF must play for (the WAV's duration,
                   or the part of it the GIF is timed to)
   desiredFps    — requested frame rate, typically renderBudget/duration
   Options:
     "MinFps"/"MaxFps"       — clamp on desiredFps (default 2-30 fps)
     "MinFrames"/"MaxFrames" — bounds on the frame count (default 2, no
                               max). If a bound applies, the delay is
                               recomputed from the bounded count so the
                               GIF still matches the audio.
     "FrameCount"            — an integer fixes the frame count (for apps
                               whose frames are set by the data at a fixed
                               rate, e.g. pendulum's 25 fps sampling); the
                               delay then comes from desiredFps alone.

   Returns <|"FrameCount", "DelayCentiseconds", "FrameDelay" (s),
             "FrameRate" (fps actually played), "GIFDuration" (s),
             "AudioDuration" (s), "Difference" (GIF minus audio, s)|>.
   Pass the plan to ExportGIF[frames, path, plan]. *)

Options[GIFFramePlan] = {"MinFps" -> 2, "MaxFps" -> 30,
                         "MinFrames" -> 2, "MaxFrames" -> Infinity,
                         "FrameCount" -> Automatic};

GIFFramePlan[audioDuration_?NumericQ, desiredFps_?NumericQ, OptionsPattern[]] :=
  Module[{fps, delayCs, nFrames, bounded, gifDuration},
    fps     = Clip[N[desiredFps], {OptionValue["MinFps"], OptionValue["MaxFps"]}];
    delayCs = Max[2, Round[100.0 / fps]];
    If[IntegerQ[OptionValue["FrameCount"]],
      nFrames = OptionValue["FrameCount"],
      nFrames = Round[100.0 * audioDuration / delayCs];
      bounded = Clip[nFrames, {OptionValue["MinFrames"], OptionValue["MaxFrames"]}];
      If[bounded != nFrames,
        nFrames = bounded;
        delayCs = Max[2, Round[100.0 * audioDuration / nFrames]]]];
    gifDuration = nFrames * delayCs / 100.0;
    <|"FrameCount"        -> nFrames,
      "DelayCentiseconds" -> delayCs,
      "FrameDelay"        -> delayCs / 100.0,
      "FrameRate"         -> 100.0 / delayCs,
      "GIFDuration"       -> gifDuration,
      "AudioDuration"     -> N[audioDuration],
      "Difference"        -> gifDuration - N[audioDuration]|>
  ]


(* ExportGIF
   Exports a list of Graphics frames as a looping animated GIF.
   Creates the output directory if it does not exist.
   Returns filePath on success.

   frames    — list of Graphics or GraphicsGrid objects
   filePath  — destination path, e.g. "output/animation.gif"
   plan      — a GIFFramePlan association (every app uses this form);
               each frame is written with the plan's whole-centisecond
               delay. A frame list whose length differs from the plan's
               frame count is still exported, with a warning line.
   frameRate — legacy numeric form (default 25 fps); the delay is
               rounded to whole centiseconds explicitly, which is what
               the GIF format stores anyway. *)

(* $STEMImageResolution, STEMRasterize, ExportPNG
   Every GIF frame and PNG is rasterised at an explicit 144 dpi, so a
   Graphics with ImageSize -> w comes out 2w pixels wide on every
   platform. Without it the pixel size follows the host's backing scale
   (2x on a Retina Mac, typically 1x on Windows and Linux); on the Mac
   144 dpi gives exactly the pixels Export produced before. Images pass
   through unchanged. *)

$STEMImageResolution = 144;

STEMRasterize[img_Image] := img;
STEMRasterize[expr_]     := Rasterize[expr, ImageResolution -> $STEMImageResolution];

ExportPNG[filePath_String, expr_] :=
  (EnsureDir[filePath];
   Export[filePath, STEMRasterize[expr], "PNG"];
   filePath)


ExportGIF[frames_List, filePath_String, plan_Association] :=
  (If[Length[frames] =!= plan["FrameCount"],
     Print["  Warning: ", Length[frames], " frames were rendered for ", filePath,
           " but the frame plan asked for ", plan["FrameCount"], "."]];
   EnsureDir[filePath];
   Export[filePath, STEMRasterize /@ frames, "GIF",
     "AnimationRepetitions" -> Infinity,
     "DisplayDurations"     -> ConstantArray[plan["FrameDelay"], Length[frames]]];
   filePath)

ExportGIF[frames_List, filePath_String, Optional[frameRate_?NumericQ, 25]] :=
  (EnsureDir[filePath];
   Export[filePath, STEMRasterize /@ frames, "GIF",
     "AnimationRepetitions" -> Infinity,
     "DisplayDurations"     -> Max[2, Round[100.0 / frameRate]] / 100.0];
   filePath)


(* GIFFrameDelays
   Reads the frame delays (seconds) actually stored in a GIF file by
   walking its block structure and reading each Graphic Control
   Extension. Equivalent to Import[path, "DisplayDurations"] but reads
   only the block headers, so it takes milliseconds instead of seconds
   on a several-hundred-frame GIF. *)

GIFFrameDelays[gifPath_String] :=
  Module[{bytes, pos, nBytes, packed, delays = {}, skipSubBlocks},
    bytes  = ReadByteArray[gifPath];
    nBytes = Length[bytes];
    skipSubBlocks[p0_] := Module[{p = p0},
      While[p <= nBytes && bytes[[p]] != 0, p += bytes[[p]] + 1];
      p + 1];
    packed = bytes[[11]];
    pos = 14 + If[BitAnd[packed, 128] > 0, 3 * 2^(BitAnd[packed, 7] + 1), 0];
    While[pos <= nBytes,
      Switch[bytes[[pos]],
        16^^21,
          If[bytes[[pos + 1]] == 16^^F9,
            AppendTo[delays, (bytes[[pos + 4]] + 256 * bytes[[pos + 5]]) / 100.0]];
          pos = skipSubBlocks[pos + 2],
        16^^2C,
          packed = bytes[[pos + 9]];
          pos += 10 + If[BitAnd[packed, 128] > 0, 3 * 2^(BitAnd[packed, 7] + 1), 0];
          pos = skipSubBlocks[pos + 1],
        _,
          pos = nBytes + 1]];
    delays
  ]


(* WAVDuration
   Duration in seconds of a PCM WAV file, from its header (data chunk
   size / block align / sample rate), without loading the samples. *)

WAVDuration[wavPath_String] :=
  Module[{s, id, size, sr = None, blockAlign = None, duration = None},
    s = OpenRead[wavPath, BinaryFormat -> True];
    SetStreamPosition[s, 12];
    While[duration === None,
      id = BinaryReadList[s, "Byte", 4];
      If[Length[id] < 4, Break[]];
      size = BinaryRead[s, "UnsignedInteger32", ByteOrdering -> -1];
      Switch[FromCharacterCode[id],
        "fmt ",
          BinaryRead[s, "UnsignedInteger16", ByteOrdering -> -1];
          BinaryRead[s, "UnsignedInteger16", ByteOrdering -> -1];
          sr = BinaryRead[s, "UnsignedInteger32", ByteOrdering -> -1];
          BinaryRead[s, "UnsignedInteger32", ByteOrdering -> -1];
          blockAlign = BinaryRead[s, "UnsignedInteger16", ByteOrdering -> -1];
          SetStreamPosition[s, StreamPosition[s] + size - 14 + Mod[size, 2]],
        "data",
          duration = N[size / blockAlign / sr],
        _,
          SetStreamPosition[s, StreamPosition[s] + size + Mod[size, 2]]]];
    Close[s];
    duration
  ]


(* PadWAVWithSilence
   Appends silence to a WAV file so it lasts targetSeconds, keeping its
   sample rate and channel count. Does nothing if the file is already
   at least that long (this project pads audio, it never trims it —
   the same convention as tools/src/video_pipeline.wl's PadAudioSilence).
   Returns the number of seconds of silence added. *)

PadWAVWithSilence[wavPath_String, targetSeconds_?NumericQ] :=
  Module[{data, sr, nTarget, nHave},
    sr   = Import[wavPath, "SampleRate"];
    data = Import[wavPath, "Data"];
    If[VectorQ[data], data = {data}];
    nHave   = Length[First[data]];
    nTarget = Round[targetSeconds * sr];
    If[nTarget <= nHave, Return[0.0]];
    data = PadRight[#, nTarget, 0.0] & /@ data;
    Export[wavPath, Sound[SampledSoundList[data, sr]], "WAV"];
    N[(nTarget - nHave) / sr]
  ]


(* SyncWAVToGIF
   Call once both files of a GIF/WAV pair have been written. Measures
   both files, pads the WAV with silence if the GIF plays longer than
   the audio by more than one frame delay, and prints one sentence
   stating the values actually written: frame count, frame delay, GIF
   duration, WAV duration and the difference.

   Options "IntroSeconds"/"OutroSeconds" (default 0): for apps whose GIF
   is deliberately timed to the sonified section between a spoken intro
   and (quantum_tunnelling's barrier mode only) a spoken outro -- clt,
   resonance, scattering, quantum_tunnelling -- the lengths of those
   spoken parts, including their pauses. The comparison then uses that
   section (WAV minus intro minus outro). Padding appends silence at the
   end of the file, so it is only applied when there is no outro;
   otherwise a warning line is printed instead.

   Returns <|"FrameCount", "FrameDelay", "GIFDuration", "WAVDuration",
             "IntroSeconds", "OutroSeconds", "Difference",
             "PaddedSeconds"|>, where Difference is GIF minus the timed
   section (the whole WAV when both options are 0), in seconds. *)

Options[SyncWAVToGIF] = {"IntroSeconds" -> 0, "OutroSeconds" -> 0};

SyncWAVToGIF[gifPath_String, wavPath_String, OptionsPattern[]] :=
  Module[{delays, nFrames, gifDur, delay, wavDur, intro, outro, diff, padded = 0.0,
          delayText, wavText, diffText, target},
    delays  = GIFFrameDelays[gifPath];
    nFrames = Length[delays];
    gifDur  = Total[delays];
    delay   = Max[delays];
    intro   = N[OptionValue["IntroSeconds"]];
    outro   = N[OptionValue["OutroSeconds"]];
    wavDur  = WAVDuration[wavPath];
    diff    = gifDur - (wavDur - intro - outro);

    If[diff > delay + 0.0005,
      If[outro > 0,
        Print["  Warning: the GIF plays ", FmtDec[diff], " s longer than the audio it is ",
              "timed to, which is more than one frame delay, and the WAV was not padded ",
              "because padding would land after the spoken outro."],
        padded = PadWAVWithSilence[wavPath, intro + gifDur];
        wavDur = WAVDuration[wavPath];
        diff   = gifDur - (wavDur - intro);
        Print["  The WAV was padded with ", FmtDec[padded], " s of silence because the GIF ",
              "played longer than the audio by more than one frame delay."]]];
    If[-diff > delay + 0.0005,
      Print["  Warning: the audio is ", FmtDec[-diff], " s longer than the GIF, which is ",
            "more than one frame delay, and the WAV was left unchanged because this ",
            "project pads audio rather than trimming it."]];

    delayText = If[Max[delays] - Min[delays] < 0.005,
      If[nFrames == 1, "1 frame of " <> FmtDec[delay] <> " s",
        ToString[nFrames] <> " frames of " <> FmtDec[delay] <> " s each"],
      ToString[nFrames] <> " frames with delays from " <> FmtDec[Min[delays]] <>
        " to " <> FmtDec[Max[delays]] <> " s"];
    wavText = Which[
      outro > 0,
        "the WAV plays for " <> FmtDec[wavDur] <> " s, of which the part between the " <>
          FmtDec[intro] <> " s spoken intro and the " <> FmtDec[outro] <>
          " s spoken outro lasts " <> FmtDec[wavDur - intro - outro] <> " s",
      intro > 0,
        "the WAV plays for " <> FmtDec[wavDur] <> " s, of which the part after the " <>
          FmtDec[intro] <> " s spoken intro lasts " <> FmtDec[wavDur - intro] <> " s",
      True,
        "the WAV plays for " <> FmtDec[wavDur] <> " s"];
    target = If[intro > 0 || outro > 0, "that part", "the WAV"];
    diffText = Which[
      Abs[diff] < 0.0005, "the GIF and " <> target <> " have the same duration to the millisecond",
      diff > 0, "the GIF is " <> FmtDec[diff] <> " s longer than " <> target,
      True,     "the GIF is " <> FmtDec[-diff] <> " s shorter than " <> target];
    Print["  GIF/WAV sync: the GIF has ", delayText, " and plays for ", FmtDec[gifDur],
          " s, ", wavText, ", and ", diffText, "."];

    <|"FrameCount" -> nFrames, "FrameDelay" -> delay, "GIFDuration" -> gifDur,
      "WAVDuration" -> wavDur, "IntroSeconds" -> intro, "OutroSeconds" -> outro,
      "Difference" -> diff,
      "PaddedSeconds" -> padded|>
  ]

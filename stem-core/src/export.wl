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
   STEMExportGIFFrames[frames, filePath,
     ConstantArray[plan["FrameDelay"], Length[frames]]])

ExportGIF[frames_List, filePath_String, Optional[frameRate_?NumericQ, 25]] :=
  STEMExportGIFFrames[frames, filePath, Max[2, Round[100.0 / frameRate]] / 100.0]


(* Failed GIF exports
   An export that returns $Failed, writes no file, or writes a file that
   does not start with a GIF header is a reported event, not a crash:
   ExportGIF prints one sentence (app, file, frame count, pixel size,
   first Wolfram message), records the path in $STEMGIFFailures and
   returns $Failed. STEMDescribeGIF and SyncWAVToGIF then print a
   "skipped" sentence for that path instead of reading the missing
   file, the app still writes its WAV, and the app's last line,
   STEMExitStatus[], exits with code 2. STEMRunApp (smoke test) and
   demo.wl reset the lists before each run and report a GIF failure
   separately from a failed run.

   STEM_GIF_DIAG=1 adds STEMGIFDiagnostics: one line of conditions
   before every export and, after a failure, one retry after a 2 s
   pause. The retry is a diagnostic: the export still counts as failed. *)

If[!ListQ[$STEMGIFFailures], $STEMGIFFailures = {}];
(* the message texts those failed exports issued, so demo.wl can tell
   them from other errors *)
If[!ListQ[$STEMGIFFailureMessages], $STEMGIFFailureMessages = {}];

STEMGIFFailedQ[filePath_String] := MemberQ[$STEMGIFFailures, filePath]

(* STEMExitStatus — the last line of every main.wl. With a failed GIF it
   prints one sentence and exits with code 2; otherwise it does nothing.
   Inside demo.wl ($STEMInHostRun) it does not exit, so the demo goes on;
   demo.wl reads $STEMGIFFailures itself. *)
STEMExitStatus[] :=
  If[$STEMGIFFailures =!= {},
    Print["  Exit code 2: the GIF export failed for ",
          StringRiffle[FileNameTake /@ $STEMGIFFailures, ", "],
          "; the WAV and the other output files were written."];
    If[!TrueQ[$STEMInHostRun], Exit[2]]]

(* first message, preferring one from Export itself (an unwritable path
   first raises internal StringForm/OpenAppend messages) *)
STEMFirstMessage[msgs_List] :=
  If[msgs === {}, "no Wolfram message was issued.",
    With[{m = StringReplace[StringTrim[
        SelectFirst[msgs, StringStartsQ[#, "Export::"] &, First[msgs]]], Whitespace -> " "]},
      If[StringEndsQ[m, "."], m, m <> "."]]]

STEMGIFWrittenQ[filePath_String] :=
  FileType[filePath] === File && FileByteCount[filePath] >= 6 &&
  MemberQ[{"GIF87a", "GIF89a"}, Quiet[FromCharacterCode[BinaryReadList[filePath, "Byte", 6]]]]

(* Chunked export
   Export holds every frame's quantised index data as integer lists while
   it builds a GIF (8 bytes a pixel): pendulum's 500-frame export peaked
   at 10.5 GB resident for a 1.3 GB frame list. Each frame is quantised
   and written on its own, with its own colour table (no global table, no
   comment block), so ExportGIF rasterises and exports the frames in
   chunks of at most $STEMGIFChunkPixels pixels and splices the files:
   the header of the first chunk, the frame blocks of every chunk, one
   trailer. The result is byte-identical to a single Export of all the
   frames (docs/VERIFICATION_gif_memory.md); a chunk whose frames differ
   in size from the first frame, or whose header differs, makes it fall
   back to the single Export (Export would pad every frame to the
   largest size of the whole list). *)

$STEMGIFChunkPixels = 24*10^6;

(* 1-based offset of the first frame block: after the header, the screen
   descriptor, the global colour table and any extension other than a
   Graphic Control Extension (the NETSCAPE loop block) *)
STEMGIFFrameStart[b_ByteArray] :=
  Module[{p, n = Length[b], packed = b[[11]]},
    p = 14 + If[BitAnd[packed, 128] > 0, 3 * 2^(BitAnd[packed, 7] + 1), 0];
    While[p < n && b[[p]] == 16^^21 && b[[p + 1]] != 16^^F9,
      p += 2; While[p <= n && b[[p]] != 0, p += b[[p]] + 1]; p++];
    p]

STEMGIFExportOpts[delays_] := Sequence["AnimationRepetitions" -> Infinity, "DisplayDurations" -> delays]

(* one Export of the whole list (short lists, the legacy scalar delay, and
   the fallback) *)
STEMExportGIFSingle[frames_List, filePath_String, delays_] :=
  Export[filePath, STEMRasterize /@ frames, "GIF", STEMGIFExportOpts[delays]]

(* chunked export; returns filePath, $Failed (an Export failed), or
   "fallback" (frame sizes or headers differ) *)
STEMExportGIFChunked[frames_List, filePath_String, delays_List, dims_List, chunks_List] :=
  Module[{header = None, parts = {}, partPath, result = filePath, strm},
    partPath[i_] := filePath <> ".part" <> ToString[i] <> ".gif";
    Catch[
      Do[Module[{raster = STEMRasterize /@ frames[[c]], b, start},
          If[!AllTrue[raster, ImageDimensions[#] === dims &], Throw["fallback", "gifchunk"]];
          If[Export[partPath[Length[parts] + 1], raster, "GIF", STEMGIFExportOpts[delays[[c]]]] === $Failed,
            Throw[$Failed, "gifchunk"]];
          raster = None;
          b = ReadByteArray[partPath[Length[parts] + 1]];
          Quiet[DeleteFile[partPath[Length[parts] + 1]]];
          If[!ByteArrayQ[b] || Length[b] < 14, Throw[$Failed, "gifchunk"]];
          start = STEMGIFFrameStart[b];
          Which[
            header === None, header = b[[;; start - 1]],
            b[[;; start - 1]] =!= header, Throw["fallback", "gifchunk"]];
          AppendTo[parts, b[[start ;; -2]]]],
        {c, chunks}];
      strm = OpenWrite[filePath, BinaryFormat -> True];
      If[Head[strm] =!= OutputStream, Throw[$Failed, "gifchunk"]];
      BinaryWrite[strm, header]; Scan[BinaryWrite[strm, #] &, parts];
      BinaryWrite[strm, ByteArray[{16^^3B}]]; Close[strm];
      If[FileByteCount[filePath] =!= Length[header] + Total[Length /@ parts] + 1, $Failed, filePath],
      "gifchunk",
      (Quiet[DeleteFile /@ Select[Table[partPath[i], {i, Length[chunks]}], FileExistsQ]]; #1) &]
  ]

(* the chunks for a frame list whose first frame has the size dims: at
   most $STEMGIFChunkPixels pixels each, never a chunk of one frame
   (a one-frame GIF may be written without the loop block) *)
STEMGIFChunks[n_Integer, dims_List] :=
  Module[{k = Max[2, Floor[$STEMGIFChunkPixels / Max[1, Times @@ dims]]], c},
    c = Partition[Range[n], UpTo[k]];
    If[Length[c] > 1 && Length[Last[c]] < 2, c = Append[Drop[c, -2], Join @@ Take[c, -2]]];
    c]

(* The GIF library's own reason for a failure. Export turns any failure of
   GIFTools`GIFWrite (giflib: "Failed to write to given file", "Failed to
   allocate required memory", ...) into the bare Export::fmterr, and
   GIFWrite runs inside Quiet @ Catch. While ExportGIF runs, a temporary
   rule on GIFWrite records what it returned when it failed. *)
STEMGIFLowLevelText[r_] :=
  Which[
    FailureQ[r], StringTrim[ToString[Quiet[r["Message"]] /. _Missing -> r[[1]]]] <>
      " (" <> ToString[r[[1]]] <> ")",
    True, ToString[Short[r, 2], InputForm]]

SetAttributes[STEMWithGIFWriteRecorder, HoldFirst];
STEMWithGIFWriteRecorder[expr_] :=
  If[!MemberQ[$Packages, "GIFTools`"] && Quiet[Check[Block[{$ContextPath}, Needs["GIFTools`"]]; True, False]] =!= True,
    {expr, {}},
    Module[{seen = {}, val},
      Internal`InheritedBlock[{GIFTools`GIFWrite},
        Unprotect[GIFTools`GIFWrite];
        GIFTools`GIFWrite[a___] /; !TrueQ[$STEMInGIFWrite] :=
          Block[{$STEMInGIFWrite = True},
            With[{r = GIFTools`GIFWrite[a]},
              If[FailureQ[r] || MatchQ[r, $Failed | _LibraryFunctionError], AppendTo[seen, r]]; r]];
        DownValues[GIFTools`GIFWrite] =
          SortBy[DownValues[GIFTools`GIFWrite], FreeQ[#, $STEMInGIFWrite] &];
        val = expr];
      {val, STEMGIFLowLevelText /@ seen}]]

STEMExportGIFOnce[frames_List, filePath_String, delays_, dims_] :=
  Module[{ed, chunks, low},
    If[FileType[filePath] === File, Quiet[DeleteFile[filePath]]];
    chunks = If[ListQ[delays] && ListQ[dims], STEMGIFChunks[Length[frames], dims], {All}];
    (* a fresh $MessageList, so a kernel that has already seen three
       failed exports (smoke test, demo.wl) does not replace this one's
       message with General::stop and report it as having none *)
    {ed, low} = STEMWithGIFWriteRecorder[Block[{$MessageList = {}}, EvaluationData[
      If[Length[chunks] > 1,
        Replace[STEMExportGIFChunked[frames, filePath, delays, dims, chunks],
          "fallback" :> STEMExportGIFSingle[frames, filePath, delays]],
        STEMExportGIFSingle[frames, filePath, delays]]]]];
    <|"ok" -> (ed["Result"] =!= $Failed && STEMGIFWrittenQ[filePath]),
      "messages" -> ed["MessagesText"], "chunks" -> Length[chunks], "lowLevel" -> low|>]

STEMExportGIFFrames[frames_List, filePath_String, delays_] :=
  Module[{first, dims, r, app, size, diag, retry, partial},
    EnsureDir[filePath];
    first = If[frames === {}, None, STEMRasterize[First[frames]]];
    dims  = If[ImageQ[first], ImageDimensions[first], None];
    diag  = Environment["STEM_GIF_DIAG"] === "1";
    If[diag, STEMGIFDiagnostics[Length[frames], first, filePath]];
    first = None;
    r = STEMExportGIFOnce[frames, filePath, delays, dims];
    If[r["ok"], Return[filePath]];
    (* a failed export can leave a truncated file that starts like a GIF
       (seen with a full output volume); remove it so nothing reads it *)
    partial = If[FileType[filePath] === File, FileByteCount[filePath], None];
    If[partial =!= None, Quiet[DeleteFile[filePath]]];
    app  = FileNameTake[DirectoryName[DirectoryName[filePath]]];
    size = If[ListQ[dims], StringRiffle[ToString /@ dims, "x"] <> " px", "unknown pixel size"];
    Print["  [GIF FAILED] ", app, ": the GIF ", filePath, " (", Length[frames],
          If[Length[frames] === 1, " frame, ", " frames, "], size,
          ") was not written; the first message was: ", STEMFirstMessage[r["messages"]],
          If[r["lowLevel"] === {}, "",
            " The GIF library reported: " <> StringRiffle[DeleteDuplicates[r["lowLevel"]], "; "] <>
            If[StringEndsQ[Last[r["lowLevel"]], "."], "", "."]],
          If[partial =!= None, " A truncated " <> ToString[partial] <> "-byte file was removed.", ""],
          " The app continues without it and will exit with code 2."];
    If[diag,
      Pause[2];
      retry = STEMExportGIFOnce[frames, filePath, delays, dims];
      If[!retry["ok"] && FileType[filePath] === File, Quiet[DeleteFile[filePath]]];
      Print["  GIF diagnostics: one retry after a 2 s pause ",
            If[retry["ok"], "wrote the GIF", "failed too (" <> StringDrop[STEMFirstMessage[retry["messages"]], -1] <> ")"],
            "; the retry is a diagnostic, not a fix, so the export still counts as failed."]];
    AppendTo[$STEMGIFFailures, filePath];
    $STEMGIFFailureMessages = Join[$STEMGIFFailureMessages, r["messages"],
      If[diag, retry["messages"], {}]];
    $Failed
  ]

(* STEMGIFDiagnostics — one line of the conditions an export runs under *)
STEMFreeSpace[dir_String] :=
  Module[{r, n},
    r = Quiet[If[$OperatingSystem === "Windows",
      RunProcess[{"powershell", "-NoProfile", "-NonInteractive", "-Command",
        "(Get-Item -LiteralPath '" <> dir <> "').PSDrive.Free"}],
      RunProcess[{"df", "-Pk", dir}]]];
    If[!AssociationQ[r] || r["ExitCode"] =!= 0, Return["unknown"]];
    n = If[$OperatingSystem === "Windows",
      Quiet[ToExpression[StringTrim[r["StandardOutput"]]]],
      Quiet[1024 ToExpression[StringSplit[Last[StringSplit[StringTrim[r["StandardOutput"]], "\n"]]][[4]]]]];
    If[IntegerQ[n], STEMBytesText[n], "unknown"]]

STEMBytesText[n_?NumericQ] := Which[
  n >= 1024.^3, FmtDec[n / 1024.^3, 2] <> " GB",
  n >= 1024.^2, FmtDec[n / 1024.^2, 1] <> " MB",
  True,         FmtDec[n / 1024., 1] <> " KB"]

STEMOpenFileLimit[] :=
  If[$OperatingSystem === "Windows", "no per-process limit reported on Windows",
    Module[{r = Quiet[RunProcess[{"sh", "-c", "ulimit -n"}]]},
      If[AssociationQ[r] && r["ExitCode"] === 0, StringTrim[r["StandardOutput"]], "unknown"]]]

STEMGIFDiagnostics[n_Integer, first_, filePath_String] :=
  Print["  GIF diagnostics before exporting ", FileNameTake[filePath], ": free space ",
        STEMFreeSpace[$TemporaryDirectory], " in the temporary directory (", $TemporaryDirectory,
        ") and ", STEMFreeSpace[DirectoryName[filePath]], " in the output directory; MemoryInUse ",
        STEMBytesText[MemoryInUse[]], ", MemoryAvailable ", STEMBytesText[MemoryAvailable[]],
        "; ", n, " frames", If[ImageQ[first],
          " of " <> StringRiffle[ToString /@ ImageDimensions[first], "x"] <> " px, rasterised about " <>
          STEMBytesText[n ByteCount[first]] <> " in all, exported in " <>
          ToString[Length[STEMGIFChunks[n, ImageDimensions[first]]]] <> " chunk(s)", ""],
        "; open-file limit ", STEMOpenFileLimit[], "."]


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

SyncWAVToGIF[gifPath_String, wavPath_String, OptionsPattern[]] /;
    STEMGIFFailedQ[gifPath] || FileType[gifPath] =!= File :=
  (Print["  GIF/WAV sync skipped: the GIF ", FileNameTake[gifPath],
         If[FileType[gifPath] === File,
           "'s export failed (only a diagnostic retry wrote the file), so it is not timed against the WAV",
           " was not written, so there is nothing to time the WAV against"],
         "; the WAV is unchanged."];
   <|"FrameCount" -> 0, "FrameDelay" -> Missing["NoGIF"], "GIFDuration" -> Missing["NoGIF"],
     "WAVDuration" -> Quiet[WAVDuration[wavPath]], "IntroSeconds" -> N[OptionValue["IntroSeconds"]],
     "OutroSeconds" -> N[OptionValue["OutroSeconds"]], "Difference" -> Missing["NoGIF"],
     "PaddedSeconds" -> 0.0|>)

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

#!/usr/bin/env wolframscript

(* ========================================================
   tools/make_presentation_video.wl — Presentation-ready MP4
   generator for LinkedIn posts and workshop/talk slides.

   STANDALONE TOOL: this is invoked on request against an
   app's already-rendered GIF + WAV output. It is not part of
   any app's own main.wl run, and it never changes an app's own
   pipeline or output files — every app's default output stays
   WAV/GIF/CSV, sonification-first, exactly as before.

   Native Wolfram Language, no ffmpeg dependency: video export
   (FrameListVideo + VideoCombine -> Export "MP4") is backed by
   WL's own bundled FFmpeg-derived Video framework (confirmed via
   $VideoEncoders/$VideoDecoders and a duplicate-library warning
   naming the bundled FFmpegTools paclet directly), the same "just
   needs the free Wolfram Engine" promise as the rest of this repo.
   See tools/README.md for the full Step 1 investigation, including
   one real gap found and worked around (stereo audio requires
   explicit AudioEncoding -> "AAC" in VideoCombine; the default
   encoding throws an opaque internal error for every stereo WAV in
   this codebase while silently working for mono).

   Usage:
     wolframscript -file tools/make_presentation_video.wl -- \
       --gif=pendulum/output/double_animation.gif \
       --wav=pendulum/output/double_audio.wav \
       --title="Double Pendulum" \
       --profile=workshop \
       --out=pendulum/output/double_workshop.mp4

   Required flags:
     --gif       path to the source animated GIF
     --wav       path to the source WAV (its duration is
                 authoritative — see priority note below)
     --title     text overlaid in the title band (generously
                 sized, structurally separated from the animation)
     --profile   "linkedin" (1080x1080) or "workshop" (1920x1080)
     --out       destination MP4 path

   Optional flags:
     --stretch=N   time-stretch factor for the SOURCE AUDIO (and a
                   matching video slowdown), for the specific case
                   of a raw chirp-style sonification too short to
                   be followed. Uses a Hilbert-transform-derived
                   instantaneous frequency/amplitude remap onto a
                   longer time axis (see StretchAudioBuffer in
                   tools/src/video_pipeline.wl) — never a naive
                   waveform resample, which would divide every
                   frequency component by the stretch factor. Only
                   appropriate for close-to-monophonic tonal audio;
                   not verified against narrated or multi-voice WAVs.
     --tolerance=N GIF/WAV duration-match tolerance as a fraction
                   (default 0.03, matching the v1.5.1 GIF/WAV sync
                   fix's documented residual)
     --hold-seconds=N        hold the first frame still for N
                   seconds at the start AND the last frame still
                   for N seconds at the end, with the audio padded
                   with matching silence at each end so picture and
                   sound stay aligned (default 0, i.e. no hold).
                   Implemented inside the composition pipeline
                   itself (HoldFrames/PadAudioSilence in
                   tools/src/video_pipeline.wl), not as a
                   post-processing pass over the finished file.
     --hold-start-seconds=N  hold amount for the start only,
                   overriding --hold-seconds for that end.
     --hold-end-seconds=N    hold amount for the end only,
                   overriding --hold-seconds for that end.
                   All three reject negative values.
     --max-duration-seconds=N  threshold for the post-mux output
                   sanity check's duration warning (default 600).
     --max-file-mb=N           threshold for the post-mux output
                   sanity check's file-size warning (default 200).
                   Both thresholds are warn-only — see
                   CheckOutputSanity in
                   tools/src/video_pipeline.wl: the output file is
                   written either way, this only makes an
                   unexpectedly large result loud instead of silent.

   Priority, explicitly: correct video/audio sync matters more than
   anything else here. If the GIF and WAV are not duration-matched
   within tolerance, this tool refuses to produce a video rather
   than silently producing a desynced one — see
   VerifyDurationMatch / MakePresentationVideo's abort path in
   tools/src/video_pipeline.wl.
   ======================================================== *)

$toolsRoot    = DirectoryName[$InputFileName];
$repoRoot     = FileNameJoin[{$toolsRoot, ".."}];
$stemCoreRoot = FileNameJoin[{$repoRoot, "stem-core"}];

Get[FileNameJoin[{$stemCoreRoot, "src", "utils.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "synth.wl"}]];
Get[FileNameJoin[{$toolsRoot, "src", "video_pipeline.wl"}]];


(* ── CLI argument parsing: --key=value, same convention as the
   per-app main.wl entry points ── *)

$rawArgs = Select[Rest[$ScriptCommandLine], # =!= "--" &];

$argMap = Association[
  Cases[$rawArgs,
    a_String /; StringStartsQ[a, "--"] && StringContainsQ[a, "="] :>
      Rule @@ StringSplit[StringDrop[a, 2], "=", 2]
  ]
];

GetArg[key_String, default_:None] := Lookup[$argMap, key, default];

gifPath   = GetArg["gif"];
wavPath   = GetArg["wav"];
title     = GetArg["title"];
profile   = GetArg["profile"];
outPath   = GetArg["out"];
stretchArg    = GetArg["stretch"];
toleranceArg  = GetArg["tolerance"];
holdArg          = GetArg["hold-seconds"];
holdStartArg     = GetArg["hold-start-seconds"];
holdEndArg       = GetArg["hold-end-seconds"];
maxDurationArg   = GetArg["max-duration-seconds"];
maxFileMBArg     = GetArg["max-file-mb"];

stretchFactor   = If[stretchArg === None, Automatic, ToExpression[stretchArg]];
durationTolerance = If[toleranceArg === None, 0.03, ToExpression[toleranceArg]];

holdSeconds      = If[holdArg === None, 0, ToExpression[holdArg]];
holdStartSeconds = If[holdStartArg === None, holdSeconds, ToExpression[holdStartArg]];
holdEndSeconds   = If[holdEndArg === None, holdSeconds, ToExpression[holdEndArg]];
maxDurationSeconds = If[maxDurationArg === None, 600, ToExpression[maxDurationArg]];
maxFileMB           = If[maxFileMBArg === None, 200, ToExpression[maxFileMBArg]];

If[holdStartSeconds < 0 || holdEndSeconds < 0,
  Print["--hold-seconds/--hold-start-seconds/--hold-end-seconds must not be negative ",
        "(got hold-start-seconds=", holdStartSeconds, ", hold-end-seconds=", holdEndSeconds, ")."];
  Quit[1]
];

$missing = Select[
  {"gif" -> gifPath, "wav" -> wavPath, "title" -> title,
   "profile" -> profile, "out" -> outPath},
  #[[2]] === None &
][[All, 1]];

If[Length[$missing] > 0,
  Print["Missing required argument(s): ", StringRiffle[$missing, ", "]];
  Print[""];
  Print["Usage: wolframscript -file tools/make_presentation_video.wl -- \\"];
  Print["  --gif=<path.gif> --wav=<path.wav> --title=\"<text>\" \\"];
  Print["  --profile=linkedin|workshop --out=<path.mp4> [--stretch=N] [--tolerance=N] \\"];
  Print["  [--hold-seconds=N] [--hold-start-seconds=N] [--hold-end-seconds=N] \\"];
  Print["  [--max-duration-seconds=N] [--max-file-mb=N]"];
  Quit[1]
];

If[!FileExistsQ[gifPath], Print["GIF not found: ", gifPath]; Quit[1]];
If[!FileExistsQ[wavPath], Print["WAV not found: ", wavPath]; Quit[1]];
If[!MemberQ[{"linkedin", "workshop"}, profile],
  Print["--profile must be \"linkedin\" or \"workshop\", got: ", profile]; Quit[1]];


(* ── Run pipeline ── *)

Print["make_presentation_video: ", gifPath, " + ", wavPath, " -> ", outPath];
Print["  profile: ", profile, "   title: \"", title, "\"",
      If[stretchFactor =!= Automatic, "   stretch: " <> ToString[stretchFactor], ""],
      If[holdStartSeconds > 0 || holdEndSeconds > 0,
         "   hold-start: " <> ToString[holdStartSeconds] <>
         "s   hold-end: " <> ToString[holdEndSeconds] <> "s", ""]];
Print[""];

report = MakePresentationVideo[gifPath, wavPath, title, profile, outPath,
                                stretchFactor, durationTolerance,
                                holdStartSeconds, holdEndSeconds,
                                maxDurationSeconds, maxFileMB];

If[report["aborted"],
  Print["ABORTED: ", report["reason"]];
  Quit[1]
];

dc  = report["durationCheck"];
fdc = report["finalDurationCheck"];
fv  = report["frameVerification"];

Print["GIF/WAV duration check: GIF=", FmtN[dc["gifDuration"], 4], "s  WAV=",
      FmtN[dc["wavDuration"], 4], "s  diff=", FmtN[100*dc["relativeDiff"], 3],
      "%  (", If[dc["ok"], "within", "OUTSIDE"], " ", FmtN[100*dc["tolerance"],3], "% tolerance)"];
Print["Final video: ", report["nFrames"], " frames @ ", FmtN[report["frameRate"], 4],
      " fps, ", report["targetSize"][[1]], "x", report["targetSize"][[2]]];

If[holdStartSeconds > 0 || holdEndSeconds > 0,
  Print["Requested opening hold ", FmtN[report["holdStartSeconds"], 6],
        " seconds; effective hold ", FmtN[report["effectiveHoldStartSeconds"], 6],
        " seconds, which is ", report["holdStartFrames"], " frames at ",
        FmtN[report["frameRate"], 6], " frames per second."];
  Print["Requested closing hold ", FmtN[report["holdEndSeconds"], 6],
        " seconds; effective hold ", FmtN[report["effectiveHoldEndSeconds"], 6],
        " seconds, which is ", report["holdEndFrames"], " frames at ",
        FmtN[report["frameRate"], 6], " frames per second."];
];

Print["Muxed duration: ", FmtN[fdc["muxedDuration"], 4], "s vs source WAV ",
      FmtN[fdc["sourceWavDuration"], 4], "s  (diff=", FmtN[100*fdc["relativeDiff"], 3], "%)"];
Print["Frame clearance check: ", If[fv["ok"], "PASS", "FAIL"], "  (", fv["nFrames"],
      " frames checked, ", fv["nViolations"], " violations)"];
Print["  worst-case margins (px): top/title-clearance=", fv["worstTitleClearance"],
      "  bottom=", fv["worstBottomMargin"], "  left=", fv["worstLeftMargin"],
      "  right=", fv["worstRightMargin"]];

sc = report["sanityCheck"];
If[sc["ok"],
  Print["Output size check passed: video duration ", FmtN[sc["videoDurationSeconds"], 6],
        " seconds, audio duration ", FmtN[sc["audioDurationSeconds"], 6],
        " seconds, file size ", FmtN[sc["fileMB"], 6],
        " MB, all within the ", FmtN[sc["maxDurationSeconds"], 6],
        " seconds and ", FmtN[sc["maxFileMB"], 6], " MB thresholds."]
];
Do[Print[w], {w, sc["warnings"]}];

Print[""];
Print["Wrote ", report["outPath"]];

If[!fv["ok"], Quit[1]];

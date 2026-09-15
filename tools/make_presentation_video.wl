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

stretchFactor   = If[stretchArg === None, Automatic, ToExpression[stretchArg]];
durationTolerance = If[toleranceArg === None, 0.03, ToExpression[toleranceArg]];

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
  Print["  --profile=linkedin|workshop --out=<path.mp4> [--stretch=N] [--tolerance=N]"];
  Quit[1]
];

If[!FileExistsQ[gifPath], Print["GIF not found: ", gifPath]; Quit[1]];
If[!FileExistsQ[wavPath], Print["WAV not found: ", wavPath]; Quit[1]];
If[!MemberQ[{"linkedin", "workshop"}, profile],
  Print["--profile must be \"linkedin\" or \"workshop\", got: ", profile]; Quit[1]];


(* ── Run pipeline ── *)

Print["make_presentation_video: ", gifPath, " + ", wavPath, " -> ", outPath];
Print["  profile: ", profile, "   title: \"", title, "\"",
      If[stretchFactor =!= Automatic, "   stretch: " <> ToString[stretchFactor], ""]];
Print[""];

report = MakePresentationVideo[gifPath, wavPath, title, profile, outPath,
                                stretchFactor, durationTolerance];

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
Print["Muxed duration: ", FmtN[fdc["muxedDuration"], 4], "s vs source WAV ",
      FmtN[fdc["sourceWavDuration"], 4], "s  (diff=", FmtN[100*fdc["relativeDiff"], 3], "%)"];
Print["Frame clearance check: ", If[fv["ok"], "PASS", "FAIL"], "  (", fv["nFrames"],
      " frames checked, ", fv["nViolations"], " violations)"];
Print["  worst-case margins (px): top/title-clearance=", fv["worstTitleClearance"],
      "  bottom=", fv["worstBottomMargin"], "  left=", fv["worstLeftMargin"],
      "  right=", fv["worstRightMargin"]];
Print[""];
Print["Wrote ", report["outPath"]];

If[!fv["ok"], Quit[1]];

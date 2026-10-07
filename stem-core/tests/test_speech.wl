#!/usr/bin/env wolframscript

(* stem-core/tests/test_speech.wl — STEMSpeakToBuffer, STEMSpeechAvailable
   and STEMResampleLinear (stem-core/src/speech.wl).

   - File-based path: the platform tool is replaced by a shell wrapper
     that records its arguments and the text file it was given, then
     runs the real tool. The test checks the tool was called with -f and
     a file (never the text as an argument), that the file holds the
     text as UTF-8 ("H\[EAcute]non" as the bytes 48 C3 A9 6E 6F 6E), and that
     audio came back. Runs on macOS (say) and on Linux when espeak-ng is
     installed; elsewhere these checks are skipped and say so.
   - Silent fallback: every tool forced unavailable (pointed at a missing
     path) and SpeechSynthesize[] switched off. The call must return {},
     print one warning line that is one sentence naming the app, the
     tiers tried and the narration lost, and a WAV built around the empty
     narration must still export and import.
   - STEM_SPEECH_OFF=1 skips every tier the same way. *)

$stemCoreRoot = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

passed = 0; failed = 0;
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition], Print["  PASS  ", label]; passed++, Print["  FAIL  ", label]; failed++];

(* Run expr with stdout captured; returns {value, list of printed lines}. *)
$captureCount = 0;
SetAttributes[CaptureOutput, HoldFirst];
CaptureOutput[expr_] :=
  Module[{path, strm, val, lines},
    (* no RandomInteger here: one test counts the helper's random draws *)
    path = FileNameJoin[{$TemporaryDirectory,
             "stem_speech_test_" <> ToString[$ProcessID] <> "_" <> ToString[++$captureCount] <> ".txt"}];
    strm = OpenWrite[path, CharacterEncoding -> "UTF8", FormatType -> OutputForm, PageWidth -> Infinity];
    val = Block[{$Output = {strm}}, expr];
    Close[strm];
    lines = StringSplit[Import[path, "Text", CharacterEncoding -> "UTF8"], "\n"];
    DeleteFile[path];
    {val, lines}
  ];

tmpDir = CreateDirectory[];
missing = AssociationMap["/nonexistent/stem-speech-test/" <> # &, Keys[$STEMSpeechTools]];


(* ── 1. Resampler ─────────────────────────────────────────── *)
Print["-- STEMResampleLinear --"];
AssertTrue["equal rates return the data unchanged", STEMResampleLinear[{0., 1., 2.}, 44100, 44100] === {0., 1., 2.}];
AssertTrue["22050 -> 44100 doubles the length and keeps the end points",
  With[{r = STEMResampleLinear[N[Range[0, 99]], 22050, 44100]},
    Length[r] == 200 && r[[1]] == 0. && Abs[r[[-1]] - 99.] < 10^-12]];
Print[""];


(* ── 2. File-based path ───────────────────────────────────── *)
Print["-- Platform tool reads the text from a UTF-8 file --"];
tool = Switch[$OperatingSystem,
  "MacOSX", If[MissingQ[STEMFindTool["say"]], None, "say"],
  "Unix",   If[MissingQ[STEMFindTool["espeak-ng"]], None, "espeak-ng"],
  _,        None];
If[tool === None,
  Print["  SKIP  no ", Switch[$OperatingSystem, "Unix", "espeak-ng", "Windows", "test wrapper for PowerShell", _, "say"],
        " on ", $OperatingSystem, ", so the file-based path is not exercised here"],
  Module[{wrapper, argsLog, textLog, text, res, args, bytes, beforeTmp, afterTmp},
    wrapper = FileNameJoin[{tmpDir, "tool"}];
    argsLog = FileNameJoin[{tmpDir, "args.txt"}];
    textLog = FileNameJoin[{tmpDir, "text.bin"}];
    Export[wrapper, StringRiffle[{
      "#!/bin/sh",
      "printf '%s\\n' \"$@\" > '" <> argsLog <> "'",
      "prev=''",
      "for a in \"$@\"; do",
      "  if [ \"$prev\" = \"-f\" ]; then cp \"$a\" '" <> textLog <> "'; fi",
      "  prev=\"$a\"",
      "done",
      "exec '" <> STEMFindTool[tool] <> "' \"$@\""}, "\n"] <> "\n", "Text", CharacterEncoding -> "UTF8"];
    RunProcess[{"chmod", "+x", wrapper}];

    text = "The H\[EAcute]non map.";
    beforeTmp = FileNames["stem_say_*", $TemporaryDirectory];
    res = Block[{$STEMSpeechTools = Append[$STEMSpeechTools, tool -> wrapper]},
      STEMSpeakPlatform[text, 44100]];
    afterTmp = FileNames["stem_say_*", $TemporaryDirectory];
    args  = If[FileExistsQ[argsLog], StringSplit[Import[argsLog, "Text", CharacterEncoding -> "UTF8"], "\n"], {}];
    bytes = If[FileExistsQ[textLog], BinaryReadList[textLog], {}];

    AssertTrue["the tool was called with -f <file>", MemberQ[args, "-f"]];
    AssertTrue["the text itself was not passed as an argument", !MemberQ[args, text]];
    AssertTrue["the file holds the text as UTF-8 (H\[EAcute]non = 48 C3 A9 6E 6F 6E)",
      SequenceCount[bytes, {16^^48, 16^^C3, 16^^A9, 16^^6E, 16^^6F, 16^^6E}] == 1 &&
      StringTrim[FromCharacterCode[bytes, "UTF8"]] === text];
    AssertTrue["audio came back (" <> ToString[Length[res["buffer"]]] <> " samples at 44.1 kHz)",
      Length[res["buffer"]] > 4410 && VectorQ[res["buffer"], NumericQ]];
    AssertTrue["the temporary text and audio files were deleted", Complement[afterTmp, beforeTmp] === {}];
    AssertTrue["STEMSpeakToBuffer returns the same samples as the platform tier",
      Block[{$STEMSpeechUseSynthesize = False}, STEMSpeakToBuffer[text, 44100]] == res["buffer"]];
    AssertTrue["one random draw per platform call (seeded runs stay reproducible)",
      Module[{a, b},
        SeedRandom[7]; Block[{$STEMSpeechTools = missing, $STEMSpeechUseSynthesize = False},
          Quiet[CaptureOutput[STEMSpeakPlatform[text, 44100]]]]; a = RandomInteger[10^6];
        SeedRandom[7]; RandomInteger[999999]; b = RandomInteger[10^6];
        a === b]];
  ]];
Print[""];


(* ── 3. Silent fallback with every tool forced unavailable ─── *)
Print["-- Silent fallback --"];
Module[{text, out, buf, lines, warn, notes, wav, imported},
  text = "One two three four five six seven eight nine ten eleven twelve " <>
         "thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty " <>
         "twenty-one twenty-two twenty-three twenty-four twenty-five twenty-six " <>
         "twenty-seven twenty-eight twenty-nine thirty thirty-one thirty-two " <>
         "thirty-three thirty-four thirty-five.";
  {buf, lines} = Block[{$STEMSpeechTools = missing, $STEMSpeechUseSynthesize = False,
                        $projectRoot = FileNameJoin[{"stem", "henon"}]},
    CaptureOutput[STEMSpeakToBuffer[text, 44100]]];
  warn = Select[lines, StringStartsQ[#, "[WARNING]"] &];
  AssertTrue["STEMSpeechAvailable[] is False with every tool missing and SpeechSynthesize[] off",
    Block[{$STEMSpeechTools = missing, $STEMSpeechUseSynthesize = False}, STEMSpeechAvailable[]] === False];
  AssertTrue["returns {} when no tier produces audio", buf === {}];
  AssertTrue["prints exactly one warning line", Length[warn] == 1];
  If[Length[warn] == 1, warn = First[warn]; Print["        ", warn]];
  AssertTrue["the warning names the app", StringContainsQ[warn, "henon:"]];
  AssertTrue["the warning names the tiers tried",
    StringContainsQ[warn, "SpeechSynthesize[], which was switched off"] &&
    (Switch[$OperatingSystem,
       "MacOSX",  StringContainsQ[warn, "the macOS say command, which was not found"],
       "Unix",    StringContainsQ[warn, "espeak-ng (not found) and espeak (not found)"],
       "Windows", StringContainsQ[warn, "PowerShell System.Speech, which was not found"],
       _,         StringContainsQ[warn, "no speech tool is configured"]])];
  AssertTrue["the warning states the narration lost (35 words at 175 wpm = 12 s)",
    StringContainsQ[warn, "about 12 s of spoken narration (35 words)"]];
  AssertTrue["the warning is one sentence (ends with a full stop, no full stop inside)",
    StringEndsQ[warn, "."] && !StringContainsQ[StringDrop[warn, -1], ". " | "? " | "! "]];
  AssertTrue["the narration text is still printed", MemberQ[lines, text]];

  (* an app joins intro, pause and notes; with {} narration it still writes a WAV *)
  notes = Table[0.3 Sin[2. Pi 440 t / 44100], {t, 0, 44099}];
  wav = FileNameJoin[{tmpDir, "fallback.wav"}];
  ExportAudioBuffer[Join[buf, If[Length[buf] > 0, ConstantArray[0., 17640], {}], notes], wav, 44100];
  imported = Quiet[Import[wav]];
  AssertTrue["a WAV built around the empty narration exports and imports (1 s of notes)",
    AudioQ[imported] && Abs[QuantityMagnitude[Duration[imported], "Seconds"] - 1.0] < 10^-3];
];
Print[""];


(* ── 4. STEM_SPEECH_OFF=1 ─────────────────────────────────── *)
Print["-- STEM_SPEECH_OFF=1 --"];
Module[{buf, lines, warn},
  SetEnvironment["STEM_SPEECH_OFF" -> "1"];
  {buf, lines} = Block[{$projectRoot = FileNameJoin[{"stem", "dynamical"}]},
    CaptureOutput[STEMSpeakToBuffer["Short text.", 44100]]];
  AssertTrue["STEMSpeechAvailable[] is False", STEMSpeechAvailable[] === False];
  SetEnvironment["STEM_SPEECH_OFF" -> None];
  warn = Select[lines, StringStartsQ[#, "[WARNING]"] &];
  AssertTrue["returns {} and warns once, naming the switch",
    buf === {} && Length[warn] == 1 && StringContainsQ[First[warn], "dynamical:"] &&
    StringContainsQ[First[warn], "STEM_SPEECH_OFF=1"]];
];
Print[""];

Quiet[DeleteDirectory[tmpDir, DeleteContents -> True]];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

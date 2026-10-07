(* ========================================================
   stem-core/src/speech.wl — Spoken narration rendered into audio

   One tiered text-to-speech path shared by every narrated app
   (it replaces the per-app copies that each app used to carry):

     1. SpeechSynthesize[]   — tried first on every platform
     2. platform tool        — macOS:   say -f <text> -o <aiff>, then
                                         afconvert to 16-bit WAV
                               Linux:   espeak-ng -b 1 -f <text> -w <wav>,
                                         then espeak with the same flags
                               Windows: PowerShell System.Speech, text read
                                         with Get-Content -Encoding UTF8
     3. nothing              — one warning sentence naming the app, the
                               tiers tried and the narration lost; the
                               text is printed (STEMSay) and {} returned,
                               so the caller builds its WAV without it

   The text reaches the platform tool through a temporary UTF-8 text
   file rather than a command-line argument, so non-ASCII text such as
   "H\[EAcute]non" is spoken correctly whatever the console code page.

   Public:
     STEMSpeakToBuffer[text, sampleRate] — mono PCM list at sampleRate,
                                           or {} when no tier produced audio
     STEMSpeechAvailable[]               — True when a tier can speak
     STEMResampleLinear[data, rawSr, targetSr]

   Test hooks (Block them, or set the environment variable):
     $STEMSpeechUseSynthesize — False skips tier 1
     $STEMSpeechTools         — tool name -> executable; point one at a
                                missing path to force that tool unavailable
     STEM_SPEECH_OFF=1        — skips every tier (end-to-end silent test)

   Requires: accessibility.wl (STEMSay)
   ======================================================== *)


$STEMSpeechUseSynthesize = True;

$STEMSpeechTools = <|
  "say"        -> "say",
  "afconvert"  -> "afconvert",
  "espeak-ng"  -> "espeak-ng",
  "espeak"     -> "espeak",
  "powershell" -> "powershell"
|>;

(* Speaking rate used only to estimate how much narration a failed call
   loses; macOS say and espeak-ng both default to about 175-180 wpm. *)
$STEMSpeechWordsPerMinute = 175;


(* STEMResampleLinear — general linear-interpolation resampler, any ratio. *)
STEMResampleLinear[data_List, rawSr_?NumericQ, targetSr_?NumericQ] :=
  Module[{n = Length[data], newN, ratio, oldPos, lo, frac},
    If[n < 2 || Abs[N[rawSr] - N[targetSr]] < 1.0, Return[data]];
    ratio = N[targetSr] / N[rawSr];
    newN  = Max[1, Round[n * ratio]];
    Table[
      oldPos = (i - 1) * (n - 1.0) / Max[newN - 1, 1];
      lo     = Clip[Floor[oldPos], {0, n - 2}];
      frac   = oldPos - lo;
      (1 - frac) * data[[lo + 1]] + frac * data[[lo + 2]],
      {i, newN}
    ]
  ];


(* STEMSpeechOffQ — True when STEM_SPEECH_OFF=1 is set (read per call). *)
STEMSpeechOffQ[] := Environment["STEM_SPEECH_OFF"] === "1";


(* STEMFindTool — absolute path of a tool from $STEMSpeechTools, or
   Missing[] when it is not installed. Searches PATH without starting a
   process; on Windows also tries the .exe name. *)
STEMFindTool[name_String] :=
  Module[{exe, sep, dirs, names, hits},
    exe = Lookup[$STEMSpeechTools, name, name];
    If[StringContainsQ[exe, "/" | "\\"],
      Return[If[FileExistsQ[exe], exe, Missing["NotFound", exe]]]];
    sep   = If[$OperatingSystem === "Windows", ";", ":"];
    dirs  = Select[StringSplit[Replace[Environment["PATH"], Except[_String] -> ""], sep],
                   StringLength[#] > 0 &];
    dirs  = DeleteDuplicates[Join[dirs, {"/usr/bin", "/usr/local/bin", "/opt/homebrew/bin"}]];
    names = If[$OperatingSystem === "Windows", {exe, exe <> ".exe"}, {exe}];
    hits  = Select[Flatten[Outer[FileNameJoin[{#1, #2}] &, dirs, names]],
                   FileExistsQ[#] && !DirectoryQ[#] &];
    If[hits === {}, Missing["NotFound", exe], First[hits]]
  ];


(* STEMSpeechPlatformTools — the platform tier's tools, in the order tried.
   macOS needs afconvert as well as say. *)
STEMSpeechPlatformTools[] :=
  Switch[$OperatingSystem,
    "MacOSX",  {"say"},
    "Unix",    {"espeak-ng", "espeak"},
    "Windows", {"powershell"},
    _,         {}
  ];


(* STEMSpeechAvailable
   True when a tier can produce audio: the platform tool is installed
   (macOS also needs afconvert), or, failing that, SpeechSynthesize[]
   returns audio for a one-word probe (the probe result is cached).
   False whenever STEM_SPEECH_OFF=1. Draws no random numbers. *)
$STEMSpeechSynthesizeProbe = Missing[];

STEMSpeechAvailable[] :=
  Module[{tools},
    If[STEMSpeechOffQ[], Return[False]];
    tools = STEMSpeechPlatformTools[];
    If[$OperatingSystem === "MacOSX",
      If[!MissingQ[STEMFindTool["say"]] && !MissingQ[STEMFindTool["afconvert"]],
        Return[True]],
      If[AnyTrue[tools, !MissingQ[STEMFindTool[#]] &], Return[True]]];
    If[!TrueQ[$STEMSpeechUseSynthesize], Return[False]];
    If[MissingQ[$STEMSpeechSynthesizeProbe],
      $STEMSpeechSynthesizeProbe = TrueQ[Quiet[Check[AudioQ[SpeechSynthesize["test"]], False]]]];
    $STEMSpeechSynthesizeProbe
  ];


(* STEMSpeechReadWAV — import a WAV written by a platform tool, delete it,
   and return mono samples resampled to targetSr ({} on any failure). *)
STEMSpeechReadWAV[wavPath_String, targetSr_Integer] :=
  Module[{snd, data, rawSr},
    snd = Quiet[Import[wavPath]];
    If[!AudioQ[snd], Quiet[DeleteFile[wavPath]]; Return[{}]];
    data  = Quiet[Flatten[N[AudioData[snd]]]];
    rawSr = Quiet[QuantityMagnitude[AudioSampleRate[snd]]];
    Quiet[DeleteFile[wavPath]];
    If[!ListQ[data] || Length[data] === 0 || !NumericQ[rawSr], Return[{}]];
    STEMResampleLinear[data, rawSr, targetSr]
  ];

STEMSpeechRunOK[r_, path_String] :=
  AssociationQ[r] && r["ExitCode"] === 0 && FileExistsQ[path];


(* STEMSpeakPlatform — tier 2. Returns <|"buffer" -> list, "status" -> str|>
   where status says what happened to the tools tried, for the warning. *)
STEMSpeakPlatform[text_String, targetSr_Integer] :=
  Module[{id, txtPath, wavPath, tools, found, r, buf = {}, status},
    tools = STEMSpeechPlatformTools[];
    If[tools === {},
      Return[<|"buffer" -> {}, "status" ->
        "no speech tool is configured for the platform " <> ToString[$OperatingSystem]|>]];

    id      = ToString[RandomInteger[999999]];
    txtPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".txt"}];
    wavPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".wav"}];
    Export[txtPath, text, "Text", CharacterEncoding -> "UTF8"];

    Switch[$OperatingSystem,

      "MacOSX",
        Module[{say, afc, aiffPath, conv},
          say = STEMFindTool["say"]; afc = STEMFindTool["afconvert"];
          status = Which[
            MissingQ[say], "the macOS say command, which was not found",
            MissingQ[afc], "the macOS say command, which could not run because afconvert was not found",
            True,          "the macOS say command, which failed"];
          If[!MissingQ[say] && !MissingQ[afc],
            aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".aiff"}];
            r = Quiet[RunProcess[{say, "-f", txtPath, "-o", aiffPath}]];
            If[STEMSpeechRunOK[r, aiffPath],
              conv = Quiet[RunProcess[{afc, aiffPath, wavPath, "-d", "LEI16", "-f", "WAVE"}]];
              If[STEMSpeechRunOK[conv, wavPath], buf = STEMSpeechReadWAV[wavPath, targetSr]]];
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]]]],

      "Unix",
        Module[{tried = {}},
          Do[
            found = STEMFindTool[tool];
            If[MissingQ[found], AppendTo[tried, tool <> " (not found)"]; Continue[]];
            r = Quiet[RunProcess[{found, "-b", "1", "-f", txtPath, "-w", wavPath}]];
            If[STEMSpeechRunOK[r, wavPath], buf = STEMSpeechReadWAV[wavPath, targetSr]];
            If[Length[buf] > 0, Break[]];
            AppendTo[tried, tool <> " (failed)"],
            {tool, tools}];
          Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]];
          status = StringRiffle[tried, " and "]],

      "Windows",
        Module[{psCmd, q},
          found = STEMFindTool["powershell"];
          status = If[MissingQ[found],
            "PowerShell System.Speech, which was not found",
            "PowerShell System.Speech, which failed"];
          If[!MissingQ[found],
            q[p_] := "'" <> StringReplace[StringReplace[p, "\\" -> "/"], "'" -> "''"] <> "'";
            psCmd = "Add-Type -AssemblyName System.Speech; " <>
                    "$t = Get-Content -Raw -Encoding UTF8 -LiteralPath " <> q[txtPath] <> "; " <>
                    "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " <>
                    "$s.SetOutputToWaveFile(" <> q[wavPath] <> "); " <>
                    "$s.Speak($t); " <>
                    "$s.SetOutputToDefaultAudioDevice()";
            r = Quiet[RunProcess[{found, "-NoProfile", "-Command", psCmd}]];
            If[STEMSpeechRunOK[r, wavPath], buf = STEMSpeechReadWAV[wavPath, targetSr]];
            Quiet[DeleteFile /@ Select[{wavPath}, FileExistsQ]]]]
    ];

    Quiet[DeleteFile[txtPath]];
    <|"buffer" -> If[ListQ[buf], buf, {}], "status" -> status|>
  ];


(* STEMSpeechAppName — the running app's directory name ($projectRoot is
   set by every main.wl, and Block-ed per app by demo*.wl). *)
STEMSpeechAppName[] :=
  If[StringQ[$projectRoot] && StringLength[$projectRoot] > 0,
    FileNameTake[StringTrim[$projectRoot, "/" | "\\"]], "stem"];


(* STEMSpeakToBuffer
   text -> mono PCM list at sampleRate via the tiers above, or {} with one
   warning sentence when no tier produced audio. The returned samples are
   exactly what the tier produced (resampled); callers normalise. *)
STEMSpeakToBuffer[text_String, sampleRate_Integer] :=
  Module[{buf, result, data, rawSr, synthNote, plat, words, lostSec},

    If[STEMSpeechOffQ[],
      synthNote = "SpeechSynthesize[] and the platform speech tool, both switched off by STEM_SPEECH_OFF=1";
      plat = Missing[],

      (* Tier 1: SpeechSynthesize[] *)
      buf = If[TrueQ[$STEMSpeechUseSynthesize],
        Quiet[Check[
          result = SpeechSynthesize[text];
          If[AudioQ[result],
            data  = Quiet[Flatten[N[AudioData[result]]]];
            rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
            If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
              STEMResampleLinear[data, rawSr, sampleRate],
              {}],
            {}],
          {}]],
        {}];
      If[ListQ[buf] && Length[buf] > 0, Return[buf]];
      synthNote = If[TrueQ[$STEMSpeechUseSynthesize],
        "SpeechSynthesize[], which failed", "SpeechSynthesize[], which was switched off"];

      (* Tier 2: platform tool *)
      plat = STEMSpeakPlatform[text, sampleRate];
      If[Length[plat["buffer"]] > 0, Return[plat["buffer"]]]
    ];

    (* Tier 3: nothing — one self-contained warning sentence *)
    words   = Length[StringSplit[text]];
    lostSec = 60.0 * words / $STEMSpeechWordsPerMinute;
    Print["[WARNING] ", STEMSpeechAppName[], ": no speech tier produced audio (tried ",
          synthNote, If[MissingQ[plat], "", ", then " <> plat["status"]],
          "), so about ", FmtDec[lostSec, 1], " s of spoken narration (", words,
          " words) is left out of the WAV, which is still written without it."];
    STEMSay[text];
    {}
  ];

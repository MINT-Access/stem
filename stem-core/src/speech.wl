(* ========================================================
   stem-core/src/speech.wl — Spoken narration rendered into audio

   One tiered text-to-speech path shared by every narrated app
   (it replaces the per-app copies that each app used to carry):

     1. SpeechSynthesize[]   — tried first on every platform, with an
                               English voice chosen by name from
                               VoiceStyleData[] (retried once on failure)
     2. platform tool        — macOS:   say -v <English voice> -f <text>
                                         -o <aiff>, then afconvert to WAV
                               Linux:   espeak-ng -v en -b 1 -f <text> -w
                                         <wav>, then espeak the same way
                               Windows: PowerShell System.Speech with an
                                         en-US or en-GB voice, text read
                                         with Get-Content -Encoding UTF8
     3. nothing              — one warning sentence naming the app, the
                               tiers tried and the narration lost; the
                               text is printed (STEMSay) and {} returned,
                               so the caller builds its WAV without it

   The text reaches the platform tool through a temporary UTF-8 text
   file rather than a command-line argument, so non-ASCII text such as
   "H\[EAcute]non" is spoken correctly whatever the console code page.

   The voice is always explicit and English, never the system default
   (on a Mac whose spoken-content language is German, say's default
   voice reads the English text in German). Choice, per tier:
     SpeechSynthesize[]  Samantha, then Daniel, then the first en-US or
                         en-GB voice by name, female before male, then
                         any English voice by name
     say                 Samantha, then Daniel, then the first en_ voice
                         by name; with none, the tier is skipped
     PowerShell          the first en-US voice by name, then en-GB
     espeak-ng/espeak    -v en
   Optional config keys (read by LoadConfig into $STEMSpeechConfig):
     simulation.speech.voice     a voice name, used by every tier that has
                                 it (espeak-ng: passed to -v as given)
     simulation.speech.rate_wpm  words per minute: say -r, espeak-ng -s;
                                 SpeechSynthesize[] and PowerShell output
                                 is time-stretched to it
   The first narration of each app prints one sentence naming the voice.

   Public:
     STEMSpeakToBuffer[text, sampleRate] — mono PCM list at sampleRate,
                                           or {} when no tier produced audio
     STEMSpeechAvailable[]               — True when a tier can speak
     STEMResampleLinear[data, rawSr, targetSr]

   Test hooks (Block them, or set the environment variable):
     $STEMSpeechUseSynthesize — False skips tier 1
     $STEMSpeechTools         — tool name -> executable; point one at a
                                missing path to force that tool unavailable
     STEM_SPEECH=platform     — skips SpeechSynthesize[] (forces tier 2)
     STEM_SPEECH=synthesize   — skips the platform tool
     STEM_SPEECH=off, or STEM_SPEECH_OFF=1 — skips every tier

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


(* STEMSpeechMode — "all", "platform", "synthesize" or "off", from
   STEM_SPEECH (read per call); STEM_SPEECH_OFF=1 means "off". *)
STEMSpeechMode[] :=
  Module[{e = Environment["STEM_SPEECH"]},
    Which[
      Environment["STEM_SPEECH_OFF"] === "1", "off",
      StringQ[e] && MemberQ[{"off", "platform", "synthesize"}, ToLowerCase[e]], ToLowerCase[e],
      True, "all"]];

STEMSpeechOffQ[] := STEMSpeechMode[] === "off";

(* $STEMSpeechConfig — simulation.speech from the merged config (LoadConfig
   sets it on every call; <||> when absent). *)
If[!AssociationQ[$STEMSpeechConfig], $STEMSpeechConfig = <||>];
STEMSpeechVoiceSetting[] := Replace[Lookup[$STEMSpeechConfig, "voice", None], Except[_String?(StringLength[#] > 0 &)] -> None];
STEMSpeechRateSetting[]  := Replace[Lookup[$STEMSpeechConfig, "rate_wpm", None], Except[_?(NumericQ[#] && # > 0 &)] -> None];

(* Announce the voice once per app (keyed by STEMSpeechAppName[]). *)
$STEMSpeechAnnounced = <||>;
STEMSpeechAnnounce[sentence_String] := STEMSpeechAnnounce[sentence, "voice"];
STEMSpeechAnnounce[sentence_String, kind_String] :=
  With[{key = {STEMSpeechAppName[], kind}},
    If[!KeyExistsQ[$STEMSpeechAnnounced, key],
      $STEMSpeechAnnounced[key] = True;
      Print["  Narration voice: ", sentence]]];


(* ── Voice choice ───────────────────────────────────────────── *)

$STEMSpeechPreferredVoices = {"Samantha", "Daniel"};

STEMSpeechLangCode[code_] :=
  If[StringQ[code], ToLowerCase[StringReplace[code, "_" -> "-"]], ""];

(* STEMSynthVoice — <|"name", "lang", "gender", "how"|> for SpeechSynthesize[],
   chosen from VoiceStyleData[] (cached per kernel), or Missing[] when the
   list has no English voice. *)
$STEMSynthVoiceList = Missing[];
STEMSynthVoices[] :=
  (If[MissingQ[$STEMSynthVoiceList],
     $STEMSynthVoiceList = Replace[Quiet[Check[VoiceStyleData[], {}]], Except[_List] -> {}]];
   $STEMSynthVoiceList);

STEMSynthVoice[] :=
  Module[{all, en, want = STEMSpeechVoiceSetting[], pick, rank, info},
    all  = Select[STEMSynthVoices[], AssociationQ[#] && StringQ[#["Name"]] &];
    info[v_, how_] := <|"name" -> v["Name"], "lang" -> v["LanguageCode"],
                        "gender" -> Replace[v["Gender"], Except[_String] -> "unknown gender"],
                        "how" -> how|>;
    If[want =!= None,
      pick = SelectFirst[all, #["Name"] === want &, None];
      If[pick =!= None, Return[info[pick, "set by simulation.speech.voice"]]];
      STEMSpeechAnnounce["the configured voice \"" <> want <> "\" is not available to SpeechSynthesize[], so an English voice is chosen instead.", "config"]];
    en = Select[all, StringStartsQ[STEMSpeechLangCode[#["LanguageCode"]], "en"] &];
    If[en === {}, Return[Missing[]]];
    Do[pick = SelectFirst[en, #["Name"] === nm &, None];
       If[pick =!= None, Return[info[pick, "chosen automatically"], Module]], {nm, $STEMSpeechPreferredVoices}];
    rank[v_] := {
      If[MemberQ[{"en-us", "en-gb"}, STEMSpeechLangCode[v["LanguageCode"]]], 0, 1],
      Switch[v["Gender"], "Female", 0, "Male", 1, _, 2],
      v["Name"]};
    info[First[SortBy[en, rank]], "chosen automatically"]
  ];

(* STEMSayVoice — the English voice for macOS say, from say -v ?, or
   Missing[] when no English voice is installed. *)
$STEMSayVoiceList = Missing[];
STEMSayVoice[say_String] :=
  Module[{r, lines, voices, want = STEMSpeechVoiceSetting[], pick},
    If[MissingQ[$STEMSayVoiceList],
      r = Quiet[RunProcess[{say, "-v", "?"}]];
      lines = If[AssociationQ[r] && StringQ[r["StandardOutput"]], StringSplit[r["StandardOutput"], "\n"], {}];
      $STEMSayVoiceList = DeleteCases[
        StringCases[#, StartOfString ~~ n : Shortest[__] ~~ Whitespace ~~ l : (LetterCharacter .. ~~ "_" ~~ WordCharacter ..) ~~ Whitespace ~~ "#" :> {StringTrim[n], l}] & /@ lines // Flatten[#, 1] &,
        {}]];
    voices = $STEMSayVoiceList;
    If[want =!= None && MemberQ[voices[[All, 1]], want],
      Return[<|"name" -> want, "lang" -> First[Cases[voices, {want, l_} :> l]], "how" -> "set by simulation.speech.voice"|>]];
    voices = Select[voices, StringStartsQ[#[[2]], "en_"] &];
    If[voices === {}, Return[Missing[]]];
    pick = SelectFirst[$STEMSpeechPreferredVoices, MemberQ[voices[[All, 1]], #] &, None];
    If[pick === None, pick = First[Sort[voices[[All, 1]]]]];
    <|"name" -> pick, "lang" -> First[Cases[voices, {pick, l_} :> l]], "how" -> "chosen automatically"|>
  ];

(* Rate for the tiers without a rate argument (SpeechSynthesize[],
   PowerShell). A voice's own rate is measured once, on a calibration
   sentence with no numbers (a clip's own word count is no guide: "1.40"
   is one word but four spoken ones), and every clip of that voice is
   time-stretched by the same factor, natural / target. *)
$STEMSpeechCalibrationText =
  "The quiet river runs past the old mill and over the stones, where children like to play on summer days.";
$STEMNaturalWPM = <||>;   (* voice key -> words per minute *)

STEMNaturalWPM[key_, data_List, sr_?NumericQ] :=
  ($STEMNaturalWPM[key] = 60.0 Length[StringSplit[$STEMSpeechCalibrationText]] / (Length[data] / sr));

STEMStretchToRate[data_List, sr_?NumericQ, natural_, rate_] :=
  Module[{a},
    If[rate === None || !NumericQ[natural] || Length[data] < 2, Return[data]];
    a = Quiet[AudioTimeStretch[Audio[data, SampleRate -> sr], natural / rate]];
    If[AudioQ[a], Flatten[N[AudioData[a]]], data]
  ];


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
    tools = If[STEMSpeechMode[] === "synthesize", {}, STEMSpeechPlatformTools[]];
    If[$OperatingSystem === "MacOSX",
      If[tools =!= {} && !MissingQ[STEMFindTool["say"]] && !MissingQ[STEMFindTool["afconvert"]],
        Return[True]],
      If[AnyTrue[tools, !MissingQ[STEMFindTool[#]] &], Return[True]]];
    If[!TrueQ[$STEMSpeechUseSynthesize] || STEMSpeechMode[] === "platform", Return[False]];
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
        Module[{say, afc, aiffPath, conv, voice = Missing[], rate = STEMSpeechRateSetting[]},
          say = STEMFindTool["say"]; afc = STEMFindTool["afconvert"];
          If[!MissingQ[say], voice = STEMSayVoice[say]];
          status = Which[
            MissingQ[say], "the macOS say command, which was not found",
            MissingQ[afc], "the macOS say command, which could not run because afconvert was not found",
            MissingQ[voice], "the macOS say command, which has no English voice installed (say -v ? lists none starting en_)",
            True,          "the macOS say command, which failed"];
          If[!MissingQ[say] && MissingQ[voice],
            STEMSpeechAnnounce["the macOS say command has no English voice installed, so it is skipped rather than reading the English text with another language's voice.", "skip"]];
          If[!MissingQ[say] && !MissingQ[afc] && !MissingQ[voice],
            aiffPath = FileNameJoin[{$TemporaryDirectory, "stem_say_" <> id <> ".aiff"}];
            r = Quiet[RunProcess[Join[{say, "-v", voice["name"]},
                    If[rate === None, {}, {"-r", ToString[Round[rate]]}],
                    {"-f", txtPath, "-o", aiffPath}]]];
            If[STEMSpeechRunOK[r, aiffPath],
              STEMSpeechAnnounce[voice["name"] <> " (" <> voice["lang"] <> ") through the macOS say command, " <>
                voice["how"] <> If[rate === None, ", at the voice's own rate.", ", at " <> ToString[Round[rate]] <> " words per minute."]]];
            If[STEMSpeechRunOK[r, aiffPath],
              conv = Quiet[RunProcess[{afc, aiffPath, wavPath, "-d", "LEI16", "-f", "WAVE"}]];
              If[STEMSpeechRunOK[conv, wavPath], buf = STEMSpeechReadWAV[wavPath, targetSr]]];
            Quiet[DeleteFile /@ Select[{aiffPath, wavPath}, FileExistsQ]]]],

      "Unix",
        Module[{tried = {}},
          Do[
            found = STEMFindTool[tool];
            If[MissingQ[found], AppendTo[tried, tool <> " (not found)"]; Continue[]];
            r = Quiet[RunProcess[Join[{found, "-v", Replace[STEMSpeechVoiceSetting[], None -> "en"]},
                    If[STEMSpeechRateSetting[] === None, {}, {"-s", ToString[Round[STEMSpeechRateSetting[]]]}],
                    {"-b", "1", "-f", txtPath, "-w", wavPath}]]];
            If[STEMSpeechRunOK[r, wavPath], buf = STEMSpeechReadWAV[wavPath, targetSr]];
            If[Length[buf] > 0,
              STEMSpeechAnnounce[tool <> " voice " <> Replace[STEMSpeechVoiceSetting[], None -> "en"] <>
                If[STEMSpeechVoiceSetting[] === None, " (English), chosen automatically", ", set by simulation.speech.voice"] <>
                If[STEMSpeechRateSetting[] === None, ", at the voice's own rate.", ", at " <> ToString[Round[STEMSpeechRateSetting[]]] <> " words per minute."]];
              Break[]];
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
            (* an en-US voice (first by name), else en-GB; the configured
               voice when installed. Prints VOICE=<name>|<culture>|<gender>,
               or NOVOICE and exit code 3 when no English voice exists. *)
            psCmd = "Add-Type -AssemblyName System.Speech; " <>
                    "$t = Get-Content -Raw -Encoding UTF8 -LiteralPath " <> q[txtPath] <> "; " <>
                    "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " <>
                    "$vs = @($s.GetInstalledVoices() | Where-Object { $_.Enabled } | ForEach-Object { $_.VoiceInfo }); " <>
                    "$v = $null; " <>
                    "$want = " <> q[Replace[STEMSpeechVoiceSetting[], None -> ""]] <> "; " <>
                    "if ($want) { $v = $vs | Where-Object { $_.Name -eq $want } | Select-Object -First 1 }; " <>
                    "if (-not $v) { $v = $vs | Where-Object { $_.Culture.Name -eq 'en-US' } | Sort-Object Name | Select-Object -First 1 }; " <>
                    "if (-not $v) { $v = $vs | Where-Object { $_.Culture.Name -eq 'en-GB' } | Sort-Object Name | Select-Object -First 1 }; " <>
                    "if (-not $v) { Write-Output 'NOVOICE'; exit 3 }; " <>
                    "$s.SelectVoice($v.Name); " <>
                    "$s.SetOutputToWaveFile(" <> q[wavPath] <> "); " <>
                    "$s.Speak($t); " <>
                    "$s.SetOutputToDefaultAudioDevice(); " <>
                    "Write-Output ('VOICE=' + $v.Name + '|' + $v.Culture.Name + '|' + $v.Gender)";
            r = Quiet[RunProcess[{found, "-NoProfile", "-Command", psCmd}]];
            If[STEMSpeechRunOK[r, wavPath] && STEMSpeechRateSetting[] =!= None && !KeyExistsQ[$STEMNaturalWPM, "powershell"],
              Module[{cTxt = txtPath <> ".cal.txt", cWav = wavPath <> ".cal.wav", cmd},
                Export[cTxt, $STEMSpeechCalibrationText, "Text", CharacterEncoding -> "UTF8"];
                cmd = StringReplace[psCmd, {q[txtPath] -> q[cTxt], q[wavPath] -> q[cWav]}];
                If[STEMSpeechRunOK[Quiet[RunProcess[{found, "-NoProfile", "-Command", cmd}]], cWav],
                  STEMNaturalWPM["powershell", STEMSpeechReadWAV[cWav, targetSr], targetSr]];
                Quiet[DeleteFile /@ Select[{cTxt, cWav}, FileExistsQ]]]];
            If[AssociationQ[r] && StringQ[r["StandardOutput"]] && StringContainsQ[r["StandardOutput"], "NOVOICE"],
              status = "PowerShell System.Speech, which has no en-US or en-GB voice installed";
              STEMSpeechAnnounce["PowerShell System.Speech has no en-US or en-GB voice installed, so it is skipped rather than reading the English text with another language's voice.", "skip"]];
            If[STEMSpeechRunOK[r, wavPath],
              buf = STEMStretchToRate[STEMSpeechReadWAV[wavPath, targetSr], targetSr,
                      Lookup[$STEMNaturalWPM, "powershell", None], STEMSpeechRateSetting[]];
              With[{m = StringCases[r["StandardOutput"], "VOICE=" ~~ n : Except["|"] .. ~~ "|" ~~ c : Except["|"] .. ~~ "|" ~~ g : Except["\n" | "\r"] .. :> {n, c, StringTrim[g]}]},
                If[m =!= {},
                  STEMSpeechAnnounce[m[[1, 1]] <> " (" <> m[[1, 2]] <> ", " <> ToLowerCase[m[[1, 3]]] <> ") through PowerShell System.Speech, " <>
                    If[STEMSpeechVoiceSetting[] === m[[1, 1]], "set by simulation.speech.voice", "chosen automatically"] <>
                    If[STEMSpeechRateSetting[] === None, ", at the voice's own rate.",
                       ", time-stretched to " <> ToString[Round[STEMSpeechRateSetting[]]] <> " words per minute."]]]]];
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
  Module[{buf = {}, data, rawSr, synthNote, plat, words, lostSec, mode, voice, synth, rate},
    mode = STEMSpeechMode[]; rate = STEMSpeechRateSetting[];

    If[mode === "off",
      synthNote = "SpeechSynthesize[] and the platform speech tool, both switched off by STEM_SPEECH=off or STEM_SPEECH_OFF=1";
      plat = Missing[],

      (* Tier 1: SpeechSynthesize[] with an English voice by name *)
      Which[
        !TrueQ[$STEMSpeechUseSynthesize], synthNote = "SpeechSynthesize[], which was switched off",
        mode === "platform",              synthNote = "SpeechSynthesize[], which STEM_SPEECH=platform skips",
        True,
          voice = STEMSynthVoice[];
          If[MissingQ[voice],
            synthNote = "SpeechSynthesize[], which offers no English voice",
            synth[t_] := Quiet[Check[
              With[{result = SpeechSynthesize[t, voice["name"]]},
                If[AudioQ[result],
                  data  = Quiet[Flatten[N[AudioData[result]]]];
                  rawSr = Quiet[QuantityMagnitude[AudioSampleRate[result]]];
                  If[ListQ[data] && Length[data] > 0 && NumericQ[rawSr],
                    STEMResampleLinear[data, rawSr, sampleRate], {}],
                  {}]],
              {}]];
            buf = synth[text];
            If[!ListQ[buf] || Length[buf] == 0, buf = synth[text]];   (* intermittent failures: retry once *)
            If[ListQ[buf] && Length[buf] > 0 && rate =!= None,
              If[!KeyExistsQ[$STEMNaturalWPM, voice["name"]],
                With[{c = synth[$STEMSpeechCalibrationText]},
                  If[ListQ[c] && Length[c] > 0, STEMNaturalWPM[voice["name"], c, sampleRate]]]];
              buf = STEMStretchToRate[buf, sampleRate, Lookup[$STEMNaturalWPM, voice["name"], None], rate]];
            If[ListQ[buf] && Length[buf] > 0,
              STEMSpeechAnnounce[voice["name"] <> " (" <> voice["lang"] <> ", " <> ToLowerCase[voice["gender"]] <>
                ") through SpeechSynthesize[], " <> voice["how"] <>
                If[rate === None, ", at the voice's own rate.",
                  ", time-stretched to " <> ToString[Round[rate]] <> " words per minute from its own " <>
                  FmtDec[Lookup[$STEMNaturalWPM, voice["name"], 0.], 0] <> " on a calibration sentence."]];
              Return[buf]];
            synthNote = "SpeechSynthesize[] with the voice " <> voice["name"] <> ", which failed twice"]];

      (* Tier 2: platform tool *)
      If[mode === "synthesize",
        plat = <|"status" -> "the platform speech tool, which STEM_SPEECH=synthesize skips"|>,
        plat = STEMSpeakPlatform[text, sampleRate];
        If[Length[plat["buffer"]] > 0, Return[plat["buffer"]]]]
    ];

    (* Tier 3: nothing — one self-contained warning sentence *)
    words   = Length[StringSplit[text]];
    lostSec = 60.0 * words / Replace[rate, None -> $STEMSpeechWordsPerMinute];
    Print["[WARNING] ", STEMSpeechAppName[], ": no speech tier produced audio (tried ",
          synthNote, If[MissingQ[plat], "", ", then " <> plat["status"]],
          "), so about ", FmtDec[lostSec, 1], " s of spoken narration (", words,
          " words) is left out of the WAV, which is still written without it."];
    STEMSay[text];
    {}
  ];

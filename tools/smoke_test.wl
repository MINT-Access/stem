#!/usr/bin/env wolframscript

(* ================================================================
   tools/smoke_test.wl — one-command check that every app runs here

   Usage (from anywhere; paths come from this file's location):
     wolframscript -file tools/smoke_test.wl                 all apps + demo.wl
     wolframscript -file tools/smoke_test.wl -- --quick      6 apps + demo.wl --quick
     wolframscript -file tools/smoke_test.wl -- --out=<path> report path
     wolframscript -file tools/smoke_test.wl -- --demo-timeout-seconds=7200
                                                 time limit for demo.wl
                                                 (default 3600)
     wolframscript -file tools/smoke_test.wl -- --resume
                                                 continue an interrupted run:
                                                 apps already in the report
                                                 are kept, not run again

   What it does, in this one kernel (no child wolframscript):
   1. An environment block: Wolfram version, system, encodings, whether
      SpeechSynthesize[] works, which speech and network tools run, a
      non-ASCII probe line, the pixel size of a test GIF export.
   2. Every app's default mode (the mode in its config.json), each run
      with stem-core STEMRunApp: console captured, messages recorded,
      Exit[] caught, 600 s time limit, and the loop always continues.
      For each run: status, seconds, WAV duration, integrated loudness
      (BS.1770), peak, GIF duration, GIF minus WAV (from the app's own
      sync sentence, which allows for spoken intros), GIF pixel size,
      whether the WAV opens with speech, and the first message.
   3. The pendulum frame-clipping check (pendulum/tests/
      verify_animation_frames.py, here in Wolfram so Python is not needed).
   4. demo.wl (with --quick under --quick), with its own time limit; if it
      is reached, the apps demo.wl had finished and the one it was
      running are listed.
   An app whose GIF export failed (stem-core ExportGIF) is listed as
   GIF FAILED with its WAV measured; its frame check is skipped.
   The report is written as UTF-8 to smoke_test_<SystemID>_<date>.txt in
   the repository root (or --out), line by line as the run goes, so an
   interrupted run leaves the lines so far. Each app's full console
   output and messages go to smoke_logs_<SystemID>_<date>/<app>.txt next
   to the report, flushed line by line (stem-core STEMRunApp "LogFile"),
   so the log of an app during which the kernel died is kept. For every
   app that failed or issued a message, the Messages section copies its
   GIF diagnostics lines, its [GIF FAILED] sentence and the 20 log lines
   before its first message. --resume reads the report being written
   (--out, or the newest smoke_test_<SystemID>_*.txt in the repository
   root), keeps the app lines it already holds and runs the rest; the
   log of the app that was running when the run stopped is kept as
   <app>.interrupted.txt and named in the report.
   Exit code 0 only if every app wrote a WAV and every GIF export
   succeeded; 1 otherwise.
   ================================================================ *)

$CharacterEncoding = "UTF8";
$smokeRoot = FileNameDrop[ExpandFileName[$InputFileName], -2];
Get[FileNameJoin[{$smokeRoot, "stem-core", "init.wl"}]];

$smokeArgs  = Select[Rest[$ScriptCommandLine], # =!= "--" &];
$smokeQuick = MemberQ[$smokeArgs, "--quick"];
$smokeOut   = With[{o = Select[$smokeArgs, StringStartsQ[#, "--out="] &]},
  If[o =!= {}, StringDrop[First[o], 6],
    FileNameJoin[{$smokeRoot, "smoke_test_" <> $SystemID <> "_" <>
      DateString[{"Year", "-", "Month", "-", "Day"}] <> ".txt"}]]];
$smokeResume = MemberQ[$smokeArgs, "--resume"];
(* --resume without --out: the newest report of this system in the root *)
If[$smokeResume && !FileExistsQ[$smokeOut],
  With[{old = FileNames["smoke_test_" <> $SystemID <> "_*.txt", $smokeRoot]},
    If[old =!= {}, $smokeOut = First[MaximalBy[old, FileDate[#, "Modification"] &]]]]];
$smokeLogDir = FileNameJoin[{DirectoryName[$smokeOut],
  With[{b = FileBaseName[$smokeOut]},
    If[StringStartsQ[b, "smoke_test_"], StringReplace[b, StartOfString ~~ "smoke_test_" -> "smoke_logs_"], b <> "_logs"]]}];
$smokeLog[app_String] := FileNameJoin[{$smokeLogDir, app <> ".txt"}];
(* the app lines of the report being resumed: app -> line *)
$smokeResumed = If[$smokeResume && FileExistsQ[$smokeOut],
  Module[{lines = StringSplit[Import[$smokeOut, "Text", CharacterEncoding -> "UTF8"], "\n"], i, j},
    i = FirstPosition[lines, l_ /; StringStartsQ[l, "app | mode | status"], {0}][[1]];
    If[i == 0, <||>,
      j = i + 1;
      While[j <= Length[lines] && (StringContainsQ[lines[[j]], " | "] || StringStartsQ[lines[[j]], "[INTERRUPTED]"]), j++];
      Association[(First[StringSplit[#, " | "]] -> #) & /@
        Select[lines[[i + 1 ;; j - 1]], StringContainsQ[#, " | "] &]]]],
  <||>];
If[$smokeResume, Print["  --resume: ", Length[$smokeResumed], " app lines kept from ", $smokeOut]];
$smokeQuickApps = {"pendulum", "dynamical", "henon", "images", "mandelbrot", "signal"};
$smokeTimeLimit = 600;
$smokeDemoTimeLimit = With[{o = Select[$smokeArgs, StringStartsQ[#, "--demo-timeout-seconds="] &]},
  If[o === {}, 3600,
    With[{v = Quiet[ToExpression[StringDrop[First[o], StringLength["--demo-timeout-seconds="]]]]},
      If[NumericQ[v] && v > 0, v,
        Print["[WARNING] --demo-timeout-seconds needs a positive number of seconds; using 3600."]; 3600]]]];

$report = {};
(* every report line goes to the report file at once (flushed), so a run
   that dies leaves its lines so far for --resume *)
EnsureDir[$smokeOut];
$reportStream = OpenWrite[$smokeOut, Method -> "STEMFlushed", CharacterEncoding -> "UTF8",
  FormatType -> OutputForm, PageWidth -> Infinity];
out[s_String] := (AppendTo[$report, s]; WriteString[$reportStream, s <> "\n"]; Print[s]);
fmt[x_?NumericQ, d_Integer] := FmtDec[x, d];
fmt[_, _] := "-";


(* ── Measurements ─────────────────────────────────────────────── *)

(* GIF logical screen size from the header (bytes 7-10, little endian). *)
GIFPixelSize[path_String] :=
  Module[{b = BinaryReadList[path, "Byte", 10]},
    If[Length[b] == 10, {b[[7]] + 256 b[[8]], b[[9]] + 256 b[[10]]}, Missing[]]];

(* WAV facts: duration, loudness, peak, and whether it opens with speech:
   at least 1 s of sound, then a silent stretch (|x| < 1e-3 on every
   channel) of at least 0.35 s starting before 60 s, which is how the
   narrated apps place their spoken intro before a 0.4 s pause. *)
WAVFacts[path_String] :=
  Module[{d, sr, m, nz, gaps, k, intro},
    d  = Quiet[Import[path, "Data"]]; sr = Quiet[Import[path, "SampleRate"]];
    If[!ListQ[d] || !NumericQ[sr], Return[<|"ok" -> False|>]];
    If[VectorQ[d], d = {d}];
    m  = Fold[(#1 + #2 + Abs[#1 - #2])/2 &, Abs[d]];   (* per-sample max over channels *)
    nz = Flatten[Position[UnitStep[m - 10.^-3], 1]];
    intro = False;
    If[Length[nz] > 1 && First[nz] < sr,
      gaps = Differences[nz];
      k = SelectFirst[Range[Length[gaps]],
            gaps[[#]] >= 0.35 sr && nz[[#]] >= sr && nz[[#]] <= 60 sr &, None];
      intro = k =!= None];
    <|"ok" -> True, "seconds" -> N[Length[First[d]] / sr],
      "lufs" -> MeasureIntegratedLoudness[d, sr],
      "peak" -> 20. Log10[Max[m]], "intro" -> intro|>
  ];

(* Frame-clipping check, ported from pendulum/tests/verify_animation_frames.py:
   a pixel is content unless it is near-achromatic (max - min channel < 12)
   and light (min channel > 120); the content bounding box must keep a
   margin of at least 3 px from every edge on every frame. *)
FrameClipCheck[path_String] :=
  Module[{frames, w, h, worst, nViol = 0, nFrames},
    frames  = Quiet[Import[path, "ImageList"]];
    If[!ListQ[frames], Return[<|"ok" -> False|>]];
    {w, h}  = ImageDimensions[First[frames]];
    nFrames = Length[frames];
    worst   = <|"top" -> Infinity, "bottom" -> Infinity, "left" -> Infinity, "right" -> Infinity|>;
    Do[
      Module[{a, r, g, b, hi, lo, content, rows, cols, margins},
        a = ImageData[ColorConvert[RemoveAlphaChannel[f], "RGB"], "Byte"];
        {r, g, b} = Transpose[a, {2, 3, 1}];
        hi = (r + g + Abs[r - g])/2; hi = (hi + b + Abs[hi - b])/2;
        lo = (r + g - Abs[r - g])/2; lo = (lo + b - Abs[lo - b])/2;
        content = 1 - UnitStep[11 - (hi - lo)] UnitStep[lo - 121];
        rows = Flatten[Position[Unitize[Total[content, {2}]], 1]];
        cols = Flatten[Position[Unitize[Total[content]], 1]];
        If[rows =!= {},
          margins = <|"top" -> First[rows] - 1, "bottom" -> h - Last[rows],
                      "left" -> First[cols] - 1, "right" -> w - Last[cols]|>;
          worst = Merge[{worst, margins}, Min];
          If[Min[Values[margins]] < 3, nViol++]]],
      {f, frames}];
    <|"ok" -> True, "frames" -> nFrames, "size" -> {w, h}, "worst" -> worst, "violations" -> nViol|>
  ];

(* GIF minus WAV in seconds from the app's own sync sentence (stem-core
   SyncWAVToGIF), which pairs the right files and, for narrated apps,
   compares the GIF with the WAV's part between intro and outro.
   Missing[] if the app printed none. *)
SyncFromLog[log_String] :=
  Module[{l = StringCases[log, "GIF/WAV sync:" ~~ Except["\n"] ..]},
    If[l === {}, Return[Missing[]]];
    l = Last[l];
    Which[
      StringContainsQ[l, "same duration"], 0.,
      True, With[{m = StringCases[l, "the GIF is " ~~ x : NumberString ~~ " s " ~~ w : ("longer" | "shorter") :>
                    If[w === "longer", 1, -1] ToExpression[x]]},
              If[m === {}, Missing[], N[Last[m]]]]]];

DefaultMode[app_String] :=
  Module[{c = Quiet[Import[FileNameJoin[{$smokeRoot, app, "config.json"}], "RawJSON",
                           CharacterEncoding -> "UTF8"]]},
    If[AssociationQ[c] && AssociationQ[c["simulation"]] && StringQ[c["simulation"]["mode"]],
      c["simulation"]["mode"], "-"]];


(* FileSystemType — the file system of the volume holding dir: df -T on
   Linux, the mount table on macOS, Get-Volume on Windows *)
FileSystemType[dir_String] :=
  Module[{r, mp, line},
    Quiet[Switch[$OperatingSystem,
      "Unix",
        r = RunProcess[{"df", "-PT", dir}, "StandardOutput"];
        If[StringQ[r], StringSplit[Last[StringSplit[StringTrim[r], "\n"]]][[2]], "unknown"],
      "MacOSX",
        r = RunProcess[{"df", "-P", dir}, "StandardOutput"];
        mp = If[StringQ[r], Last[StringSplit[Last[StringSplit[StringTrim[r], "\n"]]]], ""];
        line = SelectFirst[StringSplit[RunProcess[{"mount"}, "StandardOutput"], "\n"],
          StringContainsQ[#, " on " <> mp <> " ("] &, ""];
        First[StringCases[line, " on " <> mp <> " (" ~~ t : Except[","] .. :> t], "unknown"],
      "Windows",
        r = RunProcess[{"powershell", "-NoProfile", "-NonInteractive", "-Command",
          "(Get-Volume -FilePath '" <> dir <> "').FileSystemType"}, "StandardOutput"];
        If[StringQ[r] && StringTrim[r] =!= "", StringTrim[r], "unknown"],
      _, "unknown"]] /. Except[_String] -> "unknown"];

(* log excerpt for the Messages section: the GIF diagnostics lines, the
   [GIF FAILED] sentence, and the 20 lines before the first message *)
MessageLineQ[l_String] := StringMatchQ[l, RegularExpression["^[A-Za-z$`][A-Za-z0-9$`]*::[A-Za-z0-9]+: .*"]];
LogExcerpt[log_String] :=
  Module[{lines = StringSplit[log, "\n"], i},
    i = FirstPosition[lines, l_String /; MessageLineQ[l], {0}][[1]];
    <|"gif" -> Select[lines, StringStartsQ[#, "  GIF diagnostics" | "  [GIF FAILED]"] &],
      "before" -> If[i > 0, lines[[Max[1, i - 20] ;; i - 1]], {}],
      "first" -> If[i > 0, lines[[i]], None]|>];


(* ── 1. Environment ───────────────────────────────────────────── *)

out["STEM smoke test, " <> DateString[{"Year", "-", "Month", "-", "Day", " ", "Hour", ":", "Minute"}] <>
    If[$smokeQuick, " (--quick)", ""]];
out["== Environment =="];
out["Wolfram version: " <> $Version];
out["Operating system: " <> STEMPlatformDescription[] <> "; SystemID: " <> $SystemID];
out["Memory: " <> STEMBytesText[$SystemMemory] <> " total, " <> STEMBytesText[MemoryAvailable[]] <>
    " available (MemoryAvailable[])" <> If[$OperatingSystem === "Unix",
      With[{m = StringCases[Quiet[Import["/proc/meminfo", "Text"]] /. Except[_String] -> "",
          "MemAvailable:" ~~ Whitespace ~~ k : DigitCharacter .. :> ToExpression[k]]},
        If[m === {}, "", "; MemAvailable in /proc/meminfo " <> STEMBytesText[1024 First[m]]]], ""]];
out["Free space: " <> STEMFreeSpace[$smokeRoot] <> " on the output volume (" <> $smokeRoot <> ", " <>
    FileSystemType[$smokeRoot] <> "); " <> STEMFreeSpace[$TemporaryDirectory] <> " in $TemporaryDirectory (" <>
    $TemporaryDirectory <> ", " <> FileSystemType[$TemporaryDirectory] <> ")"];
If[$OperatingSystem === "Unix",
  With[{o = StringTrim[Quiet[Import["/proc/sys/vm/overcommit_memory", "Text"]] /. Except[_String] -> "?"]},
    out["Kernel overcommit (/proc/sys/vm/overcommit_memory): " <> o <>
        Switch[o, "0", " (heuristic)", "1", " (always)", "2", " (never, strict accounting)", _, ""]]]];
If[$OperatingSystem === "Unix",
  With[{c = StringTrim[Quiet[Import["/proc/sys/kernel/core_pattern", "Text"]] /. Except[_String] -> "?"]},
    out["Core dumps (/proc/sys/kernel/core_pattern): " <> c]]];
out["Per-app console logs: " <> $smokeLogDir <> If[$smokeResume, " (resumed run)", ""]];
out["CharacterEncoding: " <> ToString[$CharacterEncoding] <>
    ", SystemCharacterEncoding: " <> ToString[$SystemCharacterEncoding]];
out["Repository: " <> $smokeRoot];
(* SpeechSynthesize fails now and then (about one call in nine on the
   Mac); STEMSpeakToBuffer retries once, so the probe does too and says
   which attempt returned audio *)
Module[{try, why, a1, a2 = None},
  why[a_] := Which[a === $TimedOut, "no result within 60 s", a === $Failed, "$Failed", True, ToString[Head[a]]];
  try[] := TimeConstrained[Quiet[Check[SpeechSynthesize["Test."], $Failed]], 60, $TimedOut];
  a1 = try[];
  If[!AudioQ[a1], a2 = try[]];
  out["SpeechSynthesize[\"Test.\"]: " <> Which[
    AudioQ[a1], "returns audio (" <> fmt[QuantityMagnitude[Duration[a1], "Seconds"], 2] <> " s)",
    AudioQ[a2], "returned audio on the second attempt (" <>
      fmt[QuantityMagnitude[Duration[a2], "Seconds"], 2] <> " s); the first attempt gave " <> why[a1],
    True, "no audio on either of two attempts (" <> why[a2] <> ")"]]];
out["Speech tier available (STEMSpeechAvailable[]): " <> ToString[STEMSpeechAvailable[]]];
With[{v = STEMSynthVoice[]},
  out["Narration voice for SpeechSynthesize[]: " <> If[MissingQ[v], "no English voice in VoiceStyleData[]",
    v["name"] <> " (" <> v["lang"] <> ", " <> ToLowerCase[v["gender"]] <> "), " <> v["how"]] <>
    "; English voices listed: " <> ToString[Count[STEMSynthVoices[], e_ /; StringStartsQ[STEMSpeechLangCode[e["LanguageCode"]], "en"]]]]];
If[$OperatingSystem === "MacOSX" && !MissingQ[STEMFindTool["say"]],
  With[{v = STEMSayVoice[STEMFindTool["say"]]},
    out["Narration voice for say: " <> If[MissingQ[v], "no English voice (say is skipped)", v["name"] <> " (" <> v["lang"] <> "), " <> v["how"]]]]];
Scan[
  Function[tool,
    Module[{p = STEMFindTool[tool], r},
      out["Tool " <> tool <> ": " <> If[MissingQ[p], "not found",
        r = Quiet[RunProcess[{p, "--version"}]];
        p <> ", " <> If[AssociationQ[r], "starts (exit code " <> ToString[r["ExitCode"]] <> ")",
                        "found but does not start"]]]]],
  {"say", "afconvert", "espeak-ng", "espeak", "powershell", "curl"}];
With[{r = Quiet[URLRead[HTTPRequest["https://ssd-api.jpl.nasa.gov/sbdb.api?des=433"],
                        TimeConstraint -> 30, Interactive -> False]]},
  out["Network (URLRead to ssd-api.jpl.nasa.gov): " <>
      If[Head[r] === HTTPResponse, "HTTP " <> ToString[r["StatusCode"]], "no response"]]];
With[{probe = "Probe: H\[EAcute]non \[LongDash] \[Lambda] \[Times] \:2609"},
  out[probe];
  out["Probe UTF-8 bytes: " <> StringRiffle[IntegerString[#, 16, 2] & /@
        ToCharacterCode[StringDrop[probe, 7], "UTF8"], " "] <>
      " (expect 48 c3 a9 6e 6f 6e 20 e2 80 94 20 ce bb 20 c3 97 20 e2 98 89)"]];
Module[{g = Graphics[{Red, Disk[]}, ImageSize -> 100], p1, p2},
  p1 = FileNameJoin[{$TemporaryDirectory, "stem_smoke_" <> ToString[$ProcessID] <> "_a.gif"}];
  p2 = FileNameJoin[{$TemporaryDirectory, "stem_smoke_" <> ToString[$ProcessID] <> "_b.gif"}];
  ExportGIF[{g, g}, p1, GIFFramePlan[0.2, 10]];
  Export[p2, {g, g}, "GIF"];
  out["GIF of a Graphics with ImageSize 100: ExportGIF (144 dpi) " <>
      StringRiffle[ToString /@ GIFPixelSize[p1], "x"] <> " px; plain Export (host scale) " <>
      StringRiffle[ToString /@ GIFPixelSize[p2], "x"] <> " px"];
  Quiet[DeleteFile /@ {p1, p2}]];
out[""];


(* ── 2. Apps ──────────────────────────────────────────────────── *)

$apps = Sort[FileNameTake[DirectoryName[#]] & /@
          FileNames["main.wl", Select[FileNames["*", $smokeRoot], DirectoryQ]]];
If[$smokeQuick, $apps = Select[$apps, MemberQ[$smokeQuickApps, #] &]];

out["== Apps (" <> ToString[Length[$apps]] <> ", default mode each) =="];
out["app | mode | status | seconds | WAV s | LUFS | peak dBFS | GIF s | GIF-WAV s | GIF px | intro | first message"];
$results = <||>;
Scan[
  Function[app,
    Module[{r, wav, gif, wf, gs, gp, line, more, sync, log, fields},
      If[KeyExistsQ[$smokeResumed, app],
        (* resumed: keep the line; rebuild what the later sections need
           from the line and the app's log *)
        line = $smokeResumed[app]; fields = StringSplit[line, " | "];
        log = If[FileExistsQ[$smokeLog[app]], Import[$smokeLog[app], "Text", CharacterEncoding -> "UTF8"], ""];
        If[!StringQ[log], log = ""];
        out[line];
        $results[app] = <|"status" -> fields[[3]], "log" -> log, "resumed" -> True,
          "messages" -> Select[StringSplit[log, "\n"], MessageLineQ],
          "wavs" -> If[fields[[5]] === "-", {}, {"(resumed)"}],
          "gifFailures" -> If[fields[[3]] === "GIF FAILED", {"(resumed)"}, {}],
          "newFiles" -> Select[StringCases[log, Shortest[p : ($PathnameSeparator ~~ Except[WhitespaceCharacter] ..)] ~~ ".gif" :> p <> ".gif"],
            FileExistsQ], "wav" -> None, "gif" -> None|>,
      Print["  running ", app, " ..."];
      (* resuming: a log already there is from the run that stopped
         during this app; keep it as the evidence of what happened *)
      If[$smokeResume && FileExistsQ[$smokeLog[app]],
        Quiet[RenameFile[$smokeLog[app], $smokeLog[app <> ".interrupted"], OverwriteTarget -> True]];
        out["[INTERRUPTED] the previous run stopped while " <> app <> " was running; its log up to that point is " <>
            FileNameTake[$smokeLog[app <> ".interrupted"], -2] <> ", and " <> app <> " is run again."]];
      r = STEMRunApp[FileNameJoin[{$smokeRoot, app}], {},
            "Silent" -> True, "LogFile" -> $smokeLog[app], "TimeLimit" -> $smokeTimeLimit];
      wav = If[r["wavs"] === {}, None,
              First[MaximalBy[r["wavs"], Quiet[WAVDuration[#]] &]]];
      gif = SelectFirst[r["newFiles"], StringEndsQ[#, ".gif", IgnoreCase -> True] &, None];
      wf  = If[wav === None, <|"ok" -> False|>, WAVFacts[wav]];
      gs  = If[gif === None, Missing[], Total[GIFFrameDelays[gif]]];
      sync = SyncFromLog[r["log"]];
      If[MissingQ[sync] && NumericQ[gs] && wf["ok"] && Length[r["wavs"]] == 1 &&
         Count[r["newFiles"], f_ /; StringEndsQ[f, ".gif"]] == 1,
        sync = gs - wf["seconds"]];
      gp  = If[gif === None, Missing[], GIFPixelSize[gif]];
      more = If[Length[r["wavs"]] > 1, " (+" <> ToString[Length[r["wavs"]] - 1] <> " more WAV)", ""];
      line = StringRiffle[{
        app, DefaultMode[app], r["status"], fmt[r["seconds"], 1],
        If[wf["ok"], fmt[wf["seconds"], 2] <> more, "-"],
        If[wf["ok"], fmt[wf["lufs"], 2], "-"],
        If[wf["ok"], fmt[wf["peak"], 2], "-"],
        fmt[gs, 2],
        fmt[sync, 3],
        If[ListQ[gp], StringRiffle[ToString /@ gp, "x"], "-"],
        If[wf["ok"], If[wf["intro"], "yes", "no"], "-"],
        If[r["messages"] === {}, "-", StringTake[First[r["messages"]], UpTo[160]]]}, " | "];
      out[line];
      $results[app] = Join[r, <|"wav" -> wav, "gif" -> gif|>]]]],
  $apps];
out[""];


(* ── 3. Pendulum frame-clipping check ─────────────────────────── *)

out["== Pendulum frame clipping (margin >= 3 px on every frame) =="];
If[KeyExistsQ[$results, "pendulum"],
  Scan[out["[SKIP] " <> FileNameTake[#] <> ": the frame-clearance check was skipped because the GIF was not written."] &,
    $results["pendulum"]["gifFailures"]];
  Scan[
    Function[g,
      With[{c = FrameClipCheck[g]},
        out[If[!c["ok"], "[FAIL] " <> FileNameTake[g] <> ": could not read the GIF",
          If[c["violations"] == 0, "[PASS] ", "[FAIL] "] <> FileNameTake[g] <> ": " <>
          ToString[c["frames"]] <> " frames, " <> StringRiffle[ToString /@ c["size"], "x"] <>
          " px, worst margins top " <> ToString[c["worst"]["top"]] <> ", bottom " <>
          ToString[c["worst"]["bottom"]] <> ", left " <> ToString[c["worst"]["left"]] <>
          ", right " <> ToString[c["worst"]["right"]] <> " px, " <>
          ToString[c["violations"]] <> " frames under the margin"]]]],
    Select[$results["pendulum"]["newFiles"], StringEndsQ[#, ".gif"] &]],
  out["pendulum was not run"]];
out[""];


(* ── 4. demo.wl ───────────────────────────────────────────────── *)

out["== demo.wl" <> If[$smokeQuick, " --quick", ""] <> " =="];
out["demo.wl time limit: " <> fmt[$smokeDemoTimeLimit, 0] <> " s (--demo-timeout-seconds)"];
Module[{r, passed, noGif, skips, steps, done, running},
  Print["  running demo.wl ..."];
  r = STEMRunApp[$smokeRoot, If[$smokeQuick, {"--quick"}, {}], "Script" -> "demo.wl",
        "RequireWAV" -> False, "Silent" -> True, "LogFile" -> $smokeLog["demo"],
        "TimeLimit" -> $smokeDemoTimeLimit];
  passed = StringCases[r["log"], "Passed:" ~~ Whitespace ~~ p : (DigitCharacter .. ~~ "/" ~~ DigitCharacter ..) :> p];
  (* demo.wl's "GIF failed:     n (WAV written, GIF not)" line *)
  noGif = StringCases[r["log"], "GIF failed:" ~~ Whitespace ~~ n : DigitCharacter .. :> n];
  noGif = If[noGif === {}, "", ", GIF failed in " <> First[noGif] <> " (WAV written)"];
  (* demo.wl's own lines: "=== Demo k/N: app ===" opens a step and
     "  Status: PASS" (or FAIL, NO GIF) closes it *)
  steps = Flatten[StringCases[StringSplit[r["log"], "\n"], {
    StartOfString ~~ "=== Demo " ~~ k : DigitCharacter .. ~~ "/" ~~ n : DigitCharacter .. ~~
      ": " ~~ a : Except[" "] .. ~~ " ===" :> {"start", a, k, n},
    StartOfString ~~ "  Status: " ~~ st : (WordCharacter | " ") .. :> {"status", StringTrim[st]}}], 1];
  done = {}; running = None;
  Scan[If[#[[1]] === "start", running = #,
         If[running =!= None, AppendTo[done, running[[2]] <> " " <> #[[2]]]; running = None]] &, steps];
  out["demo.wl | " <> r["status"] <> " | " <> fmt[r["seconds"], 1] <> " s | " <>
      Which[
        passed =!= {}, "passed " <> First[passed] <> noGif,
        r["status"] === "TIMEOUT",
          "stopped at the " <> fmt[$smokeDemoTimeLimit, 0] <> " s limit after " <>
          ToString[Length[done]] <> If[Length[done] === 1, " finished step", " finished steps"] <>
          If[running =!= None, ", while running step " <> running[[3]] <> " of " <> running[[4]] <>
            " (" <> running[[2]] <> ")", ""],
        True, "passed count not printed"] <> " | " <>
      If[r["messages"] === {}, "-", StringTake[First[r["messages"]], UpTo[160]]]];
  If[passed === {} && done =!= {},
    out["demo.wl finished steps: " <> StringRiffle[done, ", "] <> "."]];
  (* demo.wl prints "[WARNING] <reason> \[LongDash] skipping <app>." for each step it skips *)
  skips = StringCases[r["log"], "[WARNING] " ~~ why : Shortest[__] ~~ (" \[LongDash] " | " -- ") ~~ "skipping " ~~ app : WordCharacter .. :> {app, why}];
  $demoSkipText = If[skips === {}, "no step skipped",
    ToString[Length[skips]] <> " step" <> If[Length[skips] > 1, "s", ""] <> " skipped: " <>
    StringRiffle[(#[[1]] <> ", because " <> #[[2]]) & /@ skips, "; "]];
  out["demo.wl skipped steps: " <> $demoSkipText <> "."];
  $demoPassed = Which[passed =!= {}, First[passed] <> " runs passed" <> noGif,
    r["status"] === "TIMEOUT", "timed out after " <> ToString[Length[done]] <>
      If[Length[done] === 1, " finished step", " finished steps"] <>
      If[running =!= None, " while running " <> running[[2]], ""],
    True, "no pass count"];
  $results["demo.wl"] = r];
out[""];


(* ── Messages in full ─────────────────────────────────────────── *)

out["== Messages =="];
KeyValueMap[
  Function[{k, r},
    If[r["messages"] =!= {} || !MemberQ[{"OK", "EXIT0"}, r["status"]],
      out[k <> " (" <> r["status"] <> ", " <> ToString[Length[r["messages"]]] <> " message" <>
          If[Length[r["messages"]] === 1, "", "s"] <> "; full log " <>
          FileNameTake[$smokeLog[If[k === "demo.wl", "demo", k]], -2] <> "):"];
      Scan[out["  " <> #] &, r["messages"]];
      With[{x = LogExcerpt[r["log"]]},
        If[x["gif"] =!= {}, out["  GIF lines from the log:"]; Scan[out["    " <> StringTrim[#]] &, x["gif"]]];
        If[x["first"] =!= None,
          out["  the " <> ToString[Length[x["before"]]] <> " log lines before the first message (" <> x["first"] <> "):"];
          Scan[out["    | " <> #] &, x["before"]]]]]],
  $results];
If[AllTrue[Values[$results], #["messages"] === {} && MemberQ[{"OK", "EXIT0"}, #["status"]] &], out["none"]];
out[""];

$nNoWav = Count[KeyDrop[$results, "demo.wl"], r_ /; r["wavs"] === {}];
$gifFailedApps = Keys[Select[KeyDrop[$results, "demo.wl"], #["gifFailures"] =!= {} &]];
out["Summary: " <> ToString[Length[$apps] - $nNoWav] <> " of " <> ToString[Length[$apps]] <>
    " apps wrote a WAV; " <>
    If[$gifFailedApps === {}, "every GIF export succeeded",
      ToString[Length[$gifFailedApps]] <> " GIF export" <> If[Length[$gifFailedApps] > 1, "s", ""] <>
      " failed (" <> StringRiffle[$gifFailedApps, ", "] <> ")"] <>
    "; demo.wl " <> $results["demo.wl"]["status"] <> ", " <> $demoPassed <> ", " <> $demoSkipText <> "."];

Close[$reportStream];
Print["Report: ", $smokeOut];
Exit[If[$nNoWav == 0 && $gifFailedApps === {} && Length[$apps] > 0, 0, 1]];

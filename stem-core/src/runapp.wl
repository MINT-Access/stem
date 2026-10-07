(* ========================================================
   stem-core/src/runapp.wl — Run an app's main.wl in this kernel

   The in-process pattern of demo.wl, shared by experiments.wl files
   and tools/smoke_test.wl: Block the app's top-level globals and
   $ScriptCommandLine, then Get its main.wl. No child wolframscript is
   started, so no shell string, no quoting of paths with spaces, and
   no second kernel licence.

   Public:
     STEMRunApp[appDir, args, opts]        — one run, returns a record
     STEMRunExperiments[appDir, runs]      — a list of runs with one
                                             sentence each; returns 0/1

   Requires: utils.wl (FmtDec)
   ======================================================== *)


Options[STEMRunApp] = {
  "TimeLimit" -> Infinity,   (* seconds; Infinity = no limit *)
  "Silent"    -> False,      (* True: app console output goes to a
                                temporary file, returned as "log" *)
  "Script"    -> "main.wl",  (* file in appDir to Get (demo.wl for the demo) *)
  "RequireWAV" -> True       (* False: success does not need a new WAV *)
};

(* STEMRunApp
   appDir — the app's directory (holds main.wl and output/)
   args   — command-line arguments as typed after "--", e.g.
            {"--simulation.mode=l1"}
   Returns <|"status", "seconds", "exitCode", "messages", "newFiles",
             "wavs", "log"|>. status is
     "OK"       no messages, at least one new WAV in output/
     "MESSAGES" a WAV was written but Wolfram messages were issued
     "FAIL"     no new WAV, or the run aborted, or main.wl called Exit[n != 0]
     "TIMEOUT"  the TimeLimit was reached
     "EXIT0"    main.wl ended with Exit[0] before writing audio (as
                --config-dump does); counted as a success
   Exit[] and Quit[] inside main.wl end the run, not this kernel. *)
STEMRunApp[appDir_String, args_List, OptionsPattern[]] :=
  Module[{main, outDir, t0, sinkPath = None, sink, ed, res, msgs, exitCode = 0,
          exited = False, aborted = False, before, newFiles, wavs, status, log = "", seconds,
          snapshot},
    main   = FileNameJoin[{appDir, OptionValue["Script"]}];
    outDir = FileNameJoin[{appDir, "output"}];
    If[TrueQ[OptionValue["Silent"]],
      sinkPath = FileNameJoin[{$TemporaryDirectory,
        "stem_runapp_" <> ToString[$ProcessID] <> "_" <> ToString[Round[1000 AbsoluteTime[]]] <> ".txt"}];
      sink = OpenWrite[sinkPath, CharacterEncoding -> "UTF8",
                       FormatType -> OutputForm, PageWidth -> Infinity]];
    (* output/ before the run: file -> modification date, so only files
       this run created or rewrote count as its output *)
    snapshot[] := If[DirectoryQ[outDir],
      AssociationMap[FileDate[#, "Modification"] &,
        Select[FileNames["*", outDir], !DirectoryQ[#] &]], <||>];
    before = snapshot[];
    t0 = AbsoluteTime[];
    ed = EvaluationData[
      CheckAbort[
        Catch[
          TimeConstrained[
            Block[{
                $projectRoot, $stemCoreRoot, $cliArgs, $rawArgs,
                cfg, mode, params, sol, model, $noOrbitalElements,
                $CharacterEncoding = $CharacterEncoding,
                $ScriptCommandLine = Join[{main}, If[args === {}, {}, Prepend[args, "--"]]],
                $Output = If[sinkPath === None, $Output, {sink}],
                $MessagePrePrint = Function[x, ToString[x, InputForm]],
                Exit = (Throw[{"exit", If[{##} === {}, 0, First[{##}]]}, "stemRunAppExit"] &),
                Quit = (Throw[{"exit", If[{##} === {}, 0, First[{##}]]}, "stemRunAppExit"] &)},
              Get[main];
              "done"],
            OptionValue["TimeLimit"], "timeout"],
          "stemRunAppExit"],
        aborted = True; "aborted"]];
    seconds = AbsoluteTime[] - t0;
    If[sinkPath =!= None,
      Close[sink];
      log = Quiet[Import[sinkPath, "Text", CharacterEncoding -> "UTF8"]];
      If[!StringQ[log], log = ""];
      Quiet[DeleteFile[sinkPath]]];
    res  = ed["Result"];
    If[MatchQ[res, {"exit", _}], exited = True; exitCode = res[[2]]];
    msgs = StringReplace[StringTrim[#], Whitespace -> " "] & /@ ed["MessagesText"];
    newFiles = Keys[Select[
      KeyValueMap[#1 -> (!KeyExistsQ[before, #1] || #2 =!= before[#1]) &, snapshot[]] // Association,
      TrueQ]];
    wavs = Select[newFiles, StringEndsQ[#, ".wav", IgnoreCase -> True] &];
    status = Which[
      res === "timeout",                   "TIMEOUT",
      aborted || res === "aborted",        "FAIL",
      exitCode =!= 0,                      "FAIL",
      exited && wavs === {},              "EXIT0",
      wavs === {} && TrueQ[OptionValue["RequireWAV"]], "FAIL",
      msgs =!= {},                         "MESSAGES",
      True,                                "OK"];
    <|"status" -> status, "seconds" -> seconds, "exitCode" -> exitCode,
      "messages" -> msgs, "newFiles" -> newFiles, "wavs" -> wavs, "log" -> log|>
  ];


(* STEMRunExperiments
   runs — list of {label, args}; each is run with STEMRunApp (app output
   stays on the console) and followed by one self-contained sentence.
   Ends with a summary sentence. Returns 0 if every run is OK, MESSAGES
   or EXIT0, else 1 (use it as the script's exit code). *)
STEMRunExperiments[appDir_String, runs_List] :=
  Module[{n = Length[runs], results, app = FileNameTake[appDir], nBad},
    results = MapIndexed[
      Function[{run, pos},
        Module[{r = STEMRunApp[appDir, run[[2]]], head, wavNames},
          head = "Experiment " <> ToString[First[pos]] <> " of " <> ToString[n] <>
                 " (" <> app <> ", " <> run[[1]] <> ")";
          wavNames = StringRiffle[FileNameTake /@ r["wavs"], ", "];
          Print[""];
          Print["[", r["status"], "] ", head, Switch[r["status"],
            "OK",
              " finished in " <> FmtDec[r["seconds"], 1] <> " s and wrote " <>
              ToString[Length[r["newFiles"]]] <> " files, including " <> wavNames <> ".",
            "MESSAGES",
              " finished in " <> FmtDec[r["seconds"], 1] <> " s and wrote " <> wavNames <>
              ", but issued " <> ToString[Length[r["messages"]]] <>
              " Wolfram message(s), the first being: " <> First[r["messages"]],
            "TIMEOUT",
              " was stopped after " <> FmtDec[r["seconds"], 1] <> " s by its time limit.",
            "EXIT0",
              " ended with Exit[0] after " <> FmtDec[r["seconds"], 1] <>
              " s without writing audio, which is expected for this run.",
            _,
              " failed after " <> FmtDec[r["seconds"], 1] <> " s: " <> Which[
                r["exitCode"] =!= 0, "main.wl exited with code " <> ToString[r["exitCode"]],
                r["wavs"] === {},    "no WAV was written to " <> app <> "/output",
                True,                "the run was aborted"] <>
              If[r["messages"] === {}, ".", "; first message: " <> First[r["messages"]]]]];
          r]],
      runs];
    nBad = Count[results, r_ /; !MemberQ[{"OK", "MESSAGES", "EXIT0"}, r["status"]]];
    Print[""];
    Print[app, " experiments: ", n - nBad, " of ", n, " runs finished as expected",
          If[nBad > 0, "; " <> ToString[nBad] <> " failed or timed out.", "."]];
    If[nBad > 0, 1, 0]
  ];

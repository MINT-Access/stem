(* ========================================================
   stem-core/src/platform.wl — One human-readable platform description

   STEMPlatformDescription[] is the operating system line every report
   prints (demo.wl's System section, tools/smoke_test.wl's environment
   block):
     macOS 26.7.1 (Tahoe) on ARM64
     Windows 11 25H2 (build 26200) on x86-64
     Ubuntu 24.04.1 LTS, kernel 6.8.0-45-generic, on x86-64
   Never "Windows NT" (what .NET's OSVersion reports for every Windows)
   and never a bare version number. The architecture is $ProcessorType,
   the engine's own: the x64 engine under emulation on Apple silicon
   reports x86-64.

   The string is built by pure functions from fixed inputs, so the
   mappings are unit-tested (tests/test_platform.wl); only
   STEMPlatformDescription[] asks the system.
   ======================================================== *)


(* macOS major version -> marketing name; unknown majors get none *)
$STEMMacOSNames = <|26 -> "Tahoe", 15 -> "Sequoia", 14 -> "Sonoma"|>;

STEMMacOSName[version_String] :=
  Module[{major = Quiet[ToExpression[First[StringSplit[version, "."], ""]]]},
    If[IntegerQ[major], Lookup[$STEMMacOSNames, major, Missing["Unknown"]], Missing["Unknown"]]]

STEMMacPlatformString[version_String, arch_String] :=
  Module[{name = STEMMacOSName[version]},
    "macOS" <> If[version === "", "", " " <> version] <>
    If[MissingQ[name], "", " (" <> name <> ")"] <> " on " <> arch]


(* Windows product from the build number: 22000 and above is Windows 11,
   10240 to 19045 is Windows 10; anything else gets no product number *)
STEMWindowsProduct[build_Integer] :=
  Which[build >= 22000, "Windows 11",
        10240 <= build <= 19045, "Windows 10",
        True, "Windows"]

STEMWindowsPlatformString[build_Integer, displayVersion_String, arch_String] :=
  STEMWindowsProduct[build] <>
  If[displayVersion === "", "", " " <> displayVersion] <>
  " (build " <> ToString[build] <> ") on " <> arch

STEMWindowsPlatformString[_, displayVersion_String, arch_String] :=
  "Windows" <> If[displayVersion === "", "", " " <> displayVersion] <>
  " (build unknown) on " <> arch


STEMLinuxPlatformString[prettyName_String, kernel_String, arch_String] :=
  If[prettyName === "", "Linux", prettyName] <>
  If[kernel === "", "", ", kernel " <> kernel <> ","] <> " on " <> arch


(* STEMRunText — a command's trimmed stdout, or "" if it fails *)
STEMRunText[cmd_List] :=
  Module[{r = Quiet[RunProcess[cmd]]},
    If[AssociationQ[r] && r["ExitCode"] === 0 && StringQ[r["StandardOutput"]],
      StringTrim[r["StandardOutput"]], ""]]

(* PRETTY_NAME from an os-release file's text, without its quotes *)
STEMOsReleasePrettyName[text_String] :=
  Module[{line = SelectFirst[StringSplit[text, "\n"], StringStartsQ[#, "PRETTY_NAME="] &, ""]},
    StringTrim[StringDrop[line, UpTo[12]], "\"" | "'"]]


(* STEMPlatformDescription — the live description, computed once *)
STEMPlatformDescription[] := STEMPlatformDescription[] =
  Module[{arch = ToString[$ProcessorType]},
    Switch[$OperatingSystem,
      "MacOSX",
        STEMMacPlatformString[STEMRunText[{"sw_vers", "-productVersion"}], arch],
      "Windows",
        (* one PowerShell call: build number and display version from
           HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion (ReleaseId
           on Windows 10 releases before DisplayVersion existed) *)
        Module[{out, parts, build},
          out = STEMRunText[{"powershell", "-NoProfile", "-NonInteractive", "-Command",
            "$k = Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion'; " <>
            "$v = $k.DisplayVersion; if (-not $v) { $v = $k.ReleaseId }; " <>
            "Write-Output ($k.CurrentBuildNumber + '|' + $v)"}];
          parts = StringSplit[out, "|", All];
          build = If[Length[parts] >= 1, Quiet[ToExpression[StringTrim[First[parts]]]], None];
          If[!IntegerQ[build],
            (* without PowerShell: "Microsoft Windows [Version 10.0.26200.6584]" *)
            build = Quiet[ToExpression[First[StringCases[STEMRunText[{"cmd", "/c", "ver"}],
              "10.0." ~~ b : DigitCharacter .. :> b], None]]]];
          STEMWindowsPlatformString[build,
            If[Length[parts] >= 2, StringTrim[parts[[2]]], ""], arch]],
      "Unix",
        STEMLinuxPlatformString[
          If[FileExistsQ["/etc/os-release"],
            STEMOsReleasePrettyName[Quiet[Import["/etc/os-release", "Text", CharacterEncoding -> "UTF8"]] /. Except[_String] -> ""],
            ""],
          STEMRunText[{"uname", "-r"}], arch],
      _,
        ToString[$OperatingSystem] <> " on " <> arch]]

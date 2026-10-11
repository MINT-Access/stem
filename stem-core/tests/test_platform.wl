#!/usr/bin/env wolframscript

(* stem-core/tests/test_platform.wl — the platform description strings
   (stem-core/src/platform.wl) from fixed inputs: macOS major version to
   name, Windows build number to product, the Linux form, and that the
   live STEMPlatformDescription[] never says "Windows NT" or is a bare
   version number. *)

$stemCoreRoot = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

passed = 0; failed = 0;
AssertEqual[label_String, got_, want_] :=
  If[got === want, Print["  PASS  ", label]; passed++,
    Print["  FAIL  ", label, ": got ", InputForm[got], ", expected ", InputForm[want]]; failed++];
AssertTrue[label_String, condition_] :=
  If[TrueQ[condition], Print["  PASS  ", label]; passed++, Print["  FAIL  ", label]; failed++];

Print["-- macOS --"];
AssertEqual["26.7.1 is Tahoe", STEMMacPlatformString["26.7.1", "ARM64"], "macOS 26.7.1 (Tahoe) on ARM64"];
AssertEqual["15.0.1 is Sequoia", STEMMacPlatformString["15.0.1", "ARM64"], "macOS 15.0.1 (Sequoia) on ARM64"];
AssertEqual["14.6 is Sonoma", STEMMacPlatformString["14.6", "x86-64"], "macOS 14.6 (Sonoma) on x86-64"];
AssertEqual["13.6 (unknown major) has no name", STEMMacPlatformString["13.6", "ARM64"], "macOS 13.6 on ARM64"];
AssertEqual["26 alone is Tahoe", STEMMacPlatformString["26", "ARM64"], "macOS 26 (Tahoe) on ARM64"];
AssertEqual["no version (sw_vers failed)", STEMMacPlatformString["", "ARM64"], "macOS on ARM64"];

Print["-- Windows --"];
AssertEqual["build 26200 25H2 is Windows 11", STEMWindowsPlatformString[26200, "25H2", "x86-64"],
  "Windows 11 25H2 (build 26200) on x86-64"];
AssertEqual["build 22000 is Windows 11", STEMWindowsProduct[22000], "Windows 11"];
AssertEqual["build 21999 has no product number", STEMWindowsProduct[21999], "Windows"];
AssertEqual["build 19045 is Windows 10", STEMWindowsProduct[19045], "Windows 10"];
AssertEqual["build 10240 is Windows 10", STEMWindowsProduct[10240], "Windows 10"];
AssertEqual["build 9600 has no product number", STEMWindowsProduct[9600], "Windows"];
AssertEqual["Windows 10 22H2", STEMWindowsPlatformString[19045, "22H2", "x86-64"],
  "Windows 10 22H2 (build 19045) on x86-64"];
AssertEqual["no display version", STEMWindowsPlatformString[22631, "", "ARM64"],
  "Windows 11 (build 22631) on ARM64"];
AssertEqual["no build number", STEMWindowsPlatformString[None, "", "x86-64"],
  "Windows (build unknown) on x86-64"];

Print["-- Linux --"];
AssertEqual["PRETTY_NAME read without quotes",
  STEMOsReleasePrettyName["NAME=\"Ubuntu\"\nPRETTY_NAME=\"Ubuntu 24.04.1 LTS\"\nID=ubuntu\n"], "Ubuntu 24.04.1 LTS"];
AssertEqual["Linux form", STEMLinuxPlatformString["Ubuntu 24.04.1 LTS", "6.8.0-45-generic", "x86-64"],
  "Ubuntu 24.04.1 LTS, kernel 6.8.0-45-generic, on x86-64"];
AssertEqual["no os-release", STEMLinuxPlatformString["", "", "x86-64"], "Linux on x86-64"];

Print["-- This machine --"];
With[{d = STEMPlatformDescription[]},
  Print["  ", d];
  AssertTrue["is a string naming the architecture", StringQ[d] && StringContainsQ[d, " on "]];
  AssertTrue["never says Windows NT", !StringContainsQ[d, "Windows NT"]];
  AssertTrue["is not a bare version number", !StringMatchQ[d, (DigitCharacter | ".") ..]]];

Print[""];
Print["Results: ", passed, " passed, ", failed, " failed."];
If[failed > 0, Exit[1], Exit[0]];

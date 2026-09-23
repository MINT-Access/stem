(* ========================================================
   stem-core/tests/test_gifsync.wl — GIFFramePlan, ExportGIF (plan
   form), GIFFrameDelays, WAVDuration, PadWAVWithSilence, SyncWAVToGIF,
   FmtDec

   Run: wolframscript -file stem-core/tests/test_gifsync.wl
   Exits 0 if every test passes, 1 otherwise.
   ======================================================== *)

$stemCoreRoot = FileNameJoin[{DirectoryName[$InputFileName], ".."}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

$passed = 0; $failed = 0;
check[name_String, cond_] :=
  If[TrueQ[cond],
    $passed++; Print["  PASS  ", name],
    $failed++; Print["  FAIL  ", name]];

$tmp = FileNameJoin[{$TemporaryDirectory, "stem_gifsync_test_" <> ToString[RandomInteger[10^9]]}];
CreateDirectory[$tmp];

frameList[n_Integer] := Table[Graphics[{Hue[k / n], Disk[]}, ImageSize -> 40], {k, n}];
writeWAV[path_String, seconds_?NumericQ, sr_Integer:8000] :=
  ExportAudioBuffer[{ConstantArray[0.1, Round[seconds * sr]], ConstantArray[-0.1, Round[seconds * sr]]},
                    path, sr];


STEMSection["FmtDec"];
check["4.6078 -> 4.608",  FmtDec[4.6078] === "4.608"];
check["0.22 -> 0.22",     FmtDec[0.22] === "0.22"];
check["2. -> 2",          FmtDec[2.] === "2"];
check["344.112 -> 344.112", FmtDec[344.112] === "344.112"];
check["-0.0074 -> -0.007", FmtDec[-0.0074] === "-0.007"];
check["-0.0004 -> 0",     FmtDec[-0.0004] === "0"];


STEMSection["GIFFramePlan"];
(* dynamical iterate, 2026-09-22: 150-frame budget over a 32.5533 s WAV
   requested 4.6078 fps; the old code wrote 150 x 0.22 s = 33.0 s. *)
plan = GIFFramePlan[32.5533, 150 / 32.5533];
check["dynamical iterate: delay 22 cs", plan["DelayCentiseconds"] === 22];
check["dynamical iterate: 148 frames", plan["FrameCount"] === 148];
check["dynamical iterate: GIF 32.56 s", Abs[plan["GIFDuration"] - 32.56] < 10^-9];
check["dynamical iterate: |diff| <= half a delay", Abs[plan["Difference"]] <= 0.11];

(* lorenz: 150 frames over 40 s = 3.75 fps; old GIF 150 x 0.27 = 40.5 s *)
plan = GIFFramePlan[40.0, 150 / 40.0];
check["lorenz: delay 27 cs, 148 frames, 39.96 s",
  plan["DelayCentiseconds"] === 27 && plan["FrameCount"] === 148 &&
  Abs[plan["GIFDuration"] - 39.96] < 10^-9];

(* round rate: dynamical sweep clamps to 2 fps; must stay 688 x 0.5 s *)
plan = GIFFramePlan[344.112, 150 / 344.112];
check["dynamical sweep unchanged: 688 frames of 50 cs",
  plan["DelayCentiseconds"] === 50 && plan["FrameCount"] === 688];

(* upper clamp: 30 fps -> 3 cs, as the GIF writer always stored it *)
plan = GIFFramePlan[2.0, 600 / 2.0];
check["30 fps clamp -> 3 cs", plan["DelayCentiseconds"] === 3 && plan["FrameCount"] === 67];

(* MaxFrames bound: lengthen the delay instead of cutting the GIF short *)
plan = GIFFramePlan[30.08, 50 / 30.08, "MaxFrames" -> 20];
check["MaxFrames 20: 20 frames, delay recomputed to 150 cs",
  plan["FrameCount"] === 20 && plan["DelayCentiseconds"] === 150 &&
  Abs[plan["Difference"]] < 0.1];

(* MinFrames bound with very short audio *)
plan = GIFFramePlan[0.3, 150 / 0.3];
check["MinFrames 2 honoured with short audio", plan["FrameCount"] >= 2];

(* single held frame (cellular Rule 110, primes ulam) *)
plan = GIFFramePlan[10.0, 0.1, "MinFps" -> 0, "MinFrames" -> 1, "MaxFrames" -> 1];
check["single frame held 10 s", plan["FrameCount"] === 1 && plan["DelayCentiseconds"] === 1000];

(* fixed count (pendulum: 25 fps sampling, count set by the data) *)
plan = GIFFramePlan[10.0, 25, "MinFps" -> 0, "MaxFps" -> 50, "FrameCount" -> 251];
check["fixed count keeps 25 fps", plan["FrameCount"] === 251 && plan["DelayCentiseconds"] === 4];


STEMSection["ExportGIF plan form and GIFFrameDelays"];
gifPath = FileNameJoin[{$tmp, "plan.gif"}];
plan = GIFFramePlan[3.3, 15 / 3.3];   (* 4.545 fps requested -> 22 cs *)
ExportGIF[frameList[plan["FrameCount"]], gifPath, plan];
delays = GIFFrameDelays[gifPath];
imported = Import[gifPath, "DisplayDurations"];
check["GIFFrameDelays matches Import DisplayDurations",
  Length[delays] === Length[imported] && Max[Abs[delays - imported]] < 10^-9];
check["every stored delay equals the plan delay", Max[Abs[delays - plan["FrameDelay"]]] < 10^-9];
check["stored frame count equals the plan", Length[delays] === plan["FrameCount"]];

gifPath2 = FileNameJoin[{$tmp, "legacy.gif"}];
ExportGIF[frameList[5], gifPath2, 4.6078];
check["legacy numeric form stores Round[100/fps] cs",
  FileExistsQ[gifPath2] && Length[GIFFrameDelays[gifPath2]] === 5 &&
  Max[Abs[GIFFrameDelays[gifPath2] - 0.22]] < 10^-9];


STEMSection["WAVDuration"];
wavPath = FileNameJoin[{$tmp, "a.wav"}];
writeWAV[wavPath, 3.25];
check["WAVDuration reads 3.25 s from the header", Abs[WAVDuration[wavPath] - 3.25] < 10^-6];
importedDur = Import[wavPath, "Duration"];
If[QuantityQ[importedDur], importedDur = QuantityMagnitude[UnitConvert[importedDur, "Seconds"]]];
check["WAVDuration agrees with Import Duration", Abs[WAVDuration[wavPath] - importedDur] < 10^-6];


STEMSection["SyncWAVToGIF"];
(* GIF 3.3 s (15 x 0.22) vs WAV 3.25 s: within one frame delay, no padding *)
gifPath3 = FileNameJoin[{$tmp, "sync.gif"}];
ExportGIF[frameList[15], gifPath3, GIFFramePlan[3.3, 15 / 3.3, "FrameCount" -> 15]];
res = SyncWAVToGIF[gifPath3, wavPath];
check["no padding within one frame delay", res["PaddedSeconds"] == 0.0];
check["difference reported as GIF minus WAV", Abs[res["Difference"] - 0.05] < 10^-6];

(* GIF 3.3 s vs WAV 2.0 s: GIF longer by more than one delay -> pad *)
wavShort = FileNameJoin[{$tmp, "short.wav"}];
writeWAV[wavShort, 2.0];
res = SyncWAVToGIF[gifPath3, wavShort];
check["padded to the GIF duration", Abs[WAVDuration[wavShort] - 3.3] < 10^-3];
check["after padding the files agree within one centisecond", Abs[res["Difference"]] < 0.01];
check["padding kept 2 channels and the sample rate",
  Length[Import[wavShort, "Data"]] === 2 && Import[wavShort, "SampleRate"] === 8000];

(* WAV longer than the GIF by more than one delay: warn, never trim *)
wavLong = FileNameJoin[{$tmp, "long.wav"}];
writeWAV[wavLong, 5.0];
res = SyncWAVToGIF[gifPath3, wavLong];
check["longer WAV is left untouched", Abs[WAVDuration[wavLong] - 5.0] < 10^-6 && res["PaddedSeconds"] == 0.0];

(* intro: GIF timed to the part after a 1.7 s spoken intro *)
wavIntro = FileNameJoin[{$tmp, "intro.wav"}];
writeWAV[wavIntro, 1.7 + 3.3];
res = SyncWAVToGIF[gifPath3, wavIntro, "IntroSeconds" -> 1.7];
check["intro excluded from the comparison", Abs[res["Difference"]] < 10^-6];

(* outro: no padding even when the GIF is too long *)
wavOutro = FileNameJoin[{$tmp, "outro.wav"}];
writeWAV[wavOutro, 1.0 + 2.0 + 1.0];
res = SyncWAVToGIF[gifPath3, wavOutro, "IntroSeconds" -> 1.0, "OutroSeconds" -> 1.0];
check["with an outro the WAV is not padded", res["PaddedSeconds"] == 0.0 && Abs[WAVDuration[wavOutro] - 4.0] < 10^-6];


Quiet[DeleteDirectory[$tmp, DeleteContents -> True]];
Print[""];
Print["Results: ", $passed, " passed, ", $failed, " failed."];
Exit[If[$failed > 0, 1, 0]];

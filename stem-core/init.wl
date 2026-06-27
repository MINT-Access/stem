(* ========================================================
   stem-core/init.wl — Library entry point

   Load this file once from each project's main.wl or
   experiment.wl before Get-ing any project src files:

     $projectRoot  = DirectoryName[$InputFileName];
     $stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
     Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

   Modules loaded (in dependency order):
     utils.wl         — EnsureDir, LogError, FmtN
     scales.wl        — $StemSampleRate, $StemScales, SemitoneToHz, ScaleLookup
     synth.wl         — StemSynthNote, NormalizeBuffer, ExportAudioBuffer
     export.wl        — ExportCSV, ExportGIF
     accessibility.wl — STEMHeading, STEMSection, STEMBullet, STEMPrintN,
                        STEMDescribeCSV, STEMDescribeWAV, STEMDescribeGIF,
                        $STEMSpeakEnabled, STEMSay
     config.wl        — LoadConfig, DeepMerge, GetCfg, $HardcodedDefaults
     sonification.wl  — SonifyTrajectory, SpatialLayer, MotionLayer,
                        EventLayer, MixLayers, RenderAudio
   ======================================================== *)

$stemCoreRoot = DirectoryName[$InputFileName];

Get[FileNameJoin[{$stemCoreRoot, "src", "utils.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "scales.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "synth.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "export.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "accessibility.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "config.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "sonification.wl"}]];

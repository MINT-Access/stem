(* ========================================================
   stem-core/init.wl — Library entry point

   Load this file once from each project's main.wl or
   experiment.wl before Get-ing any project src files:

     $projectRoot  = DirectoryName[$InputFileName];
     $stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
     Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];

   Modules loaded (in dependency order):
     utils.wl         — EnsureDir, LogError, FmtN, FmtDec
     scales.wl        — $StemSampleRate, $StemScales, SemitoneToHz, ScaleLookup
     synth.wl         — StemSynthNote, NormalizeBuffer, NormalizeToLoudness,
                        MeasureIntegratedLoudness (BS.1770-4: KWeight,
                        KWeightingCoefficients, BlockMeanSquares), PeakLimit,
                        LimiterSettings, LimitedNormalizeToLoudness,
                        ExportAudioBuffer
     export.wl        — ExportCSV, GIFFramePlan, ExportGIF, ExportPNG,
                        STEMRasterize, GIFFrameDelays,
                        WAVDuration, PadWAVWithSilence, SyncWAVToGIF
     accessibility.wl — STEMHeading, STEMSection, STEMBullet, STEMPrintN,
                        STEMDescribeCSV, STEMDescribeWAV, STEMDescribeGIF,
                        STEMLoudnessLine, STEMTimingLine,
                        $STEMSpeakEnabled, STEMSay
     speech.wl        — STEMSpeakToBuffer, STEMSpeechAvailable,
                        STEMResampleLinear (tiered narration TTS)
     runapp.wl        — STEMRunApp, STEMRunExperiments (run a main.wl
                        in this kernel, as demo.wl does)
     hilbert.wl       — HilbertTraversalOrder
     platform.wl      — STEMPlatformDescription (the OS line in reports)
     config.wl        — LoadConfig, DeepMerge, GetCfg, $HardcodedDefaults
     sonification.wl  — SonifyTrajectory, SpatialLayer, MotionLayer,
                        EventLayer, MixLayers, RenderAudio
   ======================================================== *)

(* UTF-8 for every text read and write (Import/Export, streams, RunProcess).
   It does not change how wolframscript -file decodes the script itself
   (Latin-1), so string literals in main.wl, experiments.wl and demo*.wl
   use named characters such as \[EAcute] instead of raw non-ASCII. *)
$CharacterEncoding = "UTF8";

$stemCoreRoot = DirectoryName[$InputFileName];

Get[FileNameJoin[{$stemCoreRoot, "src", "utils.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "scales.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "synth.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "export.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "accessibility.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "runapp.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "hilbert.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "src", "platform.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "config.wl"}]];
Get[FileNameJoin[{$stemCoreRoot, "sonification.wl"}]];

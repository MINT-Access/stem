#!/usr/bin/env wolframscript

(* ========================================================
   experiments.wl — Black body radiation parameter experiments

   Run all experiments:
     wolframscript -file experiments.wl

   Each experiment writes its own GIF/PNG, WAV, and CSV to output/
   so the results can be compared side by side.
   ======================================================== *)

$projectRoot  = DirectoryName[$InputFileName];
$stemCoreRoot = FileNameJoin[{$projectRoot, "..", "stem-core"}];
Get[FileNameJoin[{$stemCoreRoot, "init.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "model.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "sonify.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "speech.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "animate.wl"}]];
Get[FileNameJoin[{$projectRoot, "src", "output.wl"}]];

$outDir = FileNameJoin[{$projectRoot, "output"}];
If[!DirectoryQ[$outDir], CreateDirectory[$outDir]];

$sr = 44100;
$freqMin = 1.0*^6; $freqMax = 1.0*^19;
$audioFreqMin = 100.0; $audioFreqMax = 4000.0;
$nBins = 64;

RunToFile[name_String, left_List, right_List] :=
  Module[{outWAV},
    outWAV = FileNameJoin[{$outDir, name <> "_audio.wav"}];
    EnsureDir[outWAV];
    ExportAudioBuffer[NormalizeBuffer[{left, right}, 0.92], outWAV, $sr];
    Print["    WAV -> ", outWAV];
    outWAV
  ];


(* --- spectrum_sun: solar temperature, peak lands in the visible band --- *)
Print[""];
Print[">>> Experiment: spectrum_sun"];
specSun = BuildSpectrumAudio[5778.0, $nBins, $freqMin, $freqMax, $audioFreqMin, $audioFreqMax,
                             4.0, 0.08, $sr];
PrintSpectrumSummary[specSun, 5778.0];
RunToFile["spectrum_sun", Join[specSun["chordL"], specSun["sweepL"]],
                          Join[specSun["chordR"], specSun["sweepR"]]];
AnimateSpectrum[5778.0, specSun["spec"], $freqMin, $freqMax,
  FileNameJoin[{$outDir, "spectrum_sun_animation.gif"}],
  FileNameJoin[{$outDir, "spectrum_sun_plot.png"}]];
ExportSpectrumCSV[specSun, FileNameJoin[{$outDir, "spectrum_sun_stats.csv"}]];

(* --- spectrum_red_dwarf: cool star, peak well into the infrared --- *)
Print[""];
Print[">>> Experiment: spectrum_red_dwarf"];
specCool = BuildSpectrumAudio[3200.0, $nBins, $freqMin, $freqMax, $audioFreqMin, $audioFreqMax,
                              4.0, 0.08, $sr];
PrintSpectrumSummary[specCool, 3200.0];
RunToFile["spectrum_red_dwarf", Join[specCool["chordL"], specCool["sweepL"]],
                                Join[specCool["chordR"], specCool["sweepR"]]];
AnimateSpectrum[3200.0, specCool["spec"], $freqMin, $freqMax,
  FileNameJoin[{$outDir, "spectrum_red_dwarf_animation.gif"}],
  FileNameJoin[{$outDir, "spectrum_red_dwarf_plot.png"}]];
ExportSpectrumCSV[specCool, FileNameJoin[{$outDir, "spectrum_red_dwarf_stats.csv"}]];

(* --- spectrum_white_dwarf: hot remnant, peak well into the ultraviolet --- *)
Print[""];
Print[">>> Experiment: spectrum_white_dwarf"];
specHot = BuildSpectrumAudio[25000.0, $nBins, $freqMin, $freqMax, $audioFreqMin, $audioFreqMax,
                             4.0, 0.08, $sr];
PrintSpectrumSummary[specHot, 25000.0];
RunToFile["spectrum_white_dwarf", Join[specHot["chordL"], specHot["sweepL"]],
                                  Join[specHot["chordR"], specHot["sweepR"]]];
AnimateSpectrum[25000.0, specHot["spec"], $freqMin, $freqMax,
  FileNameJoin[{$outDir, "spectrum_white_dwarf_animation.gif"}],
  FileNameJoin[{$outDir, "spectrum_white_dwarf_plot.png"}]];
ExportSpectrumCSV[specHot, FileNameJoin[{$outDir, "spectrum_white_dwarf_stats.csv"}]];

(* --- temperature_default: full 2500K-40000K sweep --- *)
Print[""];
Print[">>> Experiment: temperature_default"];
tempDefault = BuildTemperatureAudio[2500.0, 40000.0, 100, $nBins, $freqMin, $freqMax,
                                    $audioFreqMin, $audioFreqMax, 0.12, $sr];
PrintTemperatureSummary[tempDefault];
RunToFile["temperature_default", tempDefault["left"], tempDefault["right"]];
AnimateTemperature[tempDefault, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "temperature_default_animation.gif"}], 60];
RenderTemperatureStaticPNG[2500.0, 40000.0, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "temperature_default_plot.png"}]];
ExportTemperatureCSV[tempDefault, FileNameJoin[{$outDir, "temperature_default_stats.csv"}]];

(* --- temperature_narrow: a narrower, stellar-only range (3000K-15000K) --- *)
Print[""];
Print[">>> Experiment: temperature_narrow"];
tempNarrow = BuildTemperatureAudio[3000.0, 15000.0, 60, $nBins, $freqMin, $freqMax,
                                   $audioFreqMin, $audioFreqMax, 0.12, $sr];
PrintTemperatureSummary[tempNarrow];
RunToFile["temperature_narrow", tempNarrow["left"], tempNarrow["right"]];
AnimateTemperature[tempNarrow, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "temperature_narrow_animation.gif"}], 40];
RenderTemperatureStaticPNG[3000.0, 15000.0, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "temperature_narrow_plot.png"}]];
ExportTemperatureCSV[tempNarrow, FileNameJoin[{$outDir, "temperature_narrow_stats.csv"}]];

(* --- star_tour: sequential tour, red dwarf to white dwarf --- *)
Print[""];
Print[">>> Experiment: star_tour"];
tourOrder  = StarOrder[];
tourResult = BuildStarTourSegments[tourOrder, $StarPresets, $nBins, $freqMin, $freqMax,
                                   $audioFreqMin, $audioFreqMax, 2.5, $sr];
PrintStarSummary[tourOrder, $StarPresets];
RunToFile["star_tour",
  Flatten[Map[#["left"] &, tourResult["segments"]]],
  Flatten[Map[#["right"] &, tourResult["segments"]]]];
AnimateStarTour[tourOrder, $StarPresets, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "star_tour_animation.gif"}]];
RenderStarTourStaticPNG[tourOrder, $StarPresets, $freqMin, $freqMax,
  FileNameJoin[{$outDir, "star_tour_plot.png"}]];
ExportStarCSV[tourOrder, $StarPresets, $nBins, $freqMin, $freqMax, $audioFreqMin, $audioFreqMax,
  FileNameJoin[{$outDir, "star_tour_stats.csv"}]];

Print[""];
Print["=== All experiments complete. Files are in output/ ==="];

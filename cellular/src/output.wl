(* ========================================================
   src/output.wl — CSV statistics export and console summary

   Columns exported per generation:
     generation       — 0-indexed generation number
     population       — total live cells
     density          — population / total_cells  ∈ [0,1]
     left_density     — live cells in left half / half cells
     right_density    — live cells in right half / half cells
     delta_population — signed change from previous generation
                        (0 for generation 0)
   ======================================================== *)


ExportCellularStats[grid3D_List, filePath_String] :=
  Module[{nGen, nRows, nCols, halfCols, halfRight, totalCells,
          populations, leftPop, rightPop, deltas,
          header, rows},

    {nGen, nRows, nCols} = Dimensions[grid3D];
    halfCols   = Floor[nCols / 2];
    halfRight  = nCols - halfCols;
    totalCells = nRows * nCols;

    populations = N[Total[grid3D, {2, 3}]];
    leftPop     = N[Total[grid3D[[All, All, 1 ;; halfCols]], {2, 3}]];
    rightPop    = N[Total[grid3D[[All, All, halfCols + 1 ;; nCols]], {2, 3}]];
    deltas      = Prepend[N[Differences[populations]], 0.0];

    header = {{"generation", "population", "density",
               "left_density", "right_density", "delta_population"}};

    rows = Table[{
      g - 1,
      populations[[g]],
      N[populations[[g]] / totalCells],
      N[leftPop[[g]] / (halfCols * nRows)],
      N[rightPop[[g]] / (halfRight * nRows)],
      deltas[[g]]
    }, {g, 1, nGen}];

    ExportCSV[Join[header, rows], filePath]
  ]


PrintCellularSummary[grid3D_List, modeName_String] :=
  Module[{nGen, nRows, nCols, pops, maxPop, minPop, firstPop, finalPop, peakGen},
    {nGen, nRows, nCols} = Dimensions[grid3D];
    pops     = Total[grid3D, {2, 3}];
    maxPop   = Max[pops];
    minPop   = Min[pops];
    firstPop = First[pops];
    finalPop = Last[pops];
    peakGen  = First[Position[pops, maxPop]][[1]] - 1;   (* 0-indexed *)

    Print["--- Cellular Automata Summary (", modeName, ") ---"];
    STEMPrintN["Generations",     nGen];
    Print["  Grid:          ", nRows, " x ", nCols, " (", nRows * nCols, " cells)"];
    STEMPrintN["Initial pop",     firstPop];
    STEMPrintN["Peak pop",        maxPop];
    Print["  Peak at generation ", peakGen];
    STEMPrintN["Min pop",         minPop];
    STEMPrintN["Final pop",       finalPop]
  ]

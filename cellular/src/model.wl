(* ========================================================
   src/model.wl — Cellular automata models

   Two models sharing the same output shape {generations, rows, cols}
   so all downstream pipeline functions are mode-agnostic:

     LifeModel[cfg]    — Conway's Game of Life (2D, toroidal)
     Rule110Model[cfg] — Wolfram Rule 110 (1D, reshaped to 3D)
   ======================================================== *)


(* ── Game of Life internals ──────────────────────────── *)

(* Toroidal neighbour count using cyclic shifts.
   RotateRight[grid, {dr,dc}] shifts every row by dr and every
   column by dc with wrap-around — exactly the toroidal boundary. *)

GoLNeighbors[grid_] :=
  Total[RotateRight[grid, #] & /@
    {{-1,-1},{-1,0},{-1,1},{0,-1},{0,1},{1,-1},{1,0},{1,1}}]

(* Zero-padded neighbour count for non-toroidal grids.
   Pad the grid with a zero border, convolve, then trim. *)

GoLNeighborsFree[grid_] :=
  Module[{padded, n},
    padded = ArrayPad[grid, 1, 0];
    n      = ListConvolve[{{1,1,1},{1,0,1},{1,1,1}}, padded];
    n[[2 ;; -2, 2 ;; -2]]
  ]

(* Apply the B3/S23 rules: born if exactly 3 neighbours,
   survives if 2 or 3 neighbours.

   All arithmetic is integer-only so WL keeps the array packed.
   Using == on integer arrays produces True/False which unpacks
   the array and kills performance; Unitize/Abs avoids that:
     born    = 1 iff n == 3           (1 - Unitize[|n-3|])
     survive = grid iff n == 2 or 3  (grid * (1 - Unitize[(n-2)(n-3)])) *)

GoLStep[grid_, wrap_:True] :=
  Module[{n, born, survive},
    n       = If[wrap, GoLNeighbors[grid], GoLNeighborsFree[grid]];
    born    = 1 - Unitize[Abs[n - 3]];
    survive = grid * (1 - Unitize[(n - 2) * (n - 3)]);
    Clip[born + survive, {0, 1}]
  ]


(* ── Starting patterns ─────────────────────────────── *)

(* Build the initial grid for a named Life pattern.
   All coordinates are 1-indexed (WL convention).
   Patterns that extend beyond the grid boundary are clipped
   silently — this only affects very small grids. *)

LifeGrid[pattern_String, rows_Integer, cols_Integer] :=
  Module[{grid, cr, cc, cells},
    grid = ConstantArray[0, {rows, cols}];
    cr   = Ceiling[rows / 2];
    cc   = Ceiling[cols / 2];

    cells = Switch[pattern,

      (* R-pentomino: 5-cell seed that produces centuries of chaotic growth.
         Bounding box: 3x3, centred on (cr, cc).
           . X X
           X X .
           . X .                                                           *)
      "rpentomino",
        {{cr-1, cc}, {cr-1, cc+1},
         {cr,   cc-1}, {cr, cc},
         {cr+1, cc}},

      (* Gosper Glider Gun: 36-cell periodic pattern emitting a glider
         every 30 generations.  Bounding box: 9 rows x 36 cols.
         Placed with top-left at (5, 2) so gliders have space to travel. *)
      "gliderlgun",
        With[{r0 = 5, c0 = 2},
          Join[
            Map[{r0+0, c0+#} &, {24}],
            Map[{r0+1, c0+#} &, {22, 24}],
            Map[{r0+2, c0+#} &, {12, 13, 20, 21, 34, 35}],
            Map[{r0+3, c0+#} &, {11, 15, 20, 21, 34, 35}],
            Map[{r0+4, c0+#} &, {0, 1, 10, 16, 20, 21}],
            Map[{r0+5, c0+#} &, {0, 1, 10, 14, 16, 17, 22, 24}],
            Map[{r0+6, c0+#} &, {10, 16, 24}],
            Map[{r0+7, c0+#} &, {11, 15}],
            Map[{r0+8, c0+#} &, {12, 13}]
          ]
        ],

      (* Random: 30% density, fully random seed *)
      "random",
        Flatten[Table[
          If[RandomReal[] < 0.3, {r, c}, Nothing],
          {r, 1, rows}, {c, 1, cols}], 1],

      (* Fallback to R-pentomino for unknown patterns *)
      _,
        {{cr-1, cc}, {cr-1, cc+1},
         {cr,   cc-1}, {cr, cc},
         {cr+1, cc}}
    ];

    Do[
      With[{r = cell[[1]], c = cell[[2]]},
        If[1 <= r <= rows && 1 <= c <= cols,
          grid[[r, c]] = 1]],
      {cell, cells}
    ];
    grid
  ]


(* LifeModel
   Runs Conway's Game of Life.
   Returns a 3D integer array of shape {generations, rows, cols}. *)

LifeModel[cfg_Association] :=
  Module[{rows, cols, gens, wrap, pattern, grid, history},
    rows    = GetCfg[cfg, {"simulation","life","rows"},             80];
    cols    = GetCfg[cfg, {"simulation","life","cols"},             80];
    gens    = GetCfg[cfg, {"simulation","life","generations"},     300];
    wrap    = GetCfg[cfg, {"simulation","life","wrap"},           True];
    pattern = GetCfg[cfg, {"simulation","life","starting_pattern"}, "rpentomino"];

    grid    = LifeGrid[pattern, rows, cols];
    history = ConstantArray[0, {gens, rows, cols}];
    history[[1]] = grid;

    Do[
      grid         = GoLStep[grid, wrap];
      history[[g]] = grid,
      {g, 2, gens}
    ];

    history
  ]


(* Rule110Model
   Runs Wolfram Rule 110 using the built-in CellularAutomaton.
   Returns a 3D array of shape {generations, 1, width} — the
   singleton row dimension makes the shape identical to LifeModel
   so downstream functions need no mode-specific branches. *)

Rule110Model[cfg_Association] :=
  Module[{width, gens, initName, init, result},
    width    = GetCfg[cfg, {"simulation","rule110","width"},       120];
    gens     = GetCfg[cfg, {"simulation","rule110","generations"}, 200];
    initName = GetCfg[cfg, {"simulation","rule110","initial"},     "single_cell"];

    init = Switch[initName,
      "single_cell",
        ReplacePart[ConstantArray[0, width], Ceiling[width / 2] -> 1],
      "random",
        RandomInteger[1, width],
      _,
        ReplacePart[ConstantArray[0, width], Ceiling[width / 2] -> 1]
    ];

    (* CellularAutomaton[110, init, t] returns t+1 rows (gens 0..t) *)
    result = CellularAutomaton[110, init, gens - 1];

    (* Wrap each row in a singleton list: {gens,width} → {gens,1,width} *)
    List /@ result
  ]

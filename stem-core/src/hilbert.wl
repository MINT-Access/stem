(* ========================================================
   stem-core/src/hilbert.wl — Hilbert curve spatial traversal

   Provides HilbertTraversalOrder[n] for converting a 2^n × 2^n
   pixel grid into a locality-preserving traversal sequence.
   Used by the images app; available to future apps (CMB maps,
   fluid snapshots, etc.) without reimplementation.
   ======================================================== *)


(* HilbertTraversalOrder
   Returns the list of {col, row} pixel coordinates (1-based)
   visited by the Hilbert curve for a 2^n × 2^n grid, in traversal
   order.  Implements the same bijection that Wolfram's built-in
   HilbertCurve[n, 2] represents geometrically (the standard d2xy
   algorithm: each integer index 0..4^n-1 maps to a unique cell).

   n      — order of the curve; grid size is 2^n × 2^n
   Result — list of 4^n pairs {{col,row}, ...}, each component
            in 1..2^n, covering every cell exactly once *)

HilbertTraversalOrder[n_Integer?Positive] :=
  Module[{size = 2^n},
    Table[
      With[{x0 = 0, y0 = 0},
        Module[{x = 0, y = 0, s = 1, rx, ry, t = d, tmp},
          While[s < size,
            rx = If[BitAnd[t, 2] > 0, 1, 0];
            ry = If[BitXor[BitAnd[t, 1], rx] > 0, 1, 0];
            If[ry === 0,
              If[rx === 1, x = s - 1 - x; y = s - 1 - y];
              tmp = x; x = y; y = tmp
            ];
            x = x + s * rx;
            y = y + s * ry;
            t = BitShiftRight[t, 2];
            s = 2 * s
          ];
          {x + 1, y + 1}   (* 1-based {col, row} *)
        ]
      ],
      {d, 0, size^2 - 1}
    ]
  ]

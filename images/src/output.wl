(* images/src/output.wl — CSV and PNG export *)

(* Write per-pixel data table: Hilbert index, col/row, brightness, hue,
   saturation, and the frequency assigned during sonification. *)
ExportImageData[model_Association, freqAssigned_List, outCSV_String] :=
  Module[{traversal, pixBright, pixHue, pixSat, nPixels},
    traversal = model["traversal"];
    pixBright = model["pixBright"];
    pixHue    = model["pixHue"];
    pixSat    = model["pixSat"];
    nPixels   = model["nPixels"];
    ExportCSV[
      Join[
        {{"hilbert_index", "col", "row", "brightness", "hue",
          "saturation", "frequency_assigned"}},
        Table[
          {i, traversal[[i, 1]], traversal[[i, 2]],
           pixBright[[i]], pixHue[[i]], pixSat[[i]], freqAssigned[[i]]},
          {i, nPixels}
        ]
      ],
      outCSV
    ];
    STEMDescribeCSV[outCSV, nPixels, 7]
  ];

(* Write the processed source image as PNG (used as visual reference). *)
ExportImagePNG[model_Association, outPNG_String] :=
  Module[{},
    Export[outPNG, model["img"], "PNG"];
    Print["  PNG: ", outPNG]
  ];

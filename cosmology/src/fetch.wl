(* cosmology/src/fetch.wl — Planck Legacy Archive data fetcher *)

(* Fetch the Planck 2018 best-fit TT power spectrum from the PLA.
   Returns {lArr, dlArr} on success, {} on any network or parse failure.
   The caller is responsible for falling back to simulated data. *)
FetchPlanckSpectrum[lMaxFetch_Integer] :=
  Module[{
    url = "https://pla.esac.esa.int/pla/aio/product-action" <>
          "?COSMOLOGY.FILE_ID=COM_PowerSpect_CMB-TT-full_R3.01.txt",
    raw, lines, dataLines, parsed, lVec, dlVec, keep
  },
    Print["  Fetching Planck 2018 TT spectrum from PLA..."];
    raw = Quiet[URLFetch[url, "Content"]];
    If[!StringQ[raw] || StringLength[raw] < 200,
      Return[{}]
    ];
    (* File format: comment lines start with #, then  l  D_l  lower  upper *)
    lines     = StringSplit[raw, "\n"];
    dataLines = Select[lines,
      StringLength[StringTrim[#]] > 0 &&
      !StringStartsQ[StringTrim[#], "#"] &];
    If[Length[dataLines] < 5, Return[{}]];
    parsed = Quiet @ Map[
      Function[line, ToExpression /@ StringSplit[StringTrim[line]]],
      dataLines
    ];
    parsed = Select[parsed,
      ListQ[#] && Length[#] >= 2 &&
      NumericQ[#[[1]]] && NumericQ[#[[2]]] &];
    If[Length[parsed] < 10, Return[{}]];
    lVec  = Round /@ parsed[[All, 1]];
    dlVec = N   @ parsed[[All, 2]];
    keep  = Select[Range[Length[lVec]], lVec[[#]] <= lMaxFetch &];
    If[Length[keep] < 5, Return[{}]];
    {lVec[[keep]], dlVec[[keep]]}
  ];

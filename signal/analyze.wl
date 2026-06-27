(* ========================================================
   signal/analyze.wl — Fourier analysis and frequency-domain filtering

   Public API:
     ComputeSNR[signal, reference]     — SNR in dB
     FourierAnalysis[signalAssoc, cfg] — full analysis pipeline

   FourierAnalysis return keys:
     "clean"                — original clean signal
     "noisy"                — noisy signal
     "recovered"            — filtered signal (inverse DFT of masked spectrum)
     "spectrum_clean"       — one-sided power spectrum of clean signal
     "spectrum_noisy"       — one-sided power spectrum of noisy signal
     "spectrum_recovered"   — one-sided power spectrum of recovered signal
     "freq_axis"            — frequency axis in Hz (length = N/2+1)
     "recovered_frequencies"— detected peaks: list of {freq_hz, amplitude}
     "snr_before"           — SNR in dB before filtering
     "snr_after"            — SNR in dB after filtering
     "sample_rate", "duration", "known_frequencies", "mode"
   ======================================================== *)


(* ComputeSNR
   SNR in dB: 10·log10(power(reference) / power(signal − reference))
   signal    — the degraded or recovered version
   reference — the ground-truth clean signal *)

ComputeSNR[signal_List, reference_List] :=
  Module[{noise, sigPow, noisePow},
    noise    = N[signal - reference];
    sigPow   = Mean[N[reference]^2];
    noisePow = Mean[noise^2] + $MachineEpsilon;
    10.0 * Log[10.0, sigPow / noisePow]
  ]


(* BuildFilterMask
   Returns a length-nLen real mask (0.0 or 1.0) for the full DFT spectrum.
   The mask is symmetric in the positive/negative frequency sense so that
   InverseFourier yields a real-valued recovered signal.

   Bin k (1-indexed) has absolute frequency:
     |freq[k]| = |(k-1) * sr/N|          for k ≤ N/2+1
               = |(k-1-N) * sr/N|        for k > N/2+1        *)

BuildFilterMask[nLen_Integer, sr_?NumericQ, mode_String, freqs_List] :=
  Module[{absFreq, bw},
    absFreq = Abs[N[Table[
      With[{k = i - 1},
        If[k <= nLen / 2, k * sr / nLen, (k - nLen) * sr / nLen]],
      {i, 1, nLen}]]];

    Switch[mode,
      "chord",
        bw = 20.0;    (* ±10 Hz window around each chord tone *)
        Table[If[Min[Abs[absFreq[[i]] - freqs]] < bw / 2, 1.0, 0.0], {i, nLen}],

      "sweep",
        (* Bandpass between start_hz and end_hz *)
        With[{f0 = Min[freqs], f1 = Max[freqs]},
          Table[If[f0 <= absFreq[[i]] <= f1, 1.0, 0.0], {i, nLen}]],

      "am",
        (* Pass carrier and both sidebands with ±30 Hz tolerance *)
        Table[If[Min[Abs[absFreq[[i]] - freqs]] < 30.0, 1.0, 0.0], {i, nLen}],

      _,
        ConstantArray[1.0, nLen]
    ]
  ]


(* FindSpectrumPeaks
   Returns {{freq1, amp1}, {freq2, amp2}, ...} of local maxima in powOneS
   above threshold (fraction of global max) and above minFreqHz.
   Finds strict local maxima — each peak must be greater than both neighbours. *)

FindSpectrumPeaks[powOneS_List, freqAxis_List,
                  threshold_:0.02, minFreqHz_:30.0] :=
  Module[{n, maxPow, thresh, peakIdxs, peakFreqs, peakAmps},
    n      = Length[powOneS];
    maxPow = Max[powOneS];
    thresh = threshold * maxPow;
    peakIdxs = Select[Range[2, n - 1],
      powOneS[[#]] > thresh &&
      powOneS[[#]] > powOneS[[# - 1]] &&
      powOneS[[#]] > powOneS[[# + 1]] &&
      freqAxis[[#]] >= minFreqHz &];
    If[Length[peakIdxs] === 0,
      {},
      Transpose[{freqAxis[[peakIdxs]], Sqrt[powOneS[[peakIdxs]]]}]
    ]
  ]


FourierAnalysis[signalAssoc_Association, cfg_Association] :=
  Module[{clean, noisy, sr, dur, freqs, mode,
          nSamples, nHalf, freqAxis,
          specClean, specNoisy, specFiltered,
          powClean, powNoisy, powRecovered,
          mask, recovered,
          peaks, snrBefore, snrAfter},

    clean  = signalAssoc["clean"];
    noisy  = signalAssoc["noisy"];
    sr     = signalAssoc["sample_rate"];
    dur    = signalAssoc["duration"];
    freqs  = N[signalAssoc["frequencies"]];
    mode   = signalAssoc["mode"];

    nSamples = Length[clean];
    nHalf    = Floor[nSamples / 2] + 1;
    freqAxis = N[Range[0, nHalf - 1] * sr / nSamples];

    (* DFT — WL convention: (1/√N) Σ xₙ e^{−2πi k n/N} *)
    Print["  Computing DFT (", nSamples, " samples)..."];
    specClean = Fourier[N[clean]];
    specNoisy = Fourier[N[noisy]];

    (* One-sided power spectra: |F[k]|² for k = 0..N/2 *)
    powClean = Abs[specClean[[1 ;; nHalf]]]^2;
    powNoisy = Abs[specNoisy[[1 ;; nHalf]]]^2;

    (* Frequency-domain filter and inverse DFT *)
    mask         = BuildFilterMask[nSamples, sr, mode, freqs];
    specFiltered = specNoisy * mask;
    recovered    = Re[InverseFourier[specFiltered]];

    powRecovered = Abs[Fourier[N[recovered]][[1 ;; nHalf]]]^2;

    (* SNR before and after filtering *)
    snrBefore = ComputeSNR[noisy, clean];
    snrAfter  = ComputeSNR[recovered, clean];

    (* Peak detection in noisy spectrum *)
    peaks = FindSpectrumPeaks[powNoisy, freqAxis];

    <| "clean"                 -> clean,
       "noisy"                 -> noisy,
       "recovered"             -> recovered,
       "spectrum_clean"        -> powClean,
       "spectrum_noisy"        -> powNoisy,
       "spectrum_recovered"    -> powRecovered,
       "freq_axis"             -> freqAxis,
       "recovered_frequencies" -> peaks,
       "snr_before"            -> snrBefore,
       "snr_after"             -> snrAfter,
       "sample_rate"           -> sr,
       "duration"              -> dur,
       "known_frequencies"     -> freqs,
       "mode"                  -> mode |>
  ]

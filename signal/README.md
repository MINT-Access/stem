# Signal Processing

A Wolfram Language demonstration of Fourier analysis, runnable entirely from
the terminal via `wolframscript`. Unlike all other apps in this project, the
WAV output **is** the phenomenon — the user hears a signal directly, not a
sonification of something else. Listening to clean → noisy → recovered in
sequence is the clearest possible demonstration of what frequency-domain
filtering does.

## The mathematics

The discrete Fourier transform decomposes any signal into a sum of sinusoids:

    F[k] = (1/√N) Σ_{n=0}^{N-1} x[n] · e^{−2πi k n/N}

The power spectrum `|F[k]|²` reveals which frequencies carry energy. A
frequency-domain filter zeroes out unwanted bins, and `InverseFourier` recovers
the filtered signal. With a well-designed filter the noise is suppressed while
the signal components are preserved almost perfectly.

## Requirements

- Mathematica or the free Wolfram Engine
- `wolframscript` on your PATH
- `stem-core` (sibling directory `../stem-core`) — loaded automatically by `main.wl`

## Usage

```bash
# Default (chord mode)
wolframscript -file main.wl

# Explicit modes
wolframscript -file main.wl -- --simulation.mode=chord
wolframscript -file main.wl -- --simulation.mode=sweep
wolframscript -file main.wl -- --simulation.mode=am

# Inspect merged config
wolframscript -file main.wl -- --config-dump

# Override a parameter
wolframscript -file main.wl -- --simulation.chord.noise_level=0.7

# Play the accessible narrative
# macOS
afplay output/chord_narrative_full.wav

# Linux
aplay output/chord_narrative_full.wav

# Windows PowerShell
Start-Process wmplayer output\chord_narrative_full.wav
```

## Modes

### `chord` — Sum of sinusoids

Generates a C major chord: C4 (261.63 Hz) + E4 (329.63 Hz) + G4 (392.00 Hz),
corrupted by Gaussian noise at level 0.4. A comb filter with ±10 Hz windows
around each known frequency recovers the tones from the noise.

Typical result: SNR improves from ~8 dB to ~30 dB (+22 dB).

### `sweep` — Linear frequency chirp

Generates a chirp sweeping from 100 Hz to 2000 Hz over 4 seconds, corrupted
by noise at level 0.3. A bandpass filter between 100 Hz and 2000 Hz passes the
sweep energy while rejecting noise outside that band.

Typical result: SNR improves by ~10 dB.

### `am` — Amplitude modulation

Generates an AM signal with carrier 440 Hz and modulator 4 Hz (depth 0.8),
corrupted by noise at level 0.35. The AM signal expands to carrier + two
sidebands at 436 Hz and 444 Hz. A narrow bandpass around all three components
recovers the signal cleanly.

Typical result: SNR improves from ~7 dB to ~33 dB (+25 dB).

## Outputs

All outputs are prefixed with the mode name so multiple modes coexist in
`output/`.

| File | Description |
|------|-------------|
| `{mode}_clean.wav` | Clean signal, normalised to 0.95 peak |
| `{mode}_noisy.wav` | Noisy signal (same normalisation) |
| `{mode}_recovered.wav` | Filtered recovered signal |
| `{mode}_narrative_full.wav` | Speech + all three stages concatenated |
| `{mode}_waveform.png` | Time domain: clean + noisy overlay |
| `{mode}_spectrum.png` | Power spectrum: clean + noisy + peak markers |
| `{mode}_recovery.png` | Time domain: clean + recovered overlay |
| `{mode}_animation.gif` | 10-frame GIF zooming through time windows |
| `{mode}_spectrum.csv` | Per-bin: frequency_hz, power_clean, power_noisy, power_recovered |

## The narrative WAV

`{mode}_narrative_full.wav` is the most accessible single output. It chains:

1. Spoken introduction (frequencies, amplitudes)
2. Clean signal
3. Spoken transition ("adding Gaussian noise at level X")
4. Noisy signal
5. Spoken transition (SNR before and after filtering)
6. Recovered signal
7. Spoken summary (dB improvement, components identified)

This lets a blind user hear the entire demonstration without running any
commands or reading any output. Speech is synthesised via macOS `say`.

## Project structure

    signal/
    ├── main.wl              Entry point
    ├── config.json          App-level defaults
    ├── src/
    │   ├── model.wl         Signal generation (ChordModel, SweepModel, AMModel)
    │   ├── analyze.wl       DFT, filtering, SNR (FourierAnalysis, ComputeSNR)
    │   ├── animate.wl       PNG + GIF visualisation (AnimateSignal)
    │   └── sonify.wl        WAV export + narrative (SonifySignal)
    ├── output/              Output files (not committed)
    ├── AGENTS.md            Guidance for Claude Code
    └── README.md

## Console output

Step numbers `[1/5]` through `[5/5]` mark each pipeline stage. SNR values are
printed with `STEMPrintN`. Export confirmations use `STEMDescribeCSV`,
`STEMDescribeWAV`, and `STEMDescribeGIF`. The final line uses `STEMSay` for
optional speech output.

To enable speech at each stage, set `STEM_SPEAK=1`:

```sh
STEM_SPEAK=1 wolframscript -file main.wl -- --simulation.mode=chord
```

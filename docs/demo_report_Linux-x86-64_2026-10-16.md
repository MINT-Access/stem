# STEM Demo Report

Generated: Fri 16 Oct 2026 22:27:32

## System

- Wolfram Language: 15.0.0 for Linux x86 (64-bit) (May 26, 2026)
- Operating system: Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, on x86-64

## Summary

| App | Preset | Duration | Files | Status |
|-----|--------|----------|-------|--------|
| pendulum | double pendulum, chaotic initial angles | 74.4 s | 3 | ✓ PASS |
| lorenz | Rossler attractor, 40 s | 167.9 s | 3 | ✓ PASS |
| dynamical | logistic map sweep, r 2.5 to 4.0, period-doubling route to chaos | 65.9 s | 3 | ✓ PASS |
| dynamical | logistic map iterate, r=3.830 (period-3 window) | 99.9 s | 3 | ✓ PASS |
| henon | attractor mode, canonical a=1.4, b=0.3 | 98.0 s | 4 | ✓ PASS |
| asteroids | last 7 days, live NASA data with orbital elements | 203.8 s | 3 | ✓ PASS |
| lagrange | L4 libration, Sun-Jupiter μ=0.000954, 6 orbital periods | 18.3 s | 4 | ✓ PASS |
| resonance | galilean moons, 4:2:1 Laplace resonance, 8 Ganymede periods | 59.4 s | 3 | ✓ PASS |
| cellular | Game of Life, R-pentomino (300 generations) | 22.7 s | 4 | ✓ PASS |
| signal | chord mode (C major, Fourier analysis + narrative WAV) | 55.0 s | 9 | ✓ PASS |
| waves | ripple mode, 6 listening points, circular membrane | 39.4 s | 4 | ✓ PASS |
| fluid | Karman vortex street, Re=150, Strouhal frequency sonified | 23.3 s | 3 | ✓ PASS |
| quantum | QHO coherent state, alpha=3.0 (large amplitude) | 160.0 s | 4 | ✓ PASS |
| qubit | rabi mode, continuous Rabi oscillation, Omega=1.5 | 4.7 s | 3 | ✓ PASS |
| bell | chsh mode, derived-optimal angles, S=2*Sqrt[2] | 23.8 s | 4 | ✓ PASS |
| grover | compare mode, N=64, binaural classical vs quantum race | 38.9 s | 4 | ✓ PASS |
| hydrogen | full emission spectrum, n=2 to n=8, chord then UV-to-IR sweep | 45.3 s | 5 | ✓ PASS |
| thermo | Maxwell-Boltzmann distribution sweep, helium, 100K to 1000K | 35.0 s | 3 | ✓ PASS |
| quantum_statistics | fermi_sea mode, T-0 step function sharpening to blurring | 14.1 s | 4 | ✓ PASS |
| montecarlo | 2D Ising model sweep, 32x32 lattice, T 4.0 to 0.5 | 92.7 s | 3 | ✓ PASS |
| magnetic | magnetic mirror, trapped particle bouncing between reflection points | 142.9 s | 3 | ✓ PASS |
| scattering | Rutherford scattering discovery mode, Thomson vs Rutherford binaural comparison | 45.1 s | 3 | ✓ PASS |
| primes | prime gap rhythm, 5000 primes | 85.9 s | 4 | ✓ PASS |
| bayes | coin bias inference, theta_true=0.7, 100 flips (uniform prior) | 61.2 s | 3 | ✓ PASS |
| images | brightness mode, 2D Gaussian test image (64x64) | 22.8 s | 4 | ✓ PASS |
| mandelbrot | mandelbrot mode, the classic set over the standard window | 35.4 s | 4 | ✓ PASS |
| relativity | GW150914 chirp, 36+29 solar masses, 4x time stretch | 119.4 s | 7 | ✓ PASS |
| cosmology | CMB acoustic peaks, spectrum mode, simulated LCDM | 5.6 s | 3 | ✓ PASS |
| blackbody | Planck spectrum, solar T=5778K, chord then radio-to-X-ray sweep | 72.7 s | 4 | ✓ PASS |
| compton | Compton scattering, discovery mode, Thomson vs Compton binaural | 12.9 s | 3 | ✓ PASS |
| quantum_tunnelling | barrier, default preset, electron at 1eV vs a 2eV barrier | 17.7 s | 4 | ✓ PASS |
| clt | dice mode, sum of up to 10 fair six-sided dice | 11.3 s | 4 | ✓ PASS |
| brownian | ensemble mode, 150 walkers, sqrt(t) law | 11.8 s | 3 | ✓ PASS |

**Total elapsed:** 1989.3 s  |  33 passed

## App Results

### pendulum

- **Preset:** double pendulum, chaotic initial angles
- **Status:** PASS
- **Duration:** 74.5 s
- **Listen for:** Two bobs in binaural stereo — hear chaotic divergence between channels

**Output files:**

| File | Size |
|------|------|
| `double_animation.gif` | 4.5 MB |
| `double_audio.wav` | 3.4 MB |
| `double_results.csv` | 161.7 KB |

### lorenz

- **Preset:** Rossler attractor, 40 s
- **Status:** PASS
- **Duration:** 167.9 s
- **Listen for:** Melodic chaos — smoother than Lorenz, almost improvisational but never repeating

**Output files:**

| File | Size |
|------|------|
| `rossler_animation.gif` | 3.1 MB |
| `rossler_audio.wav` | 6.7 MB |
| `rossler_trajectory.csv` | 657.3 KB |

### dynamical

- **Preset:** logistic map sweep, r 2.5 to 4.0, period-doubling route to chaos
- **Status:** PASS
- **Duration:** 66 s
- **Listen for:** The rhythm doubling at r=3, doubling again, dissolving into chaos near r=3.57, then a surprising return to a clean three-note rhythm at the period-3 window near r=3.83

**Output files:**

| File | Size |
|------|------|
| `sweep_audio.wav` | 19.5 MB |
| `sweep_data.csv` | 110.6 KB |
| `sweep.gif` | 4.3 MB |

### dynamical

- **Preset:** logistic map iterate, r=3.830 (period-3 window)
- **Status:** PASS
- **Duration:** 100 s
- **Listen for:** A clean, repeating three-note rhythm — the period-3 window, a surprising island of order inside the chaotic region, heard here by iterating the map at a single fixed r rather than sweeping through it

**Output files:**

| File | Size |
|------|------|
| `iterate_period3_window_audio.wav` | 8.8 MB |
| `iterate_period3_window_data.csv` | 23.4 KB |
| `iterate_period3_window.gif` | 1.6 MB |

### henon

- **Preset:** attractor mode, canonical a=1.4, b=0.3
- **Status:** PASS
- **Duration:** 98 s
- **Listen for:** The Hénon map's strange attractor — Michel Hénon's simplified model of a Poincaré section through the Lorenz attractor. Pan tracks x, pitch tracks y, and accent tones mark each turning point where the trajectory folds back on itself

**Output files:**

| File | Size |
|------|------|
| `henon_attractor.csv` | 197.5 KB |
| `henon_attractor.gif` | 2.7 MB |
| `henon_attractor.png` | 99.5 KB |
| `henon_attractor.wav` | 5.5 MB |

### asteroids

- **Preset:** last 7 days, live NASA data with orbital elements
- **Status:** PASS
- **Duration:** 203.8 s
- **Listen for:** Each asteroid is one note — pitch = miss distance, bright timbre = hazardous

**Output files:**

| File | Size |
|------|------|
| `asteroids_2026-10-10_2026-10-16.csv` | 6.4 KB |
| `asteroids_2026-10-10_2026-10-16.gif` | 3 MB |
| `asteroids_2026-10-10_2026-10-16.wav` | 3.8 MB |

### lagrange

- **Preset:** L4 libration, Sun-Jupiter μ=0.000954, 6 orbital periods
- **Status:** PASS
- **Duration:** 18.4 s
- **Listen for:** l4_audio.wav — pitch follows angular velocity as the test particle librates around Jupiter's L4 Trojan point; pan sweeps with x-position in the co-rotating frame; accent tones mark each closest approach

**Output files:**

| File | Size |
|------|------|
| `l4_audio.wav` | 3.2 MB |
| `l4.gif` | 1.1 MB |
| `l4.png` | 22.8 KB |
| `l4_trajectory.csv` | 103.5 KB |

### resonance

- **Preset:** galilean moons, 4:2:1 Laplace resonance, 8 Ganymede periods
- **Status:** PASS
- **Duration:** 59.4 s
- **Listen for:** galilean_audio.wav — Ganymede plays C3, Europa plays C4, Io plays C5 — a two-octave chord locked in place by gravity for billions of years; count exactly 4 Io notes and 2 Europa notes between each Ganymede note

**Output files:**

| File | Size |
|------|------|
| `galilean_audio.wav` | 9.6 MB |
| `galilean_data.csv` | 38.4 KB |
| `galilean.gif` | 1.4 MB |

### cellular

- **Preset:** Game of Life, R-pentomino (300 generations)
- **Status:** PASS
- **Duration:** 22.7 s
- **Listen for:** Five cells grow chaotically for 300 generations — hear population rise and settle

**Output files:**

| File | Size |
|------|------|
| `life_rpentomino_animation.gif` | 2 MB |
| `life_rpentomino_audio.wav` | 3 MB |
| `life_rpentomino_data.csv` | 3.6 KB |
| `life_rpentomino_stats.csv` | 12.1 KB |

### signal

- **Preset:** chord mode (C major, Fourier analysis + narrative WAV)
- **Status:** PASS
- **Duration:** 55.1 s
- **Listen for:** chord_narrative_full.wav — spoken guide to Fourier analysis; hear the chord buried in noise then recovered by the DFT

**Output files:**

| File | Size |
|------|------|
| `chord_animation.gif` | 3.3 MB |
| `chord_clean.wav` | 258.4 KB |
| `chord_narrative_full.wav` | 3.3 MB |
| `chord_noisy.wav` | 258.4 KB |
| `chord_recovered.wav` | 258.4 KB |
| `chord_recovery.png` | 118.1 KB |
| `chord_spectrum.csv` | 5.1 MB |
| `chord_spectrum.png` | 50 KB |
| `chord_waveform.png` | 125.2 KB |

### waves

- **Preset:** ripple mode, 6 listening points, circular membrane
- **Status:** PASS
- **Duration:** 39.4 s
- **Listen for:** ripple_audio.wav — four wavefront arrivals sweep left-to-right in stereo as the expanding ring reaches each listening point in sequence; reflected waves return from the boundary shortly after

**Output files:**

| File | Size |
|------|------|
| `ripple_audio.wav` | 3.4 MB |
| `ripple_data.csv` | 42.6 KB |
| `ripple.gif` | 467.8 KB |
| `ripple.png` | 95.2 KB |

### fluid

- **Preset:** Karman vortex street, Re=150, Strouhal frequency sonified
- **Status:** PASS
- **Duration:** 23.4 s
- **Listen for:** karman_audio.wav — a steady tone at the Strouhal frequency with clicks alternating 330 Hz / 220 Hz marking each vortex shed from the top and bottom of the cylinder -- the same pitch a wire or flagpole sings in the wind

**Output files:**

| File | Size |
|------|------|
| `karman_audio.wav` | 7.8 MB |
| `karman_data.csv` | 89.1 KB |
| `karman.gif` | 1.4 MB |

### quantum

- **Preset:** QHO coherent state, alpha=3.0 (large amplitude)
- **Status:** PASS
- **Duration:** 160 s
- **Listen for:** Smooth sinusoidal pitch — the quantum wave packet riding the harmonic potential

**Output files:**

| File | Size |
|------|------|
| `qho_audio.wav` | 2.1 MB |
| `qho_density.gif` | 3.4 MB |
| `qho_density.png` | 66.5 KB |
| `qho_timeseries.csv` | 16.2 KB |

### qubit

- **Preset:** rabi mode, continuous Rabi oscillation, Omega=1.5
- **Status:** PASS
- **Duration:** 4.8 s
- **Listen for:** qubit_rabi.wav — a continuously bending pitch tracing P(1)(t) = sin^2(Ωt/2) — the oscillation rate itself made audible, the same driven two-level system quantum/'s own coherent state sonifies from a different angle

**Output files:**

| File | Size |
|------|------|
| `qubit_rabi.csv` | 23.4 KB |
| `qubit_rabi.png` | 69.1 KB |
| `qubit_rabi.wav` | 3.7 MB |

### bell

- **Preset:** chsh mode, derived-optimal angles, S=2*Sqrt[2]
- **Status:** PASS
- **Duration:** 23.9 s
- **Listen for:** bell_chsh.wav — four notes build up the CHSH value term by term, then a sustained two-tone verdict — left holds the classical limit (S=2), right holds the actual measured S (2.83) — the audible gap is Bell's theorem, the result that won the 2022 Nobel Prize in Physics

**Output files:**

| File | Size |
|------|------|
| `bell_chsh.csv` | 231 B |
| `bell_chsh.gif` | 2 MB |
| `bell_chsh.png` | 26.8 KB |
| `bell_chsh.wav` | 3.3 MB |

### grover

- **Preset:** compare mode, N=64, binaural classical vs quantum race
- **Status:** PASS
- **Duration:** 38.9 s
- **Listen for:** grover_compare.wav — a binaural race: left channel ticks through an average-case classical search (32 queries), right channel ticks through Grover's algorithm (6 queries) — both start together, and the right channel's "found" chime rings out long before the left channel finishes, the quantum speedup made literally audible as a difference in time

**Output files:**

| File | Size |
|------|------|
| `grover_compare.csv` | 3.9 KB |
| `grover_compare.gif` | 2.9 MB |
| `grover_compare.png` | 79.6 KB |
| `grover_compare.wav` | 3.5 MB |

### hydrogen

- **Preset:** full emission spectrum, n=2 to n=8, chord then UV-to-IR sweep
- **Status:** PASS
- **Duration:** 45.3 s
- **Listen for:** spectrum_audio.wav — the chord of all 28 lines first, then a sweep from ultraviolet through the four bell-marked Balmer lines (the actual colour of hydrogen) to infrared; the same Rydberg formula behind every hydrogen spectrum ever measured, in any star or lab

**Output files:**

| File | Size |
|------|------|
| `spectrum_audio.wav` | 3.7 MB |
| `spectrum_chord.wav` | 258.4 KB |
| `spectrum_data.csv` | 2.9 KB |
| `spectrum.gif` | 1.3 MB |
| `spectrum_sweep.wav` | 723.6 KB |

### thermo

- **Preset:** Maxwell-Boltzmann distribution sweep, helium, 100K to 1000K
- **Status:** PASS
- **Duration:** 35.1 s
- **Listen for:** The spectrum broadening and rising in pitch as temperature climbs from 100K to 1000K, with a soft triple-tap at each step marking the most probable, mean, and RMS speeds

**Output files:**

| File | Size |
|------|------|
| `distribution_audio.wav` | 5.3 MB |
| `distribution_data.csv` | 7.4 KB |
| `distribution.gif` | 1.1 MB |

### quantum_statistics

- **Preset:** fermi_sea mode, T-0 step function sharpening to blurring
- **Status:** PASS
- **Duration:** 14.2 s
- **Listen for:** quantum_statistics_fermi_sea.wav — the textbook Fermi-Dirac step function, one chord per temperature: a bright, sharply-defined texture at the coldest step, softening into a duller, more even wash of sound as temperature rises and the step blurs — from thermo/'s classical Maxwell-Boltzmann gas to the deeper quantum statistics it is a limiting case of

**Output files:**

| File | Size |
|------|------|
| `quantum_statistics_fermi_sea.csv` | 19.4 KB |
| `quantum_statistics_fermi_sea.gif` | 750.2 KB |
| `quantum_statistics_fermi_sea.png` | 101.9 KB |
| `quantum_statistics_fermi_sea.wav` | 3.8 MB |

### montecarlo

- **Preset:** 2D Ising model sweep, 32x32 lattice, T 4.0 to 0.5
- **Status:** PASS
- **Duration:** 92.8 s
- **Listen for:** The loudest, most turbulent moment of the sweep is the phase transition itself — the system crossing from disordered noise into a steady, high-pitched ferromagnetic tone as it cools through T_c ≃ 2.269

**Output files:**

| File | Size |
|------|------|
| `sweep_audio.wav` | 13.7 MB |
| `sweep_data.csv` | 343.4 KB |
| `sweep.gif` | 3.2 MB |

### magnetic

- **Preset:** magnetic mirror, trapped particle bouncing between reflection points
- **Status:** PASS
- **Duration:** 143 s
- **Listen for:** mirror_audio.wav — pitch rises as the particle approaches each mirror point and falls as it retreats, with a sharp accent at every reflection — the same physics that traps solar-wind particles in Earth's Van Allen belts

**Output files:**

| File | Size |
|------|------|
| `mirror_audio.wav` | 8.1 MB |
| `mirror_data.csv` | 681 KB |
| `mirror.gif` | 3.9 MB |

### scattering

- **Preset:** Rutherford scattering discovery mode, Thomson vs Rutherford binaural comparison
- **Status:** PASS
- **Duration:** 45.1 s
- **Listen for:** discovery_audio.wav — binaural: left channel Thomson (quiet, confined to under one degree), right channel Rutherford (same background plus rare loud backscatter events) — the 1909-1911 experiment that discovered the atomic nucleus

**Output files:**

| File | Size |
|------|------|
| `discovery_audio.wav` | 7.4 MB |
| `discovery_data.csv` | 5.8 KB |
| `discovery.gif` | 2.7 MB |

### primes

- **Preset:** prime gap rhythm, 5000 primes
- **Status:** PASS
- **Duration:** 85.9 s
- **Listen for:** gaps_slow.wav at quarter tempo — twin-prime pairs as double-attacks; large gaps leave audible rests

**Output files:**

| File | Size |
|------|------|
| `gaps_animation.gif` | 2.2 MB |
| `gaps_audio.wav` | 2.5 MB |
| `gaps_slow.wav` | 10.1 MB |
| `gaps_stats.csv` | 128.7 KB |

### bayes

- **Preset:** coin bias inference, theta_true=0.7, 100 flips (uniform prior)
- **Status:** PASS
- **Duration:** 61.2 s
- **Listen for:** coin_audio.wav — the sound begins broad, every bias equally plausible, then narrows to a focused tone as 100 flips accumulate — probability updating made directly audible

**Output files:**

| File | Size |
|------|------|
| `coin_audio.wav` | 6 MB |
| `coin_data.csv` | 6.5 KB |
| `coin.gif` | 2.8 MB |

### images

- **Preset:** brightness mode, 2D Gaussian test image (64x64)
- **Status:** PASS
- **Duration:** 22.8 s
- **Listen for:** A smooth sweep from low pitch (dark edges) to high pitch (bright Gaussian peak) — the Hilbert curve makes spatially adjacent pixels adjacent in time

**Output files:**

| File | Size |
|------|------|
| `images_brightness_audio.wav` | 8.3 MB |
| `images_brightness_data.csv` | 209 KB |
| `images_brightness.gif` | 19 MB |
| `images_brightness.png` | 5.9 KB |

### mandelbrot

- **Preset:** mandelbrot mode, the classic set over the standard window
- **Status:** PASS
- **Duration:** 35.4 s
- **Listen for:** mandelbrot_mandelbrot.wav — the same Hilbert-traversal technique images/ uses, now sonifying escape-iteration count: calm, steady stretches deep inside or far outside the set, giving way to a rapid, chaotic pitch blur right at the boundary — measured, not just asserted, to be over 5 times jumpier than the interior and nearly 58 times jumpier than the exterior

**Output files:**

| File | Size |
|------|------|
| `mandelbrot_mandelbrot.csv` | 183.8 KB |
| `mandelbrot_mandelbrot.gif` | 8.9 MB |
| `mandelbrot_mandelbrot.png` | 21.5 KB |
| `mandelbrot_mandelbrot.wav` | 6.8 MB |

### relativity

- **Preset:** GW150914 chirp, 36+29 solar masses, 4x time stretch
- **Status:** PASS
- **Duration:** 119.4 s
- **Listen for:** chirp.wav — rising pitch and amplitude, abrupt merger, fading ringdown; this is what LIGO heard on 14 September 2015

**Output files:**

| File | Size |
|------|------|
| `chirp.gif` | 1.8 MB |
| `chirp.png` | 95.7 KB |
| `chirp_timeseries.csv` | 27.5 KB |
| `chirp.wav` | 308.4 KB |
| `gw150914.wav` | 308.4 KB |
| `gw170817.wav` | 1.3 MB |
| `stellar.wav` | 2.4 MB |

### cosmology

- **Preset:** CMB acoustic peaks, spectrum mode, simulated LCDM
- **Status:** PASS
- **Duration:** 5.7 s
- **Listen for:** cmb_spectrum_audio.wav — hear the Sachs-Wolfe plateau give way to the first acoustic peak swell at l≃220, then the second and third harmonics fading into the Silk damping tail

**Output files:**

| File | Size |
|------|------|
| `cmb_spectrum_audio.wav` | 4.2 MB |
| `cmb_spectrum_data.csv` | 89.8 KB |
| `cmb_spectrum.png` | 58.5 KB |

### blackbody

- **Preset:** Planck spectrum, solar T=5778K, chord then radio-to-X-ray sweep
- **Status:** PASS
- **Duration:** 72.7 s
- **Listen for:** spectrum_audio.wav — the full radio-to-X-ray curve as a single chord, two soft taps marking the narrow visible-light window, then a sweep through the same curve one bin at a time — notice how briefly the taps land relative to the whole sweep

**Output files:**

| File | Size |
|------|------|
| `spectrum_audio.wav` | 7.1 MB |
| `spectrum_data.csv` | 4.8 KB |
| `spectrum.gif` | 2.1 MB |
| `spectrum.png` | 43.2 KB |

### compton

- **Preset:** Compton scattering, discovery mode, Thomson vs Compton binaural
- **Status:** PASS
- **Duration:** 12.9 s
- **Listen for:** discovery_audio.wav — binaural: left channel Thomson (flat, no shift at any angle), right channel Compton (pitch measurably drops as angle increases) — the 1923 measurement that decided the wave/particle debate

**Output files:**

| File | Size |
|------|------|
| `discovery_audio.wav` | 7.4 MB |
| `discovery_data.csv` | 4 KB |
| `discovery.png` | 68.5 KB |

### quantum_tunnelling

- **Preset:** barrier, default preset, electron at 1eV vs a 2eV barrier
- **Status:** PASS
- **Duration:** 17.7 s
- **Listen for:** barrier_audio.wav — incoming tone, a marker click at the barrier, then a reflected tone and a transmitted tone sounding simultaneously, loud in proportion to probability — a classically impossible crossing, made audible

**Output files:**

| File | Size |
|------|------|
| `barrier_audio.wav` | 7.9 MB |
| `barrier_data.csv` | 138 B |
| `barrier.gif` | 311.5 KB |
| `barrier.png` | 18.9 KB |

### clt

- **Preset:** dice mode, sum of up to 10 fair six-sided dice
- **Status:** PASS
- **Duration:** 11.4 s
- **Listen for:** dice_audio.wav — a single die's flat, jagged, six-outcome sound smoothing into an unmistakable bell shape purely from summing more dice — the Central Limit Theorem's most recognisable illustration

**Output files:**

| File | Size |
|------|------|
| `dice_audio.wav` | 4 MB |
| `dice_data.csv` | 4.7 KB |
| `dice.gif` | 296.8 KB |
| `dice.png` | 41.6 KB |

### brownian

- **Preset:** ensemble mode, 150 walkers, sqrt(t) law
- **Status:** PASS
- **Duration:** 11.8 s
- **Listen for:** brownian_ensemble.wav — a single rising tone tracking the ensemble's average distance from the origin, its climb visibly slowing over time — displacement growing as the square root of time, not linearly, the same running-sum-of-random-steps setup as clt/, here embodied in real 2D space

**Output files:**

| File | Size |
|------|------|
| `brownian_ensemble.csv` | 253.5 KB |
| `brownian_ensemble.png` | 209.4 KB |
| `brownian_ensemble.wav` | 5.8 MB |

## Audio Guide

All audio files are in `demo/<app>/output/`. The commands below are for Linux, the platform this report was made on; run them from the repository root, in an interactive desktop session (audio does not play over SSH).

- macOS: `afplay demo/<app>/output/<file>.wav`
- Linux: `aplay demo/<app>/output/<file>.wav`
- Windows PowerShell: `(New-Object Media.SoundPlayer "$PWD\demo\<app>\output\<file>.wav").PlaySync()`

```sh
aplay demo/pendulum/output/double_audio.wav
aplay demo/lorenz/output/rossler_audio.wav
aplay demo/dynamical/output/sweep_audio.wav
aplay demo/dynamical/output/iterate_period3_window_audio.wav
aplay demo/henon/output/henon_attractor.wav
aplay demo/asteroids/output/asteroids_2026-10-10_2026-10-16.wav
aplay demo/lagrange/output/l4_audio.wav
aplay demo/resonance/output/galilean_audio.wav
aplay demo/cellular/output/life_rpentomino_audio.wav
aplay demo/signal/output/chord_clean.wav
aplay demo/signal/output/chord_narrative_full.wav
aplay demo/signal/output/chord_noisy.wav
aplay demo/signal/output/chord_recovered.wav
aplay demo/waves/output/ripple_audio.wav
aplay demo/fluid/output/karman_audio.wav
aplay demo/quantum/output/qho_audio.wav
aplay demo/qubit/output/qubit_rabi.wav
aplay demo/bell/output/bell_chsh.wav
aplay demo/grover/output/grover_compare.wav
aplay demo/hydrogen/output/spectrum_audio.wav
aplay demo/hydrogen/output/spectrum_chord.wav
aplay demo/hydrogen/output/spectrum_sweep.wav
aplay demo/thermo/output/distribution_audio.wav
aplay demo/quantum_statistics/output/quantum_statistics_fermi_sea.wav
aplay demo/montecarlo/output/sweep_audio.wav
aplay demo/magnetic/output/mirror_audio.wav
aplay demo/scattering/output/discovery_audio.wav
aplay demo/primes/output/gaps_audio.wav
aplay demo/primes/output/gaps_slow.wav
aplay demo/bayes/output/coin_audio.wav
aplay demo/images/output/images_brightness_audio.wav
aplay demo/mandelbrot/output/mandelbrot_mandelbrot.wav
aplay demo/relativity/output/chirp.wav
aplay demo/relativity/output/gw150914.wav
aplay demo/relativity/output/gw170817.wav
aplay demo/relativity/output/stellar.wav
aplay demo/cosmology/output/cmb_spectrum_audio.wav
aplay demo/blackbody/output/spectrum_audio.wav
aplay demo/compton/output/discovery_audio.wav
aplay demo/quantum_tunnelling/output/barrier_audio.wav
aplay demo/clt/output/dice_audio.wav
aplay demo/brownian/output/brownian_ensemble.wav
```

### Most interesting file per app

- **pendulum**: Two bobs in binaural stereo — hear chaotic divergence between channels
- **lorenz**: Melodic chaos — smoother than Lorenz, almost improvisational but never repeating
- **dynamical**: The rhythm doubling at r=3, doubling again, dissolving into chaos near r=3.57, then a surprising return to a clean three-note rhythm at the period-3 window near r=3.83
- **dynamical**: A clean, repeating three-note rhythm — the period-3 window, a surprising island of order inside the chaotic region, heard here by iterating the map at a single fixed r rather than sweeping through it
- **henon**: The Hénon map's strange attractor — Michel Hénon's simplified model of a Poincaré section through the Lorenz attractor. Pan tracks x, pitch tracks y, and accent tones mark each turning point where the trajectory folds back on itself
- **asteroids**: Each asteroid is one note — pitch = miss distance, bright timbre = hazardous
- **lagrange**: l4_audio.wav — pitch follows angular velocity as the test particle librates around Jupiter's L4 Trojan point; pan sweeps with x-position in the co-rotating frame; accent tones mark each closest approach
- **resonance**: galilean_audio.wav — Ganymede plays C3, Europa plays C4, Io plays C5 — a two-octave chord locked in place by gravity for billions of years; count exactly 4 Io notes and 2 Europa notes between each Ganymede note
- **cellular**: Five cells grow chaotically for 300 generations — hear population rise and settle
- **signal**: chord_narrative_full.wav — spoken guide to Fourier analysis; hear the chord buried in noise then recovered by the DFT
- **waves**: ripple_audio.wav — four wavefront arrivals sweep left-to-right in stereo as the expanding ring reaches each listening point in sequence; reflected waves return from the boundary shortly after
- **fluid**: karman_audio.wav — a steady tone at the Strouhal frequency with clicks alternating 330 Hz / 220 Hz marking each vortex shed from the top and bottom of the cylinder -- the same pitch a wire or flagpole sings in the wind
- **quantum**: Smooth sinusoidal pitch — the quantum wave packet riding the harmonic potential
- **qubit**: qubit_rabi.wav — a continuously bending pitch tracing P(1)(t) = sin^2(Ωt/2) — the oscillation rate itself made audible, the same driven two-level system quantum/'s own coherent state sonifies from a different angle
- **bell**: bell_chsh.wav — four notes build up the CHSH value term by term, then a sustained two-tone verdict — left holds the classical limit (S=2), right holds the actual measured S (2.83) — the audible gap is Bell's theorem, the result that won the 2022 Nobel Prize in Physics
- **grover**: grover_compare.wav — a binaural race: left channel ticks through an average-case classical search (32 queries), right channel ticks through Grover's algorithm (6 queries) — both start together, and the right channel's "found" chime rings out long before the left channel finishes, the quantum speedup made literally audible as a difference in time
- **hydrogen**: spectrum_audio.wav — the chord of all 28 lines first, then a sweep from ultraviolet through the four bell-marked Balmer lines (the actual colour of hydrogen) to infrared; the same Rydberg formula behind every hydrogen spectrum ever measured, in any star or lab
- **thermo**: The spectrum broadening and rising in pitch as temperature climbs from 100K to 1000K, with a soft triple-tap at each step marking the most probable, mean, and RMS speeds
- **quantum_statistics**: quantum_statistics_fermi_sea.wav — the textbook Fermi-Dirac step function, one chord per temperature: a bright, sharply-defined texture at the coldest step, softening into a duller, more even wash of sound as temperature rises and the step blurs — from thermo/'s classical Maxwell-Boltzmann gas to the deeper quantum statistics it is a limiting case of
- **montecarlo**: The loudest, most turbulent moment of the sweep is the phase transition itself — the system crossing from disordered noise into a steady, high-pitched ferromagnetic tone as it cools through T_c ≃ 2.269
- **magnetic**: mirror_audio.wav — pitch rises as the particle approaches each mirror point and falls as it retreats, with a sharp accent at every reflection — the same physics that traps solar-wind particles in Earth's Van Allen belts
- **scattering**: discovery_audio.wav — binaural: left channel Thomson (quiet, confined to under one degree), right channel Rutherford (same background plus rare loud backscatter events) — the 1909-1911 experiment that discovered the atomic nucleus
- **primes**: gaps_slow.wav at quarter tempo — twin-prime pairs as double-attacks; large gaps leave audible rests
- **bayes**: coin_audio.wav — the sound begins broad, every bias equally plausible, then narrows to a focused tone as 100 flips accumulate — probability updating made directly audible
- **images**: A smooth sweep from low pitch (dark edges) to high pitch (bright Gaussian peak) — the Hilbert curve makes spatially adjacent pixels adjacent in time
- **mandelbrot**: mandelbrot_mandelbrot.wav — the same Hilbert-traversal technique images/ uses, now sonifying escape-iteration count: calm, steady stretches deep inside or far outside the set, giving way to a rapid, chaotic pitch blur right at the boundary — measured, not just asserted, to be over 5 times jumpier than the interior and nearly 58 times jumpier than the exterior
- **relativity**: chirp.wav — rising pitch and amplitude, abrupt merger, fading ringdown; this is what LIGO heard on 14 September 2015
- **cosmology**: cmb_spectrum_audio.wav — hear the Sachs-Wolfe plateau give way to the first acoustic peak swell at l≃220, then the second and third harmonics fading into the Silk damping tail
- **blackbody**: spectrum_audio.wav — the full radio-to-X-ray curve as a single chord, two soft taps marking the narrow visible-light window, then a sweep through the same curve one bin at a time — notice how briefly the taps land relative to the whole sweep
- **compton**: discovery_audio.wav — binaural: left channel Thomson (flat, no shift at any angle), right channel Compton (pitch measurably drops as angle increases) — the 1923 measurement that decided the wave/particle debate
- **quantum_tunnelling**: barrier_audio.wav — incoming tone, a marker click at the barrier, then a reflected tone and a transmitted tone sounding simultaneously, loud in proportion to probability — a classically impossible crossing, made audible
- **clt**: dice_audio.wav — a single die's flat, jagged, six-outcome sound smoothing into an unmistakable bell shape purely from summing more dice — the Central Limit Theorem's most recognisable illustration
- **brownian**: brownian_ensemble.wav — a single rising tone tracking the ensemble's average distance from the origin, its climb visibly slowing over time — displacement growing as the square root of time, not linearly, the same running-sum-of-random-steps setup as clt/, here embodied in real 2D space

## Re-running

```sh
wolframscript -file demo.wl                                    # full run
# macOS / Linux:
NASA_API_KEY=$NASA_API_KEY wolframscript -file demo.wl         # with asteroids
# Windows PowerShell:
# $env:NASA_API_KEY='your_key'; wolframscript -file demo.wl
wolframscript -file demo.wl -- --check-only                    # verify outputs
```
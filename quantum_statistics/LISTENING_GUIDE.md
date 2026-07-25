# Listening Guide — Bose-Einstein, Fermi-Dirac, Maxwell-Boltzmann

## Recommended listening sequence

Follow this order to hear the quantum/classical bridge from three
complementary angles: three distributions compared at one temperature,
the same three swept across temperature, and Fermi-Dirac's own step
function sharpening and blurring.

1. **`spectrum`** (default): three simultaneous voices — Bose-Einstein
   low and hard left, Fermi-Dirac centred, Maxwell-Boltzmann high and
   hard right — all tracing the same energy sweep at once. Listen for
   how closely the three voices track each other through most of the
   sweep, and where (near the low-energy end) Bose-Einstein's voice
   pulls away.
2. **`temperature`**: the same three voices, now swept continuously
   over temperature instead of energy. Listen for all three converging
   quietly at low temperature, then Bose-Einstein growing loud and
   pulling away as temperature rises.
3. **`fermi_sea`**: one chord per temperature step, coldest to warmest.
   Listen for a bright, sharply-defined texture at the start (the
   step function) smoothing into a duller, more even texture by the
   end (the step blurred out).

```sh
wolframscript -file main.wl
wolframscript -file main.wl -- --simulation.mode=temperature
wolframscript -file main.wl -- --simulation.mode=fermi_sea
```

## Why `spectrum` mode's three voices are simultaneous, not sequential

The whole question this mode poses — "at this temperature, are the
three distributions similar or different?" — can only really be
answered by hearing all three at the same instant. A one-at-a-time
tour would only let you compare against memory of what you heard a
few seconds ago. Panning them to three different stereo positions
(and giving each its own pitch register) lets your ear track all
three threads independently, the same way you can follow three
instruments in a chord.

## Why `temperature` mode gets LOUDER as temperature rises, not quieter

This might be the opposite of what you'd expect from "cold and quiet,
hot and loud" intuition about physical systems generally — but it's
the verified, correct behaviour for this specific setup (chemical
potential fixed at zero, matching a photon or phonon gas). At low
temperature, all three distributions collapse together toward silence
(few particles, dilute, classical-looking). At high temperature,
Bose-Einstein's occupation number genuinely grows without bound —
loud is correct. See `AGENTS.md` design decision 3 if you want the
full derivation of why this direction, and not the more commonly
quoted "cold=quantum" story, is the right one here.

## Why `fermi_sea` mode sounds "cleaner" at the start and "muddier" at the end

The coldest temperature step produces a chord built from a nearly
binary spectral shape — bins below the Fermi energy are all close to
full amplitude, bins above are all close to silent, a sharp on/off
pattern that sounds clean and defined. As temperature rises, that
sharp on/off pattern smooths into a gradual ramp, so the chord's
energy spreads more evenly across all the bins — audibly less
"defined," more like a single wash of sound. That textural change
IS the Fermi step blurring.

## Tips for listening

- Use headphones — `spectrum` and `temperature` modes both rely on
  genuine three-way stereo separation to keep the three voices
  distinguishable.
- Try `--simulation.quantum_statistics.temperature=30000` in spectrum
  mode for a much hotter gas — Bose-Einstein's divergence near the
  low-energy end becomes dramatically more pronounced.
- Try `--simulation.quantum_statistics.temperature=10` in spectrum
  mode for a very cold gas — almost everything collapses to silence
  except right at the start of the sweep.
- Try `--simulation.quantum_statistics.reference_energy=3.0` in
  fermi_sea mode for a Fermi energy closer to a real metal's
  conduction-electron scale.
- `output/quantum_statistics_temperature.png` labels the converge/
  diverge directions directly on the plot — worth viewing alongside
  listening if the audible loudness change is surprising at first.

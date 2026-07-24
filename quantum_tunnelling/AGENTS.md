# Quantum Tunnelling — Agent Guide

## Project overview

Sonifies quantum tunnelling: the nonzero probability a particle appears
on the far side of a potential barrier it classically cannot cross.
Three modes:

| Mode | Physics | Output |
|------|---------|--------|
| `barrier` (default) | Single event at a configured/preset (E, V0, L, mass) | Narrated stereo WAV; animated diagram GIF; static PNG |
| `sweep` | Barrier-width sweep, fixed E<V0 (tunnelling only) | Fading-tone WAV; animated `T` vs `L` GIF (log-y); static PNG |
| `energy` | Particle-energy sweep across V0, both regimes | Wobbling-tone WAV; animated `T` vs `E` GIF; static PNG |

Closest sibling apps: `quantum/` (the same exactly-solvable-QM domain;
its `BoxModel`'s standing-wave energy quantization is the *same*
condition as this app's `energy`-mode resonance — see design decision 3),
`hydrogen/` (the other exact-QM app in this codebase), and `compton/`
(`barrier` mode directly reuses its `scatter` mode's discrete-narrated-
event idiom, and its diagnostic-only correctness-check convention).

## Key design decisions (read before modifying sonify.wl or model.wl)

### 1. `kappa`/`k` is one generic function, not two separately-derived formulas

`KOrKappaPerNm[mc2, deltaE] = Sqrt[2*mc2*Abs[deltaE]]/hbarc` is used by
BOTH the `E<V0` (`kappa`) and `E>V0` (`k`) branches of
`TransmissionCoefficient` — only the sign of `deltaE` (and therefore
whether the caller applies `Sinh` or `Sin`) differs between them. This
mirrors `blackbody/AGENTS.md` design decision 1's "derive, don't
duplicate" principle for the Compton wavelength: a single formula that
every consumer (both regimes, all three presets, every mode) reuses,
rather than two independently-typed-out expressions that could quietly
diverge from each other if one is edited and the other is not.

### 2. `TransmissionCoefficient` evaluates the E=V0 limit analytically, not by nudging away from it

At `E=V0` exactly, both the `E<V0` and `E>V0` branches individually hit
a `0/0` form (`Sinh[0]^2/0` or `Sin[0]^2/0`) — a genuine **removable
singularity** in the formula itself, not a floating-point precision
artifact to route around (contrast design decision 4 below, and
`blackbody/AGENTS.md` design decision 4's Rayleigh-Jeans check, both of
which ARE pure precision issues). The function detects `|E-V0|` below a
relative threshold and evaluates the analytic limit directly:
`T(E->V0) = 1/(1 + mc2*V0*L^2/(2*hbarc^2))` (derived by expanding
`Sinh[kappa*L] ~ kappa*L` for small `kappa*L` and substituting
`kappa^2 = 2*mc2*(V0-E)/hbarc^2`). This matters in practice: `energy`
mode's swept `EArr` can legitimately land a step at (or extremely close
to) `V0` depending on the chosen bounds and `n_steps`, and evaluating
the naive branch formula there would produce `Indeterminate` or a wildly
wrong value from catastrophic cancellation in the surrounding
arithmetic, not just a warning.

### 3. `energy` mode's resonance condition IS `quantum/`'s particle-in-a-box quantization

`k*L = n*Pi` (this app's perfect-transmission condition) and
`quantum/`'s `BoxModel` eigenstate condition (`E_n = n^2*Pi^2/(2*L^2)`,
which comes from requiring `k*L = n*Pi` for the box's own wavenumber
`k = Sqrt[2*E]`, in `hbar=m=1` units) are the identical standing-wave
requirement — a wave fitting a whole number of half-wavelengths across
a fixed length interferes constructively with itself, whether that
length is a box the particle is trapped inside (`quantum/box`) or a
barrier the particle passes through and beyond (this app). The
difference is what the condition determines: in `quantum/box`, it
selects which energies exist at all; here, the particle can have any
energy, and the condition instead picks out which *specific* energies
happen to make an otherwise-partially-reflecting barrier perfectly
transparent. Do not describe this as merely "a similar formula" in any
future documentation — it is the same physics, not an analogy, and
`ResonanceConditionCheck` (design decision 5) is built around that fact.

### 4. `RayleighJeans`-style precision issues do not appear here, and here is why

`blackbody/`'s Rayleigh-Jeans check needed a dimensionless-`x`
reparametrisation specifically because `Exp[x]-1` loses precision to
catastrophic cancellation for small `x`. `TransmissionCoefficient` has
no equivalent `Exp[x]-1` construction anywhere — `Sinh`/`Sin` of a
genuinely small argument are computed directly by WL to full double
precision (no leading `1+` to cancel against), so `LToZeroLimitCheck`
can safely test at `L=1e-9` with no special numerical handling. The
only removable-singularity concern in this app is the `E=V0` case
(design decision 2), which is a different failure mode (both numerator
AND denominator vanish together) requiring an actual analytic limit,
not a reparametrisation trick.

### 5. `ResonanceConditionCheck` is the single most important correctness check in this app

It is also the LEAST likely of the four checks to pass by accident if
the `E>V0` branch has a sign or formula error: `LToZeroLimitCheck` and
`DeepTunnelingAsymptoticCheck` both primarily exercise the `E<V0`
branch (only `LToZeroLimitCheck` touches `E>V0` at all, and only in the
trivial `L->0` corner where `Sin[kappa*L]^2` and `Sinh[kappa*L]^2` both
vanish the same way, masking a sign error that would only show up at a
nonzero `L`). `ProbabilityConservationCheck` is defined via `R=1-T`, so
it cannot independently catch a wrong `T` formula either — it verifies
internal consistency, not correctness against an external reference.
`ResonanceConditionCheck` solves for a specific nonzero `L`
independently (from the target condition `k*L=Pi`, not from
`TransmissionCoefficient` itself) and checks that plugging it back in
gives exactly `T=1` — the one check that would actually fail if, say,
`Sin` and `Sinh` were accidentally swapped between the two branches, or
if the `E-V0` vs. `V0-E` sign were wrong in the `k`/`kappa` argument.
Verify this check passes with particular care after touching either
branch of `TransmissionCoefficient`.

### 6. `barrier` mode's reflected and transmitted tones sound SIMULTANEOUSLY, not as alternatives

An earlier design considered randomly choosing "reflected" or
"transmitted" per run (weighted by `R`/`T`, like a coin flip) to
simulate a single measurement outcome. This was rejected: tunnelling's
physical content is the SPLIT itself — both outcomes genuinely coexist
in the same measurement statistics (or, equivalently, in the same
particle's wavefunction, which has nonzero amplitude on both sides at
once) — and sonifying a single random draw would hide exactly the fact
worth hearing. Both tones are synthesised over the same duration and
summed into the stereo buffer, not sequenced or chosen between; see the
build spec's explicit note that this is not a coin flip on any one run.

### 7. Reflected/transmitted pan convention: hard left/hard right, and why it does not need compton's fix

`compton/AGENTS.md` design decision 8 documents a real bug: a computed
recoil angle silently used the wrong sign, contradicting its own
docstring, caught only by careful review. This app's equivalent
left/right assignment (reflected panned hard left at `-1.0`,
transmitted panned hard right at `+1.0`) has no analogous sign
ambiguity to get wrong: `PanBuffer[mono, pan]` is called with two fixed
LITERAL constants (`-1.0` and `1.0`), not with a computed angle whose
sign could be inverted by an upstream formula error. There is nothing
here for a sign bug to hide in — the convention itself, not a derived
quantity, IS the pan value. If a future mode computes a pan value from
some other physical quantity (rather than using a fixed literal), apply
the same scrutiny `compton/AGENTS.md` design decision 8 describes:
verify the sign convention is documented AND matches what the code
actually does, in both `sonify.wl` and `animate.wl` alike (this app's
diagram in `animate.wl` independently reproduces the same left=reflected,
right=transmitted convention — verified by inspection to agree with
`sonify.wl`, not assumed).

### 8. `sweep` and `energy` modes use different loudness compression, and this is not an inconsistency

`sweep` mode's `T` falls off *exponentially* with the swept variable
(`L`) across many orders of magnitude — the same "needs log
compression to stay perceptible across a whole sweep" problem
`blackbody/`'s Stefan-Boltzmann loudness solves, cited directly in
`sonify.wl`. `energy` mode's `T` stays within `[0,1]` throughout,
including the above-barrier resonance wobble (which is itself the
point of that mode — it must NOT be smoothed or compressed away, per
the build spec) — a plain `Sqrt[T]` already handles that range
correctly. Applying `sweep`'s log-compression scheme to `energy` mode
would flatten the resonance wobble's audible contrast for no reason;
applying `energy`'s plain `Sqrt[T]` to `sweep` mode would make the
sound drop to near-silence almost immediately rather than fading
gradually. Each mode's choice is deliberate and matched to that mode's
own dynamic range, not an accidental divergence between two files that
should agree.

### 9. Preset-vs-manual precedence mirrors `scattering/`'s pattern, with one difference

`scattering/main.wl`'s preset resolution defaults `preset` to `""`
(empty string, meaning "no preset selected, use whatever `b` is
configured") and overrides `b` via `DeepMerge` only when a named preset
is given. This app's `preset` instead defaults to `"default"` — a real,
always-active preset — because the build spec calls for `barrier` mode
to have sensible behaviour with zero configuration at all. `"manual"`
(or any other unrecognised string) is the sentinel a user opts INTO,
functionally equivalent to `scattering/`'s empty-string default but
inverted: here, the "ignore the preset table, read the manual fields"
behaviour is the non-default path, not the default one.

## Project structure

```
quantum_tunnelling/
  main.wl              — thin orchestrator: config, correctness checks, mode dispatch
  config.json          — default simulation parameters
  experiments.wl        — 6 curated preset invocations (3 named presets + manual,
                          barrier-width sweep, two energy sweeps of different width)
  LISTENING_GUIDE.md     — user-facing recommended listening sequence
  AGENTS.md               — this file
  src/
    model.wl              — KOrKappaPerNm, TransmissionCoefficient (both regimes +
                            E=V0 limit), ReflectionCoefficient, correctness checks 1-4,
                            $TunnellingPresets, TunnellingPitchHz, BarrierModel/
                            SweepModel/EnergyModel
    sonify.wl                — TunnellingAccentBurst, PanBuffer, BuildBarrierAudio
                            (discrete events), BuildSweepAudio/BuildEnergyAudio
                            (continuous phase accumulation)
    speech.wl                 — Spoken intro/outro synthesis (SpeechSynthesize -> platform
                            TTS -> text-only fallback), BuildXIntroText per mode
    animate.wl                  — BarrierDiagramGraphics (shared GIF/PNG), per-mode
                            Render*/Animate* functions
    output.wl                    — Export*CSV per mode, Print*Summary per mode
  tests/
    test_model.wl              — unit tests (limits, resonance at n=1 and n=2,
                            conservation, presets, constants, pitch mapping)
  output/                     — generated files (gitignored)
```

## How to run

```sh
wolframscript -file main.wl                                                     # barrier, default preset
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=stm
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=alpha_decay
wolframscript -file main.wl -- --simulation.mode=sweep                          # barrier-width sweep
wolframscript -file main.wl -- --simulation.mode=energy                         # energy sweep, crosses V0
wolframscript -file main.wl -- --simulation.quantum_tunnelling.preset=manual \
                                --simulation.quantum_tunnelling.energy_ev=1.5
wolframscript -file main.wl -- --config-dump

wolframscript -file tests/test_model.wl
wolframscript -file experiments.wl
```

## Correctness checks

All four run unconditionally, every invocation, regardless of mode.
None of them abort on failure — every check here evaluates a
closed-form expression at a hand-picked test point rather than
inspecting the runtime health of a numerical integration, so a hard
gate would only ever catch a code bug that a unit test already catches
at development time. This is the SAME reasoning `compton/AGENTS.md`
design decision 6 and `blackbody/AGENTS.md` design decision 3 give —
not a blanket "no app in this codebase aborts" claim: `relativity/`'s
chirp mode genuinely does call `Exit[1]` when its numerically-solved
frequency/amplitude arrays fail a monotonicity check
(`relativity/src/model.wl`'s `fMono`/`aMono` gate), because THAT check
is testing whether a specific run's integration behaved correctly at
runtime — a materially different kind of check from any of the four
below.

1. **L → 0 limit** — `T -> 1` for both regimes at `L=1e-9` nm.
2. **Deep-tunnelling asymptotic** — exact `T` matches
   `16*(E/V0)*(1-E/V0)*Exp[-2*kappa*L]` within 0.1% at `kappa*L=20`.
3. **Resonance condition** — `T=1` to within `1e-9` at the barrier width
   solving `k*L=Pi` for a test `E=3` eV, `V0=2` eV. See design decision 5
   for why this is the check to scrutinise most carefully.
4. **Probability conservation** — `T+R=1` to `1e-12` at five
   `(E,V0,L,mass)` points, including one at `E=V0` exactly (design
   decision 2's removable singularity).

## Common pitfalls

1. **`gamma_?NumericQ : 1.0` in function signatures is broken syntax**
   — parses as `gamma_?(NumericQ : 1.0)`, a pattern that never matches.
   Always use `Optional[gamma_?NumericQ, 1.0]` instead (same pitfall
   documented in `blackbody/AGENTS.md` and `compton/AGENTS.md`).
2. **`\[SubZero]` is not a valid WL unicode long name.** An earlier
   draft of `animate.wl` used `"V\[SubZero]="` to label the barrier
   height, intending a visual subscript-zero; WL's tokeniser rejects
   any unrecognised `\[...]` name with `Syntax::sntufn` at parse time
   (caught immediately on first run — the whole script fails to load,
   not just the affected line). Plain ASCII (`"V0="`) is what every
   other label in this app's diagrams actually uses; there is no
   working built-in subscript-zero long name to reach for instead.
3. **A stray `*)` inside a prose comment silently truncates it** — see
   `blackbody/AGENTS.md`'s pitfall 2 and `compton/AGENTS.md`'s pitfall 2
   for the mechanism (a variable name ending in an implied
   multiplication, immediately followed by a closing paren in prose,
   reads as the comment's own `*)`). Checked for and avoided throughout
   this app's comments.
4. **Bare `Graphics[...]` needs an explicit `AspectRatio`** whenever the
   plotted data's x:y range ratio is extreme — `compton/AGENTS.md`
   pitfall 4 documents this being discovered the hard way (a squished,
   unreadable plot, only caught by actually rendering and viewing the
   PNG). Every curve plot in this app's `animate.wl` sets
   `AspectRatio -> 0.5` explicitly from the start, learned from that
   prior incident rather than repeating it.
5. **Dashed "guide line" endpoints must match the actual arrow
   endpoints' coordinates, not a placeholder.** An early draft of
   `BarrierDiagramGraphics` defined `incomingStart`/`reflectedEnd`/
   `transmittedEnd` at `y=0.0` while the actual incoming/reflected/
   transmitted arrows are drawn at `y=yE=0.3` — caught by rendering the
   PNG and seeing an obviously wrong diagonal dashed line where a
   horizontal one was intended. Any coordinate used by more than one
   graphics primitive in the same figure should be defined once (or
   verified to agree) rather than typed out twice at two different,
   silently-inconsistent values.

## Dependencies

- **stem-core**: `init.wl`, `LoadConfig`, `GetCfg`, `DeepMerge`,
  `STEMHeading`, `STEMSection`, `STEMSay`, `STEMPrintN`,
  `STEMDescribeWAV`, `STEMDescribeGIF`, `STEMDescribeCSV`, `FmtN`,
  `STEMPlayCmd`, `NormalizeBuffer`, `ExportAudioBuffer`, `ExportGIF`,
  `ExportCSV`, `EnsureDir`, `StemSynthNote` (all discrete-note
  synthesis: `barrier`'s incoming/reflected/transmitted tones).
  Deliberately **not** used: `SonifyTrajectory`, `SpatialLayer`,
  `MotionLayer`, `EventLayer`, `MixLayers`, `RenderAudio`, `ScaleLookup`
  — there is no trajectory in this app to feed them (same reasoning as
  `compton/AGENTS.md` design decision on its own dependency list: a
  scattering-angle- or barrier-crossing-probability formula is not a
  trajectory).
- **Mathematica/WL**: `Accumulate` (continuous phase for `sweep`/
  `energy`), `Sound`, `SampledSoundList`, `Graphics`, `Export`,
  `SpeechSynthesize`, `AudioQ`, `AudioData`, `AudioSampleRate`,
  `RunProcess` (platform TTS fallback), `Import` (reading
  TTS-generated WAV files).

## Speech synthesis note

`speech.wl`'s three-tier fallback (`SpeechSynthesize[]` -> platform TTS
-> text-only `STEMSay`) duplicates the pattern in `compton/src/speech.wl`,
`blackbody/src/speech.wl`, and `thermo/src/speech.wl` — now a seventh
independent copy, still out of scope for stem-core consolidation per
every prior app's own build spec.

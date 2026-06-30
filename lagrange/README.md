# Lagrange Points

Simulates and sonifies test-particle motion in the circular restricted three-body
problem (CR3BP), making the stability and instability of the five Lagrange points
audible.

## The physics: the co-rotating frame

Two massive bodies — a primary (e.g. the Sun) and a secondary (e.g. Jupiter) —
orbit their common centre of mass in a circle.  If you watch from a frame that
rotates at the same rate as the two bodies orbit, the primaries appear stationary.
A third, massless test particle moving in this frame experiences three forces:

1. Gravity from the large primary (at `(−μ, 0)`)
2. Gravity from the small primary (at `(1−μ, 0)`)
3. Fictitious forces: the centrifugal force (pushes outward from the rotation axis)
   and the Coriolis force (deflects moving particles perpendicular to their velocity)

The **mass parameter** `μ = m₂/(m₁+m₂)` is the fractional mass of the smaller
body.  All lengths are in units of the primary separation; the total mass is 1;
the angular velocity is 1 (one orbital period = 2π time units).

The combined effective potential `Ω(x,y)` has five saddle points and two maxima,
the **Lagrange points** L1–L5.  Only L4 and L5 (the equilateral triangle points)
are linearly stable — and only when `μ < 0.0385` (Routh's criterion).

## Equations of motion

In Cartesian co-rotating coordinates (x, y):

```
x'' − 2y' = x − (1−μ)(x+μ)/r₁³ − μ(x−1+μ)/r₂³
y'' + 2x' = y − (1−μ)y/r₁³ − μ y/r₂³

r₁ = distance to primary 1 = √((x+μ)² + y²)
r₂ = distance to primary 2 = √((x−1+μ)² + y²)
```

The `−2y'` and `+2x'` terms are the Coriolis acceleration; the `x` and `y`
terms are the centrifugal acceleration.

## Lagrange point positions

| Point | Location | Stability |
|-------|----------|-----------|
| L1 | Between the primaries on the x-axis | Unstable (saddle) |
| L2 | Beyond the small primary on the x-axis | Unstable (saddle) |
| L3 | Opposite the small primary on the x-axis | Unstable (saddle) |
| L4 | Leading triangle vertex `(½−μ, √3/2)` | Stable if μ < 0.0385 |
| L5 | Trailing triangle vertex `(½−μ, −√3/2)` | Stable if μ < 0.0385 |

L1/L2/L3 are found numerically via `FindRoot` on `∂Ω/∂x = 0` at `y=0`.
L4 and L5 are exact: each forms an equilateral triangle with both primaries.

## The Jacobi constant

The only conserved quantity in the CR3BP is the **Jacobi constant**:

```
C_J = x² + y² + 2(1−μ)/r₁ + 2μ/r₂ − (ẋ² + ẏ²)
```

`C_J` is constant along any trajectory (analogous to energy in a rotating frame).
The app measures the fractional drift in `C_J` as a numerical sanity check —
values below 0.5% confirm the integrator is working correctly.

## Real-world examples: Trojan asteroids

Jupiter's L4 and L5 points are home to the **Trojan asteroids** — over 10,000
objects librating around these stable equilibria.  The L4 group leads Jupiter in
its orbit (the "Greek camp"); the L5 group trails it (the "Trojan camp").  Their
stability is guaranteed by μ_Jupiter = 0.000954 << 0.0385.

The L1 point (between the Sun and Jupiter) has no permanent residents; any object
placed there escapes within a few orbital periods, exactly as this app sonifies.

## Sonification design

Each mode maps the trajectory to audio through three channels:

- **Stereo pan** — x-position in the co-rotating frame (left = toward the Sun,
  right = toward Jupiter and beyond)
- **Pitch** — instantaneous angular velocity `ω = (xẏ − yẋ)/(x²+y²)` around
  the barycentre; higher angular velocity → higher pitch
- **Volume** — inverse distance to the nearest primary (`1/min(r₁,r₂)`); the
  particle sounds louder when it swings close to either body

EventLayer accent tones mark the peaks of angular velocity — audible cues for the
libration rhythm in `l4`/`l5` mode, or the moments of maximum orbital speed
during escape in `l1` mode.

## Modes

### `l4` (default) — stable libration

The test particle starts 0.02 units from L4 at rest in the co-rotating frame and
librates in a complex tadpole/horseshoe pattern.  Two superimposed frequencies are
present: a fast epicyclic oscillation (period ≈ 2π) and a slow libration (period
≈ 2π/√(27μ/4) orbital years).  For Sun-Jupiter this slow period is ~150 years;
the app captures ≈6 orbital periods showing the start of the tadpole.

**What you hear:** A slowly evolving pitch variation as the particle's angular
velocity oscillates with the libration.  The sound is continuous and bounded —
never escaping, never going silent.  Accent tones mark the closest-approach rhythm.

### `l5` — symmetric libration

Identical physics at the trailing equilateral point.  The trajectory is the mirror
image of L4 (reflected in the x-axis).  Audio is similar but with opposite pan.

### `l1` — unstable escape

The test particle starts 0.02 units from L1 (displaced in y to break symmetry)
and escapes within 1–3 orbital periods.  The Lyapunov time near L1 is of order
one orbital period, so even a tiny perturbation grows exponentially.

**What you hear:** An initial burst of rapid pitch change as the particle's angular
velocity fluctuates near L1, followed by a dramatic shift in pitch and pan as it
escapes onto a different trajectory (toward Jupiter, back toward the Sun, or onto
a horseshoe).  The audio ends when the particle is clearly gone.

## Physical sanity checks

1. **Jacobi constant** — fractional drift in `C_J` over the full trajectory
   must be < 0.5% (confirms numerical integration accuracy)
2. **L4/L5 geometry** — both points satisfy `|L4−P₁| = |L4−P₂| = 1` (equilateral
   triangle, exact from Euler's result)
3. **Bounded motion** (l4/l5) — maximum distance from the Lagrange point stays
   below 0.5 units; **Escape** (l1) — distance from L1 grows by factor > 3×
4. **Quasi-periodicity** (l4/l5) — start-to-end distance after 6 orbital periods
   < 0.3 units; **Early stop** (l1) — WhenEvent terminates integration before the
   nominal end time (confirms escape actually occurred)

## Mass parameter presets

| Preset | μ | Bodies | L4/L5 stable? |
|--------|---|--------|----------------|
| `sun_jupiter` | 0.000954 | Sun + Jupiter | Yes (μ << 0.0385) |
| `earth_moon` | 0.012151 | Earth + Moon | Yes (μ < 0.0385) |
| `sun_earth` | 3.003×10⁻⁶ | Sun + Earth | Yes (μ << 0.0385) |

## Running

```sh
# Default: L4 libration, Sun-Jupiter
wolframscript -file lagrange/main.wl

# L5 (symmetric to L4)
wolframscript -file lagrange/main.wl -- --simulation.mode=l5

# L1 unstable escape
wolframscript -file lagrange/main.wl -- --simulation.mode=l1

# Earth-Moon system
wolframscript -file lagrange/main.wl -- --simulation.lagrange.preset=earth_moon

# Larger perturbation (horseshoe orbit)
wolframscript -file lagrange/main.wl -- --simulation.lagrange.perturbation=0.1

# Play the output (macOS)
afplay lagrange/output/l4_audio.wav
afplay lagrange/output/l1_audio.wav
```

## Output files

| File | Description |
|------|-------------|
| `l4_audio.wav` | Sonified L4 libration — pitch from angular velocity |
| `l4.gif` | Animated trajectory in the co-rotating frame (all 5 Lagrange points shown) |
| `l4.png` | Full trajectory static plot with primaries and Lagrange points |
| `l4_trajectory.csv` | Time series: position, velocity, angular velocity, distance to L4 |
| `l5_audio.wav` | Same for L5 |
| `l5.gif` | Animated L5 trajectory |
| `l5.png` | L5 static plot |
| `l5_trajectory.csv` | L5 trajectory data |
| `l1_audio.wav` | Sonified L1 escape — dramatic pitch change as particle departs |
| `l1.gif` | Animated escape trajectory |
| `l1.png` | Full escape trajectory |
| `l1_trajectory.csv` | Escape trajectory data |

# 2D Wave Propagation

Simulates and sonifies 2D wave propagation using the finite element method,
making the physics of expanding wavefronts and interference patterns audible.

## The physics: the wave equation

The motion of any 2D wave — a ripple on water, a struck drum membrane, sound
bouncing in a room — is governed by the same equation:

```
∂²u/∂t² = c² ∇²u
```

where `u(x, y, t)` is the displacement at position (x, y) at time t, and
`c` is the wave speed.  The Laplacian (∇²) encodes how displacement at a
point relates to its neighbours: a point that is higher than its surroundings
is pulled down; a point that is lower is pushed up.  This local coupling
propagates disturbances outward at speed c.

This app solves the wave equation numerically using Wolfram's finite element
method (`NDSolveValue` on a spatial `Region`), then extracts the time series
of displacement at fixed or moving "listening points" and sonifies them using
the same trajectory pipeline as the pendulum, lorenz, and quantum apps.

## Mode 1: ripple

A Gaussian impulse at the centre of a circular membrane (like a drum head,
or a droplet hitting still water) creates an expanding circular wavefront.
Three to four listening points are placed at increasing distances from the
source along a radius.

**What you hear:**  The wavefront arrives at the nearest listening point
first, then at the second, then the third, in strict time order.  Each
arrival is a burst of pitch and volume.  After the main wavefront passes,
you hear the reflected wave return from the fixed boundary (the drum rim),
arriving from the outside inward.  The speed of propagation — the delay
between arrivals — is directly audible as the gap between the bursts.

The stereo pan places each listening point at a distinct position:
the closest point is hard left, the most distant is hard right.  The
sequence of arrivals sweeps left to right across the stereo field.

## Mode 2: interference

Two coherent point sources oscillate in phase at the same frequency inside a
rectangular tank with Dirichlet boundary conditions (the walls absorb or
reflect, but the displacement is zero at the edges).

The interference pattern that forms is the spatial analogue of beating in the
time domain.  Where the two sources reinforce each other (path difference =
0, λ, 2λ, …) you get bright fringes (constructive interference).  Where they
cancel (path difference = λ/2, 3λ/2, …) you get dark fringes (destructive
interference).

A moving listening point sweeps across the pattern perpendicular to the
source axis.  For the first half of the audio, it sits at the central
constructive fringe (always equidistant from both sources) and you hear a
sustained, loud tone.  For the second half it sweeps from left to right,
crossing alternating bright and dark fringes — the amplitude swells and
fades periodically as it moves from constructive to destructive regions and
back.  The stereo pan tracks the LP's physical position: the signal sweeps
from left to right as the LP moves.

## Connection to the `signal` app

The `signal` app explores the *frequency domain*: how a time-domain signal
decomposes into a sum of sinusoidal components (Fourier analysis), and how
those components add and cancel to produce beats and chords.

This app explores the *spatial domain*: how exactly the same superposition
principle plays out in two dimensions across space rather than time.  The
fringe pattern in interference mode is the spatial analogue of beating — two
sources at the same frequency produce spatial "beats" just as two slightly
different frequencies produce temporal beats.

Listening to both apps together makes this symmetry concrete: in `signal`,
you hear the same note add and cancel in time; in `waves`, you hear it add
and cancel in space.

## Physical sanity checks (run on every execution)

1. **Amplitude bounded** — the solution stays finite throughout; verifies
   numerical stability of the FEM time integration.

2. **Wavefront arrival time** (ripple mode) — the time at which the wavefront
   reaches each listening point should match distance/wave_speed within
   numerical tolerance.  Any large discrepancy would indicate a fundamentally
   wrong simulation.

3. **Causality** (ripple mode) — the innermost listening point must receive
   the wavefront before all outer points.

4. **Dirichlet boundary condition** — displacement at the boundary (drum rim
   or tank wall) must remain near zero, verifying that the FEM enforces the
   fixed-edge constraint.

## Running

```sh
# Default: ripple mode
wolframscript -file waves/main.wl

# Interference mode
wolframscript -file waves/main.wl -- --simulation.mode=interference

# Faster wave speed (narrower fringe spacing in interference mode)
wolframscript -file waves/main.wl -- --simulation.waves.wave_speed=1.5

# Higher source frequency (more oscillation cycles per second)
wolframscript -file waves/main.wl -- --simulation.waves.source_frequency=3.0

# More listening points (ripple mode)
wolframscript -file waves/main.wl -- --simulation.waves.listening_points=6

# Play the output (macOS)
afplay waves/output/ripple_audio.wav
afplay waves/output/interference_audio.wav
```

## Output files

| File | Description |
|------|-------------|
| `ripple_audio.wav` | Sonified wavefront arrivals at each listening point |
| `ripple.gif` | Animated displacement field — expanding circular wavefront |
| `ripple.png` | 3D surface plot of displacement at the final time step |
| `ripple_data.csv` | Displacement time series at all listening points |
| `interference_audio.wav` | LP sweeping through fringe bands |
| `interference.gif` | Animated interference pattern (yellow dot = LP, green dots = sources) |
| `interference.png` | Final-frame fringe pattern |
| `interference_data.csv` | LP position, displacement, and fixed-LP reference over time |

## Physical parameters

| Parameter | Config key | Default | Effect |
|-----------|-----------|---------|--------|
| Wave speed | `simulation.waves.wave_speed` | 1.0 | Larger → faster propagation, earlier arrivals, wider fringe spacing |
| Membrane radius | `simulation.waves.membrane_radius` | 1.0 | Larger membrane, more space for wave to expand |
| Tank width/height | `simulation.waves.tank_width/height` | 2.0/1.0 | Tank geometry |
| Source frequency | `simulation.waves.source_frequency` | 2.0 Hz | Fringe spacing ∝ c/freq (λ = c/f) |
| Duration | `simulation.waves.duration` | 4.0 s | Simulation time (longer allows more reflections and pattern development) |
| Listening points | `simulation.waves.listening_points` | 4 | Number of radial LPs in ripple mode |

# Calibration

Every unit needs its noise floor measured before the ambient sensor means
anything. This is not optional polish — an uncalibrated floor makes the volume
either deaf to the room or permanently pinned.

**Nothing in this repo ships a calibrated value.** The defaults are starting
guesses. Even the Satellite1's previously validated `-55` is stale: it was
measured against `peak` on microphone channel 0 at gain 1, and this package
reads `rms` on channel 1 at gain 6.

---

## Why it is per-unit

The floor is a **dBFS** figure — `0 dB` is the loudest the ADC can represent
and quiet is negative. Where a given room lands on that scale depends on:

- **Microphone gain.** `gain_factor: 6` sits about 3.5 dB above `gain_factor: 4`
  for the same acoustic input. This is why the Satellite1 profile and the PE
  profile cannot share a number.
- **Microphone and ADC path.** The Satellite1's `sat1_mics` is a post-XMOS
  stream with its own AGC and noise suppression, so it is partly level
  normalised and its usable range is narrower than the PE's raw I2S capture.
- **The room.** A hard-floored kitchen and a carpeted bedroom differ by more
  than the hardware does.

Two identical units in two rooms need two different numbers.

---

## Guided calibration (recommended)

The firmware can measure itself. Four entities appear in Home Assistant:

| Entity | What it does |
|---|---|
| **Calibrate Quiet Floor** (button) | Records 60s, sets the floor |
| **Calibrate Loud Ceiling** (button) | Records 60s, sets the ceiling |
| **Reset Calibration** (button) | Restores the values from the device YAML |
| **Dyn. Vol. Calibration Status** (text) | Progress and result |

### Steps

1. **Quiet the room** to its normal resting state — the level the device should
   treat as silence. Press **Calibrate Quiet Floor** and leave the room alone
   for 60 seconds.
2. **Play TV or music from an external source** at the level you want the
   device to talk over. Press **Calibrate Loud Ceiling** and let it run.
3. Check **Dyn. Vol. Calibration Status**. It reports the value set, the window
   mean, the spread, and the sample count.

That is the whole procedure. Copy the resulting numbers into the device YAML so
a fresh unit starts near the right place.

> **Play the loud sample from an external source.** If you play it through this
> device's own media player, the feedback guard drops every sample and the
> capture reports "too few samples" — working as designed, since measuring your
> own output would be meaningless.

### What it actually computes

Each capture accumulates the **filtered** RMS (post median and EMA, so
transients are already suppressed) and sets the bound to:

```
bound = mean + calibration_sigma * stddev        # sigma defaults to 2.0
```

Using a spread-aware bound rather than the raw min or max means one cough
during a quiet capture cannot pin the floor to the cough. Two sigma covers
roughly 98% of a normal distribution, so the quiet floor lands just above the
loudest moment of a genuinely quiet room — which is exactly the semantics you
want, since anything at or below "quiet" should read 0%.

Measured example (Satellite1, 2026-08-19): a 60s quiet capture set the floor to
**-71.4 dB**, after which the resting room read a steady 0.0%.

### Persistence

The two bounds are `restore_value: true`, so a calibration survives reboots —
otherwise the feature would be pointless. The trade-off: `ambient_min_db` and
`ambient_max_db` in YAML are used on **first boot only**. After that the
restored value wins and editing YAML looks like it does nothing. Press **Reset
Calibration** to force the YAML values back.

---

## Manual procedure

Use this when tuning by eye, or on a platform where you want to see the raw
numbers before committing to them.

### Manual steps

### 1. Enable calibration logging

`logger:` is a plain dict key and merges cleanly, so set it directly in the
device file — no `!extend` needed. Add this temporarily:

```yaml
logger:
  level: DEBUG
  initial_level: DEBUG
  logs:
    ambient_sound: DEBUG
    dynamic_volume: DEBUG
    sensor: WARN
    component: WARN
    api: WARN
```

**The global level is a ceiling, not a default.** ESPHome rejects a per-tag
level more verbose than the global one, so seeing `ambient_sound: DEBUG`
requires `level: DEBUG` globally. Keep the output readable by raising the noisy
tags — `sensor`, `component`, `api` — rather than by lowering the global.

### 2. Flash and watch

```bash
esphome run <your-device>.yaml
```

You want lines like:

```
[D][ambient_sound]: RMS -52.4 dB (floor -55.0 dB) -> 4.7%
```

The first number is what you are calibrating against.

### 3. Take three readings

Let each settle — the filter chain reaches 90% of a step in roughly 7.5 s, so
give it 15–20 s per condition.

| Condition | What it establishes |
|---|---|
| Empty, quiet room | The real noise floor. **This is the number that matters.** |
| Normal conversation at usual distance | The middle of the useful range |
| Music or TV at the level you would want the device to talk over | The loud end |

Record the RMS dB for each.

### 4. Pick the floor

Set `ambient_min_db` a few dB **below** the measured quiet-room reading — far
enough that silence reads near 0%, close enough that normal speech produces
meaningful movement.

If the quiet room reads `-52 dB`, `-55` is a reasonable floor. Do not set it
30 dB below; that compresses the whole useful range into the bottom few percent.

**Sweep it live instead of reflashing.** The **`Dyn. Vol. Noise Floor`** and
**`Dyn. Vol. Loud Ceiling`** number entities are editable in Home Assistant.
Move one and watch `Ambient Sound Level` respond immediately — no rebuild, no
OOM risk, no waiting.

Both bounds are `restore_value: true`, so what you set here survives reboots and
the YAML values apply on first boot only. Still write your answer into the
device file, so a reflashed or replacement unit starts in the right place — and
use **Reset Calibration** if you want the YAML values back.

Values snap to a 0.25 dB grid; see the note under Troubleshooting.

### 5. Bake it in

```yaml
substitutions:
  ambient_min_db: "-55"
```

Reflash and re-verify: a quiet room should read a low single-digit percentage,
not 30%.

### 6. Tune the response, then turn logging back down

With the floor right, set the behaviour:

- **`Dyn. Vol. Anchor`** — the volume in a silent room. Always normalised
  `0..1`; the device remaps it onto its own volume range internally, so the same
  number means the same thing on all three platforms.
- **`Dyn. Vol. Strength`** — how hard ambient noise pushes above the anchor.
  `0` disables the effect without turning the switch off, which is a useful
  A/B test.

Then drop `logs:` back out of the device file. `ambient_sound` at DEBUG emits a
line every publish interval, indefinitely.

---

## Reading the diagnostics

Beyond the three controls (`Dynamic Volume`, `Dyn. Vol. Anchor`,
`Dyn. Vol. Strength`) the package publishes these. Two are
`disabled_by_default` and must be enabled in Home Assistant's entity settings.

| Entity | Default | Use |
|---|---|---|
| `Ambient Sound RMS` | enabled | **The calibration entity.** Raw smoothed dBFS. |
| `Ambient Sound Level` | enabled | The derived 0–100%, after the bounds are applied |
| `Dyn. Vol. Noise Floor` | enabled | The floor in use. Editable. |
| `Dyn. Vol. Loud Ceiling` | enabled | The ceiling in use. Editable. |
| `Dyn. Vol. Calibration Status` | enabled | Progress and result of a guided capture |
| `Ambient Sound Peak` | disabled | Loudest recent sample. Checking for clipping. |
| `Dyn. Vol. Target` | disabled | The volume actually applied. The control output. |

Plus three buttons: `Calibrate Quiet Floor`, `Calibrate Loud Ceiling` and
`Reset Calibration`.

`Ambient Sound Peak` is intentionally *not* feedback-guarded, so it does include
the device's own output. That is what makes it useful for confirming the
playback guard is working: peak should move during playback while RMS stays
flat.

---

## Troubleshooting

**The sensor is stuck at exactly 0%.** The floor is set far below the real one,
so everything clamps to the bottom. Raise it toward the measured quiet-room value.

**The sensor sits at 100%.** The floor is above the room's actual level. Lower it.

**The sensor reads `unknown` and never updates.** The guard is dropping every
sample. In order of likelihood: the microphone is muted (the mute switch stops
the stream — `passive: true` means this package cannot start it); `micro_wake_word`
is not running; or the media player is stuck reporting `PLAYING`.

**Readings never change no matter the noise.** Check the resolved mic binding
matches the wake word engine:

```bash
esphome config <your-device>.yaml | grep -A6 'platform: sound_level'
```

`channels` and `gain_factor` must match the device's `micro_wake_word`
microphone block. If they differ, the profile is wrong — see
`docs/UPSTREAM-BUG.md`, bug 2.

**Volume pumps up and down.** Raise `ambient_median_window` (rejects longer
transients) or lower `ambient_smoothing_alpha` (slower, smoother). Both are
profile-level `vars:`.

**Volume reacts too slowly.** Raise `ambient_smoothing_alpha` toward `1.0`, or
lower `ambient_publish_every`. Both trade stability for speed.

**Home Assistant says "enter a valid value" on a bound field.** The number is
off the step grid. HA requires `(value - min)` to be an exact multiple of
`step`, so the bounds use `step: 0.25` — a negative power of two, therefore
exactly representable in binary floating point — and guided calibration rounds
its result onto that grid. A value written before this was fixed (or set over
the API without rounding) will still trip it: press **Calibrate Quiet Floor**
again, or **Reset Calibration**, to rewrite it as a valid grid point.

**A capture reports "too few samples".** Fewer than 5 readings arrived in the
window. Either the microphone was muted, `micro_wake_word` was not running, or —
most commonly — the loud sample was played through *this device's* speaker,
where the feedback guard correctly discards every reading. Play it from
something else.

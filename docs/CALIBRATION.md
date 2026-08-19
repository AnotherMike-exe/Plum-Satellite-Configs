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

## Procedure

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
esphome run devices/<device>.yaml
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

**Sweep it live instead of reflashing.** The package exposes a
**`Dyn. Vol. Noise Floor`** number entity. Move it in Home Assistant and watch
`Ambient Sound Level` respond immediately — no rebuild, no OOM risk, no waiting.
When you find the value, write it into the device YAML.

The entity is deliberately `restore_value: false`, so the YAML value wins on
every boot. That means the slider is a scratchpad: **if you do not write your
answer into the device file, the next reboot discards it.**

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

The package publishes four entities beyond the controls. Two are enabled by
default; two are `disabled_by_default` and must be enabled in Home Assistant's
entity settings.

| Entity | Default | Use |
|---|---|---|
| `Ambient Sound RMS` | enabled | **The calibration entity.** Raw smoothed dBFS. |
| `Ambient Sound Level` | enabled | The derived 0–100%, after the floor is applied |
| `Ambient Sound Peak` | disabled | Loudest recent sample. Checking for clipping. |
| `Dyn. Vol. Target` | disabled | The volume actually applied. The control output. |

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
esphome config devices/<device>.yaml | grep -A6 'platform: sound_level'
```

`channels` and `gain_factor` must match the device's `micro_wake_word`
microphone block. If they differ, the profile is wrong — see
`docs/UPSTREAM-BUG.md`, bug 2.

**Volume pumps up and down.** Raise `ambient_median_window` (rejects longer
transients) or lower `ambient_smoothing_alpha` (slower, smoother). Both are
profile-level `vars:`.

**Volume reacts too slowly.** Raise `ambient_smoothing_alpha` toward `1.0`, or
lower `ambient_publish_every`. Both trade stability for speed.

# Architecture

## 1. What this is

A three-layer ESPHome configuration library. There is no application code — the
artefact is YAML that resolves into a valid ESPHome config and compiles to
firmware for three different ESP32-S3 voice satellites.

The architectural problem it solves: the same feature has to run on three
platforms whose microphone ids, microphone gain, and vendor packaging all
differ, without forking the logic three ways.

## 2. Project structure

```
plum-satellite-configs/
├── packages/
│   └── dynamic-volume.yaml     Behaviour. Hardware-agnostic, fully parameterised.
├── profiles/
│   ├── voice-pe.yaml           Vendor pin + hardware binding, per platform.
│   ├── satellite1.yaml
│   └── respeaker-lite.yaml
├── devices/
│   ├── *.yaml                  Per-unit identity, calibration, credentials.
│   ├── secrets.yaml            GITIGNORED
│   └── secrets.yaml.example
├── docs/
├── scripts/validate-all.sh
└── _resources/                 Dev references. NOT in git.
```

## 3. Layering

```
  devices/satellite1-01.yaml
    substitutions: name, friendly_name, ambient_min_db
    api / wifi from !secret
            │
            │  packages: !include
            ▼
  profiles/satellite1.yaml
    packages:
      vendor ──────────────► github://futureproofhomes/...@v0.2.1-beta.0
      dynamic_volume ──┐        (mic, media player, wake word, LEDs, buttons…)
            │          │
            │          │  !include with vars:
            │          │    mic_id: sat1_mics
            │          │    mic_gain_factor: "6"
            │          │    ambient_min_db: ${ambient_min_db}
            ▼          ▼
  packages/dynamic-volume.yaml
    substitutions:  ← defaults for anything not passed
    sound_level → filters → percentage → control law → media_player volume
```

Each layer owns exactly the parameters that belong to it:

| Layer | Owns | Changes when |
|---|---|---|
| package | behaviour shared by all hardware | the feature changes |
| profile | what a platform requires | a vendor releases |
| device | what a unit needs | a unit is added or recalibrated |

### Why `vars:` and not global substitutions

ESPHome's `!include` accepts a `vars:` mapping whose values are **lexically
scoped** to that include. They neither read from nor write to the global
`substitutions:` namespace. A package's own `substitutions:` block acts as the
default for anything not passed.

This matters because vendor packages define dozens of substitutions of their
own. With a global namespace, a package parameter named `mic_id` could silently
collide with a vendor's. With scoped vars, the package is a function with named
arguments, and the profile is the only thing that can call it.

Verified: a deliberately-wrong global substitution correctly loses to a scoped
var, and a device-level substitution reaches the package when the profile passes
it through explicitly as `ambient_min_db: ${ambient_min_db}`.

### Why profiles exist at all

The package could be included directly by device files, with each one repeating
the hardware binding. Profiles exist so that a vendor bump or a hardware
correction is a one-line edit in one file rather than an edit per unit — which
is the same argument that motivated the whole repo.

## 4. Signal path

```
microphone (vendor)
   │  channel 1, gain 4–6 — MUST match micro_wake_word's binding
   ▼
sound_level (passive)                      dBFS, 1 sample/s
   │
   ├── rms ──► [validity + playback guard] ──► [median] ──► [EMA] ──► on_value
   │              drop -inf / NaN / < -95      transient    smooth      │
   │              drop while PLAYING or        rejection               │
   │              ANNOUNCING, + 3s settle                              │
   │                                                                    ▼
   │                                                    Ambient Sound Level (%)
   │                                                                    │
   └── peak ──► [validity] ──► [max] ──► diagnostic only                │
                                                                        ▼
                                                       update_dynamic_volume
                                                         volume = anchor ×
                                                           (1 + level^curve × strength)
                                                         clamp, deadband
                                                                        │
                                                                        ▼
                                                        media_player.set_volume
```

**Event-driven, not polled.** The percentage is published from the dB sensor's
`on_value` trigger and the control script runs from the same trigger. There is
no `interval:` block. The upstream design polled a second sensor that re-read
the first sensor's already-published state, which is where most of its ~50 s
latency came from.

**Timing.** At `measurement_duration: 1000ms`, a median window of 5 rejects any
transient shorter than ~2 s outright, and an EMA with `alpha: 0.4` has
τ ≈ 1.96 s. A step reaches 90% in roughly 7.5 s, published within 9 s worst
case. Both windows are counted in samples, so changing `measurement_duration`
rescales the whole chain.

**Median before EMA, deliberately.** A moving average cannot reject an outlier,
only smear it — a one-second door slam 40 dB above the floor moves a 5-wide mean
noticeably and a 5-wide median not at all. Splitting outlier rejection from
smoothing lets the latency budget go to responsiveness instead of to averaging
slams away.

## 5. Guided calibration

The dB window mapped onto 0-100% is not a compile-time constant. Both bounds are
live `number` entities, and two `button` entities measure the room and write
them.

```
  [Calibrate Quiet Floor]        [Calibrate Loud Ceiling]
            │                              │
            └────────► dv_calibrate(mode) ◄┘
                            │
              sets dv_cal_mode, zeroes accumulators
                            │
                  ┌─────────┴─────────┐
                  │  60s capture       │   the rms sensor's on_value trigger
                  │  window            │   adds each FILTERED sample to
                  └─────────┬─────────┘   n / sum / sumsq
                            │
              mean + sigma*stddev, quantised to 0.25
                            │
                            ▼
       Dyn. Vol. Noise Floor   or   Dyn. Vol. Loud Ceiling
                            │
                            ▼
              Dyn. Vol. Calibration Status (text)
```

Three decisions worth keeping:

- **Sample the filtered RMS, not the raw sensor.** The accumulator sits on the
  sensor's `on_value`, downstream of the median and EMA stages, so transients
  are already suppressed before they can bias a capture.
- **`mean + sigma*stddev`, not min/max.** A raw max would let one cough during a
  quiet capture pin the floor to the cough. Two sigma covers ~98% of a normal
  distribution, which is the right semantics for "anything this quiet counts as
  silence".
- **Quantise to the number's 0.25 step.** Home Assistant rejects a value that is
  not an exact multiple of the step, and 0.25 is a negative power of two so
  every grid point is exactly representable. See docs/CLAUDE.md.

Fewer than 5 samples aborts with a diagnostic rather than writing a bogus bound.
The usual cause is the loud sample being played through the device's own
speaker, where the feedback guard correctly discards every reading.

Both bounds are `restore_value: true`, so a calibration survives reboot and the
YAML values are first-boot defaults. `Reset Calibration` restores them.

## 6. Hardware abstraction

Everything platform-specific is a profile parameter:

| Parameter | PE | Satellite1 | ReSpeaker |
|---|---|---|---|
| `mic_id` | `i2s_mics` | `sat1_mics` | `i2s_mics` |
| `mic_channel` | 1 | 1 | 1 |
| `mic_gain_factor` | 4 | **6** | 4 |
| `media_player_id` | `external_media_player` | ← | ← |
| `wake_word_id` | `mww` | ← | ← |

The anchor volume is **not** platform-specific despite the three devices
declaring different `volume_min`/`volume_max`. Both media player platforms remap
a normalised 0–1 volume onto their own range internally
(`speaker_media_player.cpp:599`, `speaker_source_media_player.cpp:813`), so the
device's declared range is transparent and the anchor means the same thing
everywhere.

## 7. External dependencies

| Repo | Pin | Provides |
|---|---|---|
| `esphome/home-assistant-voice-pe` | `26.6.0` | PE base |
| `futureproofhomes/satellite1-esphome` | `v0.2.1-beta.0` | Satellite1 base |
| `formatBCE/Respeaker-Lite-ESPHome-integration` | `3136cf79` | ReSpeaker base |

All pinned; none tracks a moving branch. **Caveat:** pinning a package freezes
its YAML, not its `external_components`, which each vendor declares against a
moving ref with `refresh: 0s`. See README, Known gaps.

## 8. Validation

`scripts/validate-all.sh` runs `esphome config` over every device file, which
fetches every remote package, applies every substitution, and binds every id
reference. `--clean` clears the cache first to prove the pins actually resolve.

This catches broken pins, renamed vendor ids, bad includes, and merge conflicts.
It does **not** compile C++ — lambdas need `esphome compile`.

## 9. Security

- API encryption keys and WiFi credentials via `!secret` only.
  `devices/secrets.yaml` is gitignored; `secrets.yaml.example` documents the
  required keys.
- `!secret` resolves relative to the config file's own directory, falling back
  to the main config's directory (`yaml_util.py:604-615`). It does not walk up
  to a repo root — hence `secrets.yaml` in `devices/`.
- No secrets in profiles or packages; those are shared and intended to be
  publishable.

## 10. Future considerations

- Pin `external_components` to SHAs via `!remove` plus a replacement list
- Tag `v1.0.0` and switch `devices/` from local `!include` to a pinned
  `github://` ref, so device files can live in an ESPHome dashboard directly
- Upstream the fixes to `jaapp` and `adri6412`
- CI running `validate-all.sh` on push

## 11. Glossary

- **dBFS** — decibels relative to full scale. `0 dB` is the loudest the ADC can
  represent; quiet is negative. What `sound_level` emits.
- **Noise floor** — the dBFS level of a quiet room on a given unit at a given
  mic gain. The value being calibrated.
- **Anchor** — the media player volume in a silent room; the base the control
  law scales up from.
- **sendspin** — ESPHome's multi-room audio sync component. Built in as of
  2026.7.4, active on all three platforms.
- **mww** — `micro_wake_word`, the on-device wake word engine. It owns the
  microphone stream that `sound_level` taps passively.

---

## 12. Credits

The dynamic volume design implemented here — an anchor volume scaled by a
strength factor against a measured ambient level — originates with
[jaapp/ha-voice-dynamic-volume](https://github.com/jaapp/ha-voice-dynamic-volume)
and its fork
[adri6412/ha-voice-dynamic-volume-2025](https://github.com/adri6412/ha-voice-dynamic-volume-2025).
The device firmware this builds on is by ESPHome / Nabu Casa, FutureProofHomes
and formatBCE. Full attribution is in the project README.

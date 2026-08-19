# Plum-Satellite-Configs

> Your voice satellite turns itself up in a noisy room and back down in a quiet
> one — with a calibration you run by pressing a button, not by reading logs.

## What this is

ESPHome voice satellites answer at whatever volume you last set. That is too
quiet with the TV on and startling at 6am. **Dynamic volume** fixes it: the
device listens to the room, works out how loud it is, and scales its own
speaking volume to match.

This repo packages that for three devices — **Home Assistant Voice PE**,
**FutureProofHomes Satellite1**, and **formatBCE ReSpeaker Lite** — as one
shared config you import. Adding it to a device is a handful of lines, and each
unit calibrates itself to its own room.

It exists because the two community projects this was ported from
([credits below](#credits-and-attribution)) contain six defects that make the
feature silently do nothing — it compiles, flashes, reports `0%` forever, and
never moves the volume. Every one is fixed here and documented with a citation
to the ESPHome source that proves it, in
**[docs/UPSTREAM-BUG.md](docs/UPSTREAM-BUG.md)**.

---

## Getting started

### 1. What you need

- **ESPHome 2026.7.0 or newer** (`pip install esphome`)
- One of the three supported devices, already running its vendor firmware and
  reachable on your network
- Your WiFi credentials and the device's API key

### 2. Set up

```bash
git clone https://github.com/AnotherMike-exe/Plum-Satellite-Configs.git
cd Plum-Satellite-Configs

cp devices/secrets.yaml.example devices/secrets.yaml
$EDITOR devices/secrets.yaml          # WiFi + one API key per device
```

Check everything resolves before touching hardware:

```bash
scripts/validate-all.sh
```

### 3. Deploy

Pick the device file matching your hardware and flash it:

```bash
esphome run devices/satellite1-01.yaml
```

Edit `name` and `friendly_name` in that file to match your unit first. **If the
device already exists in Home Assistant, keep its existing `name` exactly** —
changing it registers a second, unrelated device and orphans your entities.

Flashing is over the network; no USB needed as long as the device is reachable.

### 4. Calibrate

Two button presses in Home Assistant, roughly a minute each.

1. Get the room to its normal quiet — the level that should count as silence.
   Press **Calibrate Quiet Floor** and leave it alone for 60 seconds.
2. Play TV or music **from something other than this device**, at the level you
   want it to talk over. Press **Calibrate Loud Ceiling**.

Watch **Dyn. Vol. Calibration Status** for the result. Then turn on the
**Dynamic Volume** switch.

That is the whole setup. Everything below is detail you only need if you want it.

> Play the loud sample from an external source. Through the device's own
> speaker, the feedback guard correctly discards every reading and the capture
> reports "too few samples".

---

## What appears in Home Assistant

**Controls**

| Entity | What it does |
|---|---|
| `Dynamic Volume` | Master switch. Off by default. |
| `Dyn. Vol. Anchor` | Volume in a silent room. The baseline everything scales from. |
| `Dyn. Vol. Strength` | How hard noise pushes volume above the anchor. `0` disables the effect without switching off. |

**Calibration**

| Entity | What it does |
|---|---|
| `Calibrate Quiet Floor` | 60s capture, sets the floor |
| `Calibrate Loud Ceiling` | 60s capture, sets the ceiling |
| `Reset Calibration` | Restores the values from the device YAML |
| `Dyn. Vol. Noise Floor` | The measured floor, editable |
| `Dyn. Vol. Loud Ceiling` | The measured ceiling, editable |
| `Dyn. Vol. Calibration Status` | Progress and result text |

**Diagnostics**

| Entity | |
|---|---|
| `Ambient Sound Level` | Room loudness, 0–100% |
| `Ambient Sound RMS` | Raw measurement in dB — the number calibration is about |
| `Ambient Sound Peak` | Loudest recent sample *(disabled by default)* |
| `Dyn. Vol. Target` | The volume actually applied *(disabled by default)* |

Calibration results persist across reboots, which means the YAML values apply on
**first boot only**. Use **Reset Calibration** to force them back.

---

## Supported hardware

| | HA Voice PE | Satellite1 | ReSpeaker Lite |
|---|---|---|---|
| Vendor pin | `26.6.0` | `v0.2.1-beta.0` | `3136cf79` |
| Microphone | `i2s_mics` | `sat1_mics` | `i2s_mics` |
| Wake word gain | 4 | **6** | 4 |
| Calibrated | floor only | **yes** | — |

**Minimum ESPHome is 2026.7.0**, set by the Satellite1 vendor base.

The gain difference is why the microphone binding is a per-platform parameter:
the ambient sensor must read the same channel at the same gain as the wake word
engine, or the calibration describes a signal the device does not otherwise use.
That mismatch is [bug 2](docs/UPSTREAM-BUG.md).

**Don't copy calibration values between platforms** — this is measured, not
theoretical. The Satellite1's XMOS front-end applies AGC and noise suppression;
the PE captures raw I2S:

| | Satellite1 | HA Voice PE |
|---|---|---|
| Quiet floor | −71.4 dB | **−78.5 dB** |
| Sample spread (σ) | ~0.35 dB | **1.87 dB** |

Seven dB apart, with five times the sample-to-sample variation on the PE. A
floor copied across would be badly wrong in either direction.

---

## Layout

```
packages/dynamic-volume.yaml   All the logic. One parameterised file.
profiles/*.yaml                Vendor pin + hardware binding, one per platform.
devices/*.yaml                 Per unit: name, calibration, credentials.
scripts/validate-all.sh        Resolve every device config.
docs/                          Calibration, the upstream bugs, architecture.
```

Three layers, because the settings split three ways: what the *package* does
(shared), what a *platform* needs (mic id, gain), and what a *unit* needs (name,
its room). Values pass down through `!include` `vars:`, which are lexically
scoped — they cannot collide with a vendor package's own substitutions.

`!secret` resolves relative to the config file's directory, which is why
`secrets.yaml` lives in `devices/`.

### Running it from Home Assistant instead

Device files use `!include ../profiles/...`, so they only work inside a
checkout. To manage a device from the HA ESPHome dashboard, point it at the
published package instead:

```yaml
packages:
  plum: github://AnotherMike-exe/Plum-Satellite-Configs/profiles/satellite1.yaml@main
```

Remote packages are cloned whole, so the profile's own relative include still
resolves.

## Adding a device

```yaml
substitutions:
  name: living-room-satellite      # must match the existing device, if any
  friendly_name: Living Room Satellite

packages:
  plum: !include ../profiles/satellite1.yaml

esphome:
  name: ${name}
  name_add_mac_suffix: false
  friendly_name: ${friendly_name}

api:
  encryption:
    key: !secret api_key_living_room
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
```

Then calibrate it. Everything hardware-specific lives in the profile.

## Adding a new platform

Don't guess component ids — resolve them:

```bash
esphome config devices/<device>.yaml | grep -E 'id: (.*mic|.*media_player|mww)'
```

Write a profile binding `mic_id`, `mic_channel`, `mic_gain_factor`,
`media_player_id` and `wake_word_id`, then confirm the microphone binding
matches the wake word engine's:

```bash
esphome config devices/<new>.yaml | grep -A6 'platform: sound_level'
```

## Known gaps

**Pinned packages don't pin their components.** Pinning `packages:` freezes the
YAML, not the C++. Every vendor base declares `external_components` against a
*moving* ref with `refresh: 0s` — the PE pulls `voice_kit` from its own `dev`
branch, formatBCE pulls `i2s_audio` from a feature branch and `respeaker_lite`
from `main`. A vendor can still change compiled behaviour under a fully pinned
config. Fixing it needs `!remove` plus a complete pinned replacement list across
three platforms, deliberately deferred rather than bundled into the first
release.

**formatBCE publishes no tags**, so the ReSpeaker pin is a bare commit SHA and
must be bumped by hand.

## Status

All three build from the current source on ESPHome 2026.7.4:

| Target | Config | Compiles | On hardware |
|---|---|---|---|
| HA Voice PE | yes | RAM 44.9%, Flash 35.3% of 8 MB | **yes, floor calibrated** |
| Satellite1 | yes | RAM 46.5%, Flash 36.0% of 8 MB | **yes, calibrated** |
| ReSpeaker Lite | yes | RAM 44.9%, Flash 71.2% of 3.9 MB | not yet |

The ReSpeaker partition is half the size of the others, so it has the least
headroom — worth watching if you add wake word models.

## Roadmap

- [ ] Measure the loud ceiling on the PE (floor is done)
- [ ] Calibrate the ReSpeaker
- [ ] Tag `v1.0.0`; point `devices/` at the tag rather than local `!include`
- [ ] Offer the fixes upstream to `jaapp` and `adri6412`
- [ ] Pin `external_components` to SHAs

## Documentation

- [Calibration](docs/CALIBRATION.md) — the buttons, and tuning by hand
- [The upstream bugs](docs/UPSTREAM-BUG.md) — what was wrong, with source citations
- [Architecture](docs/ARCHITECTURE.md) — how the layering and signal path work
- [CLAUDE.md](CLAUDE.md) — conventions and gotchas for anyone editing this

---

## Credits and attribution

This project would not exist without prior work by others.

**The original dynamic volume idea and implementation**

- **[jaapp/ha-voice-dynamic-volume](https://github.com/jaapp/ha-voice-dynamic-volume)**
  — the original, for the Home Assistant Voice PE. The core design here is
  still recognisably jaapp's: an *anchor* volume scaled by a *strength* factor
  against a measured ambient level, exposed as ESPHome template entities.
- **[adri6412/ha-voice-dynamic-volume-2025](https://github.com/adri6412/ha-voice-dynamic-volume-2025)**
  — a fork that carried the idea forward, and the version this was first
  deployed from.

The entity names in this package (`Dyn. Vol. Anchor`, `Dyn. Vol. Strength`,
`Dynamic Volume`, `Ambient Sound Level`) are **deliberately identical** to
theirs, so anyone migrating keeps their Home Assistant entity ids, dashboards
and automations.

This is a reimplementation rather than a copy, and
[docs/UPSTREAM-BUG.md](docs/UPSTREAM-BUG.md) is blunt about the defects it
corrects. That is meant as a bug report, not a criticism — the bugs are subtle,
they stem from a genuinely misleading ESPHome API where a sensor documented in
"decibels" returns negative dBFS, and the feature *looks* like it works. Finding
them took live hardware and a read of the component source. The idea was theirs;
this repo only fixes the arithmetic.

**Device firmware** — this repo adds a feature to their work; it does not
replace it:

- **[esphome/home-assistant-voice-pe](https://github.com/esphome/home-assistant-voice-pe)** — Nabu Casa / ESPHome
- **[FutureProofHomes/satellite1-esphome](https://github.com/futureproofhomes/satellite1-esphome)** — FutureProofHomes
- **[formatBCE/Respeaker-Lite-ESPHome-integration](https://github.com/formatBCE/Respeaker-Lite-ESPHome-integration)** — formatBCE

**[ESPHome](https://github.com/esphome/esphome)** — the `sound_level`,
`micro_wake_word`, `media_player` and `sendspin` components everything here is
built on.

### Licensing

The ESPHome project and the PE and Satellite1 firmware repos are under the
**ESPHome License**.

The `jaapp`, `adri6412` and `formatBCE` repositories publish **no license
file**, which under default copyright means no grant of reuse. This repo
contains no copied code from any of them — the package is written from scratch
against the ESPHome component APIs — but the design lineage is theirs and is
credited above. If you are a maintainer of one of those projects and want
something changed here, please open an issue.

This repository is **MIT licensed** — see [LICENSE](LICENSE). Take the fixes,
including into either upstream project; no attribution back here is required.

## License

[MIT](LICENSE) — Copyright (c) 2026 Plum Solutions.

---

**Maintainer**: Plum Solutions

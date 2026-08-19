# plum-satellite-configs

> Ambient-noise-adaptive volume for ESPHome voice satellites, as one maintained
> package instead of a per-device debugging session.

Three voice satellite platforms — Home Assistant Voice PE, FutureProofHomes
Satellite1, and formatBCE ReSpeaker Lite — all want the same feature: measure
room noise, scale the media player volume to match. This repo ships that as a
single parameterised package plus one profile per platform, so deploying to a
new unit is a fifteen-line device file.

It replaces `jaapp/ha-voice-dynamic-volume` and
`adri6412/ha-voice-dynamic-volume-2025`, which contain six defects that make the
feature silently inert — it compiles, flashes, and reports `0%` forever. See
**[docs/UPSTREAM-BUG.md](docs/UPSTREAM-BUG.md)**, where each is cited to ESPHome
source.

---

## Quick start

```bash
pip install esphome                              # 2026.7.0 or newer
cp devices/secrets.yaml.example devices/secrets.yaml
$EDITOR devices/secrets.yaml

scripts/validate-all.sh                          # resolve every device config
esphome run devices/voice-pe-01.yaml             # flash one
```

Then **calibrate** — the shipped noise floors are guesses, not measurements.
See [docs/CALIBRATION.md](docs/CALIBRATION.md).

## Adding a device

```yaml
substitutions:
  name: living-room-satellite
  friendly_name: Living Room Satellite
  ambient_min_db: "-55"          # measure this; see docs/CALIBRATION.md

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

That is the whole file. Everything hardware-specific lives in the profile.

## Layout

```
packages/dynamic-volume.yaml   One parameterised package. All the logic.
profiles/*.yaml                Vendor pin + hardware binding, one per platform.
devices/*.yaml                 Per-unit: name, calibration, credentials.
scripts/validate-all.sh        Resolve every device config.
docs/                          Calibration, the upstream bugs, architecture.
```

Three layers, because the parameters split three ways: what the *package* does
(shared), what a *platform* requires (mic id, gain), and what a *unit* needs
(name, noise floor). Parameters pass down via `!include` `vars:`, which are
lexically scoped — they do not leak into or out of global `substitutions:`.

`!secret` resolves relative to the config file's own directory, which is why
`secrets.yaml` lives in `devices/` and not the repo root.

**Device files are not yet standalone.** They use `!include ../profiles/...`,
so they only work inside a checkout of this repo — copying one alone into
`/config/esphome/` fails. To manage a device from the Home Assistant ESPHome
dashboard, swap the local include for the published package:

```yaml
packages:
  plum: github://AnotherMike-exe/Plum-Satellite-Configs/profiles/satellite1.yaml@main
```

Remote packages are cloned whole, so the profile's own relative include of
`packages/dynamic-volume.yaml` still resolves. Pin `@main` to a tag once
`v1.0.0` is cut.

## Supported hardware

| | HA Voice PE | Satellite1 | ReSpeaker Lite |
|---|---|---|---|
| Vendor pin | `26.6.0` | `v0.2.1-beta.0` | `3136cf79` |
| Microphone | `i2s_mics` | `sat1_mics` | `i2s_mics` |
| Wake word gain | 4 | **6** | 4 |
| Media player | `external_media_player` (all three, `speaker_source`) | | |

The gain difference is why the microphone binding is a profile parameter rather
than a constant: `sound_level` must read the same channel at the same gain as
`micro_wake_word`, or the calibrated floor describes a signal the device does not
otherwise use.

**Minimum ESPHome is 2026.7.0**, set by the Satellite1 vendor base.

## Adding a new platform

Do not guess component ids. Resolve them:

```bash
esphome config devices/<device>.yaml | grep -E 'id: (.*mic|.*media_player|mww)'
```

Then write a profile binding `mic_id`, `mic_channel`, `mic_gain_factor`,
`media_player_id`, and `wake_word_id`. Confirm the mic binding matches:

```bash
esphome config devices/<new>.yaml | grep -A6 'platform: sound_level'
```

## Known gaps

**Pinned packages do not pin their components.** Pinning `packages:` freezes the
YAML, not the C++. Every vendor base declares `external_components` against a
*moving* ref with `refresh: 0s` — PE pulls `voice_kit` from its own `dev`
branch, formatBCE pulls `i2s_audio` from a feature branch and `respeaker_lite`
from `main`. A vendor can still change compiled behaviour under a fully pinned
config. Overriding this needs `!remove` on the vendor key plus a complete pinned
replacement list, across three platforms — deliberately deferred rather than
bundled into the first release.

**formatBCE publishes no tags or releases**, so the ReSpeaker pin is a bare
commit SHA and must be bumped by hand.

## Build status

All three device configs resolve from a cleared package cache, and all three
platforms compile to firmware on ESPHome 2026.7.4:

| Target | RAM | Flash |
|---|---|---|
| HA Voice PE | 44.8% | 35.2% of 8 MB |
| Satellite1 | 46.3% | 35.7% of 8 MB |
| ReSpeaker Lite | 44.8% | **71.1% of 3.9 MB** |

The ReSpeaker partition is half the size of the others, so it has the least
headroom — worth watching when adding wake word models.

No unit has been flashed or calibrated yet.

## Roadmap

- [ ] Calibrate all three units and record the measured floors
- [ ] Tag `v1.0.0` once validated on one unit per platform; point `devices/` at
      the tag rather than local `!include`
- [ ] Upstream the dB-scaling and guard fixes to `jaapp` and `adri6412`
- [ ] Pin `external_components` to SHAs

## Documentation

- [Calibration](docs/CALIBRATION.md) — measuring a unit's noise floor
- [The upstream bugs](docs/UPSTREAM-BUG.md) — what was wrong and why
- [Architecture](docs/ARCHITECTURE.md) — how the layering works
- [Dev setup](docs/DEV-SETUP.md) · [Quick reference](docs/QUICK-REFERENCE.md)
- [CLAUDE.md](CLAUDE.md) — project memory for Claude Code

---

**Maintainer**: Plum Solutions

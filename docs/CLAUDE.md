# CLAUDE.md — plum-satellite-configs

## Project Overview

An ESPHome package library providing ambient-noise-adaptive media player volume
("dynamic volume") across three voice satellite hardware platforms. It replaces
two upstream repos that ship the feature with six defects making it silently
inert.

This is a **YAML configuration library**, not an application. There is no source
code, no build system, no tests in the usual sense, and no Docker. The
deliverable is configuration that resolves and compiles.

### Key Features

- One parameterised package (`packages/dynamic-volume.yaml`) covering all
  hardware, rather than one file per platform
- Per-platform profiles that pin vendor packages and bind hardware ids
- Per-device files reduced to name, calibration value, and credentials
- Correct dBFS handling, transient rejection, and a working playback guard
- Guided in-firmware calibration: two Home Assistant buttons measure the room
  and write the dB bounds themselves

### Project Context

Source material was ported from `jaapp/ha-voice-dynamic-volume` and
`adri6412/ha-voice-dynamic-volume-2025`. Both are broken in the same ways.
`docs/UPSTREAM-BUG.md` documents all six defects with ESPHome source citations —
**read it before modifying any lambda in the package.** Several of the bugs are
easy to reintroduce because the wrong version looks more natural than the right
one.

## Technology Stack

- **ESPHome 2026.7.0+** (2026.7.4 verified). The floor is set by the Satellite1
  vendor base's `min_version`.
- **Target**: ESP32-S3, ESP-IDF framework
- **Vendor packages**: `esphome/home-assistant-voice-pe@26.6.0`,
  `futureproofhomes/satellite1-esphome@v0.2.1-beta.0`,
  `formatBCE/Respeaker-Lite-ESPHome-integration@3136cf79`
- No Python, no Docker, no CI yet

## Project Structure

```
packages/dynamic-volume.yaml   The logic. Parameterised, hardware-agnostic.
profiles/{voice-pe,satellite1,respeaker-lite}.yaml
                               Vendor pin + hardware binding + platform defaults.
devices/*.yaml                 Per-unit. Also holds secrets.yaml (gitignored).
docs/                          CALIBRATION, UPSTREAM-BUG, ARCHITECTURE, setup guides.
scripts/validate-all.sh        Resolve every device config.
_resources/                    Dev references. NEVER in git.
```

### Special directories

- `_resources/Examples/` holds the three original device configs this repo
  replaced. `_resources/Research/` holds vendor bases pulled for diffing. Both
  are gitignored and exist purely for reference.
- `devices/.esphome/` is the local package cache and build output. Gitignored.

## Naming Convention

**Ecosystem wins over the PascalCase house style here**, per the global
preference to respect the ecosystem when they conflict:

- **YAML config files**: `kebab-case.yaml` — matches all three vendor repos
- **ESPHome ids and substitutions**: `snake_case` — **mandatory**, they become
  C++ identifiers
- **Entity names**: human-readable strings, and see the constraint below

Entity names in `packages/dynamic-volume.yaml` are deliberately kept identical
to the upstream package (`Dyn. Vol. Anchor`, `Dynamic Volume`, …) so Home
Assistant entity_ids survive the migration and existing dashboards and
automations keep working. **Do not "tidy" these names** — renaming orphans live
HA entities on deployed units.

## Core Architecture

Three layers, split by what the parameter belongs to:

| Layer | Owns | Example |
|---|---|---|
| package | behaviour shared by all hardware | filter chain, control law |
| profile | what a platform requires | `mic_id`, `mic_gain_factor`, vendor pin |
| device | what a unit needs | `name`, `ambient_min_db`, API key |

Parameters pass down through `!include` `vars:`, **not** global
`substitutions:`. Vars are lexically scoped: they do not leak into or out of the
global namespace, so a package cannot accidentally pick up a same-named
substitution from a vendor config. A package's own `substitutions:` block
supplies defaults for anything not passed.

Verified working three levels deep (device substitution → profile `vars:`
pass-through → package default fallback).

## Working on this repo

### Validation is the test suite

```bash
scripts/validate-all.sh            # all devices
scripts/validate-all.sh --clean    # clear cache first, proves pins fetch
```

`esphome config` resolves every remote package, applies every substitution, and
binds every id. A broken pin, a renamed vendor id, or a bad `!include` fails
here — no flashing needed.

**`esphome config` does not compile C++.** Lambdas are unchecked by it. After
touching any lambda, run `esphome compile devices/voice-pe-01.yaml`.

### After changing the microphone binding

Always confirm the resolved binding matches the wake word engine:

```bash
esphome config devices/<device>.yaml | grep -A6 'platform: sound_level'
```

`channels` and `gain_factor` must equal the device's `micro_wake_word`
microphone block. Mismatch is upstream bug 2 and is invisible without this check.

### Do not guess component ids

Resolve them from the merged config, or read the cached vendor file under
`devices/.esphome/packages/<hash>/`. Do not search GitHub — vendor branches and
tags diverge, and the cache is what the build actually uses.

## Coding Conventions

### Substitutions inside C++ lambdas

Substitution values are strings pasted verbatim into generated C++. Every
numeric parameter reaching a lambda **must** be wrapped:

```cpp
static_cast<float>(${dv_curve_exponent})
```

This one rule avoids three separate traps:

- `${x}f` renders `-42f` — not a valid literal
- a bare negative value can glue onto a preceding operator (`--42`)
- `clamp(v, ${a}, ${b})` fails template deduction if a bound is an integer

### Float guards

Use `std::isfinite`, **never** `std::isnan`. `sound_level` publishes `-inf` on
digital silence, and ESPHome's averaging filters only guard `isnan`, so a single
`-inf` poisons the accumulator permanently. This is upstream bug 5.

### YAML gotchas that have already bitten

- **A substitution inside a flow sequence does not parse.** `channels: [${x}]`
  fails; use a block sequence. YAML parses before substitution runs.
- **`packages:` list merging concatenates; it does not override.** `!extend` is
  needed to modify an existing entry — but prefer owning the whole file for
  anything reused across devices.
- **`logger:` is a plain dict and merges cleanly**, but only per-key. Setting
  `level:` on top of a vendor's `initial_level: debug` leaves their
  `initial_level` behind and ESPHome rejects the combination. Set both.
- **The global `logger.level` is a CEILING, not a default.** ESPHome refuses a
  per-tag level more verbose than the global one, so `logs: {ambient_sound:
  DEBUG}` requires `level: DEBUG` globally. Quiet the output by *raising* noisy
  tags (`sensor`, `component`, `api` to `WARN`), never by lowering the global.
- **`substitutions:` configure nothing by existing** — they only act where
  referenced as `${...}`. A `logger:`-shaped block nested under
  `substitutions:` silently does nothing. This was live in the original
  Satellite1 config.

### Home Assistant number entities must land on the step grid

HA requires `(value - min)` to be an exact multiple of `step`, and the check is
strict. `0.1` is not representable in binary floating point, so a *computed*
value like `-71.4` arrives as `-71.400001525878906` and the field reports
"enter a valid value" the moment it is focused.

Two rules follow, and both are needed:

- Any number whose value is **computed** rather than user-picked must use a step
  that is a negative power of two (`0.25`, `0.5`), so every grid point is exact.
- Quantise the computed value onto that grid before publishing —
  `roundf(v * 4.0f) / 4.0f` for a 0.25 step.

`Dyn. Vol. Anchor` and `Dyn. Vol. Strength` keep non-power-of-two steps and are
fine: they only ever hold user-set grid values, whose residual error is ~1e-7
and within browser tolerance. The bug only bites on computed values.

### Calibration bounds are restored, so YAML is a first-boot default

`Dyn. Vol. Noise Floor` and `Dyn. Vol. Loud Ceiling` are `restore_value: true`,
because a guided calibration that evaporated on power loss would be pointless.
The consequence: editing `ambient_min_db` / `ambient_max_db` in YAML and
reflashing appears to do nothing on a unit that has already been calibrated.
The **Reset Calibration** button is the escape hatch. Do not "fix" this by
flipping `restore_value` back.

### Vendor pins

Pin every vendor package to a tag or SHA. Never track `develop`/`main` with a
short `refresh:` — that already caused one silent breakage when an upstream
branch dropped a component. Note that pinning the package does **not** pin its
`external_components`; see the known gap in README.

## Known Issues & Gotchas

- **Calibration state (measured 2026-08-19).** Satellite1: fully calibrated,
  quiet -72.3 dB, active -67.8 median / -63.6 loudest, so `ambient_min_db: -71`,
  `ambient_max_db: -62`, `dv_curve_exponent: 0.7`; usable range only ~8.7 dB
  because the XMOS front-end applies AGC. PE: floor only, quiet -82.2 dB mean
  (sd 1.87) so `ambient_min_db: -78.5`; ceiling still 0 pending a loud sample.
  ReSpeaker: nothing measured.
  The PE floor sits ~7 dB below the Satellite1's with ~5x the sample spread,
  which is the AGC difference showing up in the data — **never copy calibration
  values between platforms.**
- **`external_components` float on moving refs** inside pinned vendor packages.
- **formatBCE has no tags**, so its pin is a bare SHA needing manual bumps.
- **ReSpeaker migration**: adopting the upstream base drops the old fork's
  custom `set_alarm_time` API action in favour of an `Alarm time` datetime
  entity. HA automations calling the old action break.
- **Local compiles can OOM** (`Killed signal terminated program cc1plus`),
  usually on the wake-word objects. That is host RAM, not a config problem.

## Git

- `git pull --rebase` always (alias `git pr`)
- Atomic, well-described commits
- `_resources/` must never appear in `git status`
- `devices/secrets.yaml` is gitignored; `secrets.yaml.example` is committed

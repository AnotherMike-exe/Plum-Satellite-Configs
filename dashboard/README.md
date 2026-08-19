# Dashboard-ready device files

Copy these into the **ESPHome Device Builder** add-on in Home Assistant
(`/config/esphome/`). Unlike the files in `devices/`, these pull the shared
config from GitHub instead of relative paths, so each one is self-contained and
works on its own inside the dashboard.

## Before you paste them

Add these to the dashboard's own `/config/esphome/secrets.yaml`:

```yaml
wifi_ssid: "..."                    # you probably already have these two
wifi_password: "..."

api_key_voice_pe_01: "..."          # copy from this repo's devices/secrets.yaml
api_key_satellite1_01: "..."
api_key_respeaker_lite_01: "..."

ota_password: "..."                 # required by the ReSpeaker base only
```

The API keys must match what Home Assistant already has stored for each device,
otherwise HA cannot reconnect after a flash.

## Keeping the node names

`name:` must stay exactly as written. Changing it registers a *new* device in
Home Assistant and orphans every entity, dashboard and automation attached to
the old one. Note the ReSpeaker's underscore — `respeaker_lite-formatbce` — it
is deliberate.

## Calibration values

The `ambient_min_db` / `ambient_max_db` values here are **first-boot defaults
only**. Each device stores its own calibration (`restore_value: true`), so a
unit that has already been calibrated keeps its measured values and ignores
these. Press **Reset Calibration** on the device to force the YAML values back.

## Updating

These pin `@v1.0.0`. The shared logic lives in this repo, so:

1. change `packages/` or `profiles/` here, push, and tag a new release
2. bump `@v1.0.0` to the new tag in the dashboard file
3. hit Install in the dashboard

Pin to a tag, never `@main` — otherwise any push to this repo silently changes
your firmware on the next build, which is the exact failure mode this repo
exists to avoid.

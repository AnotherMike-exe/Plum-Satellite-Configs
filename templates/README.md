# Templates — start here

**If this is your device, copy this file.** Nothing else in this repo needs to
be downloaded; the shared logic is fetched from GitHub at build time.

| Your hardware | Copy |
|---|---|
| Home Assistant Voice PE (Nabu Casa) | [`voice-pe.yaml`](voice-pe.yaml) |
| FutureProofHomes Satellite1 | [`satellite1.yaml`](satellite1.yaml) |
| formatBCE ReSpeaker Lite | [`respeaker-lite.yaml`](respeaker-lite.yaml) |

Each file has three marked edits: the device `name`, the `friendly_name`, and
the API key. Then flash and press the two Calibrate buttons.

## Secrets

Add these to the `secrets.yaml` next to wherever you put the file — in the
ESPHome Device Builder add-on that is `/config/esphome/secrets.yaml`:

```yaml
wifi_ssid: "..."
wifi_password: "..."
api_key_<your_device>: "..."     # must match what Home Assistant already stores
ota_password: "..."              # ReSpeaker Lite only
```

`!secret` resolves relative to the config file's own directory, so the
`secrets.yaml` has to sit beside the device file, not in a parent folder.

## Version pinning

Templates pin a release tag (`@v1.1.0`). Keep it pinned — tracking `@main`
means any push to this repo silently changes your firmware on the next build.

To take a newer release, bump the tag and hit Install.

## Plum Solutions' own units

Recorded here so the deployed configuration is documented somewhere durable.
These are the real values behind the reference figures in the templates:

| Device | Node name | Floor | Ceiling |
|---|---|---|---|
| HA Voice PE | `home-assistant-voice-09472d` | −78.5 dB | unmeasured |
| Satellite1 | `satellite1-d09ee8` | −71.25 dB *(device-stored)* | −62 dB |
| ReSpeaker Lite | `respeaker_lite-formatbce` | −74.0 dB | unmeasured |

The ReSpeaker's underscore is deliberate — it is that device's real node name.

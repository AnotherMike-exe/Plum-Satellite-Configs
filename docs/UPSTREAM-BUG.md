# The upstream dynamic-volume bugs

This repo exists because `jaapp/ha-voice-dynamic-volume` and its fork
`adri6412/ha-voice-dynamic-volume-2025` contain defects that make the feature
silently inert. "Silently" is the important word: nothing errors, nothing
warns, and the config compiles and flashes cleanly. The ambient sensor simply
reads `0%` forever while the logs show the microphone responding perfectly well
to real noise.

Every claim below is cited to ESPHome source. Line numbers are from **2026.7.4**.
Paths are relative to `esphome/` inside the installed package.

**This is a bug report, not a criticism.** The dynamic volume idea and its
implementation are jaapp's, and this package still follows that design closely
enough to keep the original entity names. The defects are genuinely subtle: the
central one stems from an ESPHome API that documents a sensor in "decibels" and
returns *negative dBFS*, so the natural reading of the value is the wrong one.
The feature looks like it works. Finding these took live hardware and a read of
the component source. Credit for the idea belongs upstream; this repo only
fixes the arithmetic.

---

## Bug 1 — dB compared against a linear amplitude threshold

**The feature never works at all. This is the headline bug.**

`components/sound_level/sound_level.cpp:124,132`:

```cpp
const float peak_db = 10.0f * log10f(static_cast<float>(this->squared_peak_) / MAX_SAMPLE_SQUARED_DENOMINATOR);
const double rms_db = 10.0 * log10((this->squared_samples_sum_ / MAX_SAMPLE_SQUARED_DENOMINATOR) / ...);
```

Both outputs are **dBFS**: `0 dB` is full scale, and everything quieter is
negative. A quiet room reads around `-50 dB`.

Upstream treats the value as a small positive linear amplitude:

```cpp
const float MIN_PEAK = 0.000024f;
const float MAX_PEAK = 0.9f;
float percentage = 0;
if (peak > MIN_PEAK) {          // -50.0 > 0.000024  ->  ALWAYS FALSE
  percentage = (peak - MIN_PEAK) / (MAX_PEAK - MIN_PEAK) * 100;
}
```

`percentage` is initialised to `0` and the branch never runs, so the sensor
publishes `0%` unconditionally. Downstream, `gain = 1 + (0/100 * strength) = 1`,
so the volume never moves off the anchor.

**Fix:** map the dB range onto the percentage range.

```cpp
const float pct = clamp((rms_db - floor_db) / (ceil_db - floor_db) * 100.0f, 0.0f, 100.0f);
```

---

## Bug 2 — the ambient sensor reads a different microphone channel than the wake word engine

**Silently miscalibrates every unit.**

`components/sound_level/sensor.py:44-46` types the `microphone:` key as
`microphone.microphone_source_schema(...)`. That schema
(`components/microphone/__init__.py:105-122`) defaults to:

```python
cv.Optional(CONF_CHANNELS, default="0"): ...
cv.Optional(CONF_GAIN_FACTOR, default="1"): ...
```

Upstream uses the bare shorthand `microphone: i2s_mics`, taking both defaults —
**channel 0 at gain 1**. But every target device runs `micro_wake_word` on
**channel 1** at **gain 4** (HA Voice PE, ReSpeaker Lite) or **gain 6**
(Satellite1).

On a stereo I2S microphone the two channels may be different capsules, or one
may be an echo-cancellation reference carrying a loopback of the device's own
speaker output. Gain multiplies the signal before the dB conversion, so it
shifts the entire measured scale.

The result is that a painstakingly measured noise floor describes a signal the
device does not otherwise use, and floors calibrated on two units are not
comparable even when the hardware is identical.

**Fix:** bind the source explicitly and match the device's `micro_wake_word`
block.

```yaml
microphone:
  microphone: sat1_mics
  channels:
    - 1
  gain_factor: 6
  bits_per_sample: 16
```

---

## Bug 3 — the playback guard blocks almost every state

**Disables the feature for most of the device's life.**

`components/media_player/media_player.h:35-41`:

```cpp
MEDIA_PLAYER_STATE_NONE = 0,
MEDIA_PLAYER_STATE_IDLE = 1,
MEDIA_PLAYER_STATE_PLAYING = 2,
MEDIA_PLAYER_STATE_PAUSED = 3,
MEDIA_PLAYER_STATE_ANNOUNCING = 4,
MEDIA_PLAYER_STATE_OFF = 5,
MEDIA_PLAYER_STATE_ON = 6,
```

Upstream guards with `state != MEDIA_PLAYER_STATE_IDLE`, intending "is audio
playing?". That test is true for **five of the seven** states, including three
in which nothing is playing:

- `NONE` — the member's initial value (`media_player.h:150`), i.e. before the
  media player's `setup()` has run. Ambient measurement is frozen for the whole
  early-boot window.
- `PAUSED` — nothing is coming out of the speaker; there is no feedback to guard.
- `OFF` — `components/speaker/media_player/speaker_media_player.cpp:57` sets
  `OFF` at boot when on/off triggers are configured, and the state is restored
  across reboots. Turn the media player off once and dynamic volume is dead
  permanently.

**Fix:** test positively for the two states that actually emit audio.

```cpp
if (mp_state == media_player::MEDIA_PLAYER_STATE_PLAYING ||
    mp_state == media_player::MEDIA_PLAYER_STATE_ANNOUNCING) { /* skip */ }
```

---

## Bug 4 — `return 0.0` on a dBFS sensor means *maximum* loudness

Upstream's filter substitutes `0.0` whenever the wake word engine is not ready:

```cpp
if (!id(mww).is_ready()) {
   return 0.0;
}
```

On a dBFS scale `0.0` is **full scale — the loudest reading the microphone can
produce**. Once Bug 1 is fixed, that maps to `100%` and drives the volume to
maximum. The bug is masked upstream only because Bug 1 pins the sensor at zero.

The same lambda also returns `id(ambient_sound_peak).state` to "hold" the
previous value during playback. That injects a synthetic duplicate sample into
every downstream averager, biasing the average toward whatever the value
happened to be when playback began.

**Fix:** drop the sample. A filter lambda returns `optional<float>`, and
`return {};` discards the reading without disturbing the filter chain.

---

## Bug 5 — `-inf` permanently bricks the sensor

**Not present upstream by luck rather than design — and easy to reintroduce.**

The accumulators in `sound_level.cpp` are reset to `0` after each window
(`:127`, `:136`). If the microphone feeds digital silence — a hardware mute, a
muted XMOS path, a dead channel — then `squared_samples_sum_ == 0` and the
published value is `10 * log10(0)` = **`-inf`**, not `NaN`.

`components/sensor/filter.cpp:147-155`:

```cpp
optional<float> ExponentialMovingAverageFilter::new_value(float value) {
  if (!std::isnan(value)) {                       // -inf passes this guard
    ...
    this->accumulator_ = (this->alpha_ * value) + (1.0f - this->alpha_) * this->accumulator_;
```

`alpha * -inf + (1-alpha) * accumulator` is `-inf`, and every subsequent sample
keeps it there. The sensor is dead until reboot.
`SlidingWindowMovingAverageFilter::compute_result` (`filter.cpp:131-142`) has
the same hole.

**Fix:** guard with `std::isfinite`, never `std::isnan`, and reject anything
below the 16-bit noise floor:

```cpp
if (!std::isfinite(x) || x < -95.0f) return {};
```

---

## Bug 6 — the disable action stomps the volume on every boot

`components/template/switch/template_switch.cpp:37-52` — `setup()` calls
`turn_off()` for `RESTORE_DEFAULT_OFF`, which fires `turn_off_trigger_`. So the
switch's `turn_off_action` runs on **every boot**, not only when a user turns
the switch off.

Upstream's `turn_off_action` sets the media player volume to the anchor, so
every reboot silently overwrites the user's restored volume.

Worse, the ordering is wrong. `TemplateSwitch::get_setup_priority()` is
`HARDWARE - 2.0f` = **798** (`template_switch.cpp:34`), while both media player
platforms are `setup_priority::PROCESSOR` = **400**
(`speaker_source/speaker_source_media_player.h:153`,
`speaker/media_player/speaker_media_player.h:53`). Higher priority runs first,
so the action reaches a media player that has not been set up yet.

**Fix:** track whether this package has actually applied a volume this session,
using a non-restored `NAN` sentinel, and bail out when it has not.

```cpp
if (!std::isfinite(id(last_dynamic_volume_calculation))) return;
```

---

## Also corrected, though not strictly bugs

**~50 s response latency.** Upstream chains two template sensors, each with
`update_interval: 5s` + `sliding_window_moving_average{window_size: 5, send_every: 5}`
+ `throttle_average: 5s` — about 25 s per stage. The second reads the first's
*already published* state and re-applies the identical chain, so ambient changes
took the better part of a minute to reach the volume. This package publishes the
percentage from the dB sensor's `on_value` trigger and filters once, reaching
90% of a step in roughly 7.5 s.

**`peak` instead of `rms` as the driver.** `sound_level.cpp:107` keeps a running
maximum across the window, so one door slam pins `peak` for the whole
measurement. `rms` (`:112`) is a true energy mean and the correct statistic for
a noise floor. This package drives volume from `rms` and publishes `peak` as a
diagnostic.

**Transient rejection.** A moving average cannot reject an outlier, only smear
it. A `median` filter ahead of the smoothing stage rejects any transient shorter
than half its window outright, which is what stops brief noises from pumping the
volume.

**`abs()` on a float.** Upstream's deadband uses `abs(new_volume - last)`. A
bare `abs()` can resolve to the integer overload and truncate, which would widen
the deadband to `1.0` and suppress every update. This package uses `fabsf()`.

**A `logger:` key inside the package.** Upstream sets `logger: level: INFO`,
which silently overrides whatever the device file asked for. This package sets
no `logger:` key at all.

---

## Upstream reporting

Bugs 1–4 and 6 affect anyone installing either upstream package as-is. Both
repos are unmodified in this respect at the time of writing, and the fixes are
small and self-contained — none of them changes the design, only the arithmetic
and the guard conditions.

Offering these upstream is on the roadmap in `README.md`. If you maintain
either repository and want to take any of this, please do; no attribution to
this repo is required or expected.

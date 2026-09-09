# Countdown

Native macOS app with a shared Countdown core and three modes: Pomodoro, Timer, and Countdown.
See the [source organization](docs/architecture.md).

## Usage

- Click the circle to toggle between Normal mode and Compact mode.
- In Timer or Countdown mode, Option-click the circle to set the timeout to end exactly on the next hour.
- Scroll up or down to move an end to the next or previous five-minute mark. Hold Option to add or subtract one minute instead.
- Right-click the Countdown window and toggle settings or select **Quit Countdown** to quit.
- Select **Pomodoro**, **Timer**, or **Countdown** from **View**. Timer and Pomodoro show a clock. Countdown uses the timer without a clock. Pomodoro repeats focus periods with short rests, then a long rest. The default is four focus periods. Dots show focus progress.
- All views share the same remaining time: focus plus the current rest. Timer and Countdown edits change focus first. Pomodoro repeats only while its view is selected.
- Countdown starts automatically. Use **Pause** or **Resume** in the right-click menu. These controls apply to all three modes; a mode change does not stop the countdown.
- In **Timer** and **Pomodoro** modes, edits set fixed end times. A focus edit moves both rest end times to keep their durations constant. A rest edit changes only that rest end time. The selected spacing repeats. Pause freezes the countdown; resume shifts the end times without rounding. **Countdown** mode uses durations. Only scrolling without Option aligns values to five-minute marks.

## Configuration

Countdown reads its configuration from `$XDG_CONFIG_HOME/countdown/config.toml` or `~/.config/countdown/config.toml`

See [the default configuration](resources/config.toml) for all properties.
Restart Countdown after configuration changes. Saved Pomodoro duration edits
take priority over configuration defaults.

`notification_enabled` controls interval notifications, including text and sound.
`notification_audio_enabled` controls notification sound only.
`alarm_enabled` controls the timeout alarm independently.

`notification_time_seconds` sets how long the centered notification stays visible
between fades (default: 5 seconds). `notification_font_size_pt` sets its font size in
points (default: 144). `notification_fade_time_seconds` sets the duration of each fade
(default: 1.5 seconds; zero disables fades).
`notification_interval_minutes` defaults to 15 and rounds to the nearest
multiple of 5, with a minimum of 5 minutes. Notifications count backwards from
the active end time and include that end time. Sound paths are relative to
`config.toml`.

The selected mode, notification and alarm enablement, auto-set, and timer state are stored
under `${XDG_STATE_HOME:-$HOME/.local/state}/countdown/`. Mode and Pomodoro settings
use `settings.json`; other menu choices use `features.json`. Menu changes do not
modify `config.toml`.

## Dev 

See [automated checks](docs/testing.md) for test discovery and focused test commands.

```sh
mise run deploy
```


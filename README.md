# Countdown

Native macOS app with a shared Countdown core and three modes: Pomodoro, Timer, and Countdown.
See the [source organization](docs/architecture.md).

## Usage

- Click the circle to toggle between Normal mode and Compact mode.
- In Timer or Countdown mode, Option-click the circle to set the timeout to end exactly on the next hour.
- Scroll up or down to move an end to the next or previous five-minute mark.
- Right-click the Countdown window and toggle settings or select **Quit Countdown** to quit.
- Select **Pomodoro**, **Timer**, or **Countdown** from **Timer mode**. Timer and Pomodoro show a clock. Countdown uses the timer without a clock. Pomodoro repeats focus periods with short rests, then a long rest. The default is four focus periods. Dots show focus progress. Use **End times** in the right-click menu to adjust times.
- Countdown starts automatically. Use **Pause** or **Resume** in the right-click menu. These controls apply to all three modes; a mode change does not stop the countdown.
- In **Timer** and **Pomodoro** modes, edits set fixed end times. A focus edit moves both rest end times to keep their durations constant. A rest edit changes only that rest end time. The selected spacing repeats. Pause freezes the countdown; resume shifts the end times and rounds them to the nearest five-minute marks. **Countdown** mode uses durations and resumes without rounding.

## Configuration

Countdown reads its configuration from `$XDG_CONFIG_HOME/countdown/config.toml` or `~/.config/countdown/config.toml`

```toml
[pomodoro]
# Defaults in minutes; saved duration edits take priority.
focus = 25
rest = 5
long-rest = 15
# Focus periods before a long rest (1–12).
cycles = 4

[notifications]
popup_time = 5

# Relative paths are relative to config.toml.
green_notification = "green_notification.mp3"
yellow_notification = "yellow_notification.mp3"
red_notification = "red_notification.mp3"
alarm_notification = "alarm_notification.mp3"
```

`popup_time` is the popup interval in minutes: 5, 10, 15, 20, and so on.
Invalid values use 5 minutes. The first popup rounds up to a 5-minute clock
boundary after the interval; later popups keep that clock schedule.

The selected mode, popup and alarm enablement, auto-set, and timer state are stored
under `${XDG_STATE_HOME:-$HOME/.local/state}/countdown/`. Mode and Pomodoro settings
use `settings.json`; other menu choices use `features.json`. Menu changes do not
modify `config.toml`.

## Dev 

See [automated checks](docs/testing.md) for test discovery and focused test commands.

```sh
mise run deploy
```


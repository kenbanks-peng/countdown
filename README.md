# Countdown

Native macOS app with a shared Countdown core and two UI modes: Timer and Pomodoro.
See the [source organization](docs/architecture.md).

## Usage

- Click the circle to toggle between Normal mode and Compact mode.
- Option-click the circle to set the timeout to end exactly on the next hour.
- Scroll up to add time and scroll down to remove time in one-minute steps. Hold Option while you scroll for slower, precise one-minute adjustment. 
- Right-click the Countdown window and toggle settings or select **Quit Countdown** to quit.
- Select **Timer** or **Pomodoro** from **Timer Mode**. Pomodoro repeats four focus periods with short rests, then a long rest. Four dots show focus progress. Use **Durations** in the right-click menu to adjust times.
- Countdown starts automatically. Use **Pause** or **Resume** in the right-click menu. These controls apply to both modes; a mode change does not stop the countdown.

## Configuration

Countdown reads its configuration from `$XDG_CONFIG_HOME/countdown/config.toml` or `~/.config/countdown/config.toml`

```toml
[pomodoro]
# Defaults in minutes; saved duration edits take priority.
focus = 25
rest = 5
long-rest = 15

[notifications]
reminder_time = 5

# Relative paths are relative to config.toml.
green_notification = "green_notification.mp3"
yellow_notification = "yellow_notification.mp3"
red_notification = "red_notification.mp3"
alarm_notification = "alarm_notification.mp3"
```

`reminder_time` is the reminder interval in minutes: 5, 10, 15, 20, and so on.
Invalid values use 5 minutes. The first reminder rounds up to a 5-minute clock
boundary after the interval; later reminders keep that clock schedule.

Display choices, reminder and alarm enablement, auto-set, and timer state are stored
under `${XDG_STATE_HOME:-$HOME/.local/state}/countdown/`. Menu choices use
`features.json`; menu changes do not modify `config.toml`.

## Dev 

See [automated checks](docs/testing.md) for test discovery and focused test commands.

```sh
mise run deploy
```


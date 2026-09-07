# Countdown

Native macOS app with a shared Countdown core and two UI modes: Timer and Pomodoro.
See the [source organization](docs/architecture.md).

## Usage

- Click the circle to toggle between Normal mode and Compact mode.
- Option-click the circle to set the timeout to end exactly on the next hour.
- Scroll up to add time and scroll down to remove time in one-minute steps. Hold Option while you scroll for slower, precise one-minute adjustment. 
- Right-click the Countdown window and toggle settings or select **Quit Countdown** to quit.
- Select **Timer** or **Pomodoro** from **Timer Mode**. Pomodoro uses a 25-minute focus period and a 5-minute break.
- Countdown starts automatically. Use **Pause** or **Resume** in the right-click menu. These controls apply to both modes; a mode change does not stop the countdown.

## Configuration

Countdown reads its configuration from `$XDG_CONFIG_HOME/countdown/config.toml` or `~/.config/countdown/config.toml`

```toml
[display]
clock_face_enabled = true
clock_hands_enabled = true
current_timeout_enabled = true

[notifications]
reminder_enabled = true
reminder_time = 5
alarm_enabled = true

# Relative paths are relative to config.toml.
green_notification = "green_notification.mp3"
yellow_notification = "yellow_notification.mp3"
red_notification = "red_notification.mp3"
alarm_notification = "alarm_notification.mp3"
```

`reminder_time` is the reminder interval in minutes: 5, 10, 15, 20, and so on.
Invalid values use 5 minutes. The first reminder rounds up to a 5-minute clock
boundary after the interval; later reminders keep that clock schedule.

## Dev 

See [automated checks](docs/testing.md) for test discovery and focused test commands.

```sh
mise run deploy
```


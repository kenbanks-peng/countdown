# Countdown

Native macOS app with three modes: Pomodoro, Timer, and Countdown. Requires macOS 13 or later.

## Usage

- Click the circle to switch between normal and compact views.
- Drag the circle to move the window in each of the modes to set the transition path.
- Right-click opens the menu. Select **Pomodoro**, **Timer**, or **Countdown** under **View**.
- On first launch, Timer is empty. Mouse scroll up over the circle to set a time and start it. Select **Pause** to pause; clear **Pause** to resume.
- Scroll over the circle to increase or decrease time. Timer and Pomodoro move the selected end time to the next or previous five-minute clock mark. Countdown moves the remaining duration to a five-minute mark. Hold Option when you scroll for finer adjustments.
- In Pomodoro, mouse scroll while over the blue sector to alter the rest duration. Likewise, mouse scroll while over the focus sector or background to alter the focus duration.
- Pomodoro runs focus periods with short rests, then a long rest after the final focus period. Click a dot to restart focus at that position. Option-click a dot to also restore default durations.
- **Loop** controls repetition in the selected mode.
- Select **Align** to end the timeron the hour or half hour.
- **Notifications** controls notifications in all modes.
- **Show value** controls the remaining-minute label in Timer and Countdown.

## Configuration

Countdown reads `${XDG_CONFIG_HOME:-$HOME/.config}/countdown/config.toml`.

See [the supplied configuration](resources/config.toml) for the main settings.
Put `size` and `compact_size` at the top level, notification and alarm settings
under `[notifications]`, and focus, rest, long-rest, and cycle settings under `[pomodoro]`.
Restart Countdown after configuration changes. Saved Pomodoro duration edits
take priority over configuration defaults; Option-click a Pomodoro dot to restore
the configured durations.

`notification_enabled` permits interval and Pomodoro phase-change notifications,
including text and sound. It must be `true` for the **Notifications** menu option
to work. `notification_audio_enabled` controls notification sound only.
`alarm_enabled` controls the Timer and Countdown timeout alarm independently;
it does not add an alarm to Pomodoro.

`notification_time_seconds` sets how long the centered notification stays visible
between fades. `notification_font_size_pt` sets its font size in points.
`notification_fade_time_seconds` sets the duration of each fade; zero disables fades.
The supplied file uses 5 seconds, 600 points, and 0.8 seconds respectively.
If these keys are absent, the built-in defaults are 5 seconds, 144 points, and 1.5 seconds.
The supplied file disables notification audio and the timeout alarm; both are enabled
by default if their keys are absent.

`notification_interval_minutes` defaults to 15 and rounds to the nearest
multiple of 5, with a minimum of 5 minutes. Timer and Countdown notifications
count backwards from the end time, including zero. Pomodoro interval notifications
count backwards from the focus end; phase changes show work or rest notifications.
Relative sound paths are resolved from the directory that contains `config.toml`;
absolute paths are also accepted.

Saved state is stored under `${XDG_STATE_HOME:-$HOME/.local/state}/countdown/`.
`settings.json` stores the mode, pause state, and Pomodoro settings and schedule.
`features.json` stores menu choices such as Notifications, Loop, and Show value.
`session.json` stores timer progress. A saved disabled alarm setting in `features.json`
also suppresses the alarm. Menu changes do not modify `config.toml`.

## Development and installation

With Swift 6 or later (for Swift Testing) and mise installed, run these commands from the repository:

```sh
mise run check   # Check source organization and run tests.
mise run deploy  # Build, install, and register the app to start at login.
```

Deployment installs the executable in the repository's `bin/` directory. It copies
`resources/config.toml` only if no configuration file exists, installs the sound files,
and creates a macOS LaunchAgent. It starts or restarts the app when the executable,
image resources, or LaunchAgent changes. Configuration-only changes require a restart.

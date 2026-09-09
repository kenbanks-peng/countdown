# Source organization

Countdown uses one SwiftPM executable target. Source folders define ownership;
`tools/check-architecture` checks references between the main source layers.
The Swift build checks types and call sites.

## Source layers

| Path | Responsibility |
| --- | --- |
| `src/App/AppDelegate.swift` | Start the app and save state at shutdown. |
| `src/App/CountdownController.swift` | Select a mode, apply controls, route notifications, and save settings. |
| `src/App/Window/` | Own the floating panel, saved placement, reminder display, and transitions. |
| `src/App/Input/` | Convert scroll gestures and pointer locations into time edits. |
| `src/App/Views/` | Combine mode views, the clock, reminder details, menus, and the update task. |
| `src/Core/Timing/` | Share run state, five-minute clock rounding, and notification time bands. |
| `src/Core/Timer/` | Own timer progress, pause/resume, timeout actions, and `session.json`. |
| `src/Core/Pomodoro/` | Own focus/rest cycles, duration edits, and absolute clock schedules. |
| `src/Core/Notifications/` | Schedule reminders and play notification sounds. |
| `src/Core/Configuration/` | Read supported configuration fields and apply defaults. |
| `src/Core/Persistence/` | Store app settings and menu preferences with shared atomic JSON writes. |
| `src/Core/UI/` | Share colors, circle geometry, clock drawing, and sector layout. |
| `src/Modes/Timer/` | Draw Timer and Countdown in normal or compact form; provide timer menu controls. |
| `src/Modes/Pomodoro/` | Draw Pomodoro focus/rest sectors and progress dots. |

Core must not reference App or Modes. A mode must not reference App or another
mode. Both timing models remain in Core because they keep running when hidden.
Mode folders contain presentation code, not separate countdown engines.

## Ownership and data flow

`AppDelegate` owns `CountdownWindowController`. The window controller owns the
panel, countdown controller, scroll monitor, reminder subscription, and
`CountdownReminderController`. The reminder uses a separate, non-interactive panel. It
starts transparent at the center of the countdown window's screen, fades in,
waits for the configured duration, then fades out. It does not move, change the
main window's mode, or save window placement. It shows whole minutes for the
current timer or Pomodoro Focus period. At the start of Rest, it shows `REST`.
No interval reminders occur during Rest. Reminders resume at the next Focus period.
`CountdownPanelTransition` contains manual mode animation operations; it does not own
countdown state. `CountdownWindowStateStore` contains placement rules and saved
window keys.

`CountdownController` owns `CountdownEngine` and `ReminderScheduler`. The engine owns
the Timer and Pomodoro models and their shared pause state. A mode change changes
the display and timeout policy, not that shared run state. Model change signals
pass through the engine and controller to the view.

The view update task samples time every 100 ms. Timer and Pomodoro updates use
absolute dates. Scroll input uses uptime for gesture timing. Timer and Countdown
share one `TimerView`; its compact setting controls labels, spacing, and strokes.
Drawing and hit testing use the same circle inset and sector calculations.

Keep each timing state machine together. Its private setters keep duration,
remaining time, endpoints, and run state consistent. Separate files contain
storage operations, clock schedule rules, and shared rounding rules; splitting
the private state across extensions would weaken this ownership.

## Configuration, appearance, and stored state

- `resources/config.toml` is the user configuration template. Its adjacent sound
  files are installed beside the user configuration file.
- `src/Core/Resources/` contains bundled clock images. SwiftPM and deployment use
  this same directory. These files are not user configuration.
- `CountdownAppearance.swift` owns shared colors and circle sizes.
  `TimerAppearance.swift` maps shared urgency bands to timer colors. There is no
  separate theme configuration.
- Configuration parsing scans the supported fields once. It keeps first-match
  behavior, section-scoped Pomodoro fields, unscoped notification lookup, sound
  path resolution, and existing fallback rules. It is not a full TOML parser.
- `settings.json` stores mode, pause state, and Pomodoro settings/schedule.
  `features.json` stores menu choices. `session.json` stores the timer session.
  Each store owns its schema and validation; `JSONStateFile` owns JSON I/O.
- Missing or invalid state uses the existing fallback. A failed write does not
  stop the in-memory countdown. Menu changes do not rewrite user configuration.
- Window placement uses separate `UserDefaults` keys.

Existing configuration keys, JSON fields, mode names, window keys, and launch
commands remain unchanged. Internal names describe their purpose: for example,
`focusPeriodsPerCycle`, `showsRemainingMinutes`, `isAutoSetToNextHourEnabled`,
`reminderIntervalMinutes`, and `sessionStore`.

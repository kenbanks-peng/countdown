# Source organization

Countdown uses one SwiftPM executable target. Source folders define ownership;
`tools/check-architecture` checks references between the main source layers.
The Swift build checks types and call sites.

## Source layers

| Path | Responsibility |
| --- | --- |
| `src/App/AppDelegate.swift` | Start the app and save state at shutdown. |
| `src/App/CountdownController.swift` | Select a mode, apply controls, route notifications, and save settings. |
| `src/App/Window/` | Own the floating panel, saved placement, notification display, and transitions. |
| `src/App/Input/` | Convert scroll gestures and pointer locations into time edits. |
| `src/App/Views/` | Combine mode views, the clock, notification details, menus, and the update task. |
| `src/Core/Timing/` | Share run state, five-minute scroll alignment, and notification time bands. |
| `src/Core/Timer/` | Own timer progress, pause/resume, timeout actions, and `session.json`. |
| `src/Core/Pomodoro/` | Own focus/rest cycles, duration edits, and absolute clock schedules. |
| `src/Core/Notifications/` | Schedule notifications and play notification sounds. |
| `src/Core/Configuration/` | Read supported configuration fields and apply defaults. |
| `src/Core/Persistence/` | Store app settings and menu preferences with shared atomic JSON writes. |
| `src/Core/UI/` | Share colors, circle geometry, clock drawing, and sector layout. |
| `src/Modes/Timer/` | Draw Timer and Countdown in normal or compact form; provide timer menu controls. |
| `src/Modes/Pomodoro/` | Draw Pomodoro focus/rest sectors and progress dots. |

Core must not reference App or Modes. A mode must not reference App or another
mode. Both timing models remain in Core. Only the selected view advances the
shared time. Mode folders contain presentation code, not separate countdown engines.

## Ownership and data flow

`AppDelegate` owns `CountdownWindowController`. The window controller owns the
panel, countdown controller, scroll monitor, notification subscription, and
`CountdownNotificationController`. The notification uses a separate, non-interactive panel. It
starts transparent at the center of the countdown window's screen, fades in while
its content grows from 35% to full size with an ease-in-out curve, waits for the
configured duration, then grows to 300% with an ease-in curve as it fades out.
Each scale effect uses the fade duration and keeps the content centered without
overshoot. Transparent panel space prevents clipping during the outward scale.
Reduce Motion disables both scale effects. It does not move, change the
main window's mode, or save window placement. It shows whole minutes for the
current timer or Pomodoro Focus period. At the start of Rest, it shows `REST`.
No interval notifications occur during Rest. Notifications resume at the next Focus period.
`CountdownPanelTransition` contains manual mode animation operations; it does not own
countdown state. `CountdownWindowStateStore` contains placement rules and saved
window keys.

`CountdownController` owns `CountdownEngine` and `NotificationScheduler`. The engine owns
the Timer and Pomodoro representations and their shared pause state. The active
view owns progress and completion; the inactive representation follows its remaining
time without completion actions. Timer and Countdown show focus remaining plus
active rest remaining. Their edits change focus first and can remove it. An increase
during rest can restore focus without restoring spent rest. The schedule records
spent rest separately so future stages retain the rest allocation.

Auto Repeat is a shared menu preference, off by default. Timer and Countdown
capture their repeat duration after an explicit edit or on mode entry. Elapsed
time, pause/resume, and inactive projections do not change that duration. The
timer session stores it separately from current progress. At timeout, the selected
timer view starts that duration again from the update time when Auto Repeat is on.
Clicking a Pomodoro cycle indicator starts work at that stage with full allocations,
resumes the shared countdown, and sends a WORK notification when notifications are enabled.
It does not change the window presentation. Earlier indicators show as completed.
Pomodoro always advances through its stages. After the final long rest, it returns
to the first stage only when Auto Repeat is on; otherwise it stops with zero time
and pauses the engine. Resume starts a new cycle. Only the selected view repeats.
Selecting Pomodoro with an empty timer starts
a new cycle. Selecting Timer or Countdown caps the total at 60 minutes by reducing
focus and preserving the active rest. This reduction remains after switching back.
Entering Pomodoro reserves at least five minutes of active rest. It reduces focus
first and increases the total only when less than five minutes remain. Rest edits
also leave at least five minutes from the later of the focus end and the current
clock reference. In Pomodoro, scrolling on focus or background adjusts focus.
During rest, either scroll direction first raises rest to at least five minutes
if needed. Further increases in the same gesture restore focus in the current
stage and keep unspent rest. Decreases at zero focus leave the expired focus
endpoint unchanged, so they cannot end rest or start another stage. Scrolling on the blue sector continues to adjust rest only.
Normal countdown can still finish rest. A view change otherwise
preserves remaining time and pause state. Align is available in every view.
It selects the first valid :00 or :30 boundary. If that endpoint is already selected
and a second boundary is valid, it selects the second instead. Repeated use switches
between the two; a single valid boundary stays selected. Timer and Countdown leave
at least five minutes, stay within one hour, keep the pause state, and save the new
repeat duration. Pomodoro selects from the next two half-hour boundaries and excludes
only endpoints less than five minutes away. Align also works during rest. It raises
remaining active rest to at least five minutes, shortens it if necessary to fit the
endpoint, and fills the time before rest with focus. Spent rest is cleared from the
new allocation. The inactive short-rest allocation is capped to keep its focus-plus-rest
total within one hour.
A paused alignment uses the current wall time and stays paused; a later resume
moves the endpoints by the pause duration. The schedule saves the prior focus
allocation and restores it at the next stage. A manual focus edit replaces that
saved allocation. Model change signals pass through the engine and controller to
the view.

The view update task samples time every 100 ms. Timer and Pomodoro updates use
absolute dates. Scroll input uses uptime for gesture timing. Timer and Countdown
share one `TimerView`; its compact setting controls labels, spacing, and strokes.
Drawing and hit testing use the same circle inset and sector calculations.

Keep each timing state machine together. Its private setters keep duration,
remaining time, endpoints, and run state consistent. Separate files contain
storage operations, clock schedule rules, and scroll alignment rules; splitting
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

Internal names describe their purpose: for example,
`focusPeriodsPerCycle`, `showsRemainingMinutes`, `isAutoRepeatEnabled`,
`notificationIntervalMinutes`, and `sessionStore`.

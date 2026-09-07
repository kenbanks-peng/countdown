# Countdown architecture

Countdown provides common functionality. Timer and Pomodoro are two UI modes
that use this core. They are not separate apps.

## Source ownership

```text
src/
├── App/                 # Startup, window, input routing, and mode composition
│   ├── CountdownController.swift
│   └── CountdownView.swift
├── Core/                # Common Countdown functionality
│   ├── Configuration/   # User configuration
│   ├── Persistence/     # App settings, Timer session, and state-directory lookup
│   ├── Timing/          # Shared engine and its Timer and focus/rest records
│   ├── Resources/       # Shared clock images
│   ├── UI/              # Clock, feature menu, colors, and radial shape
│   ├── CountdownFeatures.swift
│   ├── CountdownMode.swift
│   └── CountdownSound.swift
└── Modes/
    ├── Timer/           # Timer views, appearance, and menu
    └── Pomodoro/        # Focus/rest view and mode color
```

- `Core/` must not depend on `App/` or either mode.
- Each mode can use `Core/`, but must not depend on the app controller or the
  other mode. Mode views receive models and action closures.
- `App/` connects the core and modes. `CountdownController` selects the active
  mode and routes commands. `CountdownView` adds shared controls to mode views.
- `Core/Timing/CountdownEngine` owns both timing records and one run state.
  It starts automatically. Pause and resume apply to both records, including
  records that are not visible. A mode change does not change the run state.
- Both records advance while the engine runs. Pomodoro repeats four focus periods,
  with short rests after the first three and a long rest after the fourth.
  The next cycle starts automatically. Reset starts a fresh cycle and keeps the
  core run state. Duration edits keep elapsed time and apply to later stages;
  completed focus does not reopen. Focus, rest, and long-rest allocations are
  separate. Each focus/rest pair fits within the one-hour display.
  Normal view shows four dots: filled for completed focus, a ring with a center
  dot for current focus, and an empty ring for future focus. Compact view keeps
  its sector-only display.
- The selected UI mode controls timeout actions through `CountdownController`.
  Timer mode enables its alarm and Autoset actions. Hidden Timer timeouts are
  discarded, not replayed when Timer mode is selected. Pomodoro stages advance
  without an alarm. Reminder uses one shared clock schedule with an interval
  that is a positive multiple of five minutes. Invalid intervals use five minutes.
  The first reminder is the start time plus the interval, rounded up to a
  five-minute clock boundary. Later reminders retain that schedule, including
  after a pause. Paused reminders are skipped. Duration edits and mode changes
  do not move the schedule. Hidden records and restored elapsed time do not
  produce Reminder events. A late update emits at most one event and advances
  to the next original clock boundary. Timer completion clears the schedule;
  Pomodoro stage changes keep it.
- Countdown also owns clock settings, Reminder notifications, sound playback,
  configuration, and session storage. Modes own presentation, not timing.
- Shared UI colors are in `Core/UI/CountdownColors.swift`. Each mode owns its
  specific appearance rules.
- `CountdownArcLayout` supplies sector positions for drawing and scroll selection.
  The Clock setting controls the face and hands together and selects clockwise
  clock-aligned sectors in both window sizes. Compact view omits the clock face and hands, but keeps the same sectors.
  With this setting off, sectors stay fixed at 12. In clock-aligned mode, Pomodoro
  scroll selection follows the remaining colored sectors. In duration-only mode,
  configured allocations remain scroll targets after their color has depleted.

These folders belong to one SwiftPM executable target. They are source ownership
boundaries, not separate compiled modules. `tools/check-architecture` checks
cross-layer type-name references. It does not replace Swift type checking.

## State and resources

The shared state directory is `$XDG_STATE_HOME/countdown` or
`~/.local/state/countdown`.

- `settings.json` stores the selected mode (`Timer` or `Pomodoro`) and configured
  focus, short-rest, and long-rest durations, plus the shared pause state. It does
  not store Pomodoro progress. A launch creates a fresh cycle that follows the shared
  run state. If the pause field is absent, a saved paused Timer record supplies
  the pause state; otherwise the engine starts automatically.
- `[pomodoro]` in `config.toml` supplies `focus`, `rest`, and `long-rest` defaults
  in minutes (25, 5, and 15). Saved allocations take priority. Values must be
  whole minutes from 1 to 59; focus plus either rest must not exceed 60 minutes.
  Invalid fields use standard defaults. An invalid total uses all three standard
  defaults. The right-click Durations menu can edit any allocation at any stage.
  Scrolling the rest sector edits short rest in stages 1–3 and long rest in stage 4.
- `session.json` stores only the Timer session.
- No migration or compatibility aliases are provided for the old settings file,
  mode name, Swift names, or source paths.

SwiftPM packages `src/Core/Resources`. The deploy task uses the same path.
The root `resources/` folder holds the user configuration template and sounds
that the deploy task installs outside the app bundle.

## Checks

Run these commands from the repository root:

```sh
./tools/check-architecture
./tools/swift-test
swift build -c release
```

`Tests/App/` checks mode integration, persistence, input, and rendered views.
`Tests/Core/` checks shared persistence and timing. `Tests/Modes/` checks mode behavior.
`Tests/Support/` holds shared test helpers.
`Tests/CircleTransitionCheck.swift` is a standalone visual check and remains
excluded from the SwiftPM test target.

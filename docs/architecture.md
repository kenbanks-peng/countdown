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
│   ├── Timing/          # Shared engine and its Timer and focus/break records
│   ├── Resources/       # Shared clock images
│   ├── UI/              # Clock, feature menu, colors, and radial shape
│   ├── CountdownFeatures.swift
│   ├── CountdownMode.swift
│   └── CountdownSound.swift
└── Modes/
    ├── Timer/           # Timer views, appearance, and menu
    └── Pomodoro/        # Focus/break view and mode color
```

- `Core/` must not depend on `App/` or either mode.
- Each mode can use `Core/`, but must not depend on the app controller or the
  other mode. Mode views receive models and action closures.
- `App/` connects the core and modes. `CountdownController` selects the active
  mode and routes commands. `CountdownView` adds shared controls to mode views.
- `Core/Timing/CountdownEngine` owns both timing records and one run state.
  It starts automatically. Pause and resume apply to both records, including
  records that are not visible. A mode change does not change the run state.
- Both records advance while the engine runs. Timer completion and the end of
  a focus/break pair do not pause the engine. Reset prepares a new pair and
  keeps the core run state. Timer duration edits also keep that run state.
- The selected UI mode controls timeout actions through `CountdownController`.
  Timer mode enables its alarm and Autoset actions. Hidden Timer timeouts are
  discarded, not replayed when Timer mode is selected. A Pomodoro pair ends
  without an alarm. Wakeup uses elapsed time from the selected mode only.
- Countdown also owns clock settings, Wakeup notifications, sound playback,
  configuration, and session storage. Modes own presentation, not timing.
- Shared UI colors are in `Core/UI/CountdownColors.swift`. Each mode owns its
  specific appearance rules.

These folders belong to one SwiftPM executable target. They are source ownership
boundaries, not separate compiled modules. `tools/check-architecture` checks
cross-layer type-name references. It does not replace Swift type checking.

## State and resources

The shared state directory is `$XDG_STATE_HOME/countdown` or
`~/.local/state/countdown`.

- `settings.json` stores the selected mode (`Timer` or `Pomodoro`) and configured
  focus/break durations, plus the shared pause state. It does not store
  Pomodoro progress. A launch creates a fresh pair that follows the shared
  run state. If the pause field is absent, a saved paused Timer record supplies
  the pause state; otherwise the engine starts automatically.
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

# Automated checks

Run checks from the repository root on macOS with Swift Command Line Tools.
AppKit rendering and input checks need a macOS GUI session.

## Required checks

```sh
mise run check
mise run release
```

`check` runs source ownership checks, then all Swift tests. `release` builds the
production executable. Neither command installs the app or restarts its launch
agent. `mise run deploy` changes the installed app; it is not a test command.

The direct check commands are:

```sh
tools/check-architecture
tools/swift-test
```

`tools/swift-test` supplies framework search paths when the installed Command
Line Tools require them. It passes additional arguments to `swift test`.

## Focused checks

```sh
tools/swift-test --filter 'PomodoroClock|PomodoroCycleTests'
tools/swift-test --filter 'TimerLifecycleTests|TimerClockEndpointTests'
tools/swift-test --filter 'ScrollGestureTests|ScrollTargetTests|ScrollDurationTests'
tools/swift-test --filter 'CountdownConfigurationFileTests|CountdownPreferencesTests'
tools/swift-test --filter 'CountdownView|PomodoroRenderingTests|CountdownReminderViewTests|CountdownAccessibilityTests|CountdownWindowStateTests'
```

SwiftPM discovers tests recursively under `Tests/`. No source file list needs an
update when a test moves. Suites are grouped by subject:

- `Tests/Core/`: timing, configuration, persistence, reminder schedules, and geometry.
- `Tests/App/`: controller integration, window state, pointer/scroll input, and
  hosted view rendering and accessibility.
- `Tests/Support/`: isolated clock and scroll sessions, event creation, bitmap
  rendering, OCR, and accessibility helpers.

The former standalone circle-transition check is covered by the discovered
layout suite. That suite checks all modes and intermediate sizes. Reminder tests
check text-only rendering, zero initial opacity, fixed screen-center placement,
fade completion, and cancellation.
Other view suites check sector colors, labels, pause state, and restart images.
Tests use temporary state directories and injected clocks; they must not alter
the user's saved timer state.

## Toolchain warnings

The hosted accessibility tests use the informal AppKit accessibility interface
for SwiftUI nodes that do not declare `NSAccessibilityProtocol`. Those fallback
calls can produce deprecation warnings. Some Command Line Tools versions also
link their macOS 14 Testing framework against this app's macOS 13 deployment
target. These are test-toolchain warnings, not release-build errors.

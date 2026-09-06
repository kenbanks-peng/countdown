# Automated checks

Run from the repository root on macOS with Swift Testing available:

```sh
swift build
tools/swift-test list
tools/swift-test --filter CountdownViewLayoutTests
tools/swift-test --filter TimerControllerTests
tools/swift-test --filter PomodoroLifecycleTests
tools/swift-test --filter PomodoroDurationTests
tools/swift-test --filter ScrollTimeAdjusterTests
tools/swift-test --filter TimerViewTests
```

`tools/swift-test` runs SwiftPM tests. For Command Line Tools releases that install Testing outside the default search paths, it adds the framework and runtime paths and disables unused XCTest discovery. With Xcode, it uses `swift test` directly. The app still targets macOS 13. The installed Testing framework can require a newer macOS version for tests.

The test target excludes the stand-alone `@main` circle check. State directories are unique and are removed after each test. Tests use controlled time and capture sounds; they do not play notifications or change user settings. Hosted bitmap checks test sector colors, phase text, numeric display, and Countdown circle layout with packaged SVG resources. Text checks use local Vision text recognition. Accessibility checks read the hosted AppKit accessibility output; they do not replace a VoiceOver check.

`PomodoroLifecycleTests` drives the application commands with controlled time. It covers focus-first operation, exact and delayed expiry, silent completion, pause/resume, reset, and the hidden-timer gate. `TimerViewTests` also checks green-then-blue depletion, fixed sector placement, phase-only text, accessible lifecycle descriptions, and the hosted circle's accessible press action. These checks use no real-time timer waits.

`PomodoroDurationTests` checks the shared adjustment command, elapsed-preserving edits, and reset with edited durations. `ScrollTimeAdjusterTests` sends real location- and modifier-bearing Quartz scroll events through the application adapter. It covers both sectors, fixed allocated targets, boundaries, minima, capacity, Option accumulation, mode changes, and running/paused edits. `TimerViewTests` carries scroll events into hosted sector colors, phase text, and accessible descriptions. Synthetic events are not posted to the user's event queue.

For final validation, `tools/swift-test` without a filter runs the full suite. Feature work uses individual suite filters.

## Stand-alone circle check

```sh
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
swiftc -parse-as-library \
  src/Configuration/*.swift src/Countdown/*.swift src/Pomodoro/*.swift \
  src/App/TimerController.swift src/UI/*.swift \
  Tests/CircleTransitionCheck.swift \
  -o "$check_dir/circle-transition-check"
cp src/Resources/*.svg "$check_dir/"
"$check_dir/circle-transition-check"
```

The extra source paths supply the mode-aware view dependencies. The copied SVG files let `Bundle.main` load the real face and hands. This command does not compile the application entry point, app delegate, or generated resource accessor.

## Manual checks

Manual checks are separate: menu selection and check marks, Pomodoro click and Option-click controls, Reset, VoiceOver, Countdown settings and gestures, and Compact transitions. For normal Pomodoro, scroll in both directions over blue and green, then hold Option and check the slower whole-minute steps. Check depleted targets and ignored background while running and paused. Change targets during partial Option motion and confirm that it does not carry into the new target. Return to Countdown and check its ordinary and Option-scroll sensitivity. Compact Pomodoro checks belong to its later feature slice. Do not report a manual check as passed from a build or bitmap test alone.

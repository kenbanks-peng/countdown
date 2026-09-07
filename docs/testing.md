# Automated checks

Run from the repository root on macOS with Swift Testing available:

```sh
swift build
tools/swift-test list
tools/swift-test --filter CountdownViewLayoutTests
tools/swift-test --filter TimerControllerTests
tools/swift-test --filter TimerCoreTests
tools/swift-test --filter PomodoroLifecycleTests
tools/swift-test --filter PomodoroDurationTests
tools/swift-test --filter PomodoroPersistenceTests
tools/swift-test --filter ScrollTimeAdjusterTests
tools/swift-test --filter TimerViewTests
```

`tools/swift-test` runs SwiftPM tests. For Command Line Tools releases that install Testing outside the default search paths, it adds the framework and runtime paths and disables unused XCTest discovery. With Xcode, it uses `swift test` directly. The app still targets macOS 13. The installed Testing framework can require a newer macOS version for tests.

The test target excludes the stand-alone `@main` circle check. State directories are unique and are removed after each test. Tests use controlled time and capture sounds; they do not play notifications or change user settings. Hosted bitmap checks test sector colors, phase text, numeric display, and Countdown circle layout with packaged SVG resources. Text checks use local Vision text recognition. Accessibility checks read the hosted AppKit accessibility output; they do not replace a VoiceOver check.

`TimerCoreTests` checks the same core controls in both modes: pause/resume, clock and Wakeup settings, exact and delayed reminder intervals, paused and hidden timers, and no reminders from duration edits or completion. Setting writes are captured in memory. `PomodoroLifecycleTests` checks focus-first operation, exact and delayed expiry, silent completion, pause/resume, reset, and the hidden-timer gate with Wakeup disabled. `TimerViewTests` checks green-then-blue depletion, phase text, accessible descriptions, and clock face and hands controls in both modes. Hosted press checks confirm that a click changes presentation without changing timer activity in either mode or size. These checks use controlled time.

`PomodoroDurationTests` checks the shared adjustment command, elapsed-preserving edits, and reset with edited durations. `ScrollTimeAdjusterTests` sends real location- and modifier-bearing Quartz scroll events through the application adapter. It covers both sectors, fixed allocated targets, boundaries, minima, capacity, Option accumulation, mode changes, and running/paused edits. `TimerViewTests` carries scroll events into hosted sector colors, phase text, and accessible descriptions. Synthetic events are not posted to the user's event queue.

Compact checks use the same controller and scroll adapter as normal presentation. They cover both-size sector routing, perimeter and ignored regions, Option sensitivity, duration limits, and live edits. Hosted checks cover edited pair state through normal/Compact view replacement, phase-boundary updates with both hosts alive, silent completion with Wakeup disabled, shared Compact press actions and descriptions, and no visible Compact text. Bitmap checks cover both presentations at 32, 71, 123, and 188 points, including transparent pixels outside the circle. Countdown Compact output is compared with the existing view. These checks do not run the AppDelegate window animation, the 3-second Wakeup return, or its context-menu actions.

`PomodoroPersistenceTests` saves and reconstructs the application controller with real, unique temporary storage. It covers saved mode and edited allocations, all Pomodoro activity states, time while closed, complete invalid-data fallback, minimum/capacity limits, unreadable and unwritable storage, the last valid record after a failed write, and separate Countdown restoration followed by the hidden pause gate. Permission-failure checks require a non-root test process. Startup sound capture checks silence for Pomodoro and the existing Countdown-selected Wakeup rule. A hosted `TimerViewTests` check confirms the restored ready sectors, Focus-only text, and accessible allocations.

For final validation, `tools/swift-test` without a filter runs the full suite. Feature work uses individual suite filters.

## Stand-alone circle check

```sh
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
swiftc -parse-as-library \
  src/Configuration/*.swift src/Countdown/*.swift src/Pomodoro/*.swift \
  src/App/TimerController.swift src/App/TimerFeatures.swift src/UI/*.swift \
  Tests/CircleTransitionCheck.swift \
  -o "$check_dir/circle-transition-check"
cp src/Resources/*.svg "$check_dir/"
"$check_dir/circle-transition-check"
```

The extra source paths supply the mode-aware view dependencies. The copied SVG files let `Bundle.main` load the real face and hands. This command does not compile the application entry point, app delegate, or generated resource accessor.

## Manual checks

Manual checks are separate: menu selection and check marks, shared click and Option-click controls, Reset, VoiceOver, clock settings, and Compact transitions. In each mode, click to switch views and use the menu to start, pause, or resume. In normal view, toggle Face and Hands separately. With Wakeup enabled and a running timer in Compact, check expansion at an interval and return after 3 seconds. Switch modes during that brief expansion and confirm the scheduled return still occurs. For normal Pomodoro, scroll in both directions over blue and green, then hold Option and check the slower whole-minute steps. Check depleted targets and ignored background while running and paused. Change targets during partial Option motion and confirm that it does not carry into the new target. Return to Countdown and check its ordinary and Option-scroll sensitivity. In Compact Pomodoro, check the small blue and green hit regions, including a 1-minute sector, with ordinary and Option-scroll. Use Compact and Normal in the context menu while ready, running, paused, and at a phase boundary. Check VoiceOver in both sizes, and repeat presentation changes with Reduce Motion on and off. Confirm that Wakeup expands either mode, while final-minute expansion remains Timer-specific. Confirm that the existing animation still works. For restart, select Pomodoro, edit both allocations, and quit from ready, running focus, running break, paused, and completed states. Relaunch and check the full ready pair, selected mode, Focus label, and VoiceOver allocations. Confirm no startup sound. Repeat with Countdown selected and check its established restore behavior; with Pomodoro selected, confirm Countdown stays paused until explicit Resume. Do not report a manual check as passed from a build or bitmap test alone.

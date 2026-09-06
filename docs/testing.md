# Automated checks

Run from the repository root on macOS with Swift Testing available:

```sh
swift build
tools/swift-test list
tools/swift-test --filter CountdownViewLayoutTests
tools/swift-test --filter TimerControllerTests
tools/swift-test --filter ScrollTimeAdjusterTests
tools/swift-test --filter TimerViewTests
```

`tools/swift-test` runs SwiftPM tests. For Command Line Tools releases that install Testing outside the default search paths, it adds the framework and runtime paths and disables unused XCTest discovery. With Xcode, it uses `swift test` directly. The app still targets macOS 13. The installed Testing framework can require a newer macOS version for tests.

The test target excludes the stand-alone `@main` circle check. State directories are unique and are removed after each test. Tests use controlled time and capture sounds; they do not play notifications or change user settings. Hosted bitmap checks test sector colors, phase text, numeric display, and Countdown circle layout with packaged SVG resources. Text checks use local Vision text recognition. Accessibility checks read the hosted AppKit accessibility output; they do not replace a VoiceOver check.

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

Manual checks are separate: menu selection and check marks, VoiceOver, Countdown settings and gestures, and Compact transitions. Timing, sector edits, and Compact Pomodoro checks belong to their later feature slices. Do not report a manual check as passed from a build or bitmap test alone.

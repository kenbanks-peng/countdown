# Refactor result

## Contract decision

The user permitted contract changes where needed. Internal names and interfaces
changed without compatibility aliases. App functionality, configuration keys,
saved JSON formats, window keys, mode labels, and launch commands did not change.
No saved-state migration is required.

## Changed paths and structure

- `src/App/AppDelegate.swift`: reduced app startup/shutdown handling from 336 to
  16 lines. Window ownership, placement, and animation moved to `src/App/Window/`.
- `src/App/Input/` and `src/App/Views/`: separate scroll handling from hosted
  display. Input no longer takes the shared circle inset from `PomodoroView`.
- `src/Core/Timer/` and `src/Core/Pomodoro/`: place each model beside its session
  or clock schedule. Shared rounding remains in `src/Core/Timing/`.
- `src/Core/Notifications/`: replace the broad `CountdownFeatures` name with
  `PopupScheduler`. Timer colors and popup sounds use shared urgency bands.
- `src/Core/Persistence/`: share atomic JSON reads/writes through `JSONStateFile`.
  Each domain store keeps its schema, validation, fallback, and error behavior.
- `src/Core/Configuration/`: separate field parsing from validated configuration.
  Parse the file once rather than scan it for each field.
- `src/Core/UI/CountdownAppearance.swift`: consolidate shared colors and sizes.
  Bundled images and user-editable configuration remain separate by purpose.
- `src/Modes/Timer/TimerView.swift`: replace separate normal/compact views with
  one implementation. Keep their distinct labels, strokes, opacity, and padding.
- `src/Modes/Pomodoro/PomodoroView.swift`: compute arcs and progress-dot states
  once per body evaluation instead of repeatedly in the dot loop.
- `Tests/App/`, `Tests/Core/`, and `Tests/Support/`: split large view, clock, and
  scroll suites by subject. Share fixtures, rendering, and accessibility helpers.
  Remove the undiscovered standalone circle check; the layout suite covers it.
- `Package.swift`: remove the obsolete standalone-test exclusion.
- `mise.toml`: add `mise run check` for source ownership and full test execution.
- `resources/config.toml`: correct comments about duration limits; values and
  parser behavior are unchanged.
- `docs/architecture.md` and `docs/testing.md`: supply the documents already
  linked by the README. The README was not expanded into a change list.

Names now state their purpose: `focusPeriodsPerCycle`, `sessionStore`,
`showsRemainingMinutes`, `isAutoSetToNextHourEnabled`, `popupIntervalMinutes`,
`resume`, and `pause`. Window presentation names are separate from timer mode
names. Remove the unused timer ratio, redundant completion flag, and always-true
control flag. Shared run state and completion checks remain covered by tests.

Swift source decreased from 2,556 to 2,514 lines. The largest source file is now
304 lines, down from 336. The largest test file is now 283 lines, down from 561.
Keep the timing state machines together: splitting their private setters across
files would weaken ownership without a useful reduction in complexity.

## Verification

| Check | Result |
| --- | --- |
| Baseline `tools/check-architecture` | Passed. |
| Baseline `tools/swift-test` | 135 tests in 19 suites passed. |
| First focused refactor run: preferences, configuration, popups, views, scrolling, clock endpoints | 72 tests in 6 suites passed. |
| Focused run after test-file splits | One compile failure: a trailing `@MainActor` had no declaration. Removed it. |
| Repeated focused run: configuration parser, window state, preferences, clock rules, scrolling, Pomodoro cycles | 63 tests in 12 suites passed. |
| Intermediate full `tools/swift-test` | 143 tests in 31 suites passed. |
| Temporary `TimerViewParityCheck` against both original timer views from Git HEAD | 160 PNG pairs were identical. Checked normal/compact, empty/running/paused, time bands, clock on/off, labels, and intermediate sizes. Temporary comparison code was removed. |
| Final `mise run check` | Architecture check and all 143 tests in 31 suites passed. |
| Final `mise run release` | Production build passed. |
| `shellcheck tools/swift-test launch/countdown` | Passed. |
| ShellCheck of all three scripts in `mise.toml` | Passed. |
| TOML parsing of `mise.toml` and `resources/config.toml` | Passed. |
| `git diff --check` and whitespace check of source, tests, and docs | Passed. |
| Old-identifier and local documentation-link checks | No stale identifiers or broken links found. |
| Original test-function inventory against Git HEAD | All 135 original test functions retained; eight new tests added. |

The new tests cover first-match configuration behavior, section scope, fallback
rules, stored preference preservation, window placement and transition geometry,
shared urgency thresholds, and one completion report per timeout.

All required checks ran. No known functional failures or blocked refactoring work
remain from this review. The test toolchain still reports the documented AppKit
accessibility deprecations and Testing framework deployment-target warning.
The app was not deployed or restarted. Live desktop popup timing was not manually
checked; automated checks cover scheduling, window geometry, and rendered views.

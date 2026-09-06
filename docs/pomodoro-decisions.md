# Pomodoro decision contract

## Authority and scope

- Parent specification: [#1 — Requirements: add an isolated Pomodoro mode](https://github.com/kenbanks-peng/countdown/issues/1).
- Decision prerequisite: [#2 — Define Pomodoro interaction and lifecycle rules](https://github.com/kenbanks-peng/countdown/issues/2).
- First feature: [#3 — Select Pomodoro and show the default focus and break circle](https://github.com/kenbanks-peng/countdown/issues/3).
- Source plan: [PLAN.md at a7abef627218643818d0c955fc60cd7346f10294](https://github.com/kenbanks-peng/countdown/blob/a7abef627218643818d0c955fc60cd7346f10294/PLAN.md).

The product owner supplied D1–D8 in this session. These are owner decisions, not agent guesses. The owner first selected the four policy groups below, then accepted all recommended decisions. That acceptance confirms the selected policies. It does not replace the explicit Pomodoro restart policy with session restoration.

This document completes the planning prerequisite only. It does not change or close the parent specification or implement a feature. The tables make consequences of the selected policies explicit. No product decision remains open for D1–D8.

Timer mode (Countdown or Pomodoro) is separate from panel presentation (normal or Compact). Preserve Countdown behavior while Countdown is selected, except for the approved pause on a timer-mode change. Do not add long breaks, statistics, extra notification channels, or a broad refactor.

## Recorded decisions

### D1 — One focus/break pair

Enter Pomodoro ready, with the full configured pair. Defaults are 25 minutes of focus and 5 minutes of break. Click to start focus. Focus changes to break automatically. At break completion, stop with both phases depleted. Click starts a new full pair; no later pair starts automatically.

Use elapsed time, not the number of timer updates. Exact and delayed updates must account for elapsed time across focus and break within the current pair. Discard time beyond the end of that pair. Ready, paused, and completed pairs do not consume elapsed time.

### D2 — No long breaks

Do not add long breaks after four focus sessions or any other session count. Every new pair uses the configured focus and short-break durations. No session counter or long-break setting is required.

### D3 — Minimum durations

Each configured phase has a minimum of 1 minute. Zero is forbidden as a configured duration. Clamp an edit below the minimum to 1 minute. A remaining duration of zero is valid only as a result of phase completion; it does not create a zero-duration configured phase or require a special zero-length adjustment route.

### D4 — Edits preserve elapsed time

Keep configured durations separate from elapsed and remaining time. In ready state, an edit changes the full allocation. For a running or paused active phase, preserve its elapsed time and set `remaining = max(0, new configured duration - elapsed)`. Paused time does not add to elapsed time. Apply elapsed-time updates through the command time before applying a running edit, so a stale display does not select the wrong active phase.

If an active edit reaches zero, complete that phase immediately. A running focus proceeds to running break. A paused focus proceeds to paused break. Completing break stops the pair in either case; it must not start another pair. Shortening a duration is an edit, not additional elapsed time: do not carry the removed allocation into break as time spent there.

An edit to a future phase changes its full allocation in this pair. An edit to a completed phase changes its configured allocation for the next pair only; it does not restore that phase or change time remaining in the current phase.

The configured focus and break total must be at most 60 minutes. Clamp only the edited phase to the interval from 1 minute to `60 minutes - other configured duration`. Never reduce the other phase to make room. Apply this rule to every duration input path.

### D5 — Sector hit regions and scroll sensitivity

Use configured sector allocations as hit regions, including areas that have depleted to background. Ignore unallocated background, points outside the circle, and the exact center. The shared boundary belongs to the following sector in the existing circle direction.

Measure angles from the top in the existing direction, which is clockwise on the display. Treat angular ranges as start-inclusive and end-exclusive. With default durations, break owns `[0°, 30°)`, focus owns `[30°, 180°)`, and unallocated background owns `[180°, 360°)`. At a full 60-minute allocation, the top seam wraps to break. A point on the circle perimeter is in the circle; a point beyond it is not. The exact center has no angular target.

Ordinary scroll keeps the existing sensitivity: a nonzero vertical event changes the target by one minute according to direction. Positive delta increases it; negative delta decreases it. Option-scroll keeps the existing accumulated threshold of 12 delta units for each one-minute step, including the remainder and multiple whole-minute steps in a large event. Option does not permit fractional-minute edits. Ordinary scroll clears the Option remainder as it does today.

Clear Option accumulation when the target changes, including a change to or from no target, or when timer mode changes. Do not carry partial motion from break to focus, through ignored background, or between Countdown and Pomodoro. Resolve the target from the event location and current configured geometry; duration edits can change that geometry.

### D6 — Normal and Compact input

Both presentations support sector-specific scrolling with D3–D5. Do not use whole-circle Countdown adjustment in Compact Pomodoro. Both show the two filled sectors on the fixed 60-minute scale. Normal shows a small Focus / Break label; ready identifies Focus as the next phase. Compact has no visible phase label. Neither has a visible numeric Pomodoro countdown. Both provide accessible phase and remaining-time descriptions; ready descriptions include the allocations.

### D7 — Mode changes and restart

When switching away from a running timer, account for elapsed time through the switch and pause it if it is still running. A ready or paused timer retains its in-process state. A completed timer stays completed. No timer runs while hidden. Switching back does not resume it; explicit resume is required. Switching panel presentation is not a timer-mode change and must not pause the timer.

Persist only selected timer mode and Pomodoro configured focus and break durations, separately from Countdown session storage. Do not persist Pomodoro active phase, remaining time, elapsed time, or run state. After restart, Pomodoro is READY with the full saved configured pair, even if it was running, paused, or completed when the app closed. Do not count closed-app elapsed time for Pomodoro. Do not issue startup Pomodoro alerts.

Missing or invalid Pomodoro/mode data uses the complete safe default: Countdown selected, focus 25 minutes, break 5 minutes. Invalid data includes an unknown mode, unreadable or malformed data, missing required fields, non-finite durations, a phase below 1 minute, or a total above 60 minutes. Storage that cannot be used must not prevent in-memory operation. On a later load with unavailable data, use the safe defaults; do not promise that an unsuccessful write was saved.

Preserve the established Countdown disk restoration rules. Do not erase, migrate, or reinterpret an unrelated Countdown session as Pomodoro data. A mode switch must use the approved pause policy, not clear the Countdown timer. When saved mode selects Pomodoro, Countdown must not run hidden after startup restoration. Keep the separation between Countdown restoration and the selected-mode pause gate; do not replace Countdown restoration with Pomodoro's READY rule.

### D8 — Controls and notifications

In Pomodoro, click starts a ready pair, pauses a running pair, resumes a paused pair, or starts a new pair after completion. A context-menu Reset stops activity and returns to READY with the full configured pair, not necessarily the default 25/5 durations. These timer controls apply in normal and Compact presentations. Do not inherit Countdown's click-to-change-presentation or Option-click next-hour action as Pomodoro timer controls. Presentation selection remains separate.

Focus and pair completion have no Pomodoro sounds. Use phase/sector state to show progress and completion. Repeated updates must not repeat phase completion or restart a pair. Do not route Countdown alarm, Wakeup, Autoset, next-hour actions, or final-minute expansion into Pomodoro. Pomodoro never expands the panel automatically. This ticket does not add system notifications or notification assets.

## State / action / result examples

Times below are minutes unless seconds are stated. “Completed” means that this pair has stopped with both phases depleted; it does not require a particular internal enum. Each result is supported by the listed owner decision or the confirmed parent display requirements.

### Lifecycle, edits, and limits

| State / setup | Action | Required result | Authority |
| --- | --- | --- | --- |
| First Pomodoro entry, 25/5 | Select Pomodoro | Ready; full 25 focus and 5 break; no elapsed time starts | D1, D7 |
| Ready 25/5 | Click | Focus runs; break stays full | D1, D8 |
| Focus running from full 25/5 | Update at exactly 25 elapsed | Break runs with 5 remaining; focus is zero | D1 |
| Focus running from full 25/5; no intervening updates | Update at 27 elapsed | Break runs with 3 remaining | D1 |
| Focus running from full 25/5 | Update at exactly 30 elapsed | Pair completed; both remaining values zero | D1 |
| Focus running from full 25/5; no intervening updates | Update at 65 elapsed, then update again | One pair completed; no later pair and no repeated completion | D1, D2, D8 |
| Focus running, 10 elapsed | Click, wait 20, then click | Pause with 15 focus and 5 break; resume with those values | D1, D8 |
| Break running, 2 break elapsed | Click, wait 20, then click | Pause and resume with 3 break remaining; focus stays completed | D1, D8 |
| Completed pair | Wait, then click | Start new focus with full current configured durations | D1, D2, D8 |
| Ready, running, paused, or completed; configured 20/7 | Context-menu Reset | Ready 20/7; no activity, no reset to 25/5 | D8 |
| Ready 25/5 | Change focus to 20, then break to 7 | Ready full 20/7 | D4 |
| Focus running, 10 elapsed of 25 | Change focus to 20 | Focus runs with 10 remaining; break unchanged | D4 |
| Focus paused, 10 elapsed of 25 | Change focus to 30 | Focus remains paused with 20 remaining | D4 |
| Focus running, 10 elapsed | Change focus to 10 or 9 | Focus completes now; break starts with its full allocation, not reduced by the edit | D1, D4 |
| Focus paused, 10 elapsed | Change focus to 10 or 9 | Focus completes now; full break is paused until click | D4, D8 |
| Break running or paused, 3 elapsed of 5 | Change break to 3 | Pair completed; no next pair starts | D1, D4 |
| Focus running or paused | Change future break from 5 to 7 | Break full allocation becomes 7; focus time/state unchanged | D4 |
| Break running or paused; focus completed | Change focus from 25 to 20 | Next pair uses focus 20; current break time/state unchanged; focus does not refill | D4 |
| Pair completed | Edit either duration | Change next pair allocation only; remain stopped until click or Reset | D1, D4, D8 |
| Stale focus display; 27 elapsed since start of 25/5 | Edit focus to 20 | First account for 27 elapsed: break has 3 remaining; edit completed focus for the next pair only | D1, D4 |
| Focus 25, break 5 | Request focus 0 or a negative duration | Focus clamps to 1; break stays 5; no configured zero phase | D3, D4 |
| Focus 25, break 5 | Request break 0 or a negative duration | Break clamps to 1; focus stays 25 | D3, D4 |
| Focus 54, break 5; total 59 | Increase focus by 1, then by 1 again | Focus reaches 55 and stays 55; break stays 5 | D4 |
| Focus 55, break 4; total 59 | Increase break by 1, then by 1 again | Break reaches 5 and stays 5; focus stays 55 | D4 |
| Focus 55, break 5; total 60 | Decrease focus by 1, or decrease break by 1 | Edited phase decreases by 1; other phase unchanged; total 59 | D3, D4 |
| Focus 1, break 59; total 60 | Decrease focus or increase break | Both stay 1/59; minimum and capacity both hold | D3, D4 |
| Focus 59, break 1; total 60 | Decrease break or increase focus | Both stay 59/1 | D3, D4 |

### Display and input

| State / setup | Action | Required result | Authority |
| --- | --- | --- | --- |
| Ready default pair, normal | Render | Blue 30° from top, then green 150°, then background 180°; filled circle; small Focus label; no numeric countdown | Parent #1, D6 |
| Focus running, 10 elapsed of 25/5 | Render | Green shows 15 remaining; blue stays full; configured phase boundaries do not move from time depletion | Parent #1, D1 |
| Break running | Render | Green remains depleted; blue depletes without shifting the configured focus start | Parent #1, D1 |
| Ready 25/5 | Increase break to 6 | Blue allocation becomes 36°; focus starts at 36° and still spans 150° | Parent #1, D4 |
| Any Pomodoro state, normal or Compact | Scroll over allocated blue or green | Edit only that phase, subject to elapsed/minimum/capacity rules | D3–D6 |
| Phase partly or fully depleted | Scroll within its configured allocated area | Still target that phase; apply active/completed edit rules | D4, D5 |
| Unallocated background, outside circle, or exact center | Scroll, including Option-scroll | No duration change; no accumulation carried through the ignored target | D5 |
| Default pair, point not at center | Scroll at 0°, 30°, or 180° | Target break at 0°, focus at 30°, no target at 180° | D5 |
| Full 60-minute allocation | Scroll on top seam | Target break, the following sector after wraparound | D5 |
| Allocated angular position | Scroll on perimeter, then outside perimeter | Perimeter targets the phase; outside does not | D5 |
| Any target, no Option | Send delta +1 or +30; separately send delta -1 | Each positive event adds 1 minute; negative event subtracts 1 minute, within limits | D3–D5 |
| Focus target, Option remainder zero | Send deltas +7 then +5 | First event does not edit; second adds 1 minute | D5 |
| Focus target, Option remainder +7 | Move to break and send +5 | No edit; do not reuse focus's +7 | D5 |
| Focus target, Option remainder +7 | Send event on background, then return with +5 | No edit on return; background cleared the old remainder | D5 |
| Option remainder +7 in either timer mode | Switch timer mode, then Option-scroll +5 | No carried one-minute adjustment in the new mode | D5, D7 |
| Focus target, Option remainder +7 | Ordinary scroll +1, then Option-scroll +5 | Ordinary event adds 1 minute and clears remainder; final event does not edit | D5 |
| Ready/running/paused Pomodoro | Change normal to Compact or back | Same pair and timer state; both sectors remain; label only in normal; no numeric countdown | D6, D7 |
| Normal or Compact | Read accessibility description | Phase and remaining time are available without color; ready includes focus/break allocations | Parent #1, D6 |
| Pomodoro in Compact, final minute or phase/pair completion | Update repeatedly | No automatic expansion and no sounds | D8 |
| Pomodoro selected | Use timer click or Reset | Use Pomodoro lifecycle; never next-hour, Autoset, or Countdown notification rules | D8 |

### Mode changes and restart failures

| State / setup | Action | Required result | Authority |
| --- | --- | --- | --- |
| Countdown running | Select Pomodoro, wait, select Countdown | Countdown pauses at switch; no hidden elapsed time; return requires Resume; appearance/settings preserved | D7 |
| Pomodoro focus or break running | Select Countdown, wait, select Pomodoro | Pomodoro pauses at switch; same phase/remaining on return; click resumes | D7, D8 |
| Running Pomodoro crosses focus expiry at switch time | Select Countdown | Account for elapsed time first, then pause break with its correct remainder | D1, D7 |
| Running Pomodoro crosses pair end at switch time | Select Countdown, then return | Pair stays completed; explicit click starts another | D1, D7 |
| Either timer ready/prepared or paused | Switch away and back | Keep in-process state; no automatic start or resume | D7 |
| Countdown empty or Pomodoro completed | Switch away and back | Remain empty or completed; no new activity | D1, D7 |
| Pomodoro selected; valid configured 20/7 saved | Restart from ready, running focus, running break, paused, or completed | Pomodoro selected and READY with full 20/7; no saved phase or run state | D7 |
| Pomodoro selected before close | Restart after less than, exactly, or more than one pair duration | Same full ready pair in every case; no closed-app elapsed time or startup Pomodoro alert | D7, D8 |
| Countdown selected; valid configured Pomodoro 20/7 saved | Restart, then select Pomodoro | Countdown follows its established restoration; Pomodoro enters ready 20/7 | D7 |
| Valid Pomodoro-selected data and an unrelated Countdown session | Restart | Pomodoro ready; Countdown uses its own restoration rules, then remains non-running while hidden; do not erase or reinterpret its session | D7 |
| No Pomodoro/mode data; Countdown session exists | Restart | Countdown selected with Pomodoro defaults 25/5; restore Countdown under its existing rules | D7 |
| Unknown mode, missing required field, malformed record, invalid phase duration, or total above 60 | Restart | Complete fallback: Countdown selected and Pomodoro 25/5; no partial invalid allocation; unrelated Countdown session unchanged | D3, D4, D7 |
| Storage unreadable or absent | Load | Use safe defaults and permit in-memory use; do not fail startup | D7 |
| Storage unwritable | Select Pomodoro and edit durations | In-memory commands still work; no false promise of persistence | D7 |
| Failed save, then no readable valid data on next load | Restart | Countdown selected and Pomodoro 25/5 | D7 |
| Previously valid record still readable after a failed write | Restart | Load that valid record, not unsaved in-memory edits; Pomodoro still restarts ready | D7 |
| Countdown selected; active, prepared, stale, expired, or invalid Countdown disk session | Restart | Keep established Countdown restoration outcomes; Pomodoro fallback must not replace or change these rules | D7 |

## Pre-agreed tests and command setup for #3

The owner approved these seams in this session. No further seam approval is needed:

1. **Application-facing mode-aware commands.** Drive the same commands as the UI and app lifecycle. Use real Countdown/Pomodoro lifecycle and real storage behind that boundary. Inject a controlled clock, capture sound output, and use a unique temporary state directory for each test. Exercise reload through the application-facing boundary, not private fields or direct database assertions. Do not use real delays or play sounds.
2. **Public scroll-event path.** Send location and modifier-bearing scroll events through the adapter that the app uses. Verify mode, phase allocation, and rendered results. Geometry unit checks can supplement, but cannot replace, this path.
3. **Hosted rendered integration checks.** Use NSHostingView layout and bitmap checks, following `Tests/CountdownViewLayoutTests.swift` and `Tests/CircleTransitionCheck.swift`. Check literal expected default angles, sector order, background, stable boundaries, labels, Compact output, accessibility, and circular intermediate sizes. Do not assert a private view hierarchy.

At the reviewed revision, `Package.swift` has only an executable target. `Tests/CountdownViewLayoutTests.swift` uses Swift Testing but has no registered test target. `Tests/CircleTransitionCheck.swift` is a separate `@main` program with a manual `Bundle.module` accessor; it must not be included in the unit-test target.

For #3, add a focused SwiftPM test target that depends on Countdown and excludes `CircleTransitionCheck.swift`. Keep the target/source changes small. Isolate the existing layout test's temporary state directory so it cannot read another test's or user's session. Document the commands that actually discover and run tests after registering the target. Planned commands are:

```sh
# Type-check the app throughout each feature slice.
swift build

# Confirm that SwiftPM discovers the registered tests.
swift test list

# Run the existing layout file's suite only.
swift test --filter CountdownViewLayoutTests

# Run one new source-named suite at a time; use its actual name from discovery.
swift test --filter <SourceNamedSuite>
```

Keep this stand-alone check runnable from the repository root. It deliberately excludes `src/App/main.swift`, the app delegate, and SwiftPM's generated resource accessor:

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

Ticket #3 adds the Pomodoro and mode-controller source dependencies shown above. For test discovery and execution with the installed Command Line Tools framework paths, use `tools/swift-test list` and `tools/swift-test --filter <SourceNamedSuite>`. See [testing.md](testing.md).

If a feature adds a direct source dependency for this stand-alone program, update its command in the same feature. Do not replace the program with a test that cannot render.

Use one red-green slice at a time: add one failing behavioral check at an approved seam, implement the smallest required change, then run that focused suite and `swift build`. #3 covers mode selection, ready allocation, rendered normal output, and the Countdown switch-pause regression. It does not claim phase timing, editing, Compact Pomodoro operation, or restart persistence before their feature tickets. Do not expose non-working timing controls in #3.

Run focused tests regularly. Do not run the full suite during these implementation tickets; the final validation worker will run it. Later slices use the state tables above for lifecycle, scroll, Compact, and restart checks. Preserve Countdown coverage for controls, Autoset, Wakeup, completion, restoration, Compact transitions, and final-minute expansion.

Manual checks still required for the feature: VoiceOver, normal and Option-scroll, small Compact targets, and Countdown regression behavior. A build or hosted bitmap check is not evidence that these manual checks passed. Ticket #2 adds no executable tests or feature code. Test registration and new automated behavior checks start in #3.

# Pomodoro Mode Implementation Plan

## Goal

Add a separate Pomodoro mode while preserving the existing Countdown mode's appearance, controls, and behavior unchanged. Pomodoro uses the same circle concept to show focus and break time together, without a numeric countdown.

## Agreed UX

### Mode selection

- Add Countdown / Pomodoro selection to the context menu.
- Keep Countdown-specific behavior isolated from Pomodoro behavior.
- Retain normal and Compact presentations.

### Defaults and limits

- Default focus duration: **25 minutes**.
- Default break duration: **5 minutes**.
- The circle always represents **60 minutes**, not a normalized session duration.
- Focus and break durations together must not exceed **60 minutes**.
- Increasing either duration must stop at the available capacity; do not silently shorten the other duration.

### Two-part circle

- Use filled sectors and the existing background treatment, not a numeric timer or a replacement progress ring.
- The first sector is **blue**, representing break time.
- The adjacent sector is **green**, representing focus time.
- Match the existing circle's origin and direction conventions.
- Sector angles are proportional to minutes on the fixed 60-minute scale.
- With the defaults, blue occupies 5 minutes (30 degrees), green occupies 25 minutes (150 degrees), and the remaining 30 minutes are background.
- Blue comes first spatially, but **focus runs first, followed by break**.
- During focus, the green sector depletes into the background while blue remains intact.
- During break, the blue sector depletes into the background.
- Keep phase boundaries stable during countdown; do not normalize or rescale the remaining sectors as time expires.
- Show a small **Focus / Break** label in normal mode to identify the active phase. Do not display a numeric countdown.
- Compact mode retains the two-part circle without the phase label.

### Scroll adjustment

- Scroll over the blue section to adjust break duration.
- Changing break duration moves the start of the focus section outward around the circle, preserving focus duration.
- Scroll over the green section to adjust focus duration.
- Reuse the existing one-minute scroll adjustment behavior, including Option-scroll precision.
- Enforce the combined 60-minute maximum for both adjustment paths.

## Decisions to Resolve Before Implementation

These behaviors were not established in the feature discussion and should not be assumed:

- Whether phase transitions and subsequent cycles start automatically or wait for confirmation.
- Whether long breaks after four focus sessions are in scope. The initial defaults above describe a standard focus / short-break pair only.
- Minimum durations and whether either phase can be reduced to zero.
- How scrolling during an active phase affects configured duration and remaining time.
- Whether expired portions remain scroll targets, how zero-length sectors can be increased, and what scrolling over unallocated background does.
- Whether Compact mode supports section-specific scrolling at its small size.
- What happens to an active timer when switching modes, and which Pomodoro state persists across app restarts.
- Pomodoro pause/resume controls and completion notifications. Existing Countdown Autoset, Wakeup, and final-minute expansion must not implicitly dictate Pomodoro behavior.

## Implementation Steps

### 1. Resolve interaction details

- [ ] Confirm the decisions above before implementing affected behavior.
- [ ] Define phase transitions, mode-switch behavior, and scroll hit regions.

### 2. Add isolated Pomodoro state

- [ ] Introduce mode selection without changing existing Countdown semantics.
- [ ] Add Pomodoro focus/break configuration with 25/5-minute defaults.
- [ ] Model active phase, remaining time, and the agreed running/paused/ready states.
- [ ] Centralize the combined-duration limit so every adjustment path respects it.
- [ ] Implement agreed persistence and mode-switch behavior.

Relevant existing code: `src/Countdown/CountdownModel.swift`, `src/Countdown/CountdownStateStore.swift`, and `src/Configuration/CountdownConfiguration.swift`.

### 3. Render the two-part circle

- [ ] Add offset-sector rendering for adjacent blue and green sections on a fixed 60-minute scale.
- [ ] Render expired and unallocated time as background.
- [ ] Add the non-numeric phase label in normal mode.
- [ ] Preserve the two-section display in Compact mode.
- [ ] Provide accessible phase and remaining-time descriptions without visible numeric countdowns.

Relevant existing code: `src/UI/RadialSector.swift`, `src/UI/CountdownView.swift`, `src/UI/CompactCountdownView.swift`, and `src/UI/CountdownAppearance.swift`.

### 4. Wire controls and phase progression

- [ ] Add mode selection to the context menu.
- [ ] Route scrolling by section and preserve existing adjustment sensitivity.
- [ ] Move the focus section when break duration changes, without changing focus duration.
- [ ] Implement focus-then-break progression and the agreed completion behavior.
- [ ] Keep Countdown-specific settings and interactions unchanged in Countdown mode.

Relevant existing code: `src/App/ScrollTimeAdjuster.swift` and `src/App/AppDelegate.swift`.

### 5. Verify and document

- [ ] Test default geometry: 30-degree break, 150-degree focus, 180-degree background.
- [ ] Test that break adjustment shifts focus placement but preserves focus duration.
- [ ] Test that focus adjustment preserves break duration.
- [ ] Test combined-duration limits at and around 60 minutes.
- [ ] Test green depletion followed by blue depletion, with stable phase boundaries.
- [ ] Test agreed scroll targeting, pause/resume, transitions, persistence, and mode switching.
- [ ] Check normal and Compact rendering and accessibility.
- [ ] Run existing tests and manually verify Countdown mode has not regressed.
- [ ] Update `README.md` with mode selection, defaults, and section-based scrolling.

## Acceptance Criteria

- Existing Countdown mode remains unchanged.
- Pomodoro defaults to 25 minutes of focus and 5 minutes of break.
- Both phases are visible together in one fixed-scale, 60-minute circle.
- Blue is the first sector; green follows it. Execution order is focus, then break.
- Remaining time uses phase color; expired and unallocated time use background.
- Break scrolling pushes focus placement outward without shortening or lengthening focus.
- Neither adjustment can make the combined duration exceed 60 minutes.
- The UI identifies the active phase without a visible numeric countdown.

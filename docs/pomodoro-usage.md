# Pomodoro in the normal window

1. If Countdown is Compact, click it to open the normal window.
2. Right-click the normal circle. Under **Timer Mode**, select **Pomodoro**.
3. The ready circle shows 5 minutes of break in blue, then 25 minutes of focus in green. Each minute is 6 degrees. The unused half keeps the Countdown background color.
4. Click the circle, or select **Start** in the context menu, to start focus. Green decreases while blue stays full. The small **Focus** label identifies the phase; no numeric countdown is shown.
5. Break starts automatically when focus ends. The label changes to **Break**, and blue decreases. Expired areas show background. Phase placement does not shift as time passes.
6. Click to pause or resume. The context menu also shows **Pause** or **Resume**. The accessible description gives the state, phase, and remaining time without use of color.
7. After break, both sectors are empty and the pair stops. Click or select **Start** to start a new full pair. There are no long breaks or Pomodoro sounds.
8. Select **Reset** in the context menu to stop and return to the full ready pair.

A timer pauses when you select the other timer mode. Returning does not resume it. Click Pomodoro, or select **Resume** for Countdown, to continue. A completed Pomodoro stays complete until Start or Reset.

Pomodoro clicks, including Option-clicks, control the pair. They do not change presentation or set the next hour. Countdown settings, Autoset, Wakeup, sounds, and automatic expansion do not apply to Pomodoro.

## Adjust durations

Scroll over blue to change break, or green to change focus. Each ordinary vertical scroll event changes the selected phase by 1 minute in its direction. Hold Option for slower, accumulated 1-minute steps. Each phase has a 1-minute minimum. The pair has a 60-minute maximum. An increase stops at the available space; it never shortens the other phase.

A break edit moves the start of focus but keeps the configured focus duration. A focus edit keeps the break allocation. The circle always uses the 60-minute scale.

Allocated areas remain scroll targets after their color disappears. Unallocated background, the exact center, and points outside the circle do nothing. A shared boundary belongs to the following sector clockwise: at the default 30° boundary, scroll changes focus. Changing targets or timer mode clears partial Option motion.

In ready state, edits change the full pair. During running or paused activity, an active-phase edit keeps elapsed time and changes the remaining time. An edit that removes all remaining focus time moves to the full break, still paused if focus was paused. Removing all remaining break time stops the pair. A future-phase edit changes its full allocation; a completed-phase edit changes only the next pair. Start after completion and Reset use the edited durations.

Compact Pomodoro and saved mode/durations are separate feature slices. Duration edits in this version apply to the normal Pomodoro window and are not saved across app restarts.

For build and automated checks, see [testing.md](testing.md).

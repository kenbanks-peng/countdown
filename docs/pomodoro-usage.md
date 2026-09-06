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

Duration edits, Compact Pomodoro, and saved mode/durations are separate feature slices. This version operates Pomodoro in the normal window with the 25/5-minute pair. Scroll does not change this pair yet.

For build and automated checks, see [testing.md](testing.md).

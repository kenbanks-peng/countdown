# Timer and Pomodoro

Right-click the circle and select **Timer** or **Pomodoro** under **Timer Mode**. The app name stays Countdown.

## Shared controls

Both modes use the same app controls:

- Click the circle to change between normal and compact views. This does not pause or restart the active timer. The menu also has **Normal** or **Compact**.
- Use **Face** and **Hands** in the menu to show or hide the clock face and hands in normal view. These settings apply to both modes. Compact stays a small status circle.
- Use **Start**, **Pause**, or **Resume** in the menu to control the selected timer.
- Use **Wakeup** to enable interval reminders. While time runs, each configured remaining-time interval can play the existing reminder sound. In compact view, the app expands to normal for 3 seconds, then returns to compact. In Pomodoro, the interval uses the total remaining focus and break time.

A mode change pauses the timer you leave. The other timer does not start automatically. Return to a paused timer and select **Resume** to continue.

Timer keeps its next-hour, Autoset, Timeout, completion alarm, and final-minute expansion behavior. Option-click in normal Timer view sets the next hour. In Pomodoro, Option-click changes the view, like a normal click.

## Pomodoro lifecycle

1. Select **Pomodoro**. The ready circle shows 5 minutes of break in blue, then 25 minutes of focus in green. Each minute is 6 degrees.
2. Select **Start** in the menu. Green decreases while blue stays full. The normal view shows **Focus**. Neither view shows a numeric Pomodoro countdown.
3. Break starts when focus ends. The label changes to **Break**, and blue decreases. The phase positions do not move as time passes.
4. Select **Pause** or **Resume** as necessary. The accessible description gives the state, phase, and remaining time.
5. After break, both sectors are empty and the pair stops. Select **Start** for a new full pair, or **Reset** to return to the full ready pair without starting it.

There are no long breaks, automatic repeat pairs, or phase-completion sounds. Shared Wakeup reminders still apply when enabled. Pomodoro does not use Timer's final-minute expansion or completion alarm.

## Adjust durations

Scroll over blue to change break, or green to change focus, in either view. Each ordinary vertical scroll event changes the selected phase by 1 minute. Hold Option for slower, accumulated 1-minute steps. Each phase has a 1-minute minimum. The pair has a 60-minute maximum. An increase never shortens the other phase.

Allocated areas remain scroll targets after their color disappears. The exact center, unused background, and points outside the circle do nothing. A shared boundary belongs to the following sector clockwise. Changing targets or modes clears partial Option motion.

Edits preserve elapsed time. Removing the remaining focus time moves to break; a paused pair stays paused. Removing all remaining break time stops the pair. An edit to a completed phase changes the next pair only. Start after completion and Reset use the edited durations.

Compact has the same sectors and scroll controls, but no visible phase label or number. Its accessible description still gives the phase and remaining time.

## Restart

The app saves the selected mode and configured Pomodoro durations separately from the Timer session. Clock and Wakeup settings use the existing configuration file.

After restart, Pomodoro is ready with the full saved pair. Time while closed does not reduce either phase. There is no Pomodoro startup sound. Select **Start** to begin focus.

Timer keeps its session restoration rules. If Pomodoro is selected at startup, Timer stays paused while hidden. Select **Timer**, then **Resume**, to continue it.

Missing, invalid, or unreadable mode and duration data selects Timer and uses Pomodoro defaults of 25/5 minutes. If storage is not writable, the app still works, but changes might not be saved.

For checks, see [testing.md](testing.md).

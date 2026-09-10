import Combine
import Foundation

/// Owns shared time. Only the selected view can complete or repeat it.
@MainActor
final class CountdownEngine: ObservableObject {
    @Published private(set) var isPaused: Bool
    let timer: TimerModel
    @Published private(set) var pomodoro: PomodoroModel
    private(set) var mode: CountdownMode
    private let now: () -> Date
    private var timerSubscription: AnyCancellable?

    init(timer: TimerModel, pomodoro: PomodoroModel, isPaused: Bool,
         mode: CountdownMode = .timer, now: @escaping () -> Date) {
        self.timer = timer
        self.pomodoro = pomodoro
        self.isPaused = isPaused
        self.mode = mode
        self.now = now
        self.pomodoro.isAutoRepeatEnabled = timer.isAutoRepeatEnabled
        let date = now()
        timer.isEnginePaused = isPaused
        if self.pomodoro.clockSchedule == nil { self.pomodoro.setClockEnabled(true, at: date) }
        self.pomodoro.setSharedPaused(isPaused, at: date)
        if mode.usesTimer {
            timer.setSharedRemaining(timer.remaining, at: date)
            self.pomodoro.followTimer(remaining: timer.remaining, at: date)
        } else {
            timer.setSharedRemaining(self.pomodoro.focusRemaining + self.pomodoro.restRemaining,
                                     at: self.pomodoro.clockSchedule?.pausedAt ?? date)
        }
        if mode == .pomodoro { update(at: date) }
        timerSubscription = timer.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func projectPomodoro(at date: Date) {
        timer.setSharedRemaining(pomodoro.focusRemaining + pomodoro.restRemaining,
                                 at: pomodoro.clockSchedule?.pausedAt ?? date)
    }

    func update(at date: Date? = nil) {
        let date = date ?? now()
        if mode.usesTimer {
            timer.update(at: date)
            pomodoro.followTimer(remaining: timer.remaining, at: date)
        } else {
            pomodoro.isAutoRepeatEnabled = timer.isAutoRepeatEnabled
            pomodoro.update(at: date)
            if pomodoro.focusRemaining + pomodoro.restRemaining == 0 {
                isPaused = true
                timer.isEnginePaused = true
                pomodoro.setSharedPaused(true, at: date)
            }
            projectPomodoro(at: date)
        }
    }

    /// The controller settles the outgoing view before changing its timeout policy.
    func selectMode(_ mode: CountdownMode) {
        let date = now()
        self.mode = mode
        timer.setClockEnabled(mode.isClockEnabled, settle: false)
        if mode.usesTimer {
            timer.setSharedRemaining(min(TimerModel.maximumDuration, timer.remaining), at: date)
            pomodoro.followTimer(remaining: timer.remaining, at: date)
        } else if timer.remaining == 0 {
            // An empty timer has no stage to resume. The active Pomodoro view starts a cycle.
            pomodoro.reset(at: date)
            pomodoro.setSharedPaused(isPaused, at: date)
            projectPomodoro(at: date)
        } else {
            pomodoro.reserveMinimumRest(at: date)
            projectPomodoro(at: date)
        }
        if mode.usesTimer { timer.captureRepeatDuration() }
        timer.save()
    }

    func setAutoRepeatEnabled(_ enabled: Bool) {
        timer.setAutoRepeatEnabled(enabled)
        pomodoro.isAutoRepeatEnabled = enabled
    }

    func timerDidChange(at date: Date? = nil) {
        pomodoro.followTimer(remaining: timer.remaining, at: date ?? now())
    }

    func toggleRunning() {
        update()
        let date = now()
        isPaused.toggle()
        timer.isEnginePaused = isPaused
        if mode.usesTimer {
            if isPaused { timer.pause() } else { timer.resume() }
            pomodoro.setSharedPaused(isPaused, at: date)
            pomodoro.followTimer(remaining: timer.remaining, at: date)
        } else {
            if isPaused {
                pomodoro.pause(at: date)
            } else if pomodoro.focusRemaining + pomodoro.restRemaining == 0 {
                pomodoro.reset(at: date)
                pomodoro.setSharedPaused(false, at: date)
            } else {
                pomodoro.toggleRunning(at: date)
            }
            projectPomodoro(at: date)
        }
        timer.save()
    }

    func adjustPomodoroEndpoint(_ phase: PomodoroModel.Phase, steps: Int, at date: Date) {
        pomodoro.adjustClockEndpoint(phase, steps: steps, at: date)
        projectPomodoro(at: date)
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval, at date: Date? = nil) {
        let date = date ?? now()
        pomodoro.adjustDuration(phase, by: amount, at: date)
        projectPomodoro(at: date)
    }

    func autoAlignPomodoro(at date: Date) {
        pomodoro.autoAlign(at: date)
        projectPomodoro(at: date)
    }

    /// Reset the cycle without changing the shared run state.
    func resetPomodoro() {
        let date = now()
        pomodoro.reset(at: date)
        pomodoro.setSharedPaused(isPaused, at: date)
        projectPomodoro(at: date)
    }
}

import Combine
import Foundation

/// Owns all countdown activity. UI mode changes do not change its run state.
@MainActor
final class CountdownEngine: ObservableObject {
    @Published private(set) var isPaused: Bool
    let timer: TimerModel
    @Published private(set) var pomodoro: PomodoroModel
    private let now: () -> Date
    private var timerChanges: AnyCancellable?

    init(timer: TimerModel, pomodoro: PomodoroModel, isPaused: Bool, now: @escaping () -> Date) {
        self.timer = timer
        self.pomodoro = pomodoro
        self.isPaused = isPaused
        self.now = now
        timer.isPausedByCore = isPaused
        if self.pomodoro.status == .ready { self.pomodoro.toggleRunning(at: now()) }
        if isPaused {
            timer.stop()
            self.pomodoro.pause(at: now())
        } else {
            timer.start()
        }
        timerChanges = timer.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    func update(at date: Date? = nil) {
        let date = date ?? now()
        timer.update(at: date)
        pomodoro.update(at: date)
    }

    func toggleRunning() {
        update()
        isPaused.toggle()
        timer.isPausedByCore = isPaused
        if isPaused {
            timer.stop()
            pomodoro.pause(at: now())
        } else {
            timer.start()
            if pomodoro.status == .paused { pomodoro.toggleRunning(at: now()) }
        }
    }

    func setClockEnabled(_ enabled: Bool) {
        timer.setClockEnabled(enabled)
        pomodoro.setClockEnabled(enabled, at: now())
    }

    func adjustPomodoroEndpoint(_ phase: PomodoroModel.Phase, steps: Int, at date: Date) {
        pomodoro.adjustClockEndpoint(phase, steps: steps, at: date)
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval, at date: Date? = nil) {
        pomodoro.adjustDuration(phase, by: amount, at: date ?? now())
    }

    /// Reset the cycle without changing the shared run state.
    func resetPomodoro() {
        let clock = pomodoro.clockSchedule != nil
        pomodoro.reset()
        pomodoro.toggleRunning(at: now())
        if isPaused { pomodoro.pause(at: now()) }
        pomodoro.setClockEnabled(clock, at: now())
    }
}

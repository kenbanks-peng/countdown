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
        self.pomodoro.toggleRunning(at: now())
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

    func update() {
        timer.update()
        pomodoro.update(at: now())
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

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval) {
        pomodoro.adjustDuration(phase, by: amount, at: now())
    }

    /// Reset the pair without changing the shared run state.
    func resetPomodoro() {
        pomodoro.reset()
        pomodoro.toggleRunning(at: now())
        if isPaused { pomodoro.pause(at: now()) }
    }
}

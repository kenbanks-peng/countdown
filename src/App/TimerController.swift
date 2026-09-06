import Foundation
import Combine

enum TimerMode: String, CaseIterable {
    case countdown = "Countdown"
    case pomodoro = "Pomodoro"
}

/// Mode-aware commands keep hidden timers paused and their lifecycle rules separate.
@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var mode: TimerMode = .countdown
    let countdown: CountdownModel
    @Published private(set) var pomodoro = PomodoroModel()
    private let now: () -> Date

    init(
        stateStore: CountdownStateStore = .default,
        configuration: CountdownConfiguration = .default,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownModel.playSound,
        now: @escaping () -> Date = Date.init
    ) {
        self.now = now
        countdown = CountdownModel(
            stateStore: stateStore, configuration: configuration,
            playSound: playSound, now: now
        )
    }

    func selectMode(_ mode: TimerMode) {
        guard mode != self.mode else { return }
        let previousMode = self.mode
        self.mode = mode
        if previousMode == .countdown {
            countdown.stop()
        } else {
            pomodoro.pause(at: now())
        }
    }

    func adjustCountdownDuration(by amount: TimeInterval) {
        guard mode == .countdown else { return }
        countdown.adjustDuration(by: amount)
    }

    func toggleCountdownRunning() {
        guard mode == .countdown else { return }
        countdown.toggleRunning()
    }

    func setCountdownToNextHour() {
        guard mode == .countdown else { return }
        countdown.setDurationToNextHour()
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval) {
        guard mode == .pomodoro else { return }
        pomodoro.adjustDuration(phase, by: amount, at: now())
    }

    func togglePomodoroRunning() {
        guard mode == .pomodoro else { return }
        pomodoro.toggleRunning(at: now())
    }

    func resetPomodoro() {
        guard mode == .pomodoro else { return }
        pomodoro.reset()
    }

    func update() {
        switch mode {
        case .countdown: countdown.update()
        case .pomodoro: pomodoro.update(at: now())
        }
    }

    func save() {
        countdown.save()
    }
}

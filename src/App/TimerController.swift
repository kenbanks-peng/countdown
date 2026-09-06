import Foundation
import Combine

enum TimerMode: String, CaseIterable {
    case countdown = "Countdown"
    case pomodoro = "Pomodoro"
}

/// The application command boundary keeps hidden Countdown activity out of Pomodoro.
@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var mode: TimerMode = .countdown
    let countdown: CountdownModel
    let pomodoro = PomodoroModel()

    init(
        stateStore: CountdownStateStore = .default,
        configuration: CountdownConfiguration = .default,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownModel.playSound,
        now: @escaping () -> Date = Date.init
    ) {
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

    func update() {
        guard mode == .countdown else { return }
        countdown.update()
    }

    func save() {
        countdown.save()
    }
}

import Foundation
import Combine

enum TimerMode: String, CaseIterable, Codable {
    case countdown = "Countdown"
    case pomodoro = "Pomodoro"

    var label: String { self == .countdown ? "Timer" : "Pomodoro" }
}

/// The app core owns shared features and routes commands to the selected mode.
@MainActor
final class TimerController: ObservableObject {
    @Published private(set) var mode: TimerMode = .countdown
    let features: TimerFeatures
    let countdown: CountdownModel
    @Published private(set) var pomodoro = PomodoroModel()
    private let now: () -> Date
    private let settingsStore: TimerSettingsStore
    private var countdownChanges: AnyCancellable?

    init(
        stateStore: CountdownStateStore = .default,
        configuration: CountdownConfiguration = .default,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownModel.playSound,
        now: @escaping () -> Date = Date.init,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownConfiguration.saveEnablement($0, enabled: $1) }
    ) {
        self.now = now
        settingsStore = stateStore.timerSettingsStore
        let settings = settingsStore.load()
        mode = settings.mode
        pomodoro = PomodoroModel(focusDuration: settings.focusDuration, breakDuration: settings.breakDuration)
        var isRestoringHiddenCountdown = settings.mode == .pomodoro
        let features = TimerFeatures(configuration: configuration, playSound: playSound, saveEnablement: saveEnablement)
        self.features = features
        countdown = CountdownModel(
            stateStore: stateStore, configuration: configuration,
            playSound: { url in
                if !isRestoringHiddenCountdown { playSound(url) }
            }, now: now,
            reportElapsed: { previous, remaining in
                if !isRestoringHiddenCountdown {
                    features.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            }
        )
        if mode == .pomodoro { countdown.stop() }
        isRestoringHiddenCountdown = false
        countdownChanges = countdown.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var controlLabel: String {
        switch mode {
        case .countdown: countdown.isPaused ? "Resume" : "Pause"
        case .pomodoro: pomodoro.controlLabel
        }
    }

    var canToggleRunning: Bool { mode == .pomodoro || countdown.status != .empty }

    func toggleRunning() {
        switch mode {
        case .countdown: toggleCountdownRunning()
        case .pomodoro: togglePomodoroRunning()
        }
    }

    func selectMode(_ mode: TimerMode) {
        guard mode != self.mode else { return }
        if self.mode == .countdown {
            countdown.stop()
        } else {
            let date = now()
            updatePomodoro(at: date)
            pomodoro.pause(at: date)
        }
        self.mode = mode
        saveSettings()
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
        let date = now()
        updatePomodoro(at: date)
        pomodoro.adjustDuration(phase, by: amount, at: date)
        saveSettings()
    }

    func togglePomodoroRunning() {
        guard mode == .pomodoro else { return }
        let date = now()
        updatePomodoro(at: date)
        pomodoro.toggleRunning(at: date)
    }

    func resetPomodoro() {
        guard mode == .pomodoro else { return }
        pomodoro.reset()
    }

    func update() {
        switch mode {
        case .countdown: countdown.update()
        case .pomodoro: updatePomodoro(at: now())
        }
    }

    private func updatePomodoro(at date: Date) {
        let previous = pomodoro.focusRemaining + pomodoro.breakRemaining
        pomodoro.update(at: date)
        features.reportElapsed(previousRemaining: previous, remaining: pomodoro.focusRemaining + pomodoro.breakRemaining)
    }

    func save() {
        countdown.save()
        saveSettings()
    }

    private func saveSettings() {
        settingsStore.save(TimerSettings(
            mode: mode, focusDuration: pomodoro.focusDuration, breakDuration: pomodoro.breakDuration
        ))
    }
}

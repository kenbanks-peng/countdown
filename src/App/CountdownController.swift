import Foundation
import Combine

/// Composes the shared Countdown core with Timer and Pomodoro modes.
@MainActor
final class CountdownController: ObservableObject {
    @Published private(set) var mode: CountdownMode = .timer
    let features: CountdownFeatures
    let timer: TimerModel
    @Published private(set) var pomodoro = PomodoroModel()
    private let now: () -> Date
    private let settingsStore: CountdownSettingsStore
    private var timerChanges: AnyCancellable?

    init(
        stateStore: TimerStateStore = .default,
        configuration: CountdownConfiguration = .default,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownSound.play,
        now: @escaping () -> Date = Date.init,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownConfiguration.saveEnablement($0, enabled: $1) }
    ) {
        self.now = now
        settingsStore = CountdownSettingsStore(
            fileManager: stateStore.fileManager, stateDirectory: stateStore.stateDirectory
        )
        let settings = settingsStore.load()
        mode = settings.mode
        pomodoro = PomodoroModel(focusDuration: settings.focusDuration, breakDuration: settings.breakDuration)
        var isRestoringHiddenTimer = settings.mode == .pomodoro
        let features = CountdownFeatures(configuration: configuration, playSound: playSound, saveEnablement: saveEnablement)
        self.features = features
        timer = TimerModel(
            stateStore: stateStore, configuration: configuration,
            playSound: { url in
                if !isRestoringHiddenTimer { playSound(url) }
            }, now: now,
            reportElapsed: { previous, remaining in
                if !isRestoringHiddenTimer {
                    features.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            }
        )
        if mode == .pomodoro { timer.stop() }
        isRestoringHiddenTimer = false
        timerChanges = timer.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var controlLabel: String {
        switch mode {
        case .timer: timer.isPaused ? "Resume" : "Pause"
        case .pomodoro: pomodoro.controlLabel
        }
    }

    var canToggleRunning: Bool { mode == .pomodoro || timer.status != .empty }

    func toggleRunning() {
        switch mode {
        case .timer: toggleTimerRunning()
        case .pomodoro: togglePomodoroRunning()
        }
    }

    func selectMode(_ mode: CountdownMode) {
        guard mode != self.mode else { return }
        if self.mode == .timer {
            timer.stop()
        } else {
            let date = now()
            updatePomodoro(at: date)
            pomodoro.pause(at: date)
        }
        self.mode = mode
        saveSettings()
    }

    func adjustTimerDuration(by amount: TimeInterval) {
        guard mode == .timer else { return }
        timer.adjustDuration(by: amount)
    }

    func toggleTimerRunning() {
        guard mode == .timer else { return }
        timer.toggleRunning()
    }

    func setTimerToNextHour() {
        guard mode == .timer else { return }
        timer.setDurationToNextHour()
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
        case .timer: timer.update()
        case .pomodoro: updatePomodoro(at: now())
        }
    }

    private func updatePomodoro(at date: Date) {
        let previous = pomodoro.focusRemaining + pomodoro.breakRemaining
        pomodoro.update(at: date)
        features.reportElapsed(previousRemaining: previous, remaining: pomodoro.focusRemaining + pomodoro.breakRemaining)
    }

    func save() {
        timer.save()
        saveSettings()
    }

    private func saveSettings() {
        settingsStore.save(CountdownSettings(
            mode: mode, focusDuration: pomodoro.focusDuration, breakDuration: pomodoro.breakDuration
        ))
    }
}

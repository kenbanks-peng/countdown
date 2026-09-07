import Foundation
import Combine

/// Selects presentation and timeout actions; the core owns countdown activity.
@MainActor
final class CountdownController: ObservableObject {
    @Published private(set) var mode: CountdownMode = .timer
    let features: CountdownFeatures
    let countdown: CountdownEngine
    var timer: TimerModel { countdown.timer }
    var pomodoro: PomodoroModel { countdown.pomodoro }
    private let settingsStore: CountdownSettingsStore
    private let timeoutPolicy: TimeoutPolicy
    private var countdownChanges: AnyCancellable?
    private let now: () -> Date
    var currentTime: Date { now() }

    private final class TimeoutPolicy {
        var mode: CountdownMode
        init(mode: CountdownMode) { self.mode = mode }
    }

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
        let policy = TimeoutPolicy(mode: settings.mode)
        timeoutPolicy = policy
        let features = CountdownFeatures(configuration: configuration, playSound: playSound, saveEnablement: saveEnablement)
        self.features = features
        let timer = TimerModel(
            stateStore: stateStore, configuration: configuration, playSound: playSound, now: now,
            reportElapsed: { previous, remaining in
                if policy.mode == .timer {
                    features.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            },
            timeoutActionsEnabled: { policy.mode == .timer }
        )
        countdown = CountdownEngine(
            timer: timer,
            pomodoro: PomodoroModel(focusDuration: settings.focusDuration, breakDuration: settings.breakDuration),
            isPaused: settings.isPaused ?? timer.isPaused, now: now
        )
        countdownChanges = countdown.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var controlLabel: String { countdown.isPaused ? "Resume" : "Pause" }
    var canToggleRunning: Bool { true }

    func toggleRunning() {
        update()
        countdown.toggleRunning()
        saveSettings()
    }

    func selectMode(_ mode: CountdownMode) {
        guard mode != self.mode else { return }
        // Settle elapsed time under the outgoing mode's timeout policy.
        update()
        self.mode = mode
        timeoutPolicy.mode = mode
        saveSettings()
    }

    func adjustTimerDuration(by amount: TimeInterval) {
        guard mode == .timer else { return }
        update()
        timer.adjustDuration(by: amount)
    }

    func toggleTimerRunning() {
        guard mode == .timer else { return }
        toggleRunning()
    }

    func setTimerToNextHour() {
        guard mode == .timer else { return }
        update()
        timer.setDurationToNextHour()
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval) {
        guard mode == .pomodoro else { return }
        update()
        countdown.adjustPomodoroDuration(phase, by: amount)
        saveSettings()
    }

    func togglePomodoroRunning() {
        guard mode == .pomodoro else { return }
        toggleRunning()
    }

    func resetPomodoro() {
        guard mode == .pomodoro else { return }
        update()
        countdown.resetPomodoro()
    }

    func update() {
        let previous = pomodoro.focusRemaining + pomodoro.breakRemaining
        countdown.update()
        if mode == .pomodoro {
            features.reportElapsed(previousRemaining: previous, remaining: pomodoro.focusRemaining + pomodoro.breakRemaining)
        }
    }

    func save() {
        update()
        timer.save()
        saveSettings()
    }

    private func saveSettings() {
        settingsStore.save(CountdownSettings(
            mode: mode, focusDuration: pomodoro.focusDuration, breakDuration: pomodoro.breakDuration,
            isPaused: countdown.isPaused
        ))
    }
}

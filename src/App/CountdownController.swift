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
        featureState: CountdownFeatureState? = nil,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownSound.play,
        now: @escaping () -> Date = Date.init,
        saveEnablement: ((String, Bool) -> Void)? = nil
    ) {
        self.now = now
        settingsStore = CountdownSettingsStore(
            fileManager: stateStore.fileManager, stateDirectory: stateStore.stateDirectory
        )
        let settings = settingsStore.load(defaults: CountdownSettings(
            focusDuration: TimeInterval(configuration.pomodoroFocusMinutes * 60),
            restDuration: TimeInterval(configuration.pomodoroRestMinutes * 60),
            longRestDuration: TimeInterval(configuration.pomodoroLongRestMinutes * 60)
        ))
        mode = settings.mode
        let policy = TimeoutPolicy(mode: settings.mode)
        timeoutPolicy = policy
        let featureStateStore = CountdownFeatureStateStore(
            fileManager: stateStore.fileManager, stateDirectory: stateStore.stateDirectory
        )
        let state = featureState ?? featureStateStore.load()
        let features = CountdownFeatures(
            configuration: configuration, state: state, playSound: playSound, now: now,
            saveEnablement: saveEnablement ?? { featureStateStore.saveEnablement($0, enabled: $1) }
        )
        self.features = features
        let timer = TimerModel(
            stateStore: stateStore, configuration: configuration, featureState: state, playSound: playSound, now: now,
            reportElapsed: { previous, remaining in
                if policy.mode == .timer {
                    features.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            },
            timeoutActionsEnabled: { policy.mode == .timer }
        )
        countdown = CountdownEngine(
            timer: timer,
            pomodoro: PomodoroModel(
                focusDuration: settings.focusDuration, restDuration: settings.restDuration,
                longRestDuration: settings.longRestDuration ?? 900
            ),
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
        if countdown.isPaused { features.skipPausedPopups() }
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
        let previousElapsed = pomodoro.elapsedTime
        countdown.update()
        if mode == .pomodoro {
            let remaining = pomodoro.focusRemaining + pomodoro.restRemaining
            features.reportElapsed(previousRemaining: remaining + pomodoro.elapsedTime - previousElapsed, remaining: remaining)
        } else if timer.remaining == 0 {
            features.reportElapsed(previousRemaining: 0, remaining: 0)
        }
    }

    func save() {
        update()
        timer.save()
        saveSettings()
    }

    private func saveSettings() {
        settingsStore.save(CountdownSettings(
            mode: mode, focusDuration: pomodoro.focusDuration, restDuration: pomodoro.restDuration,
            isPaused: countdown.isPaused, longRestDuration: pomodoro.longRestDuration
        ))
    }
}

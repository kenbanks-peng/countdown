import Foundation
import Combine

/// Selects presentation and timeout actions; the core owns countdown activity.
@MainActor
final class CountdownController: ObservableObject {
    @Published private(set) var mode: CountdownMode = .timer
    let notifications: NotificationScheduler
    let testEnabled: Bool
    let testNotificationRequested = PassthroughSubject<CountdownConfiguration, Never>()
    private let reloadConfiguration: () -> CountdownConfiguration
    let engine: CountdownEngine
    var timer: TimerModel { engine.timer }
    var pomodoro: PomodoroModel { engine.pomodoro }
    private let settingsStore: CountdownSettingsStore
    private let timeoutPolicy: TimeoutPolicy
    private var engineSubscription: AnyCancellable?
    private let now: () -> Date
    var currentTime: Date { now() }

    private final class TimeoutPolicy {
        var mode: CountdownMode
        init(mode: CountdownMode) { self.mode = mode }
    }

    init(
        sessionStore: TimerSessionStore = .default,
        configuration: CountdownConfiguration = .default,
        preferences: CountdownPreferences? = nil,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownSound.play,
        now: @escaping () -> Date = Date.init,
        saveEnablement: ((String, Bool) -> Void)? = nil,
        reloadConfiguration: @escaping () -> CountdownConfiguration = { CountdownConfiguration.load() }
    ) {
        self.now = now
        self.reloadConfiguration = reloadConfiguration
        testEnabled = configuration.testEnabled
        settingsStore = CountdownSettingsStore(
            fileManager: sessionStore.fileManager, stateDirectory: sessionStore.stateDirectory
        )
        let settings = settingsStore.load(defaults: CountdownSettings(
            focusDuration: TimeInterval(configuration.pomodoroFocusMinutes * 60),
            restDuration: TimeInterval(configuration.pomodoroRestMinutes * 60),
            longRestDuration: TimeInterval(configuration.pomodoroLongRestMinutes * 60)
        ))
        mode = settings.mode
        let policy = TimeoutPolicy(mode: settings.mode)
        timeoutPolicy = policy
        let preferencesStore = CountdownPreferencesStore(
            fileManager: sessionStore.fileManager, stateDirectory: sessionStore.stateDirectory
        )
        let state = preferences ?? preferencesStore.load()
        let notifications = NotificationScheduler(
            configuration: configuration, state: state, playSound: playSound,
            saveEnablement: saveEnablement ?? { preferencesStore.saveEnablement($0, enabled: $1) }
        )
        self.notifications = notifications
        let timer = TimerModel(
            sessionStore: sessionStore, configuration: configuration, preferences: state,
            isClockEnabled: settings.mode.isClockEnabled, playSound: playSound, now: now,
            reportElapsed: { previous, remaining in
                if policy.mode.usesTimer {
                    notifications.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            },
            timeoutActionsEnabled: { policy.mode.usesTimer }
        )
        var pomodoro = PomodoroModel(
            focusDuration: settings.focusDuration, restDuration: settings.restDuration,
            longRestDuration: settings.longRestDuration ?? TimeInterval(configuration.pomodoroLongRestMinutes * 60), focusPeriodsPerCycle: configuration.pomodoroFocusPeriodsPerCycle,
            defaultDurations: (
                TimeInterval(configuration.pomodoroFocusMinutes * 60),
                TimeInterval(configuration.pomodoroRestMinutes * 60),
                TimeInterval(configuration.pomodoroLongRestMinutes * 60)
            )
        )
        pomodoro.isAutoRepeatEnabled = state.autoRepeatEnabled
        if let schedule = settings.pomodoroClockSchedule {
            pomodoro.restoreClockSchedule(schedule, at: now(), advance: settings.mode == .pomodoro)
        }
        engine = CountdownEngine(
            timer: timer, pomodoro: pomodoro,
            isPaused: settings.isPaused ?? timer.isPaused, mode: settings.mode, now: now
        )
        engineSubscription = engine.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var controlLabel: String { engine.isPaused ? "Resume" : "Pause" }

    /// Preview the current notification without waiting for an interval or enabling alerts.
    func testNotification() {
        guard testEnabled else { return }
        let configuration = reloadConfiguration()
        update()
        testNotificationRequested.send(configuration)
    }

    func setAutoRepeatEnabled(_ enabled: Bool) {
        update()
        engine.setAutoRepeatEnabled(enabled)
        saveSettings()
    }

    func toggleRunning() {
        update()
        engine.toggleRunning()
        saveSettings()
    }

    func selectMode(_ mode: CountdownMode) {
        guard mode != self.mode else { return }
        // Settle elapsed time under the outgoing mode's timeout policy.
        update()
        self.mode = mode
        timeoutPolicy.mode = mode
        engine.selectMode(mode)
        saveSettings()
    }

    func adjustTimerDuration(by amount: TimeInterval) {
        guard mode.usesTimer else { return }
        update()
        timer.adjustDuration(by: amount)
        engine.timerDidChange()
        saveSettings()
    }

    func adjustTimerDuration(steps: Int) {
        guard mode.usesTimer, steps != 0 else { return }
        let date = currentTime
        update(at: date)
        defer {
            engine.timerDidChange(at: date)
            saveSettings()
        }
        if mode.isClockEnabled {
            timer.adjustClockEndpoint(steps: steps, at: date)
            return
        }
        guard timer.status != .empty || steps > 0 else { return }
        // Use the displayed minute to select the next relative mark. Otherwise,
        // elapsed fractions of a second make upward scrolls repeat the same mark.
        let delta = CountdownAdjustment.delta(
            steps: steps, end: timer.remaining, minimum: 0, maximum: TimerModel.maximumDuration,
            from: Double(timer.remainingMinutes) * 60
        )
        guard steps > 0 ? delta > 0 : delta < 0 else { return }
        timer.adjustDuration(by: delta, at: date)
    }

    func toggleTimerRunning() {
        guard mode.usesTimer else { return }
        toggleRunning()
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, by amount: TimeInterval) {
        guard mode == .pomodoro else { return }
        update()
        engine.adjustPomodoroDuration(phase, by: amount)
        saveSettings()
    }

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, steps: Int) {
        guard mode == .pomodoro, steps != 0 else { return }
        let date = currentTime
        update(at: date)
        engine.adjustPomodoroEndpoint(phase, steps: steps, at: date)
        saveSettings()
    }

    func restartPomodoroStage(_ stage: Int) {
        guard mode == .pomodoro, (1...pomodoro.focusPeriodsPerCycle).contains(stage) else { return }
        // Replace the outgoing phase without sending any overdue notifications.
        engine.restartPomodoroStage(stage, at: currentTime)
        notifications.reportPhaseChange(remaining: pomodoro.focusRemaining)
        saveSettings()
    }

    func togglePomodoroRunning() {
        guard mode == .pomodoro else { return }
        toggleRunning()
    }

    var canAutoAlign: Bool {
        mode.usesTimer || pomodoro.canAutoAlign(at: currentTime)
    }

    func autoAlign() {
        let date = currentTime
        update(at: date)
        if mode.usesTimer {
            timer.autoAlign(at: date)
            engine.timerDidChange(at: date)
        } else {
            engine.autoAlignPomodoro(at: date)
        }
        saveSettings()
    }

    func update(at date: Date? = nil) {
        let previousElapsed = pomodoro.elapsedTime
        let previousFocus = pomodoro.focusRemaining
        let previousRest = pomodoro.restRemaining
        engine.update(at: date)
        guard mode == .pomodoro, pomodoro.focusRemaining + pomodoro.restRemaining > 0 else { return }
        let elapsed = max(0, pomodoro.elapsedTime - previousElapsed)
        guard elapsed > 0 else { return }

        // A late update can cross several phases or a whole cycle. Notify only
        // for the current phase, never replay the phases that were missed.
        let crossedStage = elapsed >= previousFocus + previousRest
        if crossedStage || (previousFocus > 0 && pomodoro.focusRemaining == 0) {
            notifications.reportPhaseChange(remaining: pomodoro.focusRemaining)
        } else if previousFocus > 0 {
            notifications.reportElapsed(previousRemaining: previousFocus, remaining: pomodoro.focusRemaining)
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
            isPaused: engine.isPaused, longRestDuration: pomodoro.longRestDuration,
            pomodoroClockSchedule: pomodoro.clockSchedule
        ))
    }
}

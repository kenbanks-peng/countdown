import Foundation
import Combine

/// Selects presentation and timeout actions; the core owns countdown activity.
@MainActor
final class CountdownController: ObservableObject {
    @Published private(set) var mode: CountdownMode = .timer
    let popups: PopupScheduler
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
        saveEnablement: ((String, Bool) -> Void)? = nil
    ) {
        self.now = now
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
        let popups = PopupScheduler(
            configuration: configuration, state: state, playSound: playSound, now: now,
            saveEnablement: saveEnablement ?? { preferencesStore.saveEnablement($0, enabled: $1) }
        )
        self.popups = popups
        let timer = TimerModel(
            sessionStore: sessionStore, configuration: configuration, preferences: state,
            isClockEnabled: settings.mode.isClockEnabled, playSound: playSound, now: now,
            reportElapsed: { previous, remaining in
                if policy.mode.usesTimer {
                    popups.reportElapsed(previousRemaining: previous, remaining: remaining)
                }
            },
            timeoutActionsEnabled: { policy.mode.usesTimer }
        )
        var pomodoro = PomodoroModel(
            focusDuration: settings.focusDuration, restDuration: settings.restDuration,
            longRestDuration: settings.longRestDuration ?? 900, focusPeriodsPerCycle: configuration.pomodoroFocusPeriodsPerCycle,
            defaultDurations: (
                TimeInterval(configuration.pomodoroFocusMinutes * 60),
                TimeInterval(configuration.pomodoroRestMinutes * 60),
                TimeInterval(configuration.pomodoroLongRestMinutes * 60)
            )
        )
        if let schedule = settings.pomodoroClockSchedule {
            pomodoro.restoreClockSchedule(schedule, at: now())
        }
        engine = CountdownEngine(
            timer: timer, pomodoro: pomodoro,
            isPaused: settings.isPaused ?? timer.isPaused, now: now
        )
        engineSubscription = engine.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }

    var controlLabel: String { engine.isPaused ? "Resume" : "Pause" }

    func toggleRunning() {
        update()
        if engine.isPaused { popups.skipPausedPopups() }
        engine.toggleRunning()
        saveSettings()
    }

    func selectMode(_ mode: CountdownMode) {
        guard mode != self.mode else { return }
        // Settle elapsed time under the outgoing mode's timeout policy.
        update()
        self.mode = mode
        timeoutPolicy.mode = mode
        timer.setClockEnabled(mode.isClockEnabled)
        saveSettings()
    }

    func adjustTimerDuration(by amount: TimeInterval) {
        guard mode.usesTimer else { return }
        update()
        timer.adjustDuration(by: amount)
    }

    func adjustTimerDuration(steps: Int) {
        guard mode.usesTimer, steps != 0 else { return }
        let date = currentTime
        update(at: date)
        if mode.isClockEnabled {
            timer.adjustClockEndpoint(steps: steps, at: date)
            return
        }
        guard timer.status != .empty || steps > 0 else { return }
        // A relative countdown keeps decreasing between inputs. Snapping its remaining
        // time to the next mark would repeatedly restore the same value instead of adding time.
        let target = min(TimerModel.maximumDuration,
                         max(300, timer.remaining + Double(steps) * CountdownAdjustment.increment))
        let delta = target - timer.remaining
        guard steps > 0 ? delta > 0 : delta < 0 else { return }
        timer.adjustDuration(by: delta, at: date)
    }

    func toggleTimerRunning() {
        guard mode.usesTimer else { return }
        toggleRunning()
    }

    func setTimerToNextHour() {
        guard mode.usesTimer else { return }
        update()
        timer.setDurationToNextHour()
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

    func togglePomodoroRunning() {
        guard mode == .pomodoro else { return }
        toggleRunning()
    }

    func resetPomodoro() {
        guard mode == .pomodoro else { return }
        update()
        engine.resetPomodoro()
        saveSettings()
    }

    func update(at date: Date? = nil) {
        let previousElapsed = pomodoro.elapsedTime
        engine.update(at: date)
        if mode == .pomodoro {
            let remaining = pomodoro.focusRemaining + pomodoro.restRemaining
            popups.reportElapsed(previousRemaining: remaining + pomodoro.elapsedTime - previousElapsed, remaining: remaining)
        } else if timer.remaining == 0 {
            popups.reportElapsed(previousRemaining: 0, remaining: 0)
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

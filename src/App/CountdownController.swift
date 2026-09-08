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
        var pomodoro = PomodoroModel(
            focusDuration: settings.focusDuration, restDuration: settings.restDuration,
            longRestDuration: settings.longRestDuration ?? 900, cycles: configuration.pomodoroCycles
        )
        if state.clockEnabled, let schedule = settings.pomodoroClockSchedule {
            pomodoro.restoreClockSchedule(schedule, at: now())
        }
        countdown = CountdownEngine(
            timer: timer, pomodoro: pomodoro,
            isPaused: settings.isPaused ?? timer.isPaused, now: now
        )
        countdown.setClockEnabled(state.clockEnabled)
        features.clockEnablementChanged = { [weak self] enabled in
            guard let self else { return }
            self.update()
            self.countdown.setClockEnabled(enabled)
            self.saveSettings()
        }
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

    func adjustTimerDuration(steps: Int) {
        guard mode == .timer, steps != 0 else { return }
        let date = currentTime
        update(at: date)
        if features.isClockEnabled {
            timer.adjustClockEndpoint(steps: steps, at: date)
            return
        }
        let delta = CountdownAdjustment.delta(
            steps: steps, end: timer.remaining,
            minimum: 300, maximum: TimerModel.maximumDuration
        )
        timer.adjustDuration(by: delta, at: date)
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

    func adjustPomodoroDuration(_ phase: PomodoroModel.Phase, steps: Int) {
        guard mode == .pomodoro, steps != 0 else { return }
        let date = currentTime
        update(at: date)
        if features.isClockEnabled {
            countdown.adjustPomodoroEndpoint(phase, steps: steps, at: date)
            saveSettings()
            return
        }
        let originalStage = pomodoro.stage
        let originalEnd = pomodoroAdjustmentRange(phase).end
        let leading = pomodoro.restPhase
        let trailing: PomodoroModel.Phase = .focus
        let editsVisiblePair = phase == .focus || phase == pomodoro.restPhase

        if editsVisiblePair && phase == trailing {
            alignPomodoroEnd(leading, at: date)
        }
        let range = pomodoroAdjustmentRange(phase)
        let delta = CountdownAdjustment.delta(
            steps: steps, end: range.end, minimum: range.minimum, maximum: range.maximum,
            from: originalEnd
        )
        countdown.adjustPomodoroDuration(phase, by: delta, at: date)
        if editsVisiblePair {
            if pomodoro.stage != originalStage {
                // A decrease can finish rest. Align the new pair, not the completed stage.
                alignPomodoroEnd(pomodoro.restPhase, at: date)
                alignPomodoroEnd(.focus, at: date)
            } else {
                // Moving the leading boundary must not leave the following end between marks.
                alignPomodoroEnd(trailing, at: date)
            }
        }
        saveSettings()
    }

    private func alignPomodoroEnd(_ phase: PomodoroModel.Phase, at date: Date) {
        if phase == .focus && pomodoro.focusRemaining == 0 { return }
        let range = pomodoroAdjustmentRange(phase)
        let delta = CountdownAdjustment.nearestDelta(
            end: range.end, minimum: range.minimum, maximum: range.maximum
        )
        countdown.adjustPomodoroDuration(phase, by: delta, at: date)
    }

    private func pomodoroAdjustmentRange(
        _ phase: PomodoroModel.Phase
    ) -> (end: TimeInterval, minimum: TimeInterval, maximum: TimeInterval) {
        let model = pomodoro
        let duration: TimeInterval
        let end: TimeInterval
        let maximum: TimeInterval
        switch phase {
        case .focus:
            duration = model.focusDuration
            // Completed focus can still be edited for the next stage from the menu.
            let remaining = model.focusRemaining > 0 ? model.focusRemaining : duration
            end = model.activeRestDuration + remaining
            maximum = 3_600 - max(model.restDuration, model.longRestDuration)
        case .rest, .longRest:
            duration = phase == .rest ? model.restDuration : model.longRestDuration
            let remaining = phase == model.restPhase ? model.restRemaining : duration
            end = remaining
            maximum = 3_600 - model.focusDuration
        }
        return (end: end, minimum: end + 300 - duration, maximum: end + maximum - duration)
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

    func update(at date: Date? = nil) {
        let previousElapsed = pomodoro.elapsedTime
        countdown.update(at: date)
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
            isPaused: countdown.isPaused, longRestDuration: pomodoro.longRestDuration,
            pomodoroClockSchedule: pomodoro.clockSchedule
        ))
    }
}

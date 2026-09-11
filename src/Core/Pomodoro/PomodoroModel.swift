import Foundation

/// Repeating cycle with a configurable stage count, controlled by CountdownEngine.
/// Allocations are shared across stages; progress belongs to the current stage.
struct PomodoroModel {
    enum Status { case ready, running, paused }
    enum Phase { case focus, rest, longRest }
    enum DotState { case pending, current, completed }

    let focusPeriodsPerCycle: Int
    private let defaultDurations: (focus: TimeInterval, rest: TimeInterval, longRest: TimeInterval)

    static func normalizedFocusPeriodCount(_ value: Int) -> Int {
        (1...12).contains(value) ? value : 4
    }

    private(set) var focusDuration: TimeInterval
    private(set) var restDuration: TimeInterval
    private(set) var longRestDuration: TimeInterval
    var isAutoRepeatEnabled = true
    var isAutoAlignEnabled = false

    var savedFocusDuration: TimeInterval { clockSchedule?.savedFocusDuration ?? focusDuration }
    var savedRestDuration: TimeInterval { clockSchedule?.savedRestDuration ?? restDuration }
    var savedLongRestDuration: TimeInterval { clockSchedule?.savedLongRestDuration ?? longRestDuration }
    private(set) var stage = 1
    private(set) var status: Status = .ready
    private(set) var elapsedTime: TimeInterval = 0
    private var focusCompleted = false
    private var focusElapsed: TimeInterval = 0
    private var restElapsed: TimeInterval = 0
    private var lastUpdate: Date?
    private(set) var clockSchedule: PomodoroClockSchedule?

    init(focusDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60,
         longRestDuration: TimeInterval = 20 * 60, focusPeriodsPerCycle: Int = 4,
         defaultDurations: (focus: TimeInterval, rest: TimeInterval, longRest: TimeInterval)? = nil) {
        self.defaultDurations = defaultDurations ?? (focusDuration, restDuration, longRestDuration)
        self.focusPeriodsPerCycle = Self.normalizedFocusPeriodCount(focusPeriodsPerCycle)
        self.focusDuration = focusDuration
        self.restDuration = restDuration
        self.longRestDuration = longRestDuration
    }

    var restPhase: Phase { stage == focusPeriodsPerCycle ? .longRest : .rest }
    var activeRestDuration: TimeInterval { stage == focusPeriodsPerCycle ? longRestDuration : restDuration }
    var focusRemaining: TimeInterval {
        if let schedule = clockSchedule {
            return schedule.focusCompleted ? 0 : max(0, schedule.focusEnd.timeIntervalSince(schedule.pausedAt ?? schedule.sampledAt))
        }
        return focusCompleted ? 0 : max(0, focusDuration - focusElapsed)
    }
    var restRemaining: TimeInterval {
        if let schedule = clockSchedule {
            let date = schedule.pausedAt ?? schedule.sampledAt
            let start = schedule.focusCompleted ? date : max(date, schedule.focusEnd)
            return max(0, schedule.end(for: restPhase).timeIntervalSince(start))
        }
        return max(0, activeRestDuration - restElapsed)
    }
    var phaseLabel: String { focusRemaining > 0 ? "Focus" : (stage == focusPeriodsPerCycle ? "Long rest" : "Rest") }
    var completedFocusPeriods: Int { stage - 1 + (focusCompleted ? 1 : 0) }
    var cycleDuration: TimeInterval {
        Double(focusPeriodsPerCycle) * focusDuration + Double(focusPeriodsPerCycle - 1) * restDuration + longRestDuration
    }

    var dotStates: [DotState] {
        (1...focusPeriodsPerCycle).map { index in
            if index <= completedFocusPeriods { return .completed }
            if index == stage { return .current }
            return .pending
        }
    }

    var progressDescription: String { "Focus period \(stage) of \(focusPeriodsPerCycle). \(completedFocusPeriods) completed." }

    var accessibilityDescription: String {
        let rest = stage == focusPeriodsPerCycle ? "Long rest" : "Rest"
        switch status {
        case .ready:
            return "Pomodoro ready. Focus: \(minutes(focusDuration)) allocated. \(rest): \(minutes(activeRestDuration)) allocated."
        case .running, .paused:
            let state = status == .running ? "running" : "paused"
            if focusRemaining > 0 {
                return "Pomodoro \(state). Focus: \(minutes(focusRemaining)) remaining. \(rest): \(minutes(restRemaining)) remaining."
            }
            return "Pomodoro \(state). \(rest): \(minutes(restRemaining)) remaining. Focus complete."
        }
    }

    private func minutes(_ duration: TimeInterval) -> String {
        let count = Int(ceil(duration / 60))
        return "\(count) \(count == 1 ? "minute" : "minutes")"
    }

    mutating func setClockEnabled(_ enabled: Bool, at now: Date) {
        update(at: now)
        if enabled && clockSchedule == nil {
            let spentFocus = focusCompleted ? focusDuration : min(focusDuration, focusElapsed)
            let start = now.addingTimeInterval(-spentFocus - restElapsed)
            clockSchedule = PomodoroClockSchedule(
                stageStart: start, focusEnd: start + focusDuration,
                restEnd: start + focusDuration + restDuration,
                longRestEnd: start + focusDuration + longRestDuration,
                sampledAt: now, pausedAt: status == .running ? nil : now,
                stage: stage, focusCompleted: focusCompleted
            )
        } else if !enabled {
            clockSchedule = nil
        }
    }

    mutating func restoreClockSchedule(_ schedule: PomodoroClockSchedule, at now: Date, advance: Bool = true) {
        guard schedule.isValid(focusPeriodsPerCycle: focusPeriodsPerCycle) else { return }
        clockSchedule = schedule
        status = schedule.pausedAt == nil ? .running : .paused
        lastUpdate = schedule.sampledAt
        if advance { update(at: now) }
        syncClockProgress()
    }

    /// Change the shared run state without rounding or repeating an inactive schedule.
    mutating func setSharedPaused(_ paused: Bool, at now: Date) {
        if paused && status == .paused { return }
        if let reference = clockSchedule?.pausedAt {
            let shift = max(0, now.timeIntervalSince(reference))
            clockSchedule?.stageStart += shift
            clockSchedule?.focusEnd += shift
            clockSchedule?.restEnd += shift
            clockSchedule?.longRestEnd += shift
        }
        clockSchedule?.pausedAt = paused ? now : nil
        clockSchedule?.sampledAt = now
        status = paused ? .paused : .running
        lastUpdate = paused ? nil : now
        syncClockProgress()
    }

    func canAutoAlign(at now: Date) -> Bool {
        clockSchedule?.autoAlignedRestEnd(at: now, restPhase: restPhase) != nil
    }

    mutating func autoAlign(at now: Date) {
        update(at: now)
        let phase = restPhase
        clockSchedule?.autoAlign(at: now, restPhase: phase)
        syncClockProgress()
    }

    mutating func adjustClockEndpoint(_ phase: Phase, steps: Int, at now: Date) {
        update(at: now)
        guard let target = prepareFocusEdit(phase, increasing: steps > 0, at: now) else { return }
        clockSchedule?.edit(target, steps: steps)
        advanceClock(at: now)
        syncClockProgress()
    }

    private mutating func advanceClock(at now: Date) {
        let count = focusPeriodsPerCycle
        clockSchedule?.advance(at: now, focusPeriodsPerCycle: count,
                               autoRepeat: isAutoRepeatEnabled, autoAlign: isAutoAlignEnabled)
    }

    private mutating func syncClockProgress() {
        guard let schedule = clockSchedule else { return }
        stage = schedule.stage
        focusDuration = schedule.focusDuration
        restDuration = schedule.restDuration
        longRestDuration = schedule.longRestDuration
        focusCompleted = schedule.focusCompleted
        let date = schedule.pausedAt ?? schedule.sampledAt
        focusElapsed = min(focusDuration, max(0, date.timeIntervalSince(schedule.stageStart)))
        restElapsed = activeRestDuration - restRemaining
    }

    /// Follow the shared timer without starting another Pomodoro stage.
    mutating func followTimer(remaining: TimeInterval, at now: Date) {
        guard var schedule = clockSchedule else { return }
        if status == .running {
            elapsedTime += max(0, now.timeIntervalSince(lastUpdate ?? now))
            lastUpdate = now
            schedule.sampledAt = now
        }
        let reference = schedule.pausedAt ?? now
        if reference >= schedule.focusEnd { schedule.focusCompleted = true }
        clockSchedule = schedule
        syncClockProgress()
        let total = focusRemaining + restRemaining
        guard abs(total - remaining) > 0.000_001 else { return }

        // Keep the rest that is still available. A new timer reserves the configured rest.
        let rest = min(remaining, total > 0 ? restRemaining : activeRestDuration)
        let focus = max(0, remaining - rest)
        if focus > 0 {
            schedule.stageStart = reference
            schedule.focusEnd = reference + focus
            schedule.restEnd = schedule.focusEnd + (restPhase == .rest ? rest : restDuration)
            schedule.longRestEnd = schedule.focusEnd + (restPhase == .longRest ? rest : longRestDuration)
            schedule.restCarry = restPhase == .rest ? restDuration - rest : nil
            schedule.longRestCarry = restPhase == .longRest ? longRestDuration - rest : nil
            schedule.focusCompleted = false
        } else {
            // Retain the rest allocation and represent its spent part with a past focus endpoint.
            schedule.focusEnd = reference + rest - activeRestDuration
            schedule.stageStart = schedule.focusEnd
            schedule.restEnd = schedule.focusEnd + restDuration
            schedule.longRestEnd = schedule.focusEnd + longRestDuration
            schedule.restCarry = nil
            schedule.longRestCarry = nil
            schedule.focusCompleted = true
        }
        clockSchedule = schedule
        syncClockProgress()
    }

    /// Reserve five minutes of rest when entering Pomodoro. Reuse focus time
    /// first; only a total below five minutes needs to grow.
    mutating func reserveMinimumRest(at now: Date) {
        guard var schedule = clockSchedule, restRemaining < 300 else { return }
        let reference = schedule.pausedAt ?? now
        let focus = max(0, focusRemaining + restRemaining - 300)
        let shortRest = max(300, restDuration)
        let longRest = max(300, longRestDuration)
        schedule.stageStart = reference
        schedule.focusEnd = reference + focus
        schedule.restEnd = schedule.focusEnd + (restPhase == .rest ? 300 : shortRest)
        schedule.longRestEnd = schedule.focusEnd + (restPhase == .longRest ? 300 : longRest)
        schedule.restCarry = restPhase == .rest ? shortRest - 300 : nil
        schedule.longRestCarry = restPhase == .longRest ? longRest - 300 : nil
        schedule.focusCompleted = focus == 0
        schedule.sampledAt = now
        clockSchedule = schedule
        syncClockProgress()
    }

    mutating func adjustDuration(_ phase: Phase, by amount: TimeInterval, at now: Date) {
        guard amount.isFinite else { return }
        update(at: now)
        if clockSchedule != nil {
            guard let target = prepareFocusEdit(phase, increasing: amount > 0, at: now) else { return }
            clockSchedule?.edit(target, amount: amount)
            advanceClock(at: now)
            syncClockProgress()
            return
        }
        switch phase {
        case .focus:
            focusDuration = min(3_600 - restDuration, max(300, focusDuration + amount))
        case .rest:
            restDuration = min(3_600 - focusDuration, max(300, restDuration + amount))
        case .longRest:
            longRestDuration = min(3_600, max(300, longRestDuration + amount))
        }
        // Removed time is not elapsed time in the next phase or stage.
        finishDepletedPhases()
    }

    /// During rest, either direction first repairs the rest minimum. Further
    /// increases restore focus; decreases cannot move an expired focus endpoint.
    private mutating func prepareFocusEdit(_ phase: Phase, increasing: Bool, at now: Date) -> Phase? {
        guard phase == .focus, focusRemaining == 0,
              var schedule = clockSchedule else { return phase }
        if restRemaining < 300 { return restPhase }
        guard increasing else { return nil }
        let reference = schedule.pausedAt ?? now
        let rest = restRemaining
        schedule.stageStart = reference
        schedule.focusEnd = reference
        schedule.restEnd = reference + (restPhase == .rest ? rest : restDuration)
        schedule.longRestEnd = reference + (restPhase == .longRest ? rest : longRestDuration)
        schedule.restCarry = restPhase == .rest ? restDuration - rest : nil
        schedule.longRestCarry = restPhase == .longRest ? longRestDuration - rest : nil
        schedule.focusCompleted = false
        clockSchedule = schedule
        return phase
    }

    mutating func toggleRunning(at now: Date) {
        switch status {
        case .ready, .paused:
            clockSchedule?.resume(at: now)
            status = .running
            lastUpdate = now
            advanceClock(at: now)
            syncClockProgress()
        case .running:
            pause(at: now)
        }
    }

    /// Restart the selected stage with full allocations and no spent rest.
    mutating func restartStage(_ stage: Int, restoringDefaults: Bool = false, at now: Date) {
        guard (1...focusPeriodsPerCycle).contains(stage) else { return }
        if restoringDefaults { reset(at: now) }
        let focus = savedFocusDuration
        let rest = savedRestDuration
        let longRest = savedLongRestDuration
        focusDuration = focus
        restDuration = rest
        longRestDuration = longRest
        self.stage = stage
        resetStage()
        clockSchedule = PomodoroClockSchedule(
            stageStart: now, focusEnd: now + focusDuration,
            restEnd: now + focusDuration + restDuration,
            longRestEnd: now + focusDuration + longRestDuration,
            sampledAt: now, pausedAt: nil, stage: stage, focusCompleted: false
        )
        alignNewStage(at: now)
        status = .running
        lastUpdate = now
    }

    private mutating func alignNewStage(at now: Date) {
        guard isAutoAlignEnabled else { return }
        let isFinalStage = stage == focusPeriodsPerCycle
        clockSchedule?.alignForRepeat(at: now, isFinalStage: isFinalStage)
        syncClockProgress()
    }

    mutating func reset() {
        focusDuration = defaultDurations.focus
        restDuration = defaultDurations.rest
        longRestDuration = defaultDurations.longRest
        clockSchedule = nil
        status = .ready
        stage = 1
        elapsedTime = 0
        resetStage()
        lastUpdate = nil
    }

    /// Start from minimum allocations, then apply defaults through clock edits.
    /// This reserves at least five minutes for rest even with a large focus default.
    mutating func reset(at now: Date) {
        reset()
        clockSchedule = PomodoroClockSchedule(
            stageStart: now, focusEnd: now + 300,
            restEnd: now + 600, longRestEnd: now + 600,
            sampledAt: now, pausedAt: now, stage: 1, focusCompleted: false
        )
        adjustDuration(.focus, by: defaultDurations.focus - 300, at: now)
        adjustDuration(.rest, by: defaultDurations.rest - 300, at: now)
        adjustDuration(.longRest, by: defaultDurations.longRest - 300, at: now)
        alignNewStage(at: now)
    }

    mutating func pause(at now: Date) {
        update(at: now)
        guard status == .running else { return }
        status = .paused
        clockSchedule?.pausedAt = now
        lastUpdate = nil
    }

    mutating func update(at now: Date) {
        guard status == .running, let lastUpdate else { return }
        var elapsed = max(0, now.timeIntervalSince(lastUpdate))
        self.lastUpdate = max(lastUpdate, now)
        elapsedTime += elapsed
        if clockSchedule != nil {
            advanceClock(at: now)
            syncClockProgress()
            return
        }
        while elapsed > 0 {
            // Skip whole cycles after sleep without an unbounded loop.
            if isAutoRepeatEnabled && stage == 1 && focusElapsed == 0 && restElapsed == 0 && !focusCompleted {
                elapsed = elapsed.truncatingRemainder(dividingBy: cycleDuration)
                if elapsed == 0 { break }
            }
            let focusTime = min(focusRemaining, elapsed)
            focusElapsed += focusTime
            elapsed -= focusTime
            let restTime = min(restRemaining, elapsed)
            restElapsed += restTime
            elapsed -= restTime
            finishDepletedPhases()
            if !isAutoRepeatEnabled && stage == focusPeriodsPerCycle && focusRemaining + restRemaining == 0 { break }
        }
    }

    private mutating func finishDepletedPhases() {
        if focusRemaining == 0 { focusCompleted = true }
        if focusCompleted && restRemaining == 0 {
            if stage == focusPeriodsPerCycle && !isAutoRepeatEnabled { return }
            stage = stage == focusPeriodsPerCycle ? 1 : stage + 1
            resetStage()
        }
    }

    private mutating func resetStage() {
        focusCompleted = false
        focusElapsed = 0
        restElapsed = 0
    }
}

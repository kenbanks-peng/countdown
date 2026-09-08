import Foundation

/// Repeating cycle with a configurable stage count, controlled by CountdownEngine.
/// Allocations are shared across stages; progress belongs to the current stage.
struct PomodoroModel {
    enum Status { case ready, running, paused }
    enum Phase { case focus, rest, longRest }
    enum DotState { case pending, current, completed }

    let cycles: Int

    static func validCycles(_ value: Int) -> Int {
        (1...12).contains(value) ? value : 4
    }

    private(set) var focusDuration: TimeInterval
    private(set) var restDuration: TimeInterval
    private(set) var longRestDuration: TimeInterval
    private(set) var stage = 1
    private(set) var status: Status = .ready
    private(set) var elapsedTime: TimeInterval = 0
    private var focusCompleted = false
    private var focusElapsed: TimeInterval = 0
    private var restElapsed: TimeInterval = 0
    private var lastUpdate: Date?
    private(set) var clockSchedule: PomodoroClockSchedule?

    init(focusDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60,
         longRestDuration: TimeInterval = 15 * 60, cycles: Int = 4) {
        self.cycles = Self.validCycles(cycles)
        self.focusDuration = focusDuration
        self.restDuration = restDuration
        self.longRestDuration = longRestDuration
    }

    var restPhase: Phase { stage == cycles ? .longRest : .rest }
    var activeRestDuration: TimeInterval { stage == cycles ? longRestDuration : restDuration }
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
    var phaseLabel: String { focusRemaining > 0 ? "Focus" : (stage == cycles ? "Long rest" : "Rest") }
    var completedFocusPeriods: Int { stage - 1 + (focusCompleted ? 1 : 0) }
    var cycleDuration: TimeInterval {
        Double(cycles) * focusDuration + Double(cycles - 1) * restDuration + longRestDuration
    }

    var dotStates: [DotState] {
        (1...cycles).map { index in
            if index <= completedFocusPeriods { return .completed }
            if index == stage { return .current }
            return .pending
        }
    }

    var progressDescription: String { "Focus period \(stage) of \(cycles). \(completedFocusPeriods) completed." }

    var accessibilityDescription: String {
        let rest = stage == cycles ? "Long rest" : "Rest"
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

    mutating func restoreClockSchedule(_ schedule: PomodoroClockSchedule, at now: Date) {
        guard schedule.isValid(cycles: cycles) else { return }
        clockSchedule = schedule
        status = schedule.pausedAt == nil ? .running : .paused
        lastUpdate = schedule.sampledAt
        update(at: now)
        syncClockProgress()
    }

    mutating func adjustClockEndpoint(_ phase: Phase, steps: Int, at now: Date) {
        update(at: now)
        clockSchedule?.edit(phase, steps: steps)
        advanceClock(at: now)
        syncClockProgress()
    }

    private mutating func advanceClock(at now: Date) {
        let count = cycles
        clockSchedule?.advance(at: now, cycles: count)
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

    mutating func adjustDuration(_ phase: Phase, by amount: TimeInterval, at now: Date) {
        guard amount.isFinite else { return }
        update(at: now)
        if clockSchedule != nil {
            clockSchedule?.edit(phase, amount: amount)
            advanceClock(at: now)
            syncClockProgress()
            return
        }
        switch phase {
        case .focus:
            focusDuration = min(3_600 - max(restDuration, longRestDuration), max(60, focusDuration + amount))
        case .rest:
            restDuration = min(3_600 - focusDuration, max(60, restDuration + amount))
        case .longRest:
            longRestDuration = min(3_600 - focusDuration, max(60, longRestDuration + amount))
        }
        // Removed time is not elapsed time in the next phase or stage.
        finishDepletedPhases()
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

    mutating func reset() {
        clockSchedule = nil
        status = .ready
        stage = 1
        elapsedTime = 0
        resetStage()
        lastUpdate = nil
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
            if stage == 1 && focusElapsed == 0 && restElapsed == 0 && !focusCompleted {
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
        }
    }

    private mutating func finishDepletedPhases() {
        if focusRemaining == 0 { focusCompleted = true }
        if focusCompleted && restRemaining == 0 {
            stage = stage == cycles ? 1 : stage + 1
            resetStage()
        }
    }

    private mutating func resetStage() {
        focusCompleted = false
        focusElapsed = 0
        restElapsed = 0
    }
}

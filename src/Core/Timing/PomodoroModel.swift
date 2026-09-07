import Foundation

/// Repeating four-stage cycle, controlled by CountdownEngine.
/// Allocations are shared across stages; progress belongs to the current stage.
struct PomodoroModel {
    enum Status { case ready, running, paused }
    enum Phase { case focus, rest, longRest }
    enum DotState { case pending, current, completed }

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

    init(focusDuration: TimeInterval = 25 * 60, restDuration: TimeInterval = 5 * 60,
         longRestDuration: TimeInterval = 15 * 60) {
        self.focusDuration = focusDuration
        self.restDuration = restDuration
        self.longRestDuration = longRestDuration
    }

    var restPhase: Phase { stage == 4 ? .longRest : .rest }
    var activeRestDuration: TimeInterval { stage == 4 ? longRestDuration : restDuration }
    var focusRemaining: TimeInterval { focusCompleted ? 0 : max(0, focusDuration - focusElapsed) }
    var restRemaining: TimeInterval { max(0, activeRestDuration - restElapsed) }
    var phaseLabel: String { focusRemaining > 0 ? "Focus" : (stage == 4 ? "Long rest" : "Rest") }
    var completedFocusPeriods: Int { stage - 1 + (focusCompleted ? 1 : 0) }
    var cycleDuration: TimeInterval { 4 * focusDuration + 3 * restDuration + longRestDuration }

    var dotStates: [DotState] {
        (1...4).map { index in
            if index <= completedFocusPeriods { return .completed }
            if index == stage { return .current }
            return .pending
        }
    }

    var progressDescription: String { "Focus period \(stage) of 4. \(completedFocusPeriods) completed." }

    var accessibilityDescription: String {
        let rest = stage == 4 ? "Long rest" : "Rest"
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

    mutating func adjustDuration(_ phase: Phase, by amount: TimeInterval, at now: Date) {
        guard amount.isFinite else { return }
        update(at: now)
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
            status = .running
            lastUpdate = now
        case .running:
            pause(at: now)
        }
    }

    mutating func reset() {
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
        lastUpdate = nil
    }

    mutating func update(at now: Date) {
        guard status == .running, let lastUpdate else { return }
        var elapsed = max(0, now.timeIntervalSince(lastUpdate))
        self.lastUpdate = max(lastUpdate, now)
        elapsedTime += elapsed
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
            stage = stage == 4 ? 1 : stage + 1
            resetStage()
        }
    }

    private mutating func resetStage() {
        focusCompleted = false
        focusElapsed = 0
        restElapsed = 0
    }
}

import Foundation

/// One focus/short-break pair. Elapsed time stops at the end of the pair.
struct PomodoroModel {
    enum Status { case ready, running, paused, completed }

    let focusDuration: TimeInterval = 25 * 60
    let breakDuration: TimeInterval = 5 * 60
    private(set) var status: Status = .ready
    private var focusElapsed: TimeInterval = 0
    private var breakElapsed: TimeInterval = 0
    private var lastUpdate: Date?

    var focusRemaining: TimeInterval { max(0, focusDuration - focusElapsed) }
    var breakRemaining: TimeInterval { max(0, breakDuration - breakElapsed) }
    var phaseLabel: String { focusRemaining > 0 ? "Focus" : "Break" }

    var controlLabel: String {
        switch status {
        case .ready, .completed: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }

    var accessibilityDescription: String {
        switch status {
        case .ready:
            return "Pomodoro ready. Focus: \(minutes(focusDuration)) allocated. Break: \(minutes(breakDuration)) allocated."
        case .completed:
            return "Pomodoro complete. Focus: 0 minutes remaining. Break: 0 minutes remaining."
        case .running, .paused:
            let state = status == .running ? "running" : "paused"
            if focusRemaining > 0 {
                return "Pomodoro \(state). Focus: \(minutes(focusRemaining)) remaining. Break: \(minutes(breakRemaining)) remaining."
            }
            return "Pomodoro \(state). Break: \(minutes(breakRemaining)) remaining. Focus complete."
        }
    }

    private func minutes(_ duration: TimeInterval) -> String {
        let count = Int(ceil(duration / 60))
        return "\(count) \(count == 1 ? "minute" : "minutes")"
    }

    mutating func toggleRunning(at now: Date) {
        switch status {
        case .ready, .completed:
            focusElapsed = 0
            breakElapsed = 0
            status = .running
            lastUpdate = now
        case .running:
            pause(at: now)
        case .paused:
            status = .running
            lastUpdate = now
        }
    }

    mutating func reset() {
        status = .ready
        focusElapsed = 0
        breakElapsed = 0
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
        let elapsed = max(0, now.timeIntervalSince(lastUpdate))
        self.lastUpdate = max(lastUpdate, now)
        let focusTime = min(focusRemaining, elapsed)
        focusElapsed += focusTime
        breakElapsed += min(breakRemaining, elapsed - focusTime)
        if focusRemaining == 0 && breakRemaining == 0 {
            status = .completed
            self.lastUpdate = nil
        }
    }
}

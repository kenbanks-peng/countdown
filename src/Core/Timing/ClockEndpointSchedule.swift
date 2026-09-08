import Foundation

/// Absolute clock settings. Only an explicit edit or resume snaps an endpoint.
enum ClockBoundary {
    static func move(_ end: Date, steps: Int, minimum: Date, maximum: Date) -> Date {
        let origin = Calendar.current.startOfDay(for: minimum)
        return end.addingTimeInterval(CountdownAdjustment.delta(
            steps: steps, end: end.timeIntervalSince(origin),
            minimum: minimum.timeIntervalSince(origin), maximum: maximum.timeIntervalSince(origin)
        ))
    }

    static func nearest(_ end: Date, minimum: Date, maximum: Date) -> Date {
        let origin = Calendar.current.startOfDay(for: minimum)
        return end.addingTimeInterval(CountdownAdjustment.nearestDelta(
            end: end.timeIntervalSince(origin), minimum: minimum.timeIntervalSince(origin),
            maximum: maximum.timeIntervalSince(origin)
        ))
    }
}

/// Both rest settings follow the same focus endpoint. Editing focus moves both
/// rest endpoints by the same amount, so their durations stay constant.
struct PomodoroClockSchedule: Codable {
    // Allocation origin. An edit can move it forward to reuse elapsed clock space.
    var stageStart: Date
    var focusEnd: Date
    var restEnd: Date
    var longRestEnd: Date
    var sampledAt: Date
    var pausedAt: Date?
    var stage: Int
    var focusCompleted: Bool

    var focusDuration: TimeInterval { focusEnd.timeIntervalSince(stageStart) }
    var restDuration: TimeInterval { restEnd.timeIntervalSince(focusEnd) }
    var longRestDuration: TimeInterval { longRestEnd.timeIntervalSince(focusEnd) }

    func isValid(cycles: Int) -> Bool {
        let values = [stageStart, focusEnd, restEnd, longRestEnd, sampledAt] + [pausedAt].compactMap { $0 }
        return values.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite }
            && (1...cycles).contains(stage)
            && focusDuration >= 60 && restDuration >= 60 && longRestDuration >= 60
            && focusDuration + restDuration <= 3_600 && longRestDuration <= 3_600
    }

    func end(for phase: PomodoroModel.Phase) -> Date {
        switch phase {
        case .focus: focusEnd
        case .rest: restEnd
        case .longRest: longRestEnd
        }
    }

    mutating func edit(_ phase: PomodoroModel.Phase, steps: Int? = nil, amount: TimeInterval = 0) {
        let minimum: Date
        let maximum: Date
        switch phase {
        case .focus:
            // An active focus edit must leave five minutes from the clock reference.
            // Completed focus edits only change the allocation for following stages.
            let reference = focusCompleted ? stageStart : max(stageStart, pausedAt ?? sampledAt)
            minimum = reference.addingTimeInterval(300)
            maximum = reference.addingTimeInterval(3_600 - restDuration)
        case .rest:
            minimum = focusEnd.addingTimeInterval(300)
            let reference = max(stageStart, pausedAt ?? sampledAt)
            maximum = min(reference.addingTimeInterval(3_600), focusEnd.addingTimeInterval(3_300))
        case .longRest:
            minimum = focusEnd.addingTimeInterval(300)
            maximum = focusEnd.addingTimeInterval(3_600)
        }
        let end = end(for: phase)
        let target = steps.map { ClockBoundary.move(end, steps: $0, minimum: minimum, maximum: maximum) }
            ?? ClockBoundary.nearest(end.addingTimeInterval(amount), minimum: minimum, maximum: maximum)
        switch phase {
        case .focus:
            let shift = target.timeIntervalSince(focusEnd)
            focusEnd = target
            restEnd += shift
            longRestEnd += shift
        case .rest: restEnd = target
        case .longRest: longRestEnd = target
        }
        // Keep future allocations within one hour without counting elapsed time
        // against this edit. Do not move any selected endpoint during this rebase.
        stageStart = max(stageStart, restEnd.addingTimeInterval(-3_600))
        if (pausedAt ?? sampledAt) >= focusEnd { focusCompleted = true }
    }

    mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        let shift = max(0, now.timeIntervalSince(pausedAt))
        stageStart += shift
        focusEnd += shift
        restEnd += shift
        longRestEnd += shift
        // Snap each compensated setting once. Long rest can extend beyond the visible hour.
        focusEnd = ClockBoundary.nearest(focusEnd, minimum: stageStart + 300, maximum: stageStart + 3_300)
        restEnd = ClockBoundary.nearest(restEnd, minimum: focusEnd + 300, maximum: stageStart + 3_600)
        longRestEnd = ClockBoundary.nearest(longRestEnd, minimum: focusEnd + 300, maximum: focusEnd + 3_600)
        self.pausedAt = nil
        sampledAt = now
    }

    mutating func advance(at now: Date, cycles: Int) {
        guard pausedAt == nil else { return }
        sampledAt = max(sampledAt, now)
        while sampledAt >= (stage == cycles ? longRestEnd : restEnd) {
            let start = stage == cycles ? longRestEnd : restEnd
            stage = stage == cycles ? 1 : stage + 1
            moveStage(to: start)
            // The first stage can start between marks. Snap newly created settings,
            // not the previous stage's selected endpoints, before repeating spacing.
            focusEnd = ClockBoundary.nearest(focusEnd, minimum: start + 300, maximum: start + 3_300)
            restEnd = ClockBoundary.nearest(restEnd, minimum: focusEnd + 300, maximum: start + 3_600)
            longRestEnd = ClockBoundary.nearest(longRestEnd, minimum: focusEnd + 300, maximum: focusEnd + 3_600)
            // Once the new endpoints are aligned, whole cycles preserve alignment.
            let cycle = Double(cycles) * focusDuration
                + Double(cycles - 1) * restDuration + longRestDuration
            let completeCycles = max(0, floor(sampledAt.timeIntervalSince(stageStart) / cycle))
            let alignedStart = ClockBoundary.nearest(start, minimum: start - 300, maximum: start + 300)
            if completeCycles > 0 && start == alignedStart {
                moveStage(to: stageStart + completeCycles * cycle)
            }
        }
        if sampledAt >= focusEnd { focusCompleted = true }
    }

    mutating func moveStage(to start: Date) {
        let shift = start.timeIntervalSince(stageStart)
        stageStart = start
        focusEnd += shift
        restEnd += shift
        longRestEnd += shift
        focusCompleted = false
    }
}

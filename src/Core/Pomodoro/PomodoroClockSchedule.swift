import Foundation

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
    // Rest already spent before focus was restored.
    var restCarry: TimeInterval?
    var longRestCarry: TimeInterval?
    // Align changes this stage only. Restore this allocation at the next stage.
    var nextStageFocusDuration: TimeInterval?
    var nextStageRestDuration: TimeInterval?
    var nextStageLongRestDuration: TimeInterval?

    var savedFocusDuration: TimeInterval { nextStageFocusDuration ?? focusDuration }
    var savedRestDuration: TimeInterval { nextStageRestDuration ?? restDuration }
    var savedLongRestDuration: TimeInterval { nextStageLongRestDuration ?? longRestDuration }

    var focusDuration: TimeInterval { focusEnd.timeIntervalSince(stageStart) }
    var restDuration: TimeInterval { restEnd.timeIntervalSince(focusEnd) + (restCarry ?? 0) }
    var longRestDuration: TimeInterval { longRestEnd.timeIntervalSince(focusEnd) + (longRestCarry ?? 0) }

    func isValid(focusPeriodsPerCycle: Int) -> Bool {
        let values = [stageStart, focusEnd, restEnd, longRestEnd, sampledAt] + [pausedAt].compactMap { $0 }
        return values.allSatisfy { $0.timeIntervalSinceReferenceDate.isFinite }
            && (1...focusPeriodsPerCycle).contains(stage)
            && focusDuration >= 0 && focusDuration <= 3_600
            && restDuration >= 60 && restDuration <= 3_600
            && longRestDuration >= 60
            && (longRestDuration <= 3_600 || (nextStageLongRestDuration != nil
                && longRestDuration < savedLongRestDuration + 1_800))
            && [restCarry ?? 0, longRestCarry ?? 0].allSatisfy { $0.isFinite && $0 >= 0 }
            && (nextStageFocusDuration.map { $0.isFinite && $0 >= 0 && $0 <= 3_600 } ?? true)
            && [nextStageRestDuration, nextStageLongRestDuration].compactMap { $0 }
                .allSatisfy { $0.isFinite && $0 >= 60 && $0 <= 3_600 }
            && restEnd >= focusEnd && longRestEnd >= focusEnd
    }

    func end(for phase: PomodoroModel.Phase) -> Date {
        switch phase {
        case .focus: focusEnd
        case .rest: restEnd
        case .longRest: longRestEnd
        }
    }

    /// Switch between the next two half-hour endpoints. Only the five-minute
    /// rest minimum can exclude an endpoint; the current phase cannot.
    func autoAlignedRestEnd(at now: Date, restPhase: PomodoroModel.Phase,
                            calendar: Calendar = .current) -> Date? {
        ClockBoundary.alignment(
            from: end(for: restPhase), minimum: now + 300, maximum: now + 3_600, calendar: calendar
        )
    }

    mutating func autoAlign(at now: Date, restPhase: PomodoroModel.Phase) {
        guard let target = autoAlignedRestEnd(at: now, restPhase: restPhase) else { return }
        captureSavedDurations()
        let shortRest = restDuration
        let longRest = longRestDuration
        let reference = pausedAt ?? now
        let remainingRest = end(for: restPhase).timeIntervalSince(max(reference, focusEnd))
        let rest = min(target.timeIntervalSince(now), max(300, remainingRest))
        focusEnd = target - rest
        stageStart = now
        // Keep the inactive short-rest allocation within the one-hour clock.
        restEnd = restPhase == .rest ? target : focusEnd + min(shortRest, 3_600 - focusDuration)
        longRestEnd = restPhase == .longRest ? target : focusEnd + longRest
        restCarry = nil
        longRestCarry = nil
        focusCompleted = focusEnd <= now
        sampledAt = now
        if pausedAt != nil { pausedAt = now }
    }

    private mutating func captureSavedDurations() {
        nextStageFocusDuration = savedFocusDuration
        nextStageRestDuration = savedRestDuration
        nextStageLongRestDuration = savedLongRestDuration
    }

    /// Unlike Align, automatic alignment always chooses the first boundary.
    /// The final rest can span more boundaries but cannot be shorter than its saved minimum.
    mutating func alignForRepeat(at start: Date, isFinalStage: Bool) {
        captureSavedDurations()
        let rest = max(300, savedRestDuration)
        guard let end = ClockBoundary.halfHour(atOrAfter: start + rest) else { return }
        stageStart = start
        focusEnd = end - rest
        restEnd = end
        longRestEnd = isFinalStage
            ? ClockBoundary.halfHour(atOrAfter: focusEnd + savedLongRestDuration) ?? focusEnd + savedLongRestDuration
            : focusEnd + savedLongRestDuration
        restCarry = nil
        longRestCarry = nil
        focusCompleted = focusEnd <= start
    }

    mutating func edit(_ phase: PomodoroModel.Phase, steps: Int? = nil, amount: TimeInterval = 0) {
        // A manual edit becomes the allocation for following stages.
        switch phase {
        case .focus: nextStageFocusDuration = nil
        case .rest: nextStageRestDuration = nil
        case .longRest: nextStageLongRestDuration = nil
        }
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
            minimum = max(focusEnd, pausedAt ?? sampledAt).addingTimeInterval(300)
            let reference = max(stageStart, pausedAt ?? sampledAt)
            maximum = min(reference.addingTimeInterval(3_600), focusEnd.addingTimeInterval(3_300 - (restCarry ?? 0)))
        case .longRest:
            minimum = max(focusEnd, pausedAt ?? sampledAt).addingTimeInterval(300)
            maximum = focusEnd.addingTimeInterval(3_600 - (longRestCarry ?? 0))
        }
        if phase != .focus {
            let origin = Calendar.current.startOfDay(for: minimum)
            let firstMark = origin + ceil(minimum.timeIntervalSince(origin) / 300) * 300
            if (steps == nil ? minimum : firstMark) > maximum {
                // Spent rest can fill the allocation limit. Start its allocation
                // at the current reference, without advancing the stage. Keep
                // the selected endpoint and the other rest setting.
                let reference = max(focusEnd, pausedAt ?? sampledAt)
                let focus = focusDuration
                let shortRest = restDuration
                let longRest = longRestDuration
                let selectedEnd = end(for: phase)
                stageStart = reference - focus
                focusEnd = reference
                restEnd = phase == .rest ? max(reference, selectedEnd) : reference + shortRest
                longRestEnd = phase == .longRest ? max(reference, selectedEnd) : reference + longRest
                restCarry = nil
                longRestCarry = nil
                edit(phase, steps: steps, amount: amount)
                return
            }
        }
        let end = end(for: phase)
        let target: Date
        if let steps {
            // An elapsed rest can already be below the edit minimum. Enforce
            // that minimum even when the requested direction is downward.
            let requested = ClockBoundary.move(end, steps: steps, minimum: minimum, maximum: maximum)
            target = requested < minimum
                ? ClockBoundary.move(minimum - 300, steps: 1, minimum: minimum, maximum: maximum)
                : requested
        } else {
            target = min(maximum, max(minimum, end.addingTimeInterval(amount)))
        }
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
        self.pausedAt = nil
        sampledAt = now
    }

    mutating func advance(at now: Date, focusPeriodsPerCycle: Int, autoRepeat: Bool = true,
                          autoAlign: Bool = false) {
        guard pausedAt == nil else { return }
        sampledAt = max(sampledAt, now)
        while sampledAt >= (stage == focusPeriodsPerCycle ? longRestEnd : restEnd) {
            if stage == focusPeriodsPerCycle && !autoRepeat {
                focusCompleted = true
                return
            }
            let start = stage == focusPeriodsPerCycle ? longRestEnd : restEnd
            stage = stage == focusPeriodsPerCycle ? 1 : stage + 1
            moveStage(to: start)
            if autoAlign { alignForRepeat(at: start, isFinalStage: stage == focusPeriodsPerCycle) }
            // Once aligned, each complete cycle starts on the same clock boundary.
            let cycle: TimeInterval
            if autoAlign {
                let normal = ceil(max(300, savedRestDuration) / 1_800) * 1_800
                let focus = normal - max(300, savedRestDuration)
                let final = ceil((focus + savedLongRestDuration) / 1_800) * 1_800
                cycle = Double(focusPeriodsPerCycle - 1) * normal + final
            } else {
                cycle = Double(focusPeriodsPerCycle) * focusDuration
                    + Double(focusPeriodsPerCycle - 1) * restDuration + longRestDuration
            }
            let completeCycles = max(0, floor(sampledAt.timeIntervalSince(stageStart) / cycle))
            let isBoundary = ClockBoundary.halfHour(atOrAfter: stageStart) == stageStart
            if autoRepeat && completeCycles > 0 && (!autoAlign || isBoundary) {
                moveStage(to: stageStart + completeCycles * cycle)
                if autoAlign { alignForRepeat(at: stageStart, isFinalStage: stage == focusPeriodsPerCycle) }
            }
        }
        if sampledAt >= focusEnd { focusCompleted = true }
    }

    private mutating func moveStage(to start: Date) {
        restEnd += restCarry ?? 0
        longRestEnd += longRestCarry ?? 0
        restCarry = nil
        longRestCarry = nil
        let focus = savedFocusDuration
        let rest = savedRestDuration
        let longRest = savedLongRestDuration
        stageStart = start
        focusEnd = start + focus
        restEnd = focusEnd + rest
        longRestEnd = focusEnd + longRest
        nextStageFocusDuration = nil
        nextStageRestDuration = nil
        nextStageLongRestDuration = nil
        focusCompleted = false
    }
}

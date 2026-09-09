import Foundation

/// Clockwise sectors measured in turns from 12. A nil date keeps the duration-only display.
struct CountdownArcLayout {
    let startProportion: Double
    let proportion: Double

    /// Start-inclusive and end-exclusive, including sectors that cross 12.
    func contains(_ turn: Double) -> Bool {
        guard proportion > 0 else { return false }
        if proportion >= 1 { return true }
        // Remove coordinate conversion noise at shared boundaries.
        let scale = 1_000_000_000_000.0
        var offset = ((turn - startProportion) * scale).rounded() / scale
        offset = offset.truncatingRemainder(dividingBy: 1)
        if offset < 0 { offset += 1 }
        offset = (offset * scale).rounded() / scale
        return offset < (proportion * scale).rounded() / scale
    }

    static func minuteProportion(at date: Date, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
        return (Double(parts.minute ?? 0) + seconds / 60) / 60
    }

    static func timer(remaining: TimeInterval, at date: Date?, endDate: Date? = nil, pausedAt: Date? = nil) -> Self {
        if let date, let endDate {
            let reference = pausedAt ?? date
            return Self(startProportion: minuteProportion(at: date),
                        proportion: min(1, max(0, endDate.timeIntervalSince(reference) / 3_600)))
        }
        return Self(startProportion: date.map { minuteProportion(at: $0) } ?? 0,
                    proportion: min(1, max(0, remaining / 3_600)))
    }

    static func pomodoro(
        focusRemaining: TimeInterval, restRemaining: TimeInterval,
        restDuration: TimeInterval, at date: Date?,
        schedule: PomodoroClockSchedule? = nil, restPhase: PomodoroModel.Phase = .rest
    ) -> (focus: Self, rest: Self) {
        if let date, var schedule {
            // Shift only the drawing copy. Paused durations and stored endpoints stay unchanged.
            schedule.resume(at: date)
            let start = date
            let focusEnd = schedule.focusCompleted ? start : max(start, schedule.focusEnd)
            return (
                focus: Self(startProportion: minuteProportion(at: start),
                            proportion: max(0, focusEnd.timeIntervalSince(start) / 3_600)),
                rest: Self(startProportion: minuteProportion(at: focusEnd),
                           proportion: max(0, min(schedule.end(for: restPhase), start + 3_600)
                            .timeIntervalSince(focusEnd) / 3_600))
            )
        }
        let start = date.map { minuteProportion(at: $0) } ?? 0
        let visibleRest = max(0, min(restRemaining, 3_600 - focusRemaining))
        return (
            focus: Self(startProportion: date == nil ? min(restDuration, 3_600 - focusRemaining) / 3_600 : start,
                        proportion: max(0, focusRemaining / 3_600)),
            rest: Self(startProportion: date == nil ? 0 : start + focusRemaining / 3_600,
                             proportion: visibleRest / 3_600)
        )
    }
}

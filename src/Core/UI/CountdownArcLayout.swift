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

    static func timer(remaining: TimeInterval, at date: Date?) -> Self {
        Self(startProportion: date.map { minuteProportion(at: $0) } ?? 0,
             proportion: min(1, max(0, remaining / 3_600)))
    }

    static func pomodoro(
        focusRemaining: TimeInterval, breakRemaining: TimeInterval,
        breakDuration: TimeInterval, at date: Date?
    ) -> (focus: Self, shortBreak: Self) {
        let start = date.map { minuteProportion(at: $0) } ?? 0
        return (
            focus: Self(startProportion: date == nil ? breakDuration / 3_600 : start,
                        proportion: max(0, focusRemaining / 3_600)),
            shortBreak: Self(startProportion: date == nil ? 0 : start + focusRemaining / 3_600,
                             proportion: max(0, breakRemaining / 3_600))
        )
    }
}

import Foundation

/// Clockwise sectors measured in turns from 12. A nil date keeps the duration-only display.
struct CountdownArcLayout {
    let startProportion: Double
    let proportion: Double

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

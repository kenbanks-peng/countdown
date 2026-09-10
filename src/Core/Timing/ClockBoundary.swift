import Foundation

/// Select absolute clock boundaries for scrolling and Align.
enum ClockBoundary {
    /// Select the first valid boundary, or the second when the first is already selected.
    static func alignment(from end: Date, minimum: Date, maximum: Date,
                          calendar: Calendar = .current) -> Date? {
        guard let first = halfHour(atOrAfter: minimum, calendar: calendar), first <= maximum else { return nil }
        if abs(end.timeIntervalSince(first)) < 0.001,
           let second = halfHour(atOrAfter: first + 1, calendar: calendar), second <= maximum {
            return second
        }
        return first
    }

    static func halfHour(atOrAfter minimum: Date, calendar: Calendar = .current) -> Date? {
        let components = calendar.dateComponents([.minute, .second, .nanosecond], from: minimum)
        if [0, 30].contains(components.minute), components.second == 0, components.nanosecond == 0 {
            return minimum
        }
        return [0, 30].compactMap { minute in
            calendar.nextDate(after: minimum, matching: DateComponents(minute: minute, second: 0),
                              matchingPolicy: .nextTime)
        }.min()
    }

    static func move(_ end: Date, steps: Int, minimum: Date, maximum: Date) -> Date {
        let origin = Calendar.current.startOfDay(for: minimum)
        return end.addingTimeInterval(CountdownAdjustment.delta(
            steps: steps, end: end.timeIntervalSince(origin),
            minimum: minimum.timeIntervalSince(origin), maximum: maximum.timeIntervalSince(origin)
        ))
    }
}

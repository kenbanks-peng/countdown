import Foundation

/// Align absolute endpoints only for scrolling without Option.
enum ClockBoundary {
    static func move(_ end: Date, steps: Int, minimum: Date, maximum: Date) -> Date {
        let origin = Calendar.current.startOfDay(for: minimum)
        return end.addingTimeInterval(CountdownAdjustment.delta(
            steps: steps, end: end.timeIntervalSince(origin),
            minimum: minimum.timeIntervalSince(origin), maximum: maximum.timeIntervalSince(origin)
        ))
    }
}

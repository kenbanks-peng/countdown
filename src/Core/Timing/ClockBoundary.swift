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

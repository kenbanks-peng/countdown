import Foundation

/// Moves a sector end between five-minute marks, without exceeding its allocation limits.
enum CountdownAdjustment {
    static let increment: TimeInterval = 300

    static func delta(
        steps: Int, end: TimeInterval, minimum: TimeInterval, maximum: TimeInterval,
        from originalEnd: TimeInterval? = nil
    ) -> TimeInterval {
        let originalEnd = originalEnd ?? end
        guard steps != 0, end.isFinite, originalEnd.isFinite,
              minimum.isFinite, maximum.isFinite else { return 0 }
        // Ignore sub-microsecond date/angle conversion noise at an exact mark.
        let position = originalEnd / increment
        let nearest = position.rounded()
        let normalized = abs(position - nearest) < 1e-9 ? nearest : position
        let target = (steps > 0 ? floor(normalized) : ceil(normalized)) + Double(steps)
        let lower = ceil(minimum / increment)
        let upper = floor(maximum / increment)
        guard lower <= upper else { return 0 }
        let result = min(upper, max(lower, target)) * increment - end
        // At a limit, do not move against the requested direction.
        guard steps > 0 ? end + result >= originalEnd : end + result <= originalEnd else { return 0 }
        return result
    }
}

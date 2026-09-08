import Foundation

/// Shared time bands for timer colors and reminder sounds.
enum CountdownUrgency {
    case normal, warning, urgent

    init(remaining: TimeInterval) {
        switch remaining {
        case 1_200...: self = .normal
        case 600...: self = .warning
        default: self = .urgent
        }
    }
}

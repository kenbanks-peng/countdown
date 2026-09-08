import SwiftUI

/// Timer mode changes its indicator color as the remaining time decreases.
enum TimerAppearance {
    static func indicatorColor(for remaining: TimeInterval) -> Color {
        switch CountdownUrgency(remaining: remaining) {
        case .normal: .countdownGreen
        case .warning: .countdownYellow
        case .urgent: .countdownRed
        }
    }
}

import SwiftUI

/// Timer mode changes its indicator color as the remaining time decreases.
enum TimerAppearance {
    static func indicatorColor(for remaining: TimeInterval) -> Color {
        switch remaining {
        case 1_200...: .countdownGreen
        case 600...: .countdownYellow
        default: .countdownRed
        }
    }
}

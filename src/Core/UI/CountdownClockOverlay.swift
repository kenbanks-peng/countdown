import SwiftUI

struct CountdownClockOverlay: View {
    var isClockEnabled: Bool
    var currentTime: Date
    var showsFace = true

    var body: some View {
        ZStack {
            if isClockEnabled {
                if showsFace {
                    ClockFace()
                }
                ClockHands(date: currentTime)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

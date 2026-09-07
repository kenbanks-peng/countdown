import SwiftUI

struct CountdownClockOverlay: View {
    @ObservedObject var features: CountdownFeatures
    var currentTime: Date

    var body: some View {
        ZStack {
            if features.isClockEnabled {
                ClockFace()
                ClockHands(date: currentTime)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

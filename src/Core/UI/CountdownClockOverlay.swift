import SwiftUI

struct CountdownClockOverlay: View {
    @ObservedObject var features: CountdownFeatures
    @State private var currentTime = Date.now

    var body: some View {
        ZStack {
            if features.isClockFaceEnabled { ClockFace() }
            if features.isClockHandsEnabled {
                ClockHands(date: currentTime)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                currentTime = .now
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

import SwiftUI

/// Shared pause mark for normal and compact presentations.
struct CountdownPauseIndicator: View {
    var isCompact = false

    var body: some View {
        Image(systemName: "pause.fill")
            .font(.system(size: isCompact ? 10 : 56, weight: .bold))
            .foregroundStyle(.white.opacity(isCompact ? 0.65 : 0.34))
            .allowsHitTesting(false)
            .accessibilityLabel("Paused")
    }
}

import SwiftUI

/// Readable details for an automatic popup, scaled with its expanding circle.
struct CountdownPopupOverlay: View {
    let remaining: TimeInterval
    let phase: String
    var session: String? = nil
    var isPaused = false

    static func timeLabel(_ remaining: TimeInterval) -> String {
        let seconds = Int(ceil(max(0, remaining)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 3) {
                    Text(phase)
                        .font(.system(size: 12, weight: .semibold))
                    Text(Self.timeLabel(remaining))
                        .font(.system(size: 34, weight: .semibold).monospacedDigit())
                        .tracking(-1)
                    Text(isPaused ? "Paused" : "remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                .foregroundStyle(.white)
                .frame(width: 106, height: 88)
                .background(Color.countdownSurface, in: RoundedRectangle(cornerRadius: 17))
                .overlay {
                    RoundedRectangle(cornerRadius: 17)
                        .strokeBorder(Color.countdownMuted.opacity(0.6), lineWidth: 0.7)
                }
                if let session {
                    Text(session)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.countdownSurface, in: Capsule())
                        .offset(y: 60)
                }
            }
            .frame(width: 188, height: 188)
            .scaleEffect(min(geometry.size.width, geometry.size.height) / 188)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        // The containing timer button already describes the countdown.
        .accessibilityHidden(true)
    }
}

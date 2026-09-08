import SwiftUI

/// Only the remaining minutes, centered on a transparent surface.
struct CountdownReminderOverlay: View {
    let remaining: TimeInterval
    var fontSizePt: CGFloat = CountdownConfiguration.defaultReminderFontSizePt

    static func timeLabel(_ remaining: TimeInterval) -> String {
        String(Int(ceil(max(0, remaining) / 60)))
    }

    var body: some View {
        GeometryReader { geometry in
            Text(Self.timeLabel(remaining))
                .font(.system(size: fontSizePt, weight: .semibold).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .shadow(color: .black.opacity(0.7), radius: 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("\(Self.timeLabel(remaining)) minutes remaining")
    }
}

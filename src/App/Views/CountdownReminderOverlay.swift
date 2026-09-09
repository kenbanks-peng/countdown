import SwiftUI

/// Remaining focus/timer minutes or REST, centered on a transparent surface.
struct CountdownReminderOverlay: View {
    let remaining: TimeInterval
    var isRest = false
    var fontSizePt: CGFloat = CountdownConfiguration.defaultReminderFontSizePt
    var fontName = ""

    private var font: Font {
        fontName.isEmpty
            ? .system(size: fontSizePt, weight: .semibold).monospacedDigit()
            : .custom(fontName, fixedSize: fontSizePt)
    }

    static func timeLabel(_ remaining: TimeInterval) -> String {
        String(Int(ceil(max(0, remaining) / 60)))
    }

    var body: some View {
        GeometryReader { geometry in
            Text(isRest ? "REST" : Self.timeLabel(remaining))
                .font(font)
                .tracking(-1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .shadow(color: .black.opacity(0.7), radius: 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        .accessibilityLabel(isRest ? "REST" : "\(Self.timeLabel(remaining)) minutes remaining")
    }
}

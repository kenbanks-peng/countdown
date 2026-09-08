import SwiftUI

/// Focus minutes or a rest label on a center disc, scaled with the popup circle.
struct CountdownPopupOverlay: View {
    let remaining: TimeInterval
    var isRest = false

    static func timeLabel(_ remaining: TimeInterval) -> String {
        String(Int(ceil(max(0, remaining) / 60)))
    }

    var body: some View {
        GeometryReader { geometry in
            Text(isRest ? "REST" : Self.timeLabel(remaining))
                .font(.system(size: 40, weight: .semibold).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: 60, height: 72)
                .frame(width: 72, height: 72)
                .background(Color.countdownSurface, in: Circle())
                .frame(width: CountdownAppearance.normalSize, height: CountdownAppearance.normalSize)
                .scaleEffect(min(geometry.size.width, geometry.size.height) / CountdownAppearance.normalSize)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false)
        // The containing timer button already describes the countdown.
        .accessibilityHidden(true)
    }
}

import SwiftUI

struct CompactCountdownView: View {
    @ObservedObject var model: CountdownModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(model.status == .empty ? indicatorColor : Color.countdownSurface)

            if model.status != .empty {
                RadialSector(proportion: model.hourProportion)
                    .fill(indicatorColor)
                    .animation(arcAnimation, value: model.hourProportion)
            }

            Circle()
                .stroke(Color.countdownTrack.opacity(isHovering ? 1 : 0.8), lineWidth: 1)
                .padding(0.5)
                .animation(arcAnimation, value: isHovering)

            if model.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
    }

    private var arcAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var indicatorColor: Color {
        CountdownAppearance.indicatorColor(for: model.remaining)
    }

    private var accessibilityLabel: String {
        model.status == .empty ? "Countdown complete" : "\(model.remainingMinutes) minutes remaining"
    }

}

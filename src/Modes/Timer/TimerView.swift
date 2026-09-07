import AppKit
import SwiftUI

struct TimerView: View {
    @ObservedObject var model: TimerModel
    var clockDate: Date? = nil
    var showsLabels = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(model.status == .empty ? indicatorColor : Color.countdownSurface)

            if model.status != .empty {
                countdownProgress
            }

            Circle()
                .stroke(Color.countdownTrack.opacity(isHovering ? 0.95 : 0.7), lineWidth: 3)
                .padding(2)
                .animation(arcAnimation, value: isHovering)

            if showsLabels { countdownLabel }
        }
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
        .padding(6)
    }

    @ViewBuilder
    private var countdownProgress: some View {
        ZStack {
            RadialSector(proportion: arc.proportion, startProportion: arc.startProportion)
                .fill(indicatorColor)
                .animation(arcAnimation, value: model.hourProportion)

            if showsLabels && (model.isCurrentTimeoutEnabled || model.isPaused) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .frame(width: 50, height: model.isPaused ? 46 : 34)
                    .offset(y: 32)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private var countdownLabel: some View {
        if model.status != .empty {
            VStack(spacing: 1) {
                if model.isCurrentTimeoutEnabled {
                    Text("\(model.remainingMinutes)")
                        .font(Font(NSFont.systemFont(ofSize: 22, weight: .semibold)).monospacedDigit())
                        .foregroundStyle(indicatorColor)
                }

                if model.isPaused {
                    Text("Paused")
                        .font(.system(size: 8, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.countdownMuted)
                }
            }
            .allowsHitTesting(false)
            .offset(y: 32)

            if model.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
                    .allowsHitTesting(false)
            }
        }
    }

    private var arc: CountdownArcLayout {
        CountdownArcLayout.timer(remaining: model.remaining, at: clockDate)
    }

    private var arcAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var indicatorColor: Color {
        TimerAppearance.indicatorColor(for: model.remaining)
    }

    private var accessibilityLabel: String {
        model.status == .empty ? "Empty Countdown" : "\(model.remainingMinutes) minutes remaining"
    }

}

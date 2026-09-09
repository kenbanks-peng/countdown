import AppKit
import SwiftUI

struct TimerView: View {
    @ObservedObject var model: TimerModel
    var isCompact = false
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
                .stroke(Color.countdownTrack.opacity(trackOpacity), lineWidth: isCompact ? 1 : 3)
                .padding(isCompact ? 0.5 : 2)
                .animation(arcAnimation, value: isHovering)

            if !isCompact && showsLabels { countdownLabel }
            if model.isPaused || model.isEnginePaused {
                CountdownPauseIndicator(isCompact: isCompact)
            }
        }
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityLabel)
        .padding(isCompact ? 0 : CountdownAppearance.circleInset)
    }

    @ViewBuilder
    private var countdownProgress: some View {
        ZStack {
            RadialSector(proportion: arc.proportion, startProportion: arc.startProportion)
                .fill(indicatorColor)
                .animation(arcAnimation, value: model.hourProportion)

            if !isCompact && showsLabels && (model.showsRemainingMinutes || model.isPaused) {
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
                if model.showsRemainingMinutes {
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

        }
    }

    private var arc: CountdownArcLayout {
        CountdownArcLayout.timer(remaining: model.remaining, at: clockDate, endDate: model.endDate, pausedAt: model.pausedAt)
    }

    private var arcAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var indicatorColor: Color {
        TimerAppearance.indicatorColor(for: model.remaining)
    }

    private var trackOpacity: Double {
        isCompact ? (isHovering ? 1 : 0.8) : (isHovering ? 0.95 : 0.7)
    }

    private var accessibilityLabel: String {
        model.status == .empty
            ? (isCompact ? "Countdown complete" : "Empty Countdown")
            : "\(model.remainingMinutes) minutes remaining"
    }

}

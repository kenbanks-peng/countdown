import SwiftUI

struct CompactCountdownView: View {
    @ObservedObject var model: CountdownModel
    let expand: () -> Void

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
        .onTapGesture(perform: expand)
        .help(helpText)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Click to expand the Countdown")
        .task { await updateCountdown() }
        .onChange(of: model.remaining) { _ in
            expandAtOneMinuteRemaining()
        }
    }

    private var arcAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var indicatorColor: Color {
        CountdownAppearance.indicatorColor(for: model.remaining)
    }

    private var helpText: String {
        model.status == .empty
            ? "Countdown complete. Click to expand."
            : "\(model.remainingMinutes) minutes remaining. Click to expand."
    }

    private var accessibilityLabel: String {
        model.status == .empty ? "Countdown complete" : "\(model.remainingMinutes) minutes remaining"
    }

    private func updateCountdown() async {
        while !Task.isCancelled {
            model.update()
            expandAtOneMinuteRemaining()
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func expandAtOneMinuteRemaining() {
        guard model.status == .active, model.remaining > 0, model.remaining <= 60 else { return }
        expand()
    }
}

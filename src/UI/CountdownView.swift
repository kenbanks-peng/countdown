import AppKit
import SwiftUI

struct CountdownView: View {
    @ObservedObject var model: CountdownModel
    let compact: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var currentTime = Date.now

    var body: some View {
        ZStack {
            Circle()
                .fill(model.status == .empty ? indicatorColor : Color.countdownSurface)

            if model.status != .empty {
                countdownProgress
            }

            if model.isClockFaceEnabled {
                ClockFace()
            }

            if model.isClockHandsEnabled {
                ClockHands(date: currentTime)
                    .foregroundStyle(.white.opacity(0.42))
                    .allowsHitTesting(false)
            }

            Circle()
                .stroke(Color.countdownTrack.opacity(isHovering ? 0.95 : 0.7), lineWidth: 3)
                .padding(2)
                .animation(arcAnimation, value: isHovering)

            countdownLabel
        }
        .contentShape(Circle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.option) {
                model.setDurationToNextHour()
            } else {
                compact()
            }
        }
        .help("Click to use Compact mode. Option-click to set the timeout to the next hour.")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Click the circle to use Compact mode. Option-click the circle to set the timeout to the next hour. Scroll to adjust by one minute. Hold Option while you scroll for slower, precise one-minute adjustment.")
        .padding(6)
        .contextMenu { CountdownContextMenu(model: model) }
        .task { await updateClock() }
    }

    @ViewBuilder
    private var countdownProgress: some View {
        ZStack {
            RadialSector(proportion: model.hourProportion)
                .fill(indicatorColor)
                .animation(arcAnimation, value: model.hourProportion)

            if model.isCurrentTimeoutEnabled || model.isPaused {
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

    private var arcAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var indicatorColor: Color {
        CountdownAppearance.indicatorColor(for: model.remaining)
    }

    private var accessibilityLabel: String {
        model.status == .empty ? "Empty Countdown" : "\(model.remainingMinutes) minutes remaining"
    }

    private func updateClock() async {
        while !Task.isCancelled {
            model.update()
            currentTime = .now
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

private struct CountdownContextMenu: View {
    @ObservedObject var model: CountdownModel

    var body: some View {
        Toggle("Face", isOn: enablementBinding(\.isClockFaceEnabled, model.setClockFaceEnabled))
        Toggle("Hands", isOn: enablementBinding(\.isClockHandsEnabled, model.setClockHandsEnabled))
        Toggle("Timeout", isOn: enablementBinding(\.isCurrentTimeoutEnabled, model.setCurrentTimeoutEnabled))
        Toggle("Autoset", isOn: enablementBinding(\.isAutosetEnabled, model.setAutosetEnabled))
        Toggle("Wakeup", isOn: enablementBinding(\.isWakeupEnabled, model.setWakeupEnabled))

        Divider()

        Button("Set Timeout to Next Hour") {
            model.setDurationToNextHour()
        }

        Button(model.isPaused ? "Resume" : "Pause") {
            model.toggleRunning()
        }
        .disabled(model.status == .empty)

        Button("Quit Countdown") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func enablementBinding(
        _ keyPath: KeyPath<CountdownModel, Bool>,
        _ setEnabled: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(get: { model[keyPath: keyPath] }, set: setEnabled)
    }
}

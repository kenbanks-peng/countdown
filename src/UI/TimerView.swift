import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround either timing mode.
struct TimerView: View {
    @ObservedObject var timer: TimerController
    var isCompact = false
    let changePresentation: () -> Void

    var body: some View {
        Button(action: activate) {
            ZStack {
                modeContent
                if !isCompact {
                    TimerClockOverlay(features: timer.features)
                        .padding(6)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Click to use \(isCompact ? "normal" : "compact") view. Use the right-click menu to \(timer.controlLabel.lowercased()).")
        .help("Click to change view. Use the right-click menu for timer controls. Scroll to adjust time; hold Option for slower adjustment.")
        .contextMenu {
            Picker("Timer Mode", selection: Binding(get: { timer.mode }, set: timer.selectMode)) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            TimerFeatureMenu(features: timer.features)
            Button(timer.controlLabel, action: timer.toggleRunning)
                .disabled(!timer.canToggleRunning)
            Button(isCompact ? "Normal" : "Compact", action: changePresentation)
            Divider()
            if timer.mode == .countdown {
                CountdownContextMenu(model: timer.countdown, timer: timer)
            } else {
                Button("Reset", action: timer.resetPomodoro)
            }
            Divider()
            Button("Quit Countdown") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            while !Task.isCancelled {
                timer.update()
                expandAtOneMinuteRemaining()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch timer.mode {
        case .countdown:
            if isCompact {
                CompactCountdownView(model: timer.countdown)
            } else {
                CountdownView(model: timer.countdown)
            }
        case .pomodoro:
            PomodoroView(model: timer.pomodoro, isCompact: isCompact)
        }
    }

    private var accessibilityLabel: String {
        switch timer.mode {
        case .countdown:
            timer.countdown.status == .empty ? "Empty Timer" : "\(timer.countdown.remainingMinutes) minutes remaining"
        case .pomodoro: timer.pomodoro.accessibilityDescription
        }
    }

    private func activate() {
        if timer.mode == .countdown, !isCompact, NSEvent.modifierFlags.contains(.option) {
            timer.setCountdownToNextHour()
        } else {
            changePresentation()
        }
    }

    private func expandAtOneMinuteRemaining() {
        guard isCompact, timer.mode == .countdown, timer.countdown.status == .active,
              timer.countdown.remaining > 0, timer.countdown.remaining <= 60 else { return }
        changePresentation()
    }
}

private struct TimerClockOverlay: View {
    @ObservedObject var features: TimerFeatures
    @State private var currentTime = Date.now

    var body: some View {
        ZStack {
            if features.isClockFaceEnabled { ClockFace() }
            if features.isClockHandsEnabled {
                ClockHands(date: currentTime)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                currentTime = .now
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

private struct TimerFeatureMenu: View {
    @ObservedObject var features: TimerFeatures

    var body: some View {
        Toggle("Face", isOn: Binding(get: { features.isClockFaceEnabled }, set: features.setClockFaceEnabled))
        Toggle("Hands", isOn: Binding(get: { features.isClockHandsEnabled }, set: features.setClockHandsEnabled))
        Toggle("Wakeup", isOn: Binding(get: { features.isWakeupEnabled }, set: features.setWakeupEnabled))
    }
}

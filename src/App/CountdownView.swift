import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround either timing mode.
struct CountdownView: View {
    @ObservedObject var countdown: CountdownController
    var isCompact = false
    let changePresentation: () -> Void
    @ObservedObject private var features: CountdownFeatures
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.changePresentation = changePresentation
        self.features = countdown.features
        self._currentTime = State(initialValue: countdown.currentTime)
    }

    var body: some View {
        Button(action: activate) {
            ZStack {
                modeContent
                if !isCompact {
                    CountdownClockOverlay(features: features, currentTime: currentTime)
                        .padding(6)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Click to use \(isCompact ? "normal" : "compact") view. Use the right-click menu to \(countdown.controlLabel.lowercased()).")
        .help("Click to change view. Use the right-click menu for timer controls. Scroll to adjust time; hold Option for slower adjustment.")
        .contextMenu {
            Picker("Timer Mode", selection: Binding(get: { countdown.mode }, set: countdown.selectMode)) {
                ForEach(CountdownMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            CountdownFeatureMenu(features: countdown.features)
            Button(countdown.controlLabel, action: countdown.toggleRunning)
                .disabled(!countdown.canToggleRunning)
            Button(isCompact ? "Normal" : "Compact", action: changePresentation)
            Divider()
            if countdown.mode == .timer {
                TimerContextMenu(model: countdown.timer, setToNextHour: countdown.setTimerToNextHour)
            } else {
                Button("Reset", action: countdown.resetPomodoro)
            }
            Divider()
            Button("Quit Countdown") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            while !Task.isCancelled {
                countdown.update()
                currentTime = countdown.currentTime
                expandAtOneMinuteRemaining()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch countdown.mode {
        case .timer:
            if isCompact {
                CompactTimerView(model: countdown.timer, clockDate: clockDate)
            } else {
                TimerView(model: countdown.timer, clockDate: clockDate)
            }
        case .pomodoro:
            PomodoroView(model: countdown.pomodoro, isCompact: isCompact, clockDate: clockDate)
        }
    }

    private var clockDate: Date? {
        features.isClockFaceEnabled ? currentTime : nil
    }

    private var accessibilityLabel: String {
        switch countdown.mode {
        case .timer:
            countdown.timer.status == .empty ? "Empty Timer" : "\(countdown.timer.remainingMinutes) minutes remaining"
        case .pomodoro: countdown.pomodoro.accessibilityDescription
        }
    }

    private func activate() {
        if countdown.mode == .timer, !isCompact, NSEvent.modifierFlags.contains(.option) {
            countdown.setTimerToNextHour()
        } else {
            changePresentation()
        }
    }

    private func expandAtOneMinuteRemaining() {
        guard isCompact, countdown.mode == .timer, countdown.timer.status == .active,
              countdown.timer.remaining > 0, countdown.timer.remaining <= 60 else { return }
        changePresentation()
    }
}

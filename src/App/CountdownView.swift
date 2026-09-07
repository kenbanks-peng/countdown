import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround either timing mode.
struct CountdownView: View {
    @ObservedObject var countdown: CountdownController
    var isCompact = false
    var isPopup = false
    let changePresentation: () -> Void
    private let allowsClick: () -> Bool
    @ObservedObject private var features: CountdownFeatures
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, isPopup: Bool = false, allowsClick: @escaping () -> Bool = { true }, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.isPopup = isPopup
        self.changePresentation = changePresentation
        self.allowsClick = allowsClick
        self.features = countdown.features
        self._currentTime = State(initialValue: countdown.currentTime)
    }

    var body: some View {
        Button(action: activate) {
            ZStack {
                modeContent
                if showsPopupDetails {
                    popupOverlay
                } else if !isCompact {
                    CountdownClockOverlay(features: features, currentTime: currentTime)
                        .padding(6)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(countdown.mode == .pomodoro ? countdown.pomodoro.progressDescription : "")
        .accessibilityHint("Click to use \(isCompact ? "normal" : "compact") view. Use the right-click menu to \(countdown.controlLabel.lowercased()).")
        .help("Click to change view. Use the right-click menu for timer controls. Scroll to adjust time; hold Option for slower adjustment.")
        .contextMenu {
            Picker("Display", selection: Binding(get: { features.isClockEnabled }, set: features.setClockEnabled)) {
                Text("Countdown").tag(false)
                Text("Clock").tag(true)
            }
            .pickerStyle(.inline)
            Divider()
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
                Menu("Durations") {
                    durationMenu("Focus", phase: .focus, duration: countdown.pomodoro.focusDuration)
                    durationMenu("Rest", phase: .rest, duration: countdown.pomodoro.restDuration)
                    durationMenu("Long rest", phase: .longRest, duration: countdown.pomodoro.longRestDuration)
                }
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

    private func durationMenu(_ label: String, phase: PomodoroModel.Phase, duration: TimeInterval) -> some View {
        Menu("\(label): \(Int(duration / 60)) min") {
            Button("Increase by 1 minute") { countdown.adjustPomodoroDuration(phase, by: 60) }
            Button("Decrease by 1 minute") { countdown.adjustPomodoroDuration(phase, by: -60) }
        }
    }

    private var showsPopupDetails: Bool { isPopup && !isCompact }

    private var popupOverlay: CountdownPopupOverlay {
        if countdown.mode == .timer {
            return CountdownPopupOverlay(
                remaining: countdown.timer.remaining, phase: "Timer", isPaused: countdown.countdown.isPaused
            )
        }
        let model = countdown.pomodoro
        return CountdownPopupOverlay(
            remaining: model.focusRemaining > 0 ? model.focusRemaining : model.restRemaining,
            phase: model.phaseLabel,
            session: "Session \(model.stage) of \(model.cycles)",
            isPaused: countdown.countdown.isPaused
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch countdown.mode {
        case .timer:
            if isCompact {
                CompactTimerView(model: countdown.timer, clockDate: clockDate)
            } else {
                TimerView(model: countdown.timer, clockDate: clockDate, showsLabels: !showsPopupDetails)
            }
        case .pomodoro:
            PomodoroView(model: countdown.pomodoro, isCompact: isCompact, clockDate: clockDate, showsSessionDots: !showsPopupDetails)
        }
    }

    private var clockDate: Date? {
        features.isClockEnabled ? currentTime : nil
    }

    private var accessibilityLabel: String {
        switch countdown.mode {
        case .timer:
            countdown.timer.status == .empty ? "Empty Timer" : "\(countdown.timer.remainingMinutes) minutes remaining"
        case .pomodoro: countdown.pomodoro.accessibilityDescription
        }
    }

    private func activate() {
        guard allowsClick() else { return }
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

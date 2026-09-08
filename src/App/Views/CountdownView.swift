import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround all three modes.
struct CountdownView: View {
    @ObservedObject var countdown: CountdownController
    var isCompact = false
    var isPopup = false
    let scale: CGFloat
    let changePresentation: () -> Void
    private let allowsClick: () -> Bool
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, isPopup: Bool = false, scale: CGFloat = 1, allowsClick: @escaping () -> Bool = { true }, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.isPopup = isPopup
        self.scale = scale
        self.changePresentation = changePresentation
        self.allowsClick = allowsClick
        self._currentTime = State(initialValue: countdown.currentTime)
    }

    var body: some View {
        GeometryReader { geometry in
            controls
                .frame(width: geometry.size.width / scale, height: geometry.size.height / scale)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var controls: some View {
        Button(action: activate) {
            ZStack {
                modeContent
                if !isCompact {
                    CountdownClockOverlay(
                        isClockEnabled: countdown.mode.isClockEnabled,
                        currentTime: currentTime,
                        showsFace: !showsPopupDetails
                    )
                    .padding(CountdownAppearance.circleInset)
                }
                if showsPopupDetails {
                    popupOverlay
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
            Picker("Timer mode", selection: Binding(get: { countdown.mode }, set: countdown.selectMode)) {
                ForEach(CountdownMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle("Popups", isOn: Binding(get: { countdown.popups.isPopupEnabled }, set: countdown.popups.setPopupEnabled))
            Button(countdown.controlLabel, action: countdown.toggleRunning)
            Button(isCompact ? "Normal" : "Compact", action: changePresentation)
            Divider()
            if countdown.mode.usesTimer {
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

    private var showsPopupDetails: Bool { isPopup && !isCompact }

    private var popupOverlay: CountdownPopupOverlay {
        if countdown.mode.usesTimer {
            return CountdownPopupOverlay(
                remaining: countdown.timer.remaining
            )
        }
        let model = countdown.pomodoro
        return CountdownPopupOverlay(
            remaining: model.focusRemaining > 0 ? model.focusRemaining : model.restRemaining
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch countdown.mode {
        case .timer, .countdown:
            TimerView(model: countdown.timer, isCompact: isCompact, clockDate: clockDate, showsLabels: !showsPopupDetails)
        case .pomodoro:
            PomodoroView(model: countdown.pomodoro, isCompact: isCompact, clockDate: clockDate, showsSessionDots: !showsPopupDetails)
        }
    }

    private var clockDate: Date? {
        countdown.mode.isClockEnabled ? currentTime : nil
    }

    private var accessibilityLabel: String {
        switch countdown.mode {
        case .timer, .countdown:
            countdown.timer.status == .empty ? "Empty Timer" : "\(countdown.timer.remainingMinutes) minutes remaining"
        case .pomodoro: countdown.pomodoro.accessibilityDescription
        }
    }

    private func activate() {
        guard allowsClick() else { return }
        if countdown.mode.usesTimer, !isCompact, NSEvent.modifierFlags.contains(.option) {
            countdown.setTimerToNextHour()
        } else {
            changePresentation()
        }
    }

    private func expandAtOneMinuteRemaining() {
        guard isCompact, countdown.mode.usesTimer, countdown.timer.status == .active,
              countdown.timer.remaining > 0, countdown.timer.remaining <= 60 else { return }
        changePresentation()
    }
}

import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround all three modes.
struct CountdownView: View {
    @ObservedObject var countdown: CountdownController
    var isCompact = false
    var isReminder = false
    let scale: CGFloat
    let reminderFontSizePt: CGFloat
    let changePresentation: () -> Void
    private let allowsClick: () -> Bool
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, isReminder: Bool = false, scale: CGFloat = 1, reminderFontSizePt: CGFloat = CountdownConfiguration.defaultReminderFontSizePt, allowsClick: @escaping () -> Bool = { true }, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.isReminder = isReminder
        self.scale = scale
        self.reminderFontSizePt = reminderFontSizePt
        self.changePresentation = changePresentation
        self.allowsClick = allowsClick
        self._currentTime = State(initialValue: countdown.currentTime)
    }

    var body: some View {
        GeometryReader { geometry in
            if isReminder {
                reminderOverlay
            } else {
                controls
                    .frame(width: geometry.size.width / scale, height: geometry.size.height / scale)
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var controls: some View {
        Button(action: activate) {
            ZStack {
                modeContent
                if !isCompact {
                    CountdownClockOverlay(
                        isClockEnabled: countdown.mode.isClockEnabled,
                        currentTime: currentTime
                    )
                    .padding(CountdownAppearance.circleInset)
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
            Toggle("Reminders", isOn: Binding(get: { countdown.reminders.isReminderEnabled }, set: countdown.reminders.setReminderEnabled))
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

    private var reminderOverlay: CountdownReminderOverlay {
        if countdown.mode.usesTimer {
            return CountdownReminderOverlay(
                remaining: countdown.timer.remaining, fontSizePt: reminderFontSizePt
            )
        }
        let model = countdown.pomodoro
        return CountdownReminderOverlay(
            remaining: model.focusRemaining > 0 ? model.focusRemaining : model.restRemaining,
            fontSizePt: reminderFontSizePt
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch countdown.mode {
        case .timer, .countdown:
            TimerView(model: countdown.timer, isCompact: isCompact, clockDate: clockDate)
        case .pomodoro:
            PomodoroView(model: countdown.pomodoro, isCompact: isCompact, clockDate: clockDate)
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

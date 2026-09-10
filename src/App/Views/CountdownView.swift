import AppKit
import SwiftUI

/// Shared presentation, clock, update loop, and controls surround all three modes.
struct CountdownView: View {
    @ObservedObject var countdown: CountdownController
    var isCompact = false
    var isNotification = false
    let scale: CGFloat
    let notificationFontSizePt: CGFloat
    let notificationFont: String
    let notificationFontVariations: NotificationFontVariations
    let changePresentation: () -> Void
    private let allowsClick: () -> Bool
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, isNotification: Bool = false, scale: CGFloat = 1, notificationFontSizePt: CGFloat = CountdownConfiguration.defaultNotificationFontSizePt, notificationFont: String = "", notificationFontVariations: NotificationFontVariations = NotificationFontVariations(), allowsClick: @escaping () -> Bool = { true }, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.isNotification = isNotification
        self.scale = scale
        self.notificationFontSizePt = notificationFontSizePt
        self.notificationFont = notificationFont
        self.notificationFontVariations = notificationFontVariations
        self.changePresentation = changePresentation
        self.allowsClick = allowsClick
        self._currentTime = State(initialValue: countdown.currentTime)
    }

    var body: some View {
        GeometryReader { geometry in
            if isNotification {
                notificationOverlay
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
        .help("Click to change view. Use the right-click menu for timer controls. Scroll to align to five-minute marks; hold Option for one-minute changes.")
        .contextMenu {
            Picker("View", selection: Binding(get: { countdown.mode }, set: countdown.selectMode)) {
                ForEach(CountdownMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle("Notifications", isOn: Binding(get: { countdown.notifications.isNotificationEnabled }, set: countdown.notifications.setNotificationEnabled))
            Toggle("Loop", isOn: Binding(get: { countdown.timer.isAutoRepeatEnabled }, set: countdown.setAutoRepeatEnabled))
            Button("Align", action: countdown.autoAlign)
                .disabled(!countdown.canAutoAlign)
            if countdown.mode.usesTimer {
                TimerContextMenu(model: countdown.timer)
            }
            Divider()
            Toggle("Pause", isOn: Binding(
                get: { countdown.engine.isPaused },
                set: { paused in
                    if paused != countdown.engine.isPaused {
                        countdown.toggleRunning()
                    }
                }
            ))
            if countdown.testEnabled {
                Divider()
                Button("Test", action: countdown.testNotification)
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .task {
            while !Task.isCancelled {
                countdown.update()
                currentTime = countdown.currentTime
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var notificationOverlay: CountdownNotificationOverlay {
        if countdown.mode.usesTimer {
            return CountdownNotificationOverlay(
                remaining: countdown.timer.remaining, fontSizePt: notificationFontSizePt,
                fontName: notificationFont, fontVariations: notificationFontVariations
            )
        }
        let model = countdown.pomodoro
        return CountdownNotificationOverlay(
            remaining: model.focusRemaining,
            isRest: model.focusRemaining == 0,
            isPomodoro: true,
            fontSizePt: notificationFontSizePt, fontName: notificationFont, fontVariations: notificationFontVariations
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
            countdown.autoAlign()
        } else {
            changePresentation()
        }
    }
}

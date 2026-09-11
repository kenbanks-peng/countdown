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
    let notificationEvent: NotificationScheduler.Event?
    let changePresentation: () -> Void
    private let allowsClick: () -> Bool
    private let clickModifierFlags: () -> NSEvent.ModifierFlags
    @State private var currentTime = Date.now

    init(countdown: CountdownController, isCompact: Bool = false, isNotification: Bool = false, scale: CGFloat = 1, notificationFontSizePt: CGFloat = CountdownConfiguration.defaultNotificationFontSizePt, notificationFont: String = "", notificationFontVariations: NotificationFontVariations = NotificationFontVariations(), notificationEvent: NotificationScheduler.Event? = nil, allowsClick: @escaping () -> Bool = { true }, clickModifierFlags: @escaping () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }, changePresentation: @escaping () -> Void) {
        self.countdown = countdown
        self.isCompact = isCompact
        self.isNotification = isNotification
        self.scale = scale
        self.notificationFontSizePt = notificationFontSizePt
        self.notificationFont = notificationFont
        self.notificationFontVariations = notificationFontVariations
        self.notificationEvent = notificationEvent
        self.changePresentation = changePresentation
        self.allowsClick = allowsClick
        self.clickModifierFlags = clickModifierFlags
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
        .overlay {
            if countdown.mode == .pomodoro && !isCompact {
                PomodoroCycleControls(model: countdown.pomodoro) { stage in
                    guard allowsClick() else { return }
                    countdown.restartPomodoroStage(
                        stage, restoringDefaults: clickModifierFlags().contains(.option)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(Circle().inset(by: CountdownAppearance.circleInset))
            }
        }
        .contextMenu {
            Picker("Mode", selection: Binding(get: { countdown.mode }, set: countdown.selectMode)) {
                ForEach(CountdownMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            Section("Control") {
                Toggle("Pause", isOn: Binding(
                    get: { countdown.engine.isPaused },
                    set: { paused in
                        if paused != countdown.engine.isPaused {
                            countdown.toggleRunning()
                        }
                    }
                ))
                Toggle("Loop", isOn: Binding(get: { countdown.timer.isAutoRepeatEnabled }, set: countdown.setAutoRepeatEnabled))
            }
            Divider()
            Section("Settings") {
                if countdown.mode.usesTimer {
                    TimerContextMenu(model: countdown.timer)
                }
                Toggle("Notifications", isOn: Binding(get: { countdown.notifications.isNotificationEnabled }, set: countdown.notifications.setNotificationEnabled))
                Toggle("Auto-align", isOn: Binding(get: { countdown.timer.isAutoAlignEnabled }, set: countdown.setAutoAlignEnabled))
                Button("Align Now", action: countdown.autoAlign)
                    .disabled(!countdown.canAutoAlign)
            }
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
        let event = notificationEvent ?? (countdown.mode.usesTimer
            ? (countdown.timer.remaining <= 0
                ? countdown.notifications.alarmMessage.map(NotificationScheduler.Event.alarm) ?? .remaining(0)
                : .remaining(countdown.timer.remaining))
            : countdown.pomodoro.focusRemaining > 0
                ? .remaining(countdown.pomodoro.focusRemaining) : .rest)
        let remaining: TimeInterval
        if case .remaining(let time) = event { remaining = time } else { remaining = 0 }
        let alarmMessage: String?
        if case .alarm(let message) = event { alarmMessage = message } else { alarmMessage = nil }
        return CountdownNotificationOverlay(
            remaining: remaining,
            alarmMessage: alarmMessage,
            isRest: event == .rest,
            isWork: event == .work,
            fontSizePt: notificationFontSizePt, fontName: notificationFont, fontVariations: notificationFontVariations
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch countdown.mode {
        case .timer, .countdown:
            TimerView(model: countdown.timer, isCompact: isCompact, clockDate: clockDate)
        case .pomodoro:
            PomodoroView(model: countdown.pomodoro, isCompact: isCompact, clockDate: clockDate, showsSessionDots: false)
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

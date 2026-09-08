import AppKit
import Testing
@testable import Countdown

@MainActor
final class ScrollTestSession {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
    var sounds = 0
    var scrollTime: TimeInterval = 0
    let window: NSWindow
    let isCompact: Bool
    lazy var controller = CountdownController(
        sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
        configuration: CountdownConfiguration(alarmNotificationURL: nil, pomodoroLongRestMinutes: 15, audioNotificationEnabled: false),
        preferences: CountdownPreferences(reminderEnabled: false),
        playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now },
        saveEnablement: { _, _ in }
    )
    lazy var scrollAdjuster = ScrollTimeAdjuster(countdown: controller, window: window,
                                         isCompact: { [unowned self] in isCompact },
                                         uptime: { [unowned self] in scrollTime })

    init(isCompact: Bool = false) {
        self.isCompact = isCompact
        _ = NSApplication.shared
        let side = isCompact ? 32 : 188
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: side, height: side), styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
    }

    func scroll(angle: Double, radius: Double? = nil, delta: Int32, option: Bool = false,
                after interval: TimeInterval = 0.5, phase: NSEvent.Phase = [], momentum: Bool = false,
                precise: Bool = false) throws {
        scrollTime += interval
        let radians = angle * .pi / 180
        let radius = radius ?? (isCompact ? 14 : 66)
        let center = isCompact ? 16.0 : 94
        let point = NSPoint(x: center + radius * sin(radians), y: center + radius * cos(radians))
        scrollAdjuster.handle(try scrollEvent(in: window, at: point, delta: delta, option: option,
                                       phase: phase, momentum: momentum, precise: precise))
    }

    func close() {
        window.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

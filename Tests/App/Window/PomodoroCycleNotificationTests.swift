import AppKit
import Testing
@testable import Countdown

@MainActor
@Suite(.serialized)
struct PomodoroCycleNotificationTests {
    @Test(arguments: [false, true], [false, true])
    func cycleSelectionDisplaysWork(enabled: Bool, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "countdown.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let windowState = CountdownWindowStateStore(defaults: defaults)
        windowState.save(frame: NSRect(x: 100, y: 120, width: 188, height: 188),
                         presentation: isCompact ? .compact : .normal)
        let config = CountdownConfiguration(alarmNotificationURL: nil)
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: config, preferences: CountdownPreferences(notificationEnabled: enabled),
            playSound: { _ in }, now: { Date(timeIntervalSince1970: 1_699_999_800) }
        )
        controller.selectMode(.pomodoro)
        let notification = CountdownNotificationController()
        let priorWindows = Set(NSApplication.shared.windows.map(\.windowNumber))
        let window = CountdownWindowController(
            countdown: controller, configuration: config,
            windowState: windowState, notification: notification
        )
        defer {
            window.save()
            for panel in NSApplication.shared.windows where !priorWindows.contains(panel.windowNumber) {
                panel.close()
            }
        }
        controller.restartPomodoroStage(3)
        #expect(controller.pomodoro.stage == 3)
        #expect(controller.notifications.notificationIntervalCount == (enabled ? 1 : 0))
        #expect((notification.panel != nil) == enabled)
        if enabled {
            #expect(controller.notifications.lastEvent == .work)
        }
        #expect(windowState.presentation == (isCompact ? .compact : .normal))

        // The manual request must not change the policy for later automatic events.
        notification.dismiss()
        let interval = TimeInterval(config.notificationIntervalMinutes * 60)
        controller.notifications.reportElapsed(previousRemaining: interval + 1, remaining: interval)
        #expect((notification.panel != nil) == (enabled && isCompact))
        notification.dismiss()
        controller.notifications.reportPhaseChange(remaining: 1_500)
        #expect((notification.panel != nil) == (enabled && isCompact))
    }
}

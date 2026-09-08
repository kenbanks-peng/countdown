import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownControllerTests {
    @Test
    func modeChangesKeepAllocationsSeparateAndBothCountdownsRunning() {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.adjustTimerDuration(by: 1_200)
        session.now += 75
        controller.selectMode(.pomodoro)
        #expect(controller.timer.remaining == 1_125)
        #expect(controller.pomodoro.focusRemaining == 1_425)
        #expect(controller.pomodoro.restDuration == 300)
        session.now += 600
        controller.selectMode(.timer)
        #expect(controller.timer.remaining == 525)
        #expect(controller.timer.status == .active)
        #expect(controller.pomodoro.focusRemaining == 825)
        #expect(session.sounds == 0)
    }

    @Test
    func hiddenTimerExpiresSilentlyAndDoesNotReplayOnSelection() {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.adjustTimerDuration(by: 300)
        controller.selectMode(.pomodoro)
        session.now += 301
        controller.selectMode(.timer)
        #expect(controller.timer.status == .empty)
        #expect(controller.timer.completionCount == 0)
        #expect(session.sounds == 0)
        controller.adjustTimerDuration(by: 300)
        session.now += controller.timer.remaining
        controller.update()
        controller.update()
        #expect(controller.timer.completionCount == 1)
        #expect(session.sounds == 1)
        #expect(!controller.countdown.isPaused)
    }

    @Test
    func autosetFollowsTheActiveModeWithoutChangingTheCoreRunState() {
        let session = Session()
        defer { session.removeState() }
        session.now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 6, hour: 10, minute: 30))!
        let controller = session.makeController(autoset: true)
        #expect(controller.timer.remaining == 1_800)
        session.now += 1_800
        controller.selectMode(.pomodoro) // The outgoing Timer mode handles this timeout.
        #expect(controller.timer.remaining == 3_600)
        #expect(controller.timer.status == .active)
        session.now += 3_600
        controller.update() // Hidden timeout: no alarm and no Autoset.
        #expect(controller.timer.status == .empty)
        #expect(session.sounds == 1)
        controller.selectMode(.timer)
        #expect(controller.timer.status == .empty)
        controller.toggleRunning()
        controller.setTimerToNextHour()
        #expect(controller.timer.isPaused)
        #expect(controller.timer.remaining == 3_600)
        #expect(controller.countdown.isPaused)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        func makeController(autoset: Bool = false) -> CountdownController {
            CountdownController(
                stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
                configuration: CountdownConfiguration(alarmNotificationURL: nil),
                featureState: CountdownFeatureState(autosetEnabled: autoset, popupEnabled: false),
                playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
            )
        }
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}

import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollTimeAdjusterTests {
    @Test
    func modeChangesBlockCountdownScrollAndClearOptionRemainder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            playSound: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let adapter = ScrollTimeAdjuster(timer: timer)
        adapter.handle(try scroll(delta: 30))
        #expect(timer.countdown.remaining == 60)
        adapter.handle(try scroll(delta: 7, option: true))
        timer.selectMode(.pomodoro)
        adapter.handle(try scroll(delta: 30))
        adapter.handle(try scroll(delta: 24, option: true))
        timer.setCountdownToNextHour()
        timer.toggleCountdownRunning()
        #expect(timer.countdown.remaining == 60)
        #expect(timer.countdown.isPaused)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        timer.selectMode(.countdown)
        adapter.handle(try scroll(delta: 5, option: true))
        #expect(timer.countdown.remaining == 60)
        adapter.handle(try scroll(delta: 7, option: true))
        #expect(timer.countdown.remaining == 120)
        adapter.handle(try scroll(delta: -30))
        #expect(timer.countdown.remaining == 60)
    }

    private func scroll(delta: Int32, option: Bool = false) throws -> NSEvent {
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: delta, wheel2: 0, wheel3: 0
        ))
        event.location = CGPoint(x: 120, y: 50)
        event.flags = option ? .maskAlternate : []
        return try #require(NSEvent(cgEvent: event))
    }
}

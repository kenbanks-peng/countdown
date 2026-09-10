import Foundation
import Testing
@testable import Countdown

@MainActor
struct TimerClockEndpointTests {
    @Test
    func pausedTimerEditUsesItsFrozenClockReference() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(steps: 4)
        controller.toggleRunning()
        let end = try #require(controller.timer.endDate)
        let frozen = controller.timer.remaining
        session.now += 150
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.endDate == end + 300)
        #expect(controller.timer.remaining == frozen + 300)
        let edited = try #require(controller.timer.endDate)
        session.now += 160
        controller.toggleRunning()
        #expect(controller.timer.endDate == edited + 310)
        #expect(controller.timer.remaining == frozen + 300)
    }

    @Test
    func autoAlignAndRepeatAcrossMidnightUseAbsoluteEndpoints() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 57, second: 13))!
        let controller = session.controller
        controller.autoAlign()
        let alignedEnd = try #require(controller.timer.endDate)
        #expect(Calendar.current.component(.day, from: alignedEnd) == 16)
        #expect(Calendar.current.component(.hour, from: alignedEnd) == 0)
        #expect(Calendar.current.component(.minute, from: alignedEnd) == 30)
        controller.timer.setAutoRepeatEnabled(true)
        session.now = alignedEnd
        controller.update()
        #expect(controller.timer.endDate == alignedEnd + 1_967)
        controller.toggleRunning()
        session.now += 150
        controller.autoAlign()
        #expect(controller.timer.endDate == alignedEnd + 1_800)
        #expect(controller.timer.remaining == 1_650)
        #expect(controller.timer.isPaused)
    }
}

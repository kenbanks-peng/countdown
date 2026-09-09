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
    func nextHourAutosetAndMidnightUseAbsoluteEndpoints() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 57, second: 13))!
        let controller = session.controller
        controller.setTimerToNextHour()
        let midnight = try #require(controller.timer.endDate)
        #expect(Calendar.current.component(.day, from: midnight) == 16)
        #expect(Calendar.current.component(.hour, from: midnight) == 0)
        controller.timer.setAutoSetToNextHourEnabled(true)
        session.now = midnight
        controller.update()
        #expect(controller.timer.endDate == midnight + 3_600)
        controller.toggleRunning()
        session.now += 150
        controller.setTimerToNextHour()
        #expect(controller.timer.endDate == midnight + 3_600)
        #expect(controller.timer.remaining == 3_450)
        #expect(controller.timer.isPaused)
    }
}

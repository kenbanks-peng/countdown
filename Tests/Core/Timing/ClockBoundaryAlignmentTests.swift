import Foundation
import Testing
@testable import Countdown

struct ClockBoundaryAlignmentTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int = 10, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: hour, minute: minute))!
    }

    @Test
    func switchesBetweenTwoValidBoundaries() {
        let first = date(minute: 30)
        let second = date(hour: 11)
        let minimum = date(minute: 7)
        let maximum = date(hour: 11, minute: 2)
        for (current, expected) in [(date(minute: 27), first), (first, second), (second, first)] {
            #expect(ClockBoundary.alignment(from: current, minimum: minimum, maximum: maximum,
                                            calendar: calendar) == expected)
        }
    }

    @Test
    func singleBoundaryStaysSelectedAndEmptyRangeHasNoAlignment() {
        let first = date(minute: 30)
        #expect(ClockBoundary.alignment(from: first, minimum: first, maximum: date(minute: 59),
                                        calendar: calendar) == first)
        #expect(ClockBoundary.alignment(from: first, minimum: first + 0.25, maximum: date(minute: 59),
                                        calendar: calendar) == nil)
    }

    @Test
    func maximumIsInclusiveAndExpiredChoiceIsNotSelected() {
        let first = date(minute: 30)
        let second = date(hour: 11)
        #expect(ClockBoundary.alignment(from: first, minimum: first, maximum: second,
                                        calendar: calendar) == second)
        #expect(ClockBoundary.alignment(from: first, minimum: first, maximum: second - 0.25,
                                        calendar: calendar) == first)
        #expect(ClockBoundary.alignment(from: second, minimum: first + 0.25, maximum: second,
                                        calendar: calendar) == second)
    }

    @Test
    func switchesAcrossMidnight() {
        let midnight = date(hour: 23) + 3_600
        let halfPast = midnight + 1_800
        #expect(ClockBoundary.alignment(from: midnight, minimum: midnight - 60,
                                        maximum: halfPast, calendar: calendar) == halfPast)
        #expect(ClockBoundary.alignment(from: halfPast, minimum: midnight - 60,
                                        maximum: halfPast, calendar: calendar) == midnight)
    }
}

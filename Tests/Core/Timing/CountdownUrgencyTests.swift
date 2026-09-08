import Foundation
import Testing
@testable import Countdown

struct CountdownUrgencyTests {
    @Test(arguments: [
        (0.0, CountdownUrgency.urgent),
        (599.999, .urgent),
        (600, .warning),
        (1_199.999, .warning),
        (1_200, .normal),
        (3_600, .normal)
    ])
    func timeBandsKeepTheirExactBoundaries(remaining: TimeInterval, expected: CountdownUrgency) {
        #expect(CountdownUrgency(remaining: remaining) == expected)
    }
}

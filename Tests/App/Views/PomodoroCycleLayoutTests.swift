import Testing
@testable import Countdown

struct PomodoroCycleLayoutTests {
    @Test
    func allCycleCountsUseBalancedRowsAndCountSpecificDiameters() {
        let expectedRows = [[1], [2], [3], [4], [3, 2], [3, 3], [4, 3], [4, 4],
                            [5, 4], [5, 5], [4, 4, 3], [4, 4, 4], [5, 4, 4], [5, 5, 4], [5, 5, 5]]
        let diameters = [12, 12, 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 7, 7, 7]
        for count in 1...15 {
            let layout = PomodoroCycleLayout(count: count)
            #expect(layout.rows.map(\.count) == expectedRows[count - 1])
            #expect(Double(layout.diameter) == Double(diameters[count - 1]))
            #expect(layout.rows.flatMap { Array($0) } == Array(0..<count))
        }
    }

    @Test
    func defaultUsesSevenCyclesInTwoRows() {
        let model = PomodoroModel()
        #expect(model.focusPeriodsPerCycle == 7)
        #expect(CountdownConfiguration(alarmNotificationURL: nil).pomodoroFocusPeriodsPerCycle == 7)
        #expect(PomodoroCycleLayout(count: model.focusPeriodsPerCycle).rows.map(\.count) == [4, 3])
    }
}

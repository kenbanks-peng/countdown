import Foundation
import Testing
@testable import Countdown

func expectClockMark(_ date: Date, sourceLocation: SourceLocation = #_sourceLocation) {
    let seconds = date.timeIntervalSince(Calendar.current.startOfDay(for: date))
    #expect(abs(seconds - (seconds / 300).rounded() * 300) < 1e-6, sourceLocation: sourceLocation)
}

@MainActor
final class ClockTestSession {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 2, second: 13))!.addingTimeInterval(0.25)
    lazy var controller = makeController()
    init(clock: Bool = true) {
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path])
        CountdownSettingsStore(fileManager: .default, stateDirectory: store.stateDirectory)
            .save(CountdownSettings(mode: clock ? .timer : .countdown))
    }
    func makeController() -> CountdownController {
        CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, pomodoroLongRestMinutes: 15, notificationAudioEnabled: false),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in }, now: { [unowned self] in now }, saveEnablement: { _, _ in }
        )
    }
    func close() { try? FileManager.default.removeItem(at: directory) }
}

import Foundation
import Testing
@testable import Countdown

@MainActor
struct TimerLifecycleTests {
    @Test(arguments: [false, true], [false, true])
    func alarmControlIsIndependentOfNotifications(alarm: Bool, notifications: Bool) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let sound = URL(fileURLWithPath: "/tmp/alarm.mp3")
        var sounds: [URL?] = []
        let timer = TimerModel(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(
                alarmNotificationURL: sound, notificationEnabled: notifications,
                notificationAudioEnabled: false, alarmEnabled: alarm
            ), preferences: CountdownPreferences(), isClockEnabled: false,
            playSound: { sounds.append($0) }, now: { now }
        )
        timer.setDuration(from: 1.0 / 60)
        now += 60
        timer.update()
        #expect(timer.completionCount == 1)
        #expect(sounds == (alarm ? [sound] : []))
    }

    @Test(arguments: [false, true])
    func eachTimeoutReportsOnceIncludingAutomaticNextHour(autoSet: Bool) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12, minute: 59))!
        var sounds = 0
        let timer = TimerModel(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(autoSetToNextHourEnabled: autoSet, notificationEnabled: false),
            isClockEnabled: false, playSound: { _ in sounds += 1 }, now: { now }
        )
        timer.setDuration(from: 1.0 / 60)
        now += 60
        for _ in 0..<5 { timer.update() }
        #expect(timer.completionCount == 1)
        #expect(sounds == 1)
        #expect(timer.remaining == (autoSet ? 3_600 : 0))
        timer.setDuration(from: 1.0 / 60)
        now += 60
        for _ in 0..<5 { timer.update() }
        #expect(timer.completionCount == 2)
        #expect(sounds == 2)
    }
}

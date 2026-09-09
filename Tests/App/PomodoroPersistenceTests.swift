import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroPersistenceTests {
    @Test(arguments: [false, true], [60.0, 1_620, 7_200])
    func restartRetainsModeDurationsAndCorePauseState(paused: Bool, closedTime: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: -300)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        controller.adjustPomodoroDuration(.longRest, by: 300)
        session.now += 600
        controller.update()
        if paused { controller.toggleRunning() }
        controller.save()
        session.now += closedTime
        let restored = session.makeController()
        #expect(restored.mode == .pomodoro)
        #expect(restored.engine.isPaused == paused)
        #expect(restored.pomodoro.status == (paused ? .paused : .running))
        // The fixed schedule advances while closed, but a paused schedule stays frozen.
        controller.update()
        #expect(restored.pomodoro.clockSchedule?.focusEnd == controller.pomodoro.clockSchedule?.focusEnd)
        #expect(restored.pomodoro.clockSchedule?.restEnd == controller.pomodoro.clockSchedule?.restEnd)
        #expect(restored.pomodoro.stage == controller.pomodoro.stage)
        #expect(restored.pomodoro.longRestDuration == 1_200)
        #expect(restored.pomodoro.focusDuration == 1_200)
        #expect(restored.pomodoro.restDuration == 600)
        session.now += 60
        restored.update()
        controller.update()
        #expect(restored.pomodoro.focusRemaining == controller.pomodoro.focusRemaining)
        #expect(restored.pomodoro.restRemaining == controller.pomodoro.restRemaining)
        restored.selectMode(.timer)
        #expect(restored.controlLabel == (paused ? "Resume" : "Pause"))
    }

    @Test(arguments: [false, true])
    func resetAfterRestartUsesConfiguredDefaults(paused: Bool) {
        let session = Session()
        defer { session.removeState() }
        let configuration = CountdownConfiguration(
            alarmNotificationURL: nil, pomodoroFocusMinutes: 20,
            pomodoroRestMinutes: 10, pomodoroLongRestMinutes: 20, pomodoroFocusPeriodsPerCycle: 3
        )
        let controller = session.makeController(configuration: configuration)
        controller.selectMode(.pomodoro)
        session.now += 3_600
        controller.update()
        #expect(controller.pomodoro.stage == 3)
        controller.adjustPomodoroDuration(.focus, by: 300)
        controller.adjustPomodoroDuration(.rest, by: 300)
        controller.adjustPomodoroDuration(.longRest, by: 300)
        if paused { controller.toggleRunning() }
        controller.save()

        let restored = session.makeController(configuration: configuration)
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.restDuration == 900)
        #expect(restored.pomodoro.longRestDuration == 1_500)
        restored.resetPomodoro()

        // Reset saves the new schedule without a separate save command.
        let reloaded = session.makeController(configuration: configuration)
        #expect(reloaded.pomodoro.stage == 1)
        #expect(reloaded.pomodoro.focusPeriodsPerCycle == 3)
        #expect(reloaded.pomodoro.completedFocusPeriods == 0)
        #expect(reloaded.pomodoro.focusRemaining == 1_200)
        #expect(reloaded.pomodoro.restRemaining == 600)
        #expect(reloaded.pomodoro.longRestDuration == 1_200)
        #expect(reloaded.engine.isPaused == paused)
    }

    @Test(arguments: [
        "not JSON", "{}",
        #"{"mode":"Other","focusDuration":1200,"restDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200}"#,
        #"{"mode":"Pomodoro","restDuration":420}"#,
        #"{"focusDuration":1200,"restDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":3601,"restDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"restDuration":59}"#,
        #"{"mode":"Pomodoro","focusDuration":-60,"restDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"restDuration":-60}"#,
        #"{"mode":"Pomodoro","focusDuration":3300,"restDuration":3601}"#,
        #"{"mode":"Pomodoro","focusDuration":1e309,"restDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"restDuration":"NaN"}"#,
        #"{"mode":"Pomodoro","focusDuration":null,"restDuration":420}"#
    ])
    func invalidSettingsUseDefaultsAndRetainTheSavedPause(record: String) throws {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.adjustTimerDuration(by: 1_200)
        controller.toggleRunning()
        controller.save()
        try Data(record.utf8).write(to: session.settingsURL)
        session.now += 60
        let restored = session.makeController()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.focusRemaining == 900)
        #expect(restored.pomodoro.restDuration == 300)
        #expect(restored.pomodoro.status == .paused)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 1_200)
        #expect(session.sounds == 0)
    }

    @Test
    func hiddenTimerRestoresAndContinuesWithoutStartupSounds() {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.adjustTimerDuration(by: 1_200)
        controller.selectMode(.pomodoro)
        controller.save()
        session.now += 301
        let restored = session.makeController()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.status == .running)
        #expect(restored.timer.status == .active)
        #expect(restored.timer.remaining == 899)
        #expect(restored.timer.completionCount == 0)
        #expect(session.sounds == 0)
        session.now += 60
        restored.selectMode(.timer)
        #expect(restored.timer.remaining == 839)
        session.now += 839
        restored.update()
        #expect(restored.timer.completionCount == 1)
        #expect(restored.notifications.notificationIntervalCount == 1)
        #expect(session.sounds == 2) // Endpoint notification and completion alarm.
    }

    @Test(arguments: [true, false])
    func savedMinimumAndCapacityRemainValidAfterRestart(focusAtMinimum: Bool) {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.selectMode(.pomodoro)
        let minimum: PomodoroModel.Phase = focusAtMinimum ? .focus : .rest
        let maximum: PomodoroModel.Phase = focusAtMinimum ? .rest : .focus
        controller.adjustPomodoroDuration(minimum, by: -3_600)
        controller.adjustPomodoroDuration(maximum, by: 3_600)
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.focusDuration == (focusAtMinimum ? 300 : 3_300))
        #expect(restored.pomodoro.restDuration == (focusAtMinimum ? 3_300 : 300))
        restored.adjustPomodoroDuration(minimum, by: -60)
        restored.adjustPomodoroDuration(maximum, by: 60)
        restored.resetPomodoro()
        let reloaded = session.makeController()
        #expect(reloaded.pomodoro.status == .running)
        #expect(reloaded.pomodoro.stage == 1)
        #expect(reloaded.pomodoro.focusRemaining == 1_500)
        #expect(reloaded.pomodoro.restRemaining == 300)
    }

    @Test(arguments: [true, false])
    func unavailableStorageAllowsInMemoryUse(blockStateRoot: Bool) throws {
        let session = Session()
        defer { session.removeState() }
        if blockStateRoot {
            try Data("not a directory".utf8).write(to: session.directory)
        } else {
            try FileManager.default.createDirectory(at: session.settingsURL, withIntermediateDirectories: true)
        }
        let controller = session.makeController()
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: -300)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        session.now += 60
        controller.update()
        controller.save()
        #expect(controller.pomodoro.status == .running)
        #expect(controller.pomodoro.focusRemaining == 1_140)
        let restored = session.makeController()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.status == .running)
        #expect(restored.pomodoro.focusRemaining + restored.pomodoro.restRemaining == restored.timer.remaining)
        #expect(restored.pomodoro.restDuration == 300)
    }

    @Test
    func failedWriteKeepsLastReadableSettings() throws {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: -300)
        controller.save()
        let directory = session.settingsURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        #expect(!FileManager.default.isWritableFile(atPath: directory.path))
        controller.adjustPomodoroDuration(.focus, steps: 1)
        controller.selectMode(.timer)
        controller.save()
        #expect(controller.pomodoro.focusDuration == 1_500)
        let restored = session.makeController()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.focusDuration == 1_200)
        #expect(restored.pomodoro.status == .running)
    }

    enum CountdownRecord: CaseIterable {
        case active, prepared, staleActive, stalePrepared, expired, invalid
    }

    @Test(arguments: CountdownRecord.allCases, ["missing", "invalid", "Timer", "Pomodoro", "Countdown"])
    func restorationUsesTheSelectedViewsSavedTime(record: CountdownRecord, selectedMode: String) throws {
        let session = Session()
        defer { session.removeState() }
        let prepared = record == .prepared || record == .stalePrepared
        let stale = record == .staleActive || record == .stalePrepared
        session.store.save(TimerSession(
            status: prepared ? .prepared : .active, duration: 1_200, remaining: 1_200,
            endDate: record == .invalid ? nil : session.now + (record == .expired ? -1 : 899),
            savedAt: session.now - (stale ? 1_201 : 301)
        ))
        if selectedMode != "missing" {
            let settings = selectedMode == "invalid" ? "{}"
                : "{\"mode\":\"\(selectedMode)\",\"focusDuration\":1200,\"restDuration\":420}"
            try Data(settings.utf8).write(to: session.settingsURL)
        }
        let restored = session.makeController()
        #expect(restored.mode == (CountdownMode(rawValue: selectedMode) ?? .timer))
        let retainsPrepared = prepared && (record != .stalePrepared || restored.mode.isClockEnabled)
        #expect(restored.pomodoro.status == (retainsPrepared ? .paused : .running))
        #expect(restored.timer.completionCount == 0)
        if restored.mode == .pomodoro {
            #expect(restored.timer.remaining == 1_620)
            #expect(restored.timer.remaining == restored.pomodoro.focusRemaining + restored.pomodoro.restRemaining)
            #expect(session.sounds == 0)
            return
        }
        switch record {
        case .active:
            #expect(restored.timer.status == .active)
            #expect(restored.timer.remaining == 899)
            #expect(session.sounds == 0) // Restored elapsed time must not replay Notification.
        case .prepared, .stalePrepared:
            #expect(restored.timer.isPaused == retainsPrepared)
            #expect(restored.timer.remaining == (retainsPrepared ? 1_200 : 0))
            #expect(session.sounds == 0)
        case .staleActive, .expired, .invalid:
            #expect(restored.timer.status == .empty)
            #expect(session.sounds == 0)
        }
    }

    @Test
    func unreadableSettingsDoNotPauseTheTimer() throws {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.adjustTimerDuration(by: 900)
        controller.selectMode(.pomodoro)
        controller.save()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: session.settingsURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: session.settingsURL.path) }
        #expect(!FileManager.default.isReadableFile(atPath: session.settingsURL.path))
        let restored = session.makeController()
        #expect(restored.mode == .timer)
        #expect(restored.timer.status == .active)
        #expect(restored.timer.remaining == 900)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        var store: TimerSessionStore { TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]) }
        var settingsURL: URL { directory.appendingPathComponent("countdown/settings.json") }
        func makeController(
            configuration: CountdownConfiguration = CountdownConfiguration(alarmNotificationURL: nil, pomodoroLongRestMinutes: 15)
        ) -> CountdownController {
            CountdownController(
                sessionStore: store, configuration: configuration,
                preferences: CountdownPreferences(),
                playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
            )
        }
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}

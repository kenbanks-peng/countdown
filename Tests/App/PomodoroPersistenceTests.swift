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
        controller.adjustPomodoroDuration(.shortBreak, by: 120)
        session.now += 600
        controller.update()
        if paused { controller.toggleRunning() }
        controller.save()
        session.now += closedTime
        let restored = session.makeController()
        #expect(restored.mode == .pomodoro)
        #expect(restored.countdown.isPaused == paused)
        #expect(restored.pomodoro.status == (paused ? .paused : .running))
        // Pomodoro allocations persist, but each launch creates a fresh pair.
        #expect(restored.pomodoro.focusRemaining == 1_200)
        #expect(restored.pomodoro.breakRemaining == 420)
        session.now += 60
        restored.update()
        #expect(restored.pomodoro.focusRemaining == (paused ? 1_200 : 1_140))
        restored.selectMode(.timer)
        #expect(restored.controlLabel == (paused ? "Resume" : "Pause"))
    }

    @Test(arguments: [
        "not JSON", "{}",
        #"{"mode":"Other","focusDuration":1200,"breakDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200}"#,
        #"{"mode":"Pomodoro","breakDuration":420}"#,
        #"{"focusDuration":1200,"breakDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":0,"breakDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"breakDuration":59}"#,
        #"{"mode":"Pomodoro","focusDuration":-60,"breakDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"breakDuration":-60}"#,
        #"{"mode":"Pomodoro","focusDuration":3300,"breakDuration":301}"#,
        #"{"mode":"Pomodoro","focusDuration":1e309,"breakDuration":420}"#,
        #"{"mode":"Pomodoro","focusDuration":1200,"breakDuration":"NaN"}"#,
        #"{"mode":"Pomodoro","focusDuration":null,"breakDuration":420}"#
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
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.breakDuration == 300)
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
        #expect(session.sounds == 1)
    }

    @Test(arguments: [true, false])
    func savedMinimumAndCapacityRemainValidAfterRestart(focusAtMinimum: Bool) {
        let session = Session()
        defer { session.removeState() }
        let controller = session.makeController()
        controller.selectMode(.pomodoro)
        let minimum: PomodoroModel.Phase = focusAtMinimum ? .focus : .shortBreak
        let maximum: PomodoroModel.Phase = focusAtMinimum ? .shortBreak : .focus
        controller.adjustPomodoroDuration(minimum, by: -3_600)
        controller.adjustPomodoroDuration(maximum, by: 3_600)
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.focusDuration == (focusAtMinimum ? 60 : 3_540))
        #expect(restored.pomodoro.breakDuration == (focusAtMinimum ? 3_540 : 60))
        restored.adjustPomodoroDuration(minimum, by: -60)
        restored.adjustPomodoroDuration(maximum, by: 60)
        restored.resetPomodoro()
        let reloaded = session.makeController()
        #expect(reloaded.pomodoro.status == .running)
        #expect(reloaded.pomodoro.focusRemaining == (focusAtMinimum ? 60 : 3_540))
        #expect(reloaded.pomodoro.breakRemaining == (focusAtMinimum ? 3_540 : 60))
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
        controller.adjustPomodoroDuration(.shortBreak, by: 120)
        session.now += 60
        controller.update()
        controller.save()
        #expect(controller.pomodoro.status == .running)
        #expect(controller.pomodoro.focusRemaining == 1_140)
        let restored = session.makeController()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.status == .running)
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.breakDuration == 300)
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
        controller.adjustPomodoroDuration(.focus, by: 60)
        controller.selectMode(.timer)
        controller.save()
        #expect(controller.pomodoro.focusDuration == 1_260)
        let restored = session.makeController()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.focusDuration == 1_200)
        #expect(restored.pomodoro.status == .running)
    }

    enum CountdownRecord: CaseIterable {
        case active, prepared, staleActive, stalePrepared, expired, invalid
    }

    @Test(arguments: CountdownRecord.allCases, ["missing", "invalid", "Timer", "Pomodoro"])
    func timerRestorationDoesNotDependOnMode(record: CountdownRecord, selectedMode: String) throws {
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
                : "{\"mode\":\"\(selectedMode)\",\"focusDuration\":1200,\"breakDuration\":420}"
            try Data(settings.utf8).write(to: session.settingsURL)
        }
        let restored = session.makeController()
        #expect(restored.mode == (selectedMode == "Pomodoro" ? .pomodoro : .timer))
        #expect(restored.pomodoro.status == (record == .prepared ? .paused : .running))
        #expect(restored.timer.completionCount == 0)
        switch record {
        case .active:
            #expect(restored.timer.status == .active)
            #expect(restored.timer.remaining == 899)
            #expect(session.sounds == 0) // Restored elapsed time must not replay Wakeup.
        case .prepared:
            #expect(restored.timer.isPaused)
            #expect(restored.timer.remaining == 1_200)
            #expect(session.sounds == 0)
        case .staleActive, .stalePrepared, .expired, .invalid:
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
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        var store: TimerStateStore { TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]) }
        var settingsURL: URL { directory.appendingPathComponent("countdown/settings.json") }
        func makeController() -> CountdownController {
            CountdownController(
                stateStore: store, configuration: CountdownConfiguration(alarmNotificationURL: nil),
                playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
            )
        }
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}

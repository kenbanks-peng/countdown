import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroPersistenceTests {
    enum SavedActivity: CaseIterable {
        case ready, runningFocus, runningBreak, pausedFocus, pausedBreak, completed
    }

    @Test(arguments: SavedActivity.allCases, [60.0, 1_620, 7_200])
    func restartRetainsSelectedModeAndEditedPairButNotActivity(activity: SavedActivity, closedTime: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        if activity != .ready {
            timer.togglePomodoroRunning()
            switch activity {
            case .runningFocus, .pausedFocus: session.now += 600
            case .runningBreak, .pausedBreak: session.now += 1_320
            case .completed: session.now += 1_620
            case .ready: break
            }
            timer.update()
            if activity == .pausedFocus || activity == .pausedBreak { timer.togglePomodoroRunning() }
        }
        timer.save()
        session.now += closedTime
        let soundsBeforeRestart = session.sounds

        let restored = session.makeTimer()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.pomodoro.focusRemaining == 1_200)
        #expect(restored.pomodoro.breakRemaining == 420)
        #expect(restored.pomodoro.accessibilityDescription == "Pomodoro ready. Focus: 20 minutes allocated. Break: 7 minutes allocated.")
        session.now += 7_200
        restored.update()
        #expect(restored.pomodoro.status == .ready)
        restored.togglePomodoroRunning()
        session.now += 60
        restored.update()
        #expect(restored.pomodoro.focusRemaining == 1_140)
        #expect(restored.pomodoro.breakRemaining == 420)
        #expect(session.sounds == soundsBeforeRestart)
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
    func invalidSettingsUseCompleteDefaultsWithoutChangingCountdown(record: String) throws {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.adjustTimerDuration(by: 1_200)
        timer.toggleTimerRunning()
        timer.save()
        try Data(record.utf8).write(to: session.settingsURL)
        session.now += 60

        let restored = session.makeTimer()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.breakDuration == 300)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 1_200)
        #expect(session.sounds == 0)
    }

    @Test
    func pomodoroStartupRestoresThenPausesUnrelatedCountdownWithoutStartupSounds() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        timer.save()
        // An independent active Countdown record can exist beside the selected mode.
        session.countdownStore.save(TimerSession(
            status: .active, duration: 1_200, remaining: 1_200,
            endDate: session.now + 1_200, savedAt: session.now
        ))
        session.now += 301

        let restored = session.makeTimer()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 899)
        #expect(restored.timer.completionCount == 0)
        #expect(session.sounds == 0)
        session.now += 60
        restored.update()
        restored.selectMode(.timer)
        #expect(restored.timer.remaining == 899)
        #expect(restored.timer.isPaused)
        restored.toggleTimerRunning()
        session.now += 60
        restored.update()
        #expect(restored.timer.remaining == 839)
        session.now += 839
        restored.update()
        #expect(restored.timer.completionCount == 1)
        #expect(session.sounds == 1, "Startup suppression must not mute later Countdown completion")
    }

    @Test
    func modeAndDurationCommandsSaveWithoutWritingTheCountdownSession() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        session.countdownStore.save(TimerSession(
            status: .prepared, duration: 900, remaining: 900,
            endDate: nil, savedAt: session.now
        ))
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        timer.resetPomodoro()

        let restored = session.makeTimer()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.focusDuration == 1_200)
        #expect(restored.pomodoro.breakDuration == 420)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 900)
        restored.selectMode(.timer)
        let countdownSelected = session.makeTimer()
        #expect(countdownSelected.mode == .timer)
        #expect(countdownSelected.pomodoro.focusDuration == 1_200)
        #expect(countdownSelected.pomodoro.breakDuration == 420)
        #expect(countdownSelected.timer.remaining == 900)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [true, false])
    func savedMinimumAndCapacityRemainValidAfterRestart(focusAtMinimum: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        let minimumPhase: PomodoroModel.Phase = focusAtMinimum ? .focus : .shortBreak
        let maximumPhase: PomodoroModel.Phase = focusAtMinimum ? .shortBreak : .focus
        timer.adjustPomodoroDuration(minimumPhase, by: -3_600)
        timer.adjustPomodoroDuration(maximumPhase, by: 3_600)
        timer.save()

        let restored = session.makeTimer()
        #expect(restored.pomodoro.focusDuration == (focusAtMinimum ? 60 : 3_540))
        #expect(restored.pomodoro.breakDuration == (focusAtMinimum ? 3_540 : 60))
        restored.adjustPomodoroDuration(minimumPhase, by: -60)
        restored.adjustPomodoroDuration(maximumPhase, by: 60)
        restored.resetPomodoro()
        let reloaded = session.makeTimer()
        #expect(reloaded.pomodoro.status == .ready)
        #expect(reloaded.pomodoro.focusRemaining == (focusAtMinimum ? 60 : 3_540))
        #expect(reloaded.pomodoro.breakRemaining == (focusAtMinimum ? 3_540 : 60))
    }

    @Test(arguments: [true, false])
    func unavailableStorageStillAllowsInMemoryUseAndReloadsDefaults(blockStateRoot: Bool) throws {
        let session = Session()
        defer { session.removeState() }
        if blockStateRoot {
            try Data("not a directory".utf8).write(to: session.directory)
        } else {
            // A directory at the record path cannot be read or replaced as a JSON file.
            try FileManager.default.createDirectory(at: session.settingsURL, withIntermediateDirectories: true)
        }
        let timer = session.makeTimer()
        #expect(timer.mode == .timer)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        timer.togglePomodoroRunning()
        session.now += 60
        timer.update()
        timer.save()
        #expect(timer.mode == .pomodoro)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.focusRemaining == 1_140)
        #expect(timer.pomodoro.breakRemaining == 420)

        let restored = session.makeTimer()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.breakDuration == 300)
        #expect(session.sounds == 0)
    }

    @Test
    func failedWriteKeepsTheLastReadableSettingsNotUnsavedEdits() throws {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        timer.save()
        let stateDirectory = session.settingsURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: stateDirectory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stateDirectory.path) }
        #expect(!FileManager.default.isWritableFile(atPath: stateDirectory.path))
        timer.adjustPomodoroDuration(.focus, by: 60)
        timer.selectMode(.timer)
        timer.save()
        #expect(timer.mode == .timer)
        #expect(timer.pomodoro.focusDuration == 1_260)

        let restored = session.makeTimer()
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.pomodoro.focusDuration == 1_200)
        #expect(restored.pomodoro.breakDuration == 420)
        #expect(session.sounds == 0)
    }

    enum CountdownRecord: CaseIterable {
        case active, prepared, staleActive, stalePrepared, expired, invalid
    }

    @Test(arguments: CountdownRecord.allCases, ["missing", "invalid", "Timer", "Pomodoro"])
    func countdownRestorationKeepsItsRulesBeforeTheHiddenPauseGate(record: CountdownRecord, selectedMode: String) throws {
        let session = Session()
        defer { session.removeState() }
        let prepared = record == .prepared || record == .stalePrepared
        let stale = record == .staleActive || record == .stalePrepared
        session.countdownStore.save(TimerSession(
            status: prepared ? .prepared : .active, duration: 1_200, remaining: 1_200,
            endDate: record == .invalid ? nil : session.now + (record == .expired ? -1 : 899),
            savedAt: session.now - (stale ? 1_201 : 301)
        ))
        if selectedMode != "missing" {
            let settings = selectedMode == "invalid" ? "{}"
                : "{\"mode\":\"\(selectedMode)\",\"focusDuration\":1200,\"breakDuration\":420}"
            try Data(settings.utf8).write(to: session.settingsURL)
        }
        let restored = session.makeTimer()
        #expect(restored.mode == (selectedMode == "Pomodoro" ? .pomodoro : .timer))
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.timer.completionCount == 0)
        switch record {
        case .active:
            #expect(restored.timer.status == (selectedMode == "Pomodoro" ? .prepared : .active))
            #expect(restored.timer.remaining == 899)
            // Countdown-selected startup retains its established Wakeup rule.
            #expect(session.sounds == (selectedMode == "Pomodoro" ? 0 : 1))
        case .prepared:
            #expect(restored.timer.isPaused)
            #expect(restored.timer.remaining == 1_200)
            #expect(session.sounds == 0)
        case .staleActive, .stalePrepared, .expired, .invalid:
            #expect(restored.timer.status == .empty)
            #expect(restored.timer.remaining == 0)
            #expect(session.sounds == 0)
        }
    }

    @Test
    func unreadableSettingsFallBackWithoutReplacingCountdown() throws {
        let session = Session()
        defer { session.removeState() }
        let timer = session.makeTimer()
        timer.adjustTimerDuration(by: 900)
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.save()
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: session.settingsURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: session.settingsURL.path) }
        #expect(!FileManager.default.isReadableFile(atPath: session.settingsURL.path))

        let restored = session.makeTimer()
        #expect(restored.mode == .timer)
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.breakDuration == 300)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 900)
        #expect(session.sounds == 0)
    }

    @Test
    func startupPauseGateAlsoStopsCountdownAutosetWithoutChangingItsSettings() {
        let session = Session()
        defer { session.removeState() }
        session.now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 6, hour: 10, minute: 30))!
        let timer = session.makeTimer()
        timer.selectMode(.pomodoro)
        timer.save()
        let restored = session.makeTimer(configuration: CountdownConfiguration(
            alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false,
            currentTimeoutEnabled: false, autosetEnabled: true
        ))
        #expect(restored.mode == .pomodoro)
        #expect(restored.pomodoro.status == .ready)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 1_800)
        #expect(restored.timer.isAutosetEnabled)
        #expect(restored.features.isWakeupEnabled)
        #expect(!restored.features.isClockFaceEnabled)
        #expect(!restored.features.isClockHandsEnabled)
        #expect(!restored.timer.isCurrentTimeoutEnabled)
        session.now += 3_600
        restored.update()
        restored.selectMode(.timer)
        #expect(restored.timer.isPaused)
        #expect(restored.timer.remaining == 1_800)
        #expect(session.sounds == 0)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0

        var countdownStore: TimerStateStore {
            TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        }

        var settingsURL: URL {
            directory.appendingPathComponent("countdown/settings.json")
        }

        func makeTimer(configuration: CountdownConfiguration = CountdownConfiguration(alarmNotificationURL: nil)) -> CountdownController {
            CountdownController(
                stateStore: countdownStore,
                configuration: configuration,
                playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
            )
        }

        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}

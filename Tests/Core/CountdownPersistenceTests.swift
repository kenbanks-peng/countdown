import Foundation
import Testing
@testable import Countdown

struct CountdownPersistenceTests {
    @Test
    func stateDirectoryUsesTheConfiguredRoot() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = CountdownStateDirectory.resolve(environment: ["XDG_STATE_HOME": root.path])
        #expect(directory.path == root.appendingPathComponent("countdown").path)
    }

    @Test(arguments: [[:], ["XDG_STATE_HOME": ""]])
    func stateDirectoryUsesTheHomeDirectoryWhenNoRootIsSet(environment: [String: String]) {
        let directory = CountdownStateDirectory.resolve(environment: environment)
        let expected = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state/countdown")
        #expect(directory.path == expected.path)
    }

    @Test(arguments: CountdownMode.allCases)
    func settingsStoreUsesAppModeNamesAndDoesNotWriteASession(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CountdownSettingsStore(fileManager: .default, stateDirectory: directory)
        store.save(CountdownSettings(mode: mode, focusDuration: 1_200, breakDuration: 420))

        let restored = store.load()
        #expect(restored.mode == mode)
        #expect(restored.focusDuration == 1_200)
        #expect(restored.breakDuration == 420)
        let data = try Data(contentsOf: directory.appendingPathComponent("settings.json"))
        let record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(record["mode"] as? String == (mode == .timer ? "Timer" : "Pomodoro"))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("session.json").path))
    }
}

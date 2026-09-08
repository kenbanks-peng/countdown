import Foundation
import Testing
@testable import Countdown

struct CountdownScaleConfigurationTests {
    @Test(arguments: ["", "invalid", "0", "-0.8", "nan", "inf", "1e999", "\"1.5\""])
    func invalidScalesUseOriginalSizes(value: String) throws {
        let config = try load("size = \(value)\ncompact_size = \(value)")
        #expect(config.size == 1)
        #expect(config.compactSize == 1)
    }

    @Test
    func independentScalesAcceptDecimalsAndComments() throws {
        let config = try load("size = 1.5 # Normal\ncompact_size = 0.8 # Compact")
        #expect(config.size == 1.5)
        #expect(config.compactSize == 0.8)
        let normalOnly = try load("size = 2")
        #expect(normalOnly.size == 2)
        #expect(normalOnly.compactSize == 1)
        let compactOnly = try load("compact_size = 0.8")
        #expect(compactOnly.size == 1)
        #expect(compactOnly.compactSize == 0.8)
    }

    @Test
    func defaultsAndSectionScope() throws {
        let defaults = CountdownConfiguration(alarmNotificationURL: nil)
        #expect(defaults.size == 1)
        #expect(defaults.compactSize == 1)
        let config = try load("[pomodoro]\nsize = 1.5\ncompact_size = 0.8")
        #expect(config.size == 1)
        #expect(config.compactSize == 1)
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity, -Double.infinity])
    func initializerRejectsInvalidScales(value: Double) {
        let config = CountdownConfiguration(alarmNotificationURL: nil, size: value, compactSize: value)
        #expect(config.size == 1)
        #expect(config.compactSize == 1)
    }

    private func load(_ contents: String) throws -> CountdownConfiguration {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try contents.write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        return CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
    }
}

import Foundation
import Testing
@testable import Countdown

struct CountdownSizeConfigurationTests {
    @Test(arguments: ["", "invalid", "0", "-0.8", "nan", "inf", "1e999", "\"220\""])
    func invalidSizesUseDefaults(value: String) throws {
        let config = try load("size_px = \(value)\ncompact_size_px = \(value)")
        #expect(config.sizePx == 220)
        #expect(config.compactSizePx == 32)
    }

    @Test
    func independentSizesAcceptDecimalsAndComments() throws {
        let config = try load("size_px = 282.5 # Normal\ncompact_size_px = 25.6 # Compact")
        #expect(config.sizePx == 282.5)
        #expect(config.compactSizePx == 25.6)
        let normalOnly = try load("size_px = 376")
        #expect(normalOnly.sizePx == 376)
        #expect(normalOnly.compactSizePx == 32)
        let compactOnly = try load("compact_size_px = 25.6")
        #expect(compactOnly.sizePx == 220)
        #expect(compactOnly.compactSizePx == 25.6)
    }

    @Test
    func defaultsAndSectionScope() throws {
        let defaults = CountdownConfiguration(alarmNotificationURL: nil)
        #expect(defaults.sizePx == 220)
        #expect(defaults.compactSizePx == 32)
        #expect(defaults.compactSizePx == Double(CountdownAppearance.compactSize))
        let config = try load("[pomodoro]\nsize_px = 282\ncompact_size_px = 25.6")
        #expect(config.sizePx == 220)
        #expect(config.compactSizePx == 32)
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity, -Double.infinity])
    func initializerRejectsInvalidSizes(value: Double) {
        let config = CountdownConfiguration(alarmNotificationURL: nil, sizePx: value, compactSizePx: value)
        #expect(config.sizePx == 220)
        #expect(config.compactSizePx == 32)
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

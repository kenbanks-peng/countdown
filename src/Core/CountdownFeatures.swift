import Combine
import Foundation

/// App-wide display settings and interval notifications, shared by both modes.
@MainActor
final class CountdownFeatures: ObservableObject {
    @Published private(set) var isClockFaceEnabled: Bool
    @Published private(set) var isClockHandsEnabled: Bool
    @Published private(set) var isWakeupEnabled: Bool
    @Published private(set) var wakeupIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void

    init(
        configuration: CountdownConfiguration,
        playSound: @escaping @MainActor (URL?) -> Void,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownConfiguration.saveEnablement($0, enabled: $1) }
    ) {
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isClockFaceEnabled = configuration.clockFaceEnabled
        isClockHandsEnabled = configuration.clockHandsEnabled
        isWakeupEnabled = configuration.wakeupEnabled
    }

    func setClockFaceEnabled(_ enabled: Bool) {
        isClockFaceEnabled = enabled
        saveEnablement("clock_face_enabled", enabled)
    }

    func setClockHandsEnabled(_ enabled: Bool) {
        isClockHandsEnabled = enabled
        saveEnablement("clock_hands_enabled", enabled)
    }

    func setWakeupEnabled(_ enabled: Bool) {
        isWakeupEnabled = enabled
        saveEnablement("wakeup_enabled", enabled)
    }

    /// Report only elapsed time, not duration edits or mode changes.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        let interval = TimeInterval(max(1, configuration.wakeupTime)) * 60
        guard isWakeupEnabled, remaining > 0, previousRemaining > remaining,
              ceil(previousRemaining / interval) > ceil(remaining / interval)
        else { return }

        wakeupIntervalCount += 1
        let sound: URL?
        switch remaining {
        case 1_200...: sound = configuration.greenNotificationURL
        case 600...: sound = configuration.yellowNotificationURL
        default: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}

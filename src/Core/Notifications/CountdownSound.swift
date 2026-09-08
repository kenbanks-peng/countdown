import AppKit

/// Sound playback shared by mode alarms and Countdown interval notifications.
@MainActor
enum CountdownSound {
    static func play(at soundURL: URL?) {
        guard let soundURL,
              let sound = NSSound(contentsOf: soundURL, byReference: true)
        else {
            NSSound.beep()
            return
        }
        sound.play()
    }
}

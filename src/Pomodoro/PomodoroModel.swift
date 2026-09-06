import Foundation

/// Ready allocation only. Phase timing is a separate feature.
struct PomodoroModel {
    let focusDuration: TimeInterval = 25 * 60
    let breakDuration: TimeInterval = 5 * 60

    var phaseLabel: String { "Focus" }

    var accessibilityDescription: String {
        "Pomodoro ready. Focus: 25 minutes allocated. Break: 5 minutes allocated."
    }
}

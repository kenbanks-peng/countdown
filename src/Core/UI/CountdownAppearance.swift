import SwiftUI

/// Geometry shared by drawing, hit testing, and popup scaling.
enum CountdownAppearance {
    static let normalSize: CGFloat = 188
    static let compactSize: CGFloat = 32
    static let circleInset: CGFloat = 6
}

extension Color {
    static let pomodoroBlue = Color(.sRGB, red: 0.20, green: 0.48, blue: 0.88)
    static let countdownGreen = Color(.sRGB, red: 0.24, green: 0.68, blue: 0.42)
    static let countdownYellow = Color(.sRGB, red: 0.84, green: 0.62, blue: 0.20)
    static let countdownRed = Color(.sRGB, red: 0.88, green: 0.30, blue: 0.32)
    static let countdownSurface = Color(.sRGB, red: 0.11, green: 0.11, blue: 0.12)
    static let countdownTrack = Color(.sRGB, red: 0.33, green: 0.33, blue: 0.36)
    static let countdownMuted = Color(.sRGB, red: 0.66, green: 0.66, blue: 0.69)
}

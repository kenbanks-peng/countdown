import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct PomodoroRenderingTests {
    @Test(arguments: [0.0, 600, 1_500, 1_620, 1_800, 6_900], [false, true])
    func pomodoroClockRendersCurrentSectorsAcrossPhases(elapsed: TimeInterval, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(reminderEnabled: false), playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        now += elapsed
        controller.update()
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: isCompact, changePresentation: {}))
        let bitmap = try render(hosting, side: side)
        let model = controller.pomodoro
        let schedule = try #require(model.clockSchedule)
        func angle(at date: Date) -> Double {
            date.timeIntervalSince(Calendar.current.startOfDay(for: date))
                .truncatingRemainder(dividingBy: 3_600) / 10
        }
        if model.focusRemaining > 0 {
            let middle = now + model.focusRemaining / 2
            #expect(try sample(bitmap, angle: angle(at: middle), radius: 0.32).greenComponent > 0.6)
        }
        let restEnd = schedule.end(for: model.restPhase)
        let restMiddle = restEnd - model.restRemaining / 2
        #expect(try sample(bitmap, angle: angle(at: restMiddle), radius: 0.32).blueComponent > 0.8)
        let text = try recognizedText(bitmap)
        #expect(!text.contains("Focus") && !text.contains("Rest"))
        #expect(controller.mode.isClockEnabled)
        #expect(controller.pomodoro.stage == (elapsed < 1_800 ? 1 : elapsed < 6_900 ? 2 : 4))
    }

    @Test(arguments: [32.0, 71, 123, 188], [false, true])
    func pomodoroStaysCircularAtBothPresentationsAndSquareTransitionSizes(side: Double, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(reminderEnabled: false),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        controller.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: isCompact, changePresentation: {}))
        let bitmap = try render(hosting, side: side)
        let radius = (side / 2 - (isCompact ? 0 : 6) - 4) / side
        #expect(try sample(bitmap, angle: 165, radius: radius).blueComponent > 0.8)
        #expect(try sample(bitmap, angle: 90, radius: radius).greenComponent > 0.6)
        #expect(try sample(bitmap, angle: 255, radius: min(radius, 0.32)).greenComponent < 0.2)
        if isCompact { #expect(try recognizedText(bitmap).isEmpty) }
        if isCompact && side == 188 {
            #expect(try sample(bitmap, angle: 153).blueComponent > 0.8)
            #expect(try sample(bitmap, angle: 33).greenComponent > 0.6)
            #expect(try sample(bitmap, angle: 147).greenComponent > 0.6)
            #expect(try sample(bitmap, angle: 183).greenComponent < 0.2)
        }
        #expect(try sample(bitmap, angle: 90, radius: 0.12).greenComponent > 0.6)
        let maxX = bitmap.pixelsWide - 1
        let maxY = bitmap.pixelsHigh - 1
        for (x, y) in [(1, 1), (maxX - 1, 1), (1, maxY - 1), (maxX - 1, maxY - 1)] {
            #expect(try #require(bitmap.colorAt(x: x, y: y)).alphaComponent < 0.05)
        }
        for angle in [0.0, 90, 180, 270] {
            #expect(try sample(bitmap, angle: angle, radius: radius).alphaComponent > 0.95)
        }
        let scale = Double(bitmap.pixelsWide) / side
        let outerRadius = (side / 2 - (isCompact ? 0 : 6) + 1) * scale
        var outsideAlpha: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if hypot(Double(x) + 0.5 - Double(bitmap.pixelsWide) / 2,
                         Double(y) + 0.5 - Double(bitmap.pixelsHigh) / 2) > outerRadius {
                    outsideAlpha = max(outsideAlpha, bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1)
                }
            }
        }
        #expect(outsideAlpha < 0.05)
    }

    @Test(arguments: [0.0, 1_500, 1_800, 3_600, 5_400, 6_900, 7_800])
    func fourDotsRenderCompletedCurrentAndPendingFocus(elapsed: TimeInterval) throws {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        var model = PomodoroModel()
        model.toggleRunning(at: start)
        model.update(at: start + elapsed)
        let bitmap = try render(NSHostingView(rootView: PomodoroView(model: model)))
        let scale = Double(bitmap.pixelsWide) / 188
        var areas: [PomodoroModel.DotState: [Int]] = [:]
        for index in 0..<4 {
            let centerX = 73.0 + Double(index) * 14
            var whitePixels = 0
            for y in Int(122 * scale)..<Int(130 * scale) {
                for x in Int((centerX - 4) * scale)..<Int((centerX + 4) * scale) {
                    let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    if min(color.redComponent, color.greenComponent, color.blueComponent) > 0.8 {
                        whitePixels += 1
                    }
                }
            }
            #expect(whitePixels > 0, "Dot \(index + 1) must be visible")
            areas[model.dotStates[index], default: []].append(whitePixels)
        }
        if let completed = areas[.completed]?.min(), let current = areas[.current]?.max() {
            #expect(completed > current)
        }
        if let current = areas[.current]?.min(), let pending = areas[.pending]?.max() {
            #expect(current > pending)
        }
        if let completed = areas[.completed]?.min(), let pending = areas[.pending]?.max() {
            #expect(completed > pending)
        }
    }
}

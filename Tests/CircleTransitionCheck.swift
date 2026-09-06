import AppKit
import SwiftUI

// SwiftPM normally synthesizes this accessor for the application target.
extension Bundle {
    static let module = Bundle.main
}

@main
struct CircleTransitionCheck {
    @MainActor
    static func main() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateStore = CountdownStateStore(environment: [
            "XDG_STATE_HOME": directory.path
        ])
        let configuration = CountdownConfiguration(alarmNotificationURL: nil)
        let model = CountdownModel(
            stateStore: stateStore,
            configuration: configuration,
            playSound: { _ in }
        )
        let hostingView = NSHostingView(rootView: CountdownView(model: model, compact: {}))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        var failures: [String] = []

        for side in stride(from: 45.0, through: 175.0, by: 13.0) {
            hostingView.frame = NSRect(x: 0, y: 0, width: side, height: side)
            hostingView.layoutSubtreeIfNeeded()
            guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                failures.append("could not render \(Int(side))x\(Int(side))")
                continue
            }
            bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

            let maxX = bitmap.pixelsWide - 1
            let maxY = bitmap.pixelsHigh - 1
            let corners = [(1, 1), (maxX - 1, 1), (1, maxY - 1), (maxX - 1, maxY - 1)]
            let cornerAlpha = corners.compactMap { bitmap.colorAt(x: $0.0, y: $0.1)?.alphaComponent }.max() ?? 1
            let centerAlpha = bitmap.colorAt(x: maxX / 2, y: maxY / 2)?.alphaComponent ?? 0
            let inset = max(1, Int(8 * CGFloat(bitmap.pixelsWide) / side))
            let edgePoints = [
                (maxX / 2, inset), (maxX / 2, maxY - inset),
                (inset, maxY / 2), (maxX - inset, maxY / 2)
            ]
            let edgeAlpha = edgePoints.compactMap { bitmap.colorAt(x: $0.0, y: $0.1)?.alphaComponent }.min() ?? 0
            if cornerAlpha > 0.05 || edgeAlpha < 0.5 || centerAlpha < 0.5 {
                failures.append("rendered \(Int(side))x\(Int(side)): corner alpha \(cornerAlpha), edge alpha \(edgeAlpha), center alpha \(centerAlpha)")
            }
        }

        guard failures.isEmpty else {
            fputs("FAIL: normal countdown content becomes square during intermediate sizes:\n", stderr)
            failures.forEach { fputs("- \($0)\n", stderr) }
            exit(1)
        }

        print("PASS: normal countdown content follows every square transition size")
    }
}

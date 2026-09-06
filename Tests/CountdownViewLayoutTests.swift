import SwiftUI
import Testing
@testable import Countdown

@MainActor
struct CountdownViewLayoutTests {
    @Test
    func normalViewRemainsSquareAtIntermediateTransitionSizes() {
        let stateStore = CountdownStateStore(environment: [
            "XDG_STATE_HOME": FileManager.default.temporaryDirectory.path
        ])
        let configuration = CountdownConfiguration(alarmNotificationURL: nil)
        let model = CountdownModel(
            stateStore: stateStore,
            configuration: configuration,
            playSound: { _ in }
        )
        let hostingView = NSHostingView(rootView: CountdownView(model: model, compact: {}))

        for side in stride(from: 32.0, through: 188.0, by: 13.0) {
            let proposedSize = NSSize(width: side, height: side)
            let fittedSize = hostingView.sizeThatFits(proposedSize)

            #expect(abs(fittedSize.width - side) <= 0.5, "Width must follow the square transition frame")
            #expect(abs(fittedSize.height - side) <= 0.5, "Height must follow the square transition frame")
        }
    }
}

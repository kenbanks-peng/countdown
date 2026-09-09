import SwiftUI

struct TimerContextMenu: View {
    @ObservedObject var model: TimerModel
    let setToNextHour: () -> Void

    var body: some View {
        Toggle("Timeout", isOn: enablementBinding(\.showsRemainingMinutes, model.setRemainingMinutesVisible))
        Divider()
        Button("Set Timeout to Next Hour", action: setToNextHour)
    }

    private func enablementBinding(
        _ keyPath: KeyPath<TimerModel, Bool>,
        _ setEnabled: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(get: { model[keyPath: keyPath] }, set: setEnabled)
    }
}

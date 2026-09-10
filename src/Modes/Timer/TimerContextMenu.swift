import SwiftUI

struct TimerContextMenu: View {
    @ObservedObject var model: TimerModel

    var body: some View {
        Toggle("Show value", isOn: enablementBinding(\.showsRemainingMinutes, model.setRemainingMinutesVisible))
    }

    private func enablementBinding(
        _ keyPath: KeyPath<TimerModel, Bool>,
        _ setEnabled: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(get: { model[keyPath: keyPath] }, set: setEnabled)
    }
}

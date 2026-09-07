import SwiftUI

struct CountdownFeatureMenu: View {
    @ObservedObject var features: CountdownFeatures

    var body: some View {
        Toggle("Reminders", isOn: Binding(get: { features.isReminderEnabled }, set: features.setReminderEnabled))
    }
}

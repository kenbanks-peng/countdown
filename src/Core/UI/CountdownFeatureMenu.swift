import SwiftUI

struct CountdownFeatureMenu: View {
    @ObservedObject var features: CountdownFeatures

    var body: some View {
        Toggle("Clock", isOn: Binding(get: { features.isClockEnabled }, set: features.setClockEnabled))
        Toggle("Reminders", isOn: Binding(get: { features.isReminderEnabled }, set: features.setReminderEnabled))
    }
}

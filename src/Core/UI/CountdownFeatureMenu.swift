import SwiftUI

struct CountdownFeatureMenu: View {
    @ObservedObject var features: CountdownFeatures

    var body: some View {
        Toggle("Face", isOn: Binding(get: { features.isClockFaceEnabled }, set: features.setClockFaceEnabled))
        Toggle("Hands", isOn: Binding(get: { features.isClockHandsEnabled }, set: features.setClockHandsEnabled))
        Toggle("Wakeup", isOn: Binding(get: { features.isWakeupEnabled }, set: features.setWakeupEnabled))
    }
}

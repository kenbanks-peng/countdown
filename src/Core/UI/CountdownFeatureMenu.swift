import SwiftUI

struct CountdownFeatureMenu: View {
    @ObservedObject var features: CountdownFeatures

    var body: some View {
        Toggle("Popups", isOn: Binding(get: { features.isPopupEnabled }, set: features.setPopupEnabled))
    }
}

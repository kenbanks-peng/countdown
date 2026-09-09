import Foundation

/// Optional OpenType axis values. Missing values keep the selected font's defaults.
struct NotificationFontVariations: Equatable {
    let weight: Double?
    let width: Double?
    let opticalSize: Double?

    init(weight: Double? = nil, width: Double? = nil, opticalSize: Double? = nil) {
        self.weight = Self.positiveFinite(weight)
        self.width = Self.positiveFinite(width)
        self.opticalSize = Self.positiveFinite(opticalSize)
    }

    private static func positiveFinite(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

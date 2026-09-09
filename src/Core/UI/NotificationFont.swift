import AppKit
import CoreText

/// Applies supported OpenType axes without changing the font's point size.
enum NotificationFont {
    static func make(name: String, size: CGFloat, variations: NotificationFontVariations) -> CTFont {
        let base = name.isEmpty ? nil : NSFont(name: name, size: size)
        let font = base ?? NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        guard let axes = CTFontCopyVariationAxes(font) as? [[String: Any]] else { return font }

        // OpenType tags: wght, wdth, opsz, slnt.
        let requested: [UInt32: Double?] = [
            0x77676874: variations.weight,
            0x77647468: variations.width,
            0x6F70737A: variations.opticalSize,
            0x736C6E74: variations.slant,
        ]
        var values = (CTFontCopyVariation(font) as? [NSNumber: NSNumber]) ?? [:]
        var attributes: [CFString: Any] = [:]
        var changed = false
        for axis in axes {
            guard let identifier = axis[kCTFontVariationAxisIdentifierKey as String] as? NSNumber,
                  let value = requested[identifier.uint32Value] ?? nil,
                  let minimum = axis[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber,
                  let maximum = axis[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber else { continue }
            let clamped = min(maximum.doubleValue, max(minimum.doubleValue, value))
            values[identifier] = NSNumber(value: clamped)
            if identifier.uint32Value == 0x6F70737A {
                attributes[kCTFontOpticalSizeAttribute] = clamped
            }
            changed = true
        }
        guard changed else { return font }
        attributes[kCTFontVariationAttribute] = values
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateCopyWithAttributes(font, size, nil, descriptor)
    }
}

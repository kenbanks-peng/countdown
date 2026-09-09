import AppKit
import CoreText
import Testing
@testable import Countdown

struct NotificationFontTests {
    @Test
    func unspecifiedVariationsKeepSystemFont() {
        let font = NotificationFont.make(name: "", size: 144, variations: NotificationFontVariations())
        let expected = NSFont.monospacedDigitSystemFont(ofSize: 144, weight: .semibold)
        #expect(CFEqual(font, expected))
    }

    @Test
    func systemFontAcceptsWeightWidthAndOpticalSize() throws {
        let font = NotificationFont.make(name: "", size: 144,
                                         variations: NotificationFontVariations(weight: 700, width: 75, opticalSize: 48))
        let values = try #require(CTFontCopyVariation(font) as? [NSNumber: NSNumber])
        #expect(values[0x77676874]?.doubleValue == 700)
        #expect(values[0x77647468]?.doubleValue == 75)
        #expect(values[0x6F70737A]?.doubleValue == 48)
        #expect(CTFontGetSize(font) == 144)
    }

    @Test(arguments: [0.01, 1e10])
    func valuesAreLimitedToSupportedRanges(value: Double) throws {
        let base = NSFont.monospacedDigitSystemFont(ofSize: 144, weight: .semibold)
        let axes = try #require(CTFontCopyVariationAxes(base) as? [[String: Any]])
        let font = NotificationFont.make(name: "", size: 144,
                                         variations: NotificationFontVariations(weight: value, width: value, opticalSize: value))
        let values = try #require(CTFontCopyVariation(font) as? [NSNumber: NSNumber])
        for tag: NSNumber in [0x77676874, 0x77647468, 0x6F70737A] {
            let axis = try #require(axes.first { ($0[kCTFontVariationAxisIdentifierKey as String] as? NSNumber) == tag })
            let minimum = try #require(axis[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber)
            let maximum = try #require(axis[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber)
            #expect(values[tag]?.doubleValue == min(maximum.doubleValue, max(minimum.doubleValue, value)))
        }
    }

    @Test
    func widthOverrideKeepsOtherAxesAndDigitFeatures() throws {
        let base = NSFont.monospacedDigitSystemFont(ofSize: 144, weight: .semibold)
        let font = NotificationFont.make(name: "", size: 144, variations: NotificationFontVariations(width: 75))
        let original = try #require(CTFontCopyVariation(base) as? [NSNumber: NSNumber])
        let values = try #require(CTFontCopyVariation(font) as? [NSNumber: NSNumber])
        #expect(values[0x77676874] == original[0x77676874])
        #expect(values[0x6F70737A] == original[0x6F70737A])
        #expect(CTFontCopyFeatureSettings(font) as NSArray? == CTFontCopyFeatureSettings(base) as NSArray?)
    }

    @Test
    func staticFontIgnoresUnsupportedAxes() throws {
        let base = try #require(NSFont(name: "Impact", size: 144))
        let font = NotificationFont.make(name: "Impact", size: 144,
                                         variations: NotificationFontVariations(weight: 700, width: 75, opticalSize: 48))
        #expect(CFEqual(font, base))
    }

    @Test
    func missingFontFallsBackToSystemWithVariations() {
        let variations = NotificationFontVariations(weight: 700, width: 75)
        let font = NotificationFont.make(name: "Countdown-Nonexistent-Font", size: 144, variations: variations)
        let expected = NotificationFont.make(name: "", size: 144, variations: variations)
        #expect(CFEqual(font, expected))
    }
}

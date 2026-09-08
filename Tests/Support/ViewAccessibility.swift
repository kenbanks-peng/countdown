import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
func pressTimer(_ element: Any, labelPrefix: String) -> Bool {
    if let element = element as? NSAccessibilityProtocol {
        if element.accessibilityLabel()?.hasPrefix(labelPrefix) == true {
            return element.accessibilityPerformPress()
        }
        return (element.accessibilityChildren() ?? []).contains { pressTimer($0, labelPrefix: labelPrefix) }
    }
    guard let element = element as? NSObject else { return false }
    let label = element.accessibilityAttributeValue(.description) as? String
        ?? (element.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXAttributedDescription")) as? NSAttributedString)?.string
    let press = NSSelectorFromString("accessibilityPerformPress")
    if label?.hasPrefix(labelPrefix) == true, element.responds(to: press) {
        // SwiftUI exposes the public AppKit action without declaring
        // NSAccessibilityProtocol conformance. Keep its BOOL return type.
        let action = unsafeBitCast(element.method(for: press), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return action(element, press)
    }
    return (element.accessibilityAttributeValue(.children) as? [Any] ?? []).contains { pressTimer($0, labelPrefix: labelPrefix) }
}

@MainActor
func accessibilityLabels(_ element: Any) -> [String] {
    if let element = element as? NSAccessibilityProtocol {
        let label = element.accessibilityLabel().map { [$0] } ?? []
        return label + (element.accessibilityChildren() ?? []).flatMap(accessibilityLabels)
    }
    guard let element = element as? NSObject else { return [] }
    // SwiftUI nodes use the informal AppKit accessibility API.
    let label = element.accessibilityAttributeValue(.description) as? String
        ?? (element.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXAttributedDescription")) as? NSAttributedString)?.string
    let children = element.accessibilityAttributeValue(.children) as? [Any] ?? []
    return (label.map { [$0] } ?? []) + children.flatMap(accessibilityLabels)
}

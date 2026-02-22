import SwiftUI
import XCTest
@testable import WhisperNotesLib

final class ColorExtensionTests: XCTestCase {
    func testHexWithHash() {
        let color = Color(hex: "#FF0000")
        _ = color // No crash = success
    }

    func testHexWithoutHash() {
        let color = Color(hex: "00FF00")
        _ = color
    }

    func testShortHexDoesNotCrash() {
        let color = Color(hex: "FFF")
        _ = color
    }

    func testEmptyStringDoesNotCrash() {
        let color = Color(hex: "")
        _ = color
    }

    func testAllPresetColorsParseWithoutCrash() {
        for hex in Tag.presetColors {
            _ = Color(hex: hex)
        }
    }
}

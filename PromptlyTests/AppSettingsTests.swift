import XCTest
import SwiftUI
@testable import Promptly

final class AppSettingsTests: XCTestCase {

    func testDefaults() {
        let settings = AppSettings.defaults

        XCTAssertEqual(settings.fontSize, 32)
        XCTAssertEqual(settings.textColor, "#FFFFFF")
        XCTAssertEqual(settings.backgroundColor, "#000000")
        XCTAssertEqual(settings.backgroundOpacity, 0.85)
        XCTAssertEqual(settings.scrollSpeed, 1.0)
        XCTAssertEqual(settings.micSensitivity, -30.0)
        XCTAssertEqual(settings.countdownSeconds, .three)
        XCTAssertEqual(settings.preferredMode, .notch)
        XCTAssertTrue(settings.showSpeedIndicator)
        XCTAssertTrue(settings.showProgressIndicator)
        XCTAssertNil(settings.floatingWindowX)
        XCTAssertNil(settings.floatingWindowY)
        XCTAssertNil(settings.floatingWindowWidth)
        XCTAssertNil(settings.floatingWindowHeight)
    }

    func testCustomInitialization() {
        let settings = AppSettings(
            fontSize: 48,
            textColor: "#FF0000",
            backgroundColor: "#0000FF",
            backgroundOpacity: 0.5,
            scrollSpeed: 2.0,
            micSensitivity: -40.0,
            countdownSeconds: .five,
            preferredMode: .floating,
            showSpeedIndicator: false,
            showProgressIndicator: false,
            floatingWindowX: 100,
            floatingWindowY: 200,
            floatingWindowWidth: 600,
            floatingWindowHeight: 150
        )

        XCTAssertEqual(settings.fontSize, 48)
        XCTAssertEqual(settings.textColor, "#FF0000")
        XCTAssertEqual(settings.backgroundColor, "#0000FF")
        XCTAssertEqual(settings.backgroundOpacity, 0.5)
        XCTAssertEqual(settings.scrollSpeed, 2.0)
        XCTAssertEqual(settings.micSensitivity, -40.0)
        XCTAssertEqual(settings.countdownSeconds, .five)
        XCTAssertEqual(settings.preferredMode, .floating)
        XCTAssertFalse(settings.showSpeedIndicator)
        XCTAssertFalse(settings.showProgressIndicator)
        XCTAssertEqual(settings.floatingWindowX, 100)
        XCTAssertEqual(settings.floatingWindowY, 200)
        XCTAssertEqual(settings.floatingWindowWidth, 600)
        XCTAssertEqual(settings.floatingWindowHeight, 150)
    }

    func testCodable() throws {
        let original = AppSettings(
            fontSize: 36,
            textColor: "#00FF00",
            backgroundColor: "#333333",
            backgroundOpacity: 0.9,
            scrollSpeed: 1.5,
            micSensitivity: -25.0,
            countdownSeconds: .ten,
            preferredMode: .floating,
            showSpeedIndicator: true,
            showProgressIndicator: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testHexToColor() {
        // White
        let white = AppSettings.color(from: "#FFFFFF")
        XCTAssertNotNil(white.cgColor)

        // Black
        let black = AppSettings.color(from: "#000000")
        XCTAssertNotNil(black.cgColor)

        // Red
        let red = AppSettings.color(from: "#FF0000")
        XCTAssertNotNil(red.cgColor)

        // Without hash
        let green = AppSettings.color(from: "00FF00")
        XCTAssertNotNil(green.cgColor)
    }

    func testColorToHex() {
        let hex = AppSettings.hexString(from: Color.white)
        XCTAssertTrue(hex.hasPrefix("#"))
        XCTAssertEqual(hex.count, 7)
    }

    func testSwiftUIColorAccessors() {
        let settings = AppSettings(
            textColor: "#FF0000",
            backgroundColor: "#0000FF"
        )

        // Just verify we can access the colors without crashing
        _ = settings.textSwiftUIColor
        _ = settings.backgroundSwiftUIColor
    }

    func testPrompterModeRawValues() {
        XCTAssertEqual(PrompterMode.notch.rawValue, "notch")
        XCTAssertEqual(PrompterMode.floating.rawValue, "floating")
    }

    func testPrompterModeDisplayNames() {
        XCTAssertEqual(PrompterMode.notch.displayName, "Notch Mode")
        XCTAssertEqual(PrompterMode.floating.displayName, "Floating Mode")
    }

    func testCountdownDurationRawValues() {
        XCTAssertEqual(CountdownDuration.three.rawValue, 3)
        XCTAssertEqual(CountdownDuration.five.rawValue, 5)
        XCTAssertEqual(CountdownDuration.ten.rawValue, 10)
    }

    func testCountdownDurationDisplayNames() {
        XCTAssertEqual(CountdownDuration.three.displayName, "3 seconds")
        XCTAssertEqual(CountdownDuration.five.displayName, "5 seconds")
        XCTAssertEqual(CountdownDuration.ten.displayName, "10 seconds")
    }

    func testEquality() {
        let settings1 = AppSettings.defaults
        let settings2 = AppSettings.defaults
        let settings3 = AppSettings(fontSize: 48)

        XCTAssertEqual(settings1, settings2)
        XCTAssertNotEqual(settings1, settings3)
    }

    func testHexParsingFormats() {
        // 6 character hex
        _ = AppSettings.color(from: "#AABBCC")

        // 8 character hex (with alpha)
        _ = AppSettings.color(from: "#AABBCCDD")

        // Without hash
        _ = AppSettings.color(from: "AABBCC")

        // Invalid length returns white
        let invalid = AppSettings.color(from: "#ABC")
        XCTAssertNotNil(invalid.cgColor)
    }
}

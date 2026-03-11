import XCTest
import AppKit
@testable import Promptly

@MainActor
final class SettingsManagerTests: XCTestCase {

    private func createTestManager() -> SettingsManager {
        SettingsManager.forTesting()
    }

    func testInitialSettings() {
        let manager = createTestManager()

        XCTAssertEqual(manager.settings, AppSettings.defaults)
    }

    func testSettingsPersistence() {
        let suiteName = "com.promptly.test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Create manager and change settings
        let manager = SettingsManager(userDefaults: defaults)
        manager.fontSize = 48
        manager.scrollSpeed = 2.0

        // Create new manager with same defaults
        let newManager = SettingsManager(userDefaults: defaults)

        XCTAssertEqual(newManager.fontSize, 48)
        XCTAssertEqual(newManager.scrollSpeed, 2.0)
    }

    func testFontSizeAccessor() {
        let manager = createTestManager()

        manager.fontSize = 36
        XCTAssertEqual(manager.fontSize, 36)
        XCTAssertEqual(manager.settings.fontSize, 36)
    }

    func testScrollSpeedAccessor() {
        let manager = createTestManager()

        manager.scrollSpeed = 1.75
        XCTAssertEqual(manager.scrollSpeed, 1.75)
        XCTAssertEqual(manager.settings.scrollSpeed, 1.75)
    }

    func testMicSensitivityAccessor() {
        let manager = createTestManager()

        manager.micSensitivity = -40.0
        XCTAssertEqual(manager.micSensitivity, -40.0)
        XCTAssertEqual(manager.settings.micSensitivity, -40.0)
    }

    func testBackgroundOpacityAccessor() {
        let manager = createTestManager()

        manager.backgroundOpacity = 0.75
        XCTAssertEqual(manager.backgroundOpacity, 0.75)
        XCTAssertEqual(manager.settings.backgroundOpacity, 0.75)
    }

    func testCountdownSecondsAccessor() {
        let manager = createTestManager()

        manager.countdownSeconds = .five
        XCTAssertEqual(manager.countdownSeconds, .five)
        XCTAssertEqual(manager.settings.countdownSeconds, .five)
    }

    func testPreferredModeAccessor() {
        let manager = createTestManager()

        manager.preferredMode = .floating
        XCTAssertEqual(manager.preferredMode, .floating)
        XCTAssertEqual(manager.settings.preferredMode, .floating)
    }

    func testShowSpeedIndicatorAccessor() {
        let manager = createTestManager()

        manager.showSpeedIndicator = false
        XCTAssertFalse(manager.showSpeedIndicator)
        XCTAssertFalse(manager.settings.showSpeedIndicator)
    }

    func testShowProgressIndicatorAccessor() {
        let manager = createTestManager()

        manager.showProgressIndicator = false
        XCTAssertFalse(manager.showProgressIndicator)
        XCTAssertFalse(manager.settings.showProgressIndicator)
    }

    func testResetToDefaults() {
        let manager = createTestManager()

        // Change some settings
        manager.fontSize = 48
        manager.scrollSpeed = 2.5
        manager.preferredMode = .floating

        // Reset
        manager.resetToDefaults()

        XCTAssertEqual(manager.settings, AppSettings.defaults)
    }

    func testSaveFloatingWindowFrame() {
        let manager = createTestManager()

        let frame = NSRect(x: 100, y: 200, width: 600, height: 150)
        manager.saveFloatingWindowFrame(frame)

        XCTAssertEqual(manager.settings.floatingWindowX, 100)
        XCTAssertEqual(manager.settings.floatingWindowY, 200)
        XCTAssertEqual(manager.settings.floatingWindowWidth, 600)
        XCTAssertEqual(manager.settings.floatingWindowHeight, 150)
    }

    func testSavedFloatingWindowFrame() {
        let manager = createTestManager()

        XCTAssertNil(manager.savedFloatingWindowFrame)

        let frame = NSRect(x: 100, y: 200, width: 600, height: 150)
        manager.saveFloatingWindowFrame(frame)

        let saved = manager.savedFloatingWindowFrame
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.origin.x, 100)
        XCTAssertEqual(saved?.origin.y, 200)
        XCTAssertEqual(saved?.width, 600)
        XCTAssertEqual(saved?.height, 150)
    }

    func testClearFloatingWindowFrame() {
        let manager = createTestManager()

        let frame = NSRect(x: 100, y: 200, width: 600, height: 150)
        manager.saveFloatingWindowFrame(frame)
        XCTAssertNotNil(manager.savedFloatingWindowFrame)

        manager.clearFloatingWindowFrame()

        XCTAssertNil(manager.savedFloatingWindowFrame)
    }

    func testForTestingFactory() {
        let manager1 = SettingsManager.forTesting()
        let manager2 = SettingsManager.forTesting()

        manager1.fontSize = 48

        // Changes to one shouldn't affect the other
        XCTAssertEqual(manager2.fontSize, AppSettings.defaults.fontSize)
    }

    func testSettingsUpdateTriggersSave() {
        let suiteName = "com.promptly.test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = SettingsManager(userDefaults: defaults)

        // Modify settings
        manager.fontSize = 64

        // Verify data was saved
        let data = defaults.data(forKey: "com.promptly.settings")
        XCTAssertNotNil(data)

        if let data = data {
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
            XCTAssertEqual(decoded?.fontSize, 64)
        }
    }
}

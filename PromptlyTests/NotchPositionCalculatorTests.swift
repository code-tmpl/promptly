import XCTest
import AppKit
@testable import Promptly

final class NotchPositionCalculatorTests: XCTestCase {

    func testDefaultWindowHeight() {
        // 220px provides 3-5 lines of text at typical font sizes (was 80px showing only 1 line)
        XCTAssertEqual(NotchPositionCalculator.defaultWindowHeight, 220)
    }

    func testMinimumWindowHeight() {
        XCTAssertEqual(NotchPositionCalculator.minimumWindowHeight, 40)
    }

    func testMaximumWindowHeight() {
        XCTAssertEqual(NotchPositionCalculator.maximumWindowHeight, 300)
    }

    func testDefaultFloatingDimensions() {
        XCTAssertEqual(NotchPositionCalculator.defaultFloatingWidth, 600)
        XCTAssertEqual(NotchPositionCalculator.defaultFloatingHeight, 150)
    }

    @MainActor
    func testCalculateNotchFrameWidth() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let frame = NotchPositionCalculator.calculateNotchFrame(for: screen)

        XCTAssertEqual(frame.width, screen.frame.width)
    }

    @MainActor
    func testCalculateNotchFrameCustomHeight() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let customHeight: CGFloat = 100
        let frame = NotchPositionCalculator.calculateNotchFrame(for: screen, height: customHeight)

        XCTAssertEqual(frame.height, customHeight)
    }

    @MainActor
    func testCalculateNotchFramePosition() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let frame = NotchPositionCalculator.calculateNotchFrame(for: screen)

        // Frame should be near the top of the screen
        let screenTop = screen.frame.origin.y + screen.frame.height
        XCTAssertLessThanOrEqual(frame.origin.y + frame.height, screenTop)
    }

    func testDefaultFloatingFrameCentered() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let frame = NotchPositionCalculator.calculateDefaultFloatingFrame(for: screen)
        let screenFrame = screen.visibleFrame

        let expectedX = screenFrame.origin.x + (screenFrame.width - NotchPositionCalculator.defaultFloatingWidth) / 2

        XCTAssertEqual(frame.origin.x, expectedX, accuracy: 1)
    }

    func testDefaultFloatingFrameDimensions() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let frame = NotchPositionCalculator.calculateDefaultFloatingFrame(for: screen)

        XCTAssertEqual(frame.width, NotchPositionCalculator.defaultFloatingWidth)
        XCTAssertEqual(frame.height, NotchPositionCalculator.defaultFloatingHeight)
    }

    func testConstrainFrameMinWidth() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let tooSmall = NSRect(x: 0, y: 0, width: 100, height: 80)
        let constrained = NotchPositionCalculator.constrainFrame(tooSmall, to: screen)

        XCTAssertGreaterThanOrEqual(constrained.width, 200)
    }

    func testConstrainFrameMinHeight() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let tooSmall = NSRect(x: 0, y: 0, width: 400, height: 20)
        let constrained = NotchPositionCalculator.constrainFrame(tooSmall, to: screen)

        XCTAssertGreaterThanOrEqual(constrained.height, NotchPositionCalculator.minimumWindowHeight)
    }

    func testConstrainFrameMaxHeight() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let tooLarge = NSRect(x: 0, y: 0, width: 400, height: 500)
        let constrained = NotchPositionCalculator.constrainFrame(tooLarge, to: screen)

        XCTAssertLessThanOrEqual(constrained.height, NotchPositionCalculator.maximumWindowHeight)
    }

    func testConstrainFrameRightEdge() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let screenFrame = screen.visibleFrame
        let offRight = NSRect(x: screenFrame.maxX + 100, y: screenFrame.midY, width: 400, height: 80)
        let constrained = NotchPositionCalculator.constrainFrame(offRight, to: screen)

        XCTAssertLessThanOrEqual(constrained.maxX, screenFrame.maxX)
    }

    func testConstrainFrameLeftEdge() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let screenFrame = screen.visibleFrame
        let offLeft = NSRect(x: screenFrame.origin.x - 500, y: screenFrame.midY, width: 400, height: 80)
        let constrained = NotchPositionCalculator.constrainFrame(offLeft, to: screen)

        XCTAssertGreaterThanOrEqual(constrained.origin.x, screenFrame.origin.x)
    }

    func testConstrainFrameBottomEdge() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let screenFrame = screen.visibleFrame
        let offBottom = NSRect(x: screenFrame.midX, y: screenFrame.origin.y - 100, width: 400, height: 80)
        let constrained = NotchPositionCalculator.constrainFrame(offBottom, to: screen)

        XCTAssertGreaterThanOrEqual(constrained.origin.y, screenFrame.origin.y)
    }

    func testConstrainFrameTopEdge() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        let screenFrame = screen.visibleFrame
        let offTop = NSRect(x: screenFrame.midX, y: screenFrame.maxY + 100, width: 400, height: 80)
        let constrained = NotchPositionCalculator.constrainFrame(offTop, to: screen)

        XCTAssertLessThanOrEqual(constrained.maxY, screenFrame.maxY)
    }

    @MainActor
    func testTextRegionsNonNotch() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        // If screen doesn't have notch, should return single region
        if !NotchPositionCalculator.hasNotch(screen) {
            let regions = NotchPositionCalculator.textRegions(for: screen)
            XCTAssertEqual(regions.count, 1)
        }
    }

    func testCameraScreen() {
        let cameraScreen = NSScreen.cameraScreen

        // Should return main screen or first available
        XCTAssertTrue(cameraScreen != nil || NSScreen.screens.isEmpty)
    }

    func testNSScreenHasNotchExtension() {
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }

        // Just verify the extension works without crashing
        _ = screen.hasNotch
    }
}

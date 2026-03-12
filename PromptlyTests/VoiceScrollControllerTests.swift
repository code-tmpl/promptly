import XCTest
@testable import Promptly

@MainActor
final class VoiceScrollControllerTests: XCTestCase {

    func testInitialState() {
        let controller = VoiceScrollController()

        XCTAssertEqual(controller.scrollOffset, 0)
        XCTAssertFalse(controller.isScrolling)
        XCTAssertEqual(controller.speed, 1.0)
        XCTAssertFalse(controller.isPaused)
    }

    func testManualScroll() {
        let controller = VoiceScrollController()

        controller.manualScroll(delta: 100)
        XCTAssertEqual(controller.scrollOffset, 100)

        controller.manualScroll(delta: 50)
        XCTAssertEqual(controller.scrollOffset, 150)
    }

    func testManualScrollNoNegative() {
        let controller = VoiceScrollController()

        controller.manualScroll(delta: 50)
        controller.manualScroll(delta: -100)

        XCTAssertEqual(controller.scrollOffset, 0)
    }

    func testAdjustSpeed() {
        let controller = VoiceScrollController()

        controller.adjustSpeed(by: 0.5)
        XCTAssertEqual(controller.speed, 1.5)

        controller.adjustSpeed(by: -0.5)
        XCTAssertEqual(controller.speed, 1.0)
    }

    func testSpeedMinimum() {
        let controller = VoiceScrollController()

        controller.adjustSpeed(by: -10.0)

        XCTAssertEqual(controller.speed, 0.25)
    }

    func testSpeedMaximum() {
        let controller = VoiceScrollController()

        controller.adjustSpeed(by: 10.0)

        XCTAssertEqual(controller.speed, 3.0)
    }

    func testReset() {
        let controller = VoiceScrollController()

        controller.manualScroll(delta: 500)
        XCTAssertEqual(controller.scrollOffset, 500)

        controller.reset()
        XCTAssertEqual(controller.scrollOffset, 0)
    }

    func testSetScrollOffset() {
        let controller = VoiceScrollController()

        controller.setScrollOffset(250)
        XCTAssertEqual(controller.scrollOffset, 250)

        controller.setScrollOffset(-50)
        XCTAssertEqual(controller.scrollOffset, 0)
    }

    func testSimulateSpeakingStartsScrolling() {
        let controller = VoiceScrollController()

        controller.simulateSpeaking(true)

        XCTAssertTrue(controller.isScrolling)
    }

    func testSimulateSpeakingStopsScrolling() {
        let controller = VoiceScrollController()

        controller.simulateSpeaking(true)
        XCTAssertTrue(controller.isScrolling)

        controller.simulateSpeaking(false)
        XCTAssertFalse(controller.isScrolling)
    }

    func testPausePreventsScrolling() {
        let controller = VoiceScrollController()

        controller.simulateSpeaking(true)
        XCTAssertTrue(controller.isScrolling)

        controller.isPaused = true
        XCTAssertFalse(controller.isScrolling)
    }

    func testAdvanceFrame() {
        let controller = VoiceScrollController()

        // Default: baseScrollRate = 50, speed = 1.0, deltaTime = 1/60
        controller.advanceFrame(deltaTime: 1.0 / 60.0)

        let expectedScroll = 50.0 * 1.0 * (1.0 / 60.0)
        XCTAssertEqual(controller.scrollOffset, expectedScroll, accuracy: 0.01)
    }

    func testAdvanceFrameRespectsSpeed() {
        let controller = VoiceScrollController()
        controller.speed = 2.0

        controller.advanceFrame(deltaTime: 1.0 / 60.0)

        let expectedScroll = 50.0 * 2.0 * (1.0 / 60.0)
        XCTAssertEqual(controller.scrollOffset, expectedScroll, accuracy: 0.01)
    }

    func testAdvanceFrameWhenPaused() {
        let controller = VoiceScrollController()
        controller.isPaused = true

        controller.advanceFrame(deltaTime: 1.0 / 60.0)

        XCTAssertEqual(controller.scrollOffset, 0)
    }

    func testBaseScrollRate() {
        let controller = VoiceScrollController()
        controller.baseScrollRate = 100

        controller.advanceFrame(deltaTime: 1.0)

        XCTAssertEqual(controller.scrollOffset, 100)
    }

    func testStopClearsCancellables() {
        let controller = VoiceScrollController()

        controller.simulateSpeaking(true)
        controller.stop()

        XCTAssertFalse(controller.isScrolling)
    }

    func testMultipleFrameAdvances() {
        let controller = VoiceScrollController()
        controller.baseScrollRate = 60
        controller.speed = 1.0

        // 60 frames at 1/60 second each = 1 second = 60 points at rate 60
        for _ in 0..<60 {
            controller.advanceFrame(deltaTime: 1.0 / 60.0)
        }

        XCTAssertEqual(controller.scrollOffset, 60.0, accuracy: 1.0)
    }

    // MARK: - Integration Tests

    func testRealScrollTimerIntegration() async throws {
        let controller = VoiceScrollController()
        controller.baseScrollRate = 100  // Use higher rate for visible movement

        // Start speaking — this triggers startScrolling() which sets up
        // CVDisplayLink or fallback Timer for 60fps scroll updates
        controller.simulateSpeaking(true)

        XCTAssertTrue(controller.isScrolling, "Should be scrolling after simulateSpeaking(true)")
        XCTAssertEqual(controller.scrollOffset, 0, "Scroll offset should start at 0")

        // Wait long enough for at least a few frame callbacks to fire (150ms ~ 9 frames at 60fps)
        try await Task.sleep(for: .milliseconds(150))

        // The real timer/display link path should have produced actual scroll movement
        XCTAssertGreaterThan(controller.scrollOffset, 0,
                             "Scroll offset should be > 0 after real timer/display link fires")

        // Cleanup
        controller.simulateSpeaking(false)
        XCTAssertFalse(controller.isScrolling, "Should stop scrolling after simulateSpeaking(false)")
    }
}

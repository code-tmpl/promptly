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

    func testStartBeginsScrolling() {
        let controller = VoiceScrollController()

        controller.start()

        XCTAssertTrue(controller.isScrolling,
                      "start() should begin scrolling immediately")
    }

    func testStopEndsScrolling() {
        let controller = VoiceScrollController()

        controller.start()
        XCTAssertTrue(controller.isScrolling)

        controller.stop()
        XCTAssertFalse(controller.isScrolling,
                       "stop() should end scrolling")
    }

    func testVoiceModulatesSpeedNotScrollState() {
        let controller = VoiceScrollController()

        // Start scrolling first
        controller.start()
        XCTAssertTrue(controller.isScrolling)

        // Simulate speaking - should NOT change isScrolling, just modulate speed
        controller.simulateSpeaking(true)
        XCTAssertTrue(controller.isScrolling,
                      "Speaking should not change scroll state")

        // Simulate silence - scrolling should continue (voice modulates speed, not start/stop)
        controller.simulateSpeaking(false)
        XCTAssertTrue(controller.isScrolling,
                      "Silence should not stop scrolling (voice modulates speed)")
    }

    func testPausePreventsScrolling() {
        let controller = VoiceScrollController()

        controller.start()
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

        controller.start()
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

        // start() triggers scrolling immediately (no need for simulateSpeaking)
        controller.start()

        XCTAssertTrue(controller.isScrolling, "Should be scrolling after start()")
        XCTAssertEqual(controller.scrollOffset, 0, "Scroll offset should start at 0")

        // Wait long enough for at least a few frame callbacks to fire (150ms ~ 9 frames at 60fps)
        try await Task.sleep(for: .milliseconds(150))

        // The real timer/display link path should have produced actual scroll movement
        XCTAssertGreaterThan(controller.scrollOffset, 0,
                             "Scroll offset should be > 0 after real timer/display link fires")

        // Cleanup
        controller.stop()
        XCTAssertFalse(controller.isScrolling, "Should stop scrolling after stop()")
    }

    func testVoiceModulatesScrollSpeed() async throws {
        let controller = VoiceScrollController()
        controller.baseScrollRate = 100
        controller.speakingSpeedMultiplier = 2.0  // 2x speed when speaking
        controller.silentSpeedMultiplier = 0.5    // 0.5x speed when silent
        controller.silenceGracePeriod = 0.1       // Short grace period for testing

        // Start scrolling
        controller.start()

        // Record initial scroll position
        let initialOffset = controller.scrollOffset

        // Simulate speaking (should use speakingSpeedMultiplier)
        controller.simulateSpeaking(true)

        // Wait for some scrolling
        try await Task.sleep(for: .milliseconds(100))
        let speakingOffset = controller.scrollOffset
        let speakingDelta = speakingOffset - initialOffset

        XCTAssertGreaterThan(speakingDelta, 0, "Should have scrolled while speaking")

        // Reset and test silent speed
        controller.reset()
        controller.simulateSpeaking(false)

        // Wait for grace period to expire
        try await Task.sleep(for: .milliseconds(200))

        // Record position after grace period
        let afterGraceOffset = controller.scrollOffset

        // Wait for more scrolling at silent speed
        try await Task.sleep(for: .milliseconds(100))
        let silentOffset = controller.scrollOffset
        let silentDelta = silentOffset - afterGraceOffset

        XCTAssertGreaterThan(silentDelta, 0, "Should still scroll when silent (just slower)")

        // Silent delta should be significantly less than speaking delta
        // (accounting for timing variations, we just check it's slower)
        XCTAssertLessThan(silentDelta, speakingDelta,
                          "Silent scrolling should be slower than speaking scrolling")

        controller.stop()
    }
}

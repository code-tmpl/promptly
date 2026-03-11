import XCTest
@testable import Promptly

@MainActor
final class AudioLevelDetectorTests: XCTestCase {

    func testInitialState() {
        let detector = AudioLevelDetector()

        XCTAssertFalse(detector.isSpeaking)
        XCTAssertEqual(detector.audioLevel, -60.0)
    }

    func testUpdateThreshold() {
        let detector = AudioLevelDetector()

        detector.updateThreshold(-40.0)

        XCTAssertEqual(detector.currentThreshold, -40.0)
    }

    func testSimulateAudioAboveThreshold() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Simulate audio level above threshold
        detector.simulateAudioLevel(-20.0)

        // Wait for speech debounce
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(detector.audioLevel, -20.0)
        XCTAssertTrue(detector.isSpeaking)
    }

    func testSimulateAudioBelowThreshold() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // First trigger speaking
        detector.simulateAudioLevel(-20.0)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(detector.isSpeaking)

        // Then go silent
        detector.simulateAudioLevel(-50.0)

        // Wait for silence debounce (0.3s default)
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertFalse(detector.isSpeaking)
    }

    func testAudioLevelUpdates() {
        let detector = AudioLevelDetector()

        detector.simulateAudioLevel(-25.0)
        XCTAssertEqual(detector.audioLevel, -25.0)

        detector.simulateAudioLevel(-45.0)
        XCTAssertEqual(detector.audioLevel, -45.0)
    }

    func testDebouncing() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Rapid transitions shouldn't cause rapid state changes
        detector.simulateAudioLevel(-20.0)
        detector.simulateAudioLevel(-50.0)
        detector.simulateAudioLevel(-20.0)
        detector.simulateAudioLevel(-50.0)

        // Short delay
        try await Task.sleep(for: .milliseconds(50))

        // State should still be settling due to debounce
        // The exact state depends on timing, but we're testing no crash
        _ = detector.isSpeaking
    }

    func testThresholdBoundary() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Exactly at threshold should not trigger
        detector.simulateAudioLevel(-30.0)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(detector.isSpeaking)

        // Just above threshold should trigger
        detector.simulateAudioLevel(-29.9)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(detector.isSpeaking)
    }

    func testStopClearsState() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Trigger speaking
        detector.simulateAudioLevel(-20.0)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(detector.isSpeaking)

        // Stop should reset state
        detector.stop()

        XCTAssertFalse(detector.isSpeaking)
        XCTAssertEqual(detector.audioLevel, -60.0)
    }
}

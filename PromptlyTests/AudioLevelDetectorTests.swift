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

    func testDebouncePreventsImmediateSpeaking() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Single above-threshold sample should NOT immediately set isSpeaking
        // because of the speechDebounceInterval (0.05s)
        detector.simulateAudioLevel(-20.0)

        // Immediately after — debounce hasn't fired yet
        XCTAssertFalse(detector.isSpeaking,
                       "Should not be speaking immediately — debounce hasn't elapsed")

        // After debounce interval, it should be speaking
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(detector.isSpeaking,
                      "Should be speaking after debounce interval with sustained audio")
    }

    func testRapidTransitionsDoNotCrash() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Rapid above/below transitions — the main assertion is no crash
        // The debounce timers must handle rapid invalidation safely
        for _ in 0..<10 {
            detector.simulateAudioLevel(-20.0) // above
            detector.simulateAudioLevel(-50.0) // below
        }

        // Wait for all debounce timers to settle
        try await Task.sleep(for: .milliseconds(500))

        // After rapid transitions ending below threshold, stop should work cleanly
        detector.stop()
        XCTAssertFalse(detector.isSpeaking)
        XCTAssertEqual(detector.audioLevel, -60.0)
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

    // MARK: - Integration Tests

    func testEngineStartStopIntegration() throws {
        let detector = AudioLevelDetector()

        // Attempt to start — may fail if no mic permission in CI environment
        do {
            try detector.start()
        } catch {
            // Skip if start() throws (no mic permission or no input device)
            throw XCTSkip("Audio engine start failed (likely no mic permission): \(error)")
        }

        // If start() returned without throwing but engine isn't running,
        // it means permission was not yet determined (async request pending) — skip
        try XCTSkipUnless(detector.isEngineRunning,
                          "Audio engine not running (permission pending or no hardware)")

        XCTAssertTrue(detector.isEngineRunning, "Engine should be running after start()")

        detector.stop()

        XCTAssertFalse(detector.isEngineRunning, "Engine should not be running after stop()")
    }
}

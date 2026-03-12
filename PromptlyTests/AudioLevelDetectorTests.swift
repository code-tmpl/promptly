import XCTest
import AVFoundation
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

    // MARK: - Regression Tests

    /// Regression test for BUG-001: Swift 6 actor isolation crash in audio tap handler.
    ///
    /// The original bug: Swift 6 strict concurrency (SE-0423) infers closures defined
    /// inside @MainActor methods as @MainActor-isolated. The compiler inserted a
    /// runtime isolation assertion into the installTap callback thunk. When Core Audio
    /// invoked the callback on its realtime thread, the assertion failed with:
    ///   _dispatch_assert_queue_fail → swift_task_checkIsolatedSwift
    ///
    /// The fix: Extract the tap handler into a `nonisolated static func makeTapHandler`
    /// so the returned closure has NO actor isolation.
    ///
    /// This test verifies the fix by:
    /// 1. Creating the tap handler via the public test hook
    /// 2. Invoking it from a background queue (simulating Core Audio's realtime thread)
    /// 3. Asserting no crash occurs and audio levels are processed correctly
    func testTapHandlerCanBeInvokedFromBackgroundThread() async throws {
        let detector = AudioLevelDetector()
        detector.updateThreshold(-30.0)

        // Create the tap handler — this is the nonisolated static func path
        let tapHandler = detector.createTapHandlerForTesting()

        // Create a test audio buffer with known signal level
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to create test audio buffer")
            return
        }
        buffer.frameLength = 1024

        // Fill buffer with a sine wave that produces ~-20dB (above threshold)
        // RMS of 0.1 ≈ -20dB, so amplitude of ~0.14 gives us that
        let amplitude: Float = 0.14
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                let phase = Float(frame) / Float(buffer.frameLength) * 2 * .pi * 10
                channelData[0][frame] = amplitude * sin(phase)
            }
        }

        // Create a mock AVAudioTime (not used by handler, but required by signature)
        let audioTime = AVAudioTime(sampleTime: 0, atRate: 44100)

        // Expectation: the handler will bounce the level to main thread, updating audioLevel
        let levelUpdated = expectation(description: "Audio level should be updated")

        // Start observing audio level changes
        let observationTask = Task { @MainActor in
            // Poll for audio level change (bridge.send uses DispatchQueue.main.async)
            for _ in 0..<50 {  // 50 iterations * 20ms = 1 second max
                if detector.audioLevel > -60.0 {
                    levelUpdated.fulfill()
                    return
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        // KEY TEST: Invoke the tap handler from a BACKGROUND thread.
        // If the original bug were present (@MainActor closure), this would crash with:
        //   _dispatch_assert_queue_fail at the thunk entry point
        DispatchQueue.global(qos: .userInteractive).async {
            // This simulates Core Audio's realtime thread calling the installTap callback
            tapHandler(buffer, audioTime)
        }

        // Wait for the audio level to propagate through the bridge to main thread
        await fulfillment(of: [levelUpdated], timeout: 2.0)

        // Cancel observation task
        observationTask.cancel()

        // Verify the audio level was actually processed
        // The sine wave at amplitude 0.14 should produce roughly -17 to -20 dB
        XCTAssertGreaterThan(detector.audioLevel, -25.0,
                             "Audio level should reflect the test signal (~-20dB)")
        XCTAssertLessThan(detector.audioLevel, -10.0,
                          "Audio level should be reasonable for test signal")

        // If we got here without crashing, the nonisolated fix is working!
    }

    /// Additional regression test: verify multiple rapid invocations from background thread
    func testTapHandlerMultipleBackgroundInvocations() async throws {
        let detector = AudioLevelDetector()
        let tapHandler = detector.createTapHandlerForTesting()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512) else {
            XCTFail("Failed to create test audio buffer")
            return
        }
        buffer.frameLength = 512

        // Fill with test signal
        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                channelData[0][frame] = 0.1 * sin(Float(frame) * 0.1)
            }
        }

        let audioTime = AVAudioTime(sampleTime: 0, atRate: 44100)
        let allInvocationsComplete = expectation(description: "All background invocations complete")

        // Simulate rapid-fire callbacks like Core Audio would do at 60fps
        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<100 {
                tapHandler(buffer, audioTime)
            }
            DispatchQueue.main.async {
                allInvocationsComplete.fulfill()
            }
        }

        await fulfillment(of: [allInvocationsComplete], timeout: 2.0)

        // Success = no crash. The detector should have processed many levels.
        // Just verify we didn't crash and state is reasonable.
        XCTAssertFalse(detector.audioLevel.isNaN, "Audio level should not be NaN after processing")
    }
}

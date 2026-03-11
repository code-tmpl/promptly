import Foundation
import AVFoundation
import Combine

/// Monitors microphone input for speech detection using audio level thresholds
@MainActor
public final class AudioLevelDetector: ObservableObject, @unchecked Sendable {
    // MARK: - Published Properties

    /// Whether the user is currently speaking (audio above threshold)
    @Published public private(set) var isSpeaking: Bool = false

    /// Current audio level in decibels
    @Published public private(set) var audioLevel: Float = -60.0

    /// Whether audio was interrupted (e.g., mic disconnected)
    @Published public private(set) var isInterrupted: Bool = false

    // MARK: - Configuration

    /// Threshold in decibels above which audio is considered speech
    private var threshold: Float = -30.0

    /// Duration of silence before isSpeaking becomes false
    private let silenceDebounceInterval: TimeInterval = 0.3

    /// Duration of speech before isSpeaking becomes true
    private let speechDebounceInterval: TimeInterval = 0.05

    // MARK: - Audio Engine

    private let audioEngine: AVAudioEngine
    private var isRunning = false
    private var silenceTimer: Timer?
    private var speechTimer: Timer?

    // MARK: - Async Streams

    private var speakingContinuation: AsyncStream<Bool>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?

    // MARK: - Notification Observers

    /// Wrapper to make observer references Sendable
    private final class ObserverBox: @unchecked Sendable {
        var configurationChangeObserver: NSObjectProtocol?
        var audioInterruptionObserver: NSObjectProtocol?
    }

    private let observers = ObserverBox()

    public init(audioEngine: AVAudioEngine? = nil) {
        self.audioEngine = audioEngine ?? AVAudioEngine()
        setupNotificationObservers()
    }

    deinit {
        speakingContinuation?.finish()
        audioLevelContinuation?.finish()
        // Remove observers directly in deinit (NotificationCenter is thread-safe)
        if let observer = observers.configurationChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = observers.audioInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Observe audio configuration changes (mic connect/disconnect)
        observers.configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: audioEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleConfigurationChange()
            }
        }
    }

    private func handleConfigurationChange() {
        // Audio configuration changed (e.g., mic disconnected/reconnected)
        if isRunning {
            isInterrupted = true
            stop()

            // Attempt to restart after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.isInterrupted else { return }
                do {
                    try self.start()
                    self.isInterrupted = false
                } catch {
                    // Remain in interrupted state; user may need to restart manually
                    print("Failed to restart audio after configuration change: \(error)")
                }
            }
        }
    }

    // MARK: - Public API

    /// Starts monitoring the microphone for audio levels
    public func start() throws {
        guard !isRunning else { return }

        // Verify microphone access on macOS
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard authStatus == .authorized else {
            if authStatus == .notDetermined {
                // Request access - caller should retry after permission granted
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
            throw AudioError.noInputDevice
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Verify we have a valid format
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioError.invalidFormat
        }

        // Install tap on input node
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Start the audio engine with proper error handling
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            // Clean up the tap we just installed
            inputNode.removeTap(onBus: 0)
            throw AudioError.engineStartFailed
        }

        isRunning = true
        isInterrupted = false
    }

    /// Stops monitoring the microphone
    public func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        speechTimer?.invalidate()
        speechTimer = nil

        if isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            isRunning = false
        }

        isSpeaking = false
        audioLevel = -60.0
    }

    /// Updates the speech detection threshold
    public func updateThreshold(_ dB: Float) {
        threshold = dB
    }

    /// Provides an async stream of speaking state changes
    public func speakingStateStream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.speakingContinuation = continuation
        }
    }

    /// Provides an async stream of audio level changes
    public func audioLevelStream() -> AsyncStream<Float> {
        AsyncStream { continuation in
            self.audioLevelContinuation = continuation
        }
    }

    // MARK: - Private Implementation

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS (Root Mean Square) of the audio
        var rms: Float = 0
        for channel in 0..<channelCount {
            let data = channelData[channel]
            var sum: Float = 0
            for frame in 0..<frameLength {
                let sample = data[frame]
                sum += sample * sample
            }
            rms += sum
        }

        rms = sqrt(rms / Float(frameLength * channelCount))

        // Convert to decibels
        let dB = 20 * log10(max(rms, 0.000001))

        // Update on main thread
        Task { @MainActor [weak self] in
            self?.handleAudioLevel(dB)
        }
    }

    private func handleAudioLevel(_ dB: Float) {
        audioLevel = dB
        audioLevelContinuation?.yield(dB)

        let aboveThreshold = dB > threshold

        if aboveThreshold && !isSpeaking {
            // Audio above threshold, start speech timer
            silenceTimer?.invalidate()
            silenceTimer = nil

            if speechTimer == nil {
                speechTimer = Timer.scheduledTimer(
                    withTimeInterval: speechDebounceInterval,
                    repeats: false
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setSpeaking(true)
                        self?.speechTimer = nil
                    }
                }
            }
        } else if !aboveThreshold && isSpeaking {
            // Audio below threshold, start silence timer
            speechTimer?.invalidate()
            speechTimer = nil

            if silenceTimer == nil {
                silenceTimer = Timer.scheduledTimer(
                    withTimeInterval: silenceDebounceInterval,
                    repeats: false
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setSpeaking(false)
                        self?.silenceTimer = nil
                    }
                }
            }
        } else if aboveThreshold && isSpeaking {
            // Still speaking, reset silence timer
            silenceTimer?.invalidate()
            silenceTimer = nil
        }
    }

    private func setSpeaking(_ speaking: Bool) {
        guard isSpeaking != speaking else { return }
        isSpeaking = speaking
        speakingContinuation?.yield(speaking)
    }
}

// MARK: - Audio Errors

public enum AudioError: Error, LocalizedError {
    case invalidFormat
    case engineStartFailed
    case noInputDevice

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format. Please check your microphone settings."
        case .engineStartFailed:
            return "Failed to start audio engine."
        case .noInputDevice:
            return "No microphone input device found."
        }
    }
}

// MARK: - Testing Support

extension AudioLevelDetector {
    /// Simulates audio input for testing purposes
    public func simulateAudioLevel(_ dB: Float) {
        handleAudioLevel(dB)
    }

    /// Returns the current threshold for testing
    public var currentThreshold: Float {
        threshold
    }
}

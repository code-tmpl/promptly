import Foundation
import AVFoundation
import Combine

/// Non-actor bridge that can be safely captured in the audio tap closure.
/// Holds a callback that is set on MainActor and invoked from any thread
/// via DispatchQueue.main.async, avoiding Swift 6 isolation checks.
private final class AudioTapBridge: @unchecked Sendable {
    var onLevel: ((Float) -> Void)?

    func send(_ dB: Float) {
        DispatchQueue.main.async { [self] in
            self.onLevel?(dB)
        }
    }
}

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

    /// Preferred audio input device unique ID (nil = system default)
    public var preferredDeviceID: String?

    // MARK: - Recovery

    /// Task for audio config recovery — stored to cancel on re-entry
    private var configRecoveryTask: Task<Void, Never>?

    // MARK: - Async Streams

    private var speakingContinuation: AsyncStream<Bool>.Continuation?
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?

    // MARK: - Audio Tap Bridge

    /// Bridge object for safely passing audio levels from the realtime thread.
    /// Not @MainActor, so capturing it in the tap won't trigger isolation checks.
    private let tapBridge = AudioTapBridge()

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

            // Cancel any previous recovery task to prevent races
            // (e.g., bluetooth headset flapping connect/disconnect rapidly)
            configRecoveryTask?.cancel()
            configRecoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                guard let self, self.isInterrupted else { return }
                do {
                    try self.start()
                    self.isInterrupted = false
                } catch {
                    print("Failed to restart audio after configuration change: \(error)")
                }
                self.configRecoveryTask = nil
            }
        }
    }

    // MARK: - Audio Device Selection

    /// Sets the audio engine's input device by unique ID
    private func setInputDevice(uniqueID: String) {
        #if os(macOS)
        // Find the CoreAudio device ID matching the uniqueID
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices.first(where: { $0.uniqueID == uniqueID }) else {
            print("Audio device not found: \(uniqueID)")
            return
        }

        // Get the AudioDeviceID from the transport type + uniqueID
        var deviceID: AudioDeviceID = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size)
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)

        // Find the device matching the uniqueID
        for id in deviceIDs {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            let status = AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &uidSize, &uid)
            if status == noErr, uid as String == uniqueID {
                deviceID = id
                break
            }
        }

        guard deviceID != 0 else {
            print("Could not find CoreAudio device for: \(uniqueID)")
            return
        }

        // Set the input device on the audio engine's input node
        let inputNode = audioEngine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            print("Audio unit not available — cannot set input device")
            return
        }
        var mutableDeviceID = deviceID
        let setStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if setStatus != noErr {
            print("Failed to set audio input device: \(setStatus)")
        }
        #endif
    }

    // MARK: - Public API

    /// Starts monitoring the microphone for audio levels
    public func start() throws {
        guard !isRunning else { return }

        // Verify microphone access on macOS
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch authStatus {
        case .authorized:
            break // proceed
        case .notDetermined:
            // Permission not yet asked — request it asynchronously.
            // Caller should retry after user grants permission.
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if granted {
                    try? self.start() // retry after grant
                }
            }
            return // don't throw — just wait for user to respond
        case .denied, .restricted:
            throw AudioError.noInputDevice
        @unknown default:
            throw AudioError.noInputDevice
        }

        // Set preferred audio device if specified
        if let deviceID = preferredDeviceID {
            setInputDevice(uniqueID: deviceID)
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Verify we have a valid format
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioError.invalidFormat
        }

        // Install tap on input node.
        // IMPORTANT: The tap callback runs on Core Audio's realtime thread.
        // Swift 6 infers closures defined inside @MainActor methods as
        // @MainActor-isolated, inserting a runtime assertion that crashes
        // when Core Audio invokes the callback off the main thread.
        // Fix: `makeTapHandler` is `nonisolated static`, so the returned
        // closure has no actor isolation.  It only captures `bridge`
        // (a non-actor Sendable type) and bounces levels to MainActor
        // via DispatchQueue.main.async inside `bridge.send()`.
        tapBridge.onLevel = { [weak self] dB in
            self?.handleAudioLevel(dB)
        }
        let bridge = tapBridge  // local let — NOT @MainActor typed

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format,
            block: Self.makeTapHandler(bridge: bridge)
        )

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

        // Finish async stream continuations so consumers exit for-await loops
        speakingContinuation?.finish()
        speakingContinuation = nil
        audioLevelContinuation?.finish()
        audioLevelContinuation = nil

        isSpeaking = false
        audioLevel = -60.0
    }

    /// Updates the speech detection threshold
    public func updateThreshold(_ dB: Float) {
        threshold = dB
    }

    /// Provides an async stream of speaking state changes.
    /// Calling this again finishes any previous stream so old consumers don't hang.
    public func speakingStateStream() -> AsyncStream<Bool> {
        // Finish the previous continuation so any old consumer exits for-await
        speakingContinuation?.finish()
        speakingContinuation = nil

        return AsyncStream { continuation in
            self.speakingContinuation = continuation
        }
    }

    /// Provides an async stream of audio level changes.
    /// Calling this again finishes any previous stream so old consumers don't hang.
    public func audioLevelStream() -> AsyncStream<Float> {
        audioLevelContinuation?.finish()
        audioLevelContinuation = nil

        return AsyncStream { continuation in
            self.audioLevelContinuation = continuation
        }
    }

    // MARK: - Audio Tap Handler (nonisolated)

    /// Returns the installTap block.  Defined as `nonisolated static` so the
    /// closure is **not** inferred as `@MainActor` by Swift 6.  The returned
    /// closure only captures the non-actor `AudioTapBridge`, which is safe to
    /// call from Core Audio's realtime thread.
    nonisolated private static func makeTapHandler(
        bridge: AudioTapBridge
    ) -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        return { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0, channelCount > 0 else { return }

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
            let dB = 20 * log10(max(rms, 0.000001))

            bridge.send(dB)
        }
    }

    // MARK: - Private Implementation

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

    /// Simulates an audio configuration change (e.g., headset disconnect)
    public func simulateConfigurationChange() {
        handleConfigurationChange()
    }

    /// Returns the current threshold for testing
    public var currentThreshold: Float {
        threshold
    }

    /// Returns whether the audio engine is currently running
    public var isEngineRunning: Bool {
        audioEngine.isRunning
    }

    /// Creates a tap handler bound to this detector's bridge for regression testing.
    /// The returned closure can safely be invoked from any thread (including background
    /// queues simulating Core Audio's realtime thread). This tests the Swift 6
    /// nonisolated fix — the closure must NOT have @MainActor isolation.
    ///
    /// Returns a closure that accepts (AVAudioPCMBuffer, AVAudioTime) and processes
    /// audio levels. Call this from a background thread to verify no crash occurs.
    public func createTapHandlerForTesting() -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        tapBridge.onLevel = { [weak self] dB in
            self?.handleAudioLevel(dB)
        }
        return Self.makeTapHandler(bridge: tapBridge)
    }
}

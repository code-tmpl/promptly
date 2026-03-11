import Foundation
import SwiftUI
import Combine
import AppKit
import AVFoundation

/// Error types for prompter operations
public enum PrompterError: Error, LocalizedError, Equatable {
    case noScriptSelected
    case emptyScript
    case microphonePermissionDenied
    case audioEngineFailure(String)
    case scriptSaveFailure(String)

    public var errorDescription: String? {
        switch self {
        case .noScriptSelected:
            return "No script selected"
        case .emptyScript:
            return "The selected script is empty"
        case .microphonePermissionDenied:
            return "Microphone access is required for voice-activated scrolling"
        case .audioEngineFailure(let message):
            return "Audio engine error: \(message)"
        case .scriptSaveFailure(let message):
            return "Failed to save script: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noScriptSelected:
            return "Create or select a script from the sidebar"
        case .emptyScript:
            return "Add some text to your script before starting"
        case .microphonePermissionDenied:
            return "Open System Settings to grant microphone access"
        case .audioEngineFailure:
            return "Check your audio settings and try again"
        case .scriptSaveFailure:
            return "Check available disk space and file permissions"
        }
    }

    public var canOpenSettings: Bool {
        self == .microphonePermissionDenied
    }
}

/// Main view model coordinating the prompter functionality
@MainActor
@Observable
public final class PrompterViewModel {
    // MARK: - Published State

    /// The current prompter state
    public let state: PrompterState

    /// Error message for display (legacy)
    public var errorMessage: String?

    /// Current error for alert display
    public var currentError: PrompterError?

    /// Whether to show error alert
    public var showErrorAlert: Bool = false

    // MARK: - Dependencies

    public let scriptStore: ScriptStore
    public let settingsManager: SettingsManager
    public let audioDetector: AudioLevelDetector
    public let scrollController: VoiceScrollController

    // MARK: - Callbacks

    /// Called when the prompter active state changes (for keyboard shortcut gating)
    public var onActiveStateChanged: ((Bool) -> Void)?

    // MARK: - Window Management

    private var windowController: PrompterWindowController?
    private var countdownTimer: Timer?
    private var stateUpdateCancellable: AnyCancellable?

    public init(
        scriptStore: ScriptStore,
        settingsManager: SettingsManager,
        audioDetector: AudioLevelDetector? = nil,
        scrollController: VoiceScrollController? = nil
    ) {
        self.scriptStore = scriptStore
        self.settingsManager = settingsManager
        self.state = PrompterState()

        // Initialize audio components
        self.audioDetector = audioDetector ?? AudioLevelDetector()
        self.scrollController = scrollController ?? VoiceScrollController()

        // Set initial speed from settings
        self.state.currentSpeed = settingsManager.scrollSpeed
        self.audioDetector.updateThreshold(settingsManager.micSensitivity)

        setupBindings()
    }

    // MARK: - Public API

    /// The script currently being prompted
    public var currentScript: Script? {
        scriptStore.currentScript
    }

    /// Displays an error to the user
    public func showError(_ error: PrompterError) {
        currentError = error
        errorMessage = error.localizedDescription
        showErrorAlert = true
    }

    /// Clears the current error
    public func clearError() {
        currentError = nil
        errorMessage = nil
        showErrorAlert = false
    }

    /// Starts the prompter with optional countdown
    public func startPrompting() {
        guard let script = currentScript else {
            showError(.noScriptSelected)
            return
        }

        guard !script.content.isEmpty else {
            showError(.emptyScript)
            return
        }

        // Check microphone permission
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if authStatus == .denied || authStatus == .restricted {
            showError(.microphonePermissionDenied)
            return
        }

        // Reset state
        state.reset(countdownSeconds: settingsManager.countdownSeconds.rawValue)
        state.currentSpeed = settingsManager.scrollSpeed

        // Create and show window
        let mode = settingsManager.preferredMode
        windowController = PrompterWindowController(
            mode: mode,
            settingsManager: settingsManager
        )

        let overlayView = PrompterOverlayView(
            script: script,
            state: state,
            settings: settingsManager.settings,
            onContentHeightChanged: { [weak self] height in
                self?.state.totalContentHeight = height
            }
        )

        // Wire up hover callbacks for pause/resume
        windowController?.onMouseEntered = { [weak self] in
            self?.pause()
        }
        windowController?.onMouseExited = { [weak self] in
            self?.resume()
        }

        windowController?.showWindow(with: overlayView)
        windowController?.startObservingWindowPosition()

        // Start countdown
        startCountdown()
    }

    /// Stops the prompter and closes the window
    public func stopPrompting() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        audioDetector.stop()
        scrollController.stop()

        windowController?.stopObservingWindowPosition()
        windowController?.closeWindow()
        windowController = nil

        state.isActive = false
        state.isCountingDown = false
        onActiveStateChanged?(false)
    }

    /// Toggles between notch and floating mode
    public func toggleMode() {
        let newMode: PrompterMode = settingsManager.preferredMode == .notch ? .floating : .notch
        settingsManager.preferredMode = newMode

        // If prompting, restart with new mode
        if state.isActive {
            stopPrompting()
            startPrompting()
        }
    }

    /// Pauses scrolling
    public func pause() {
        state.isPaused = true
        scrollController.isPaused = true
    }

    /// Resumes scrolling
    public func resume() {
        state.isPaused = false
        scrollController.isPaused = false
    }

    /// Toggles pause state
    public func togglePause() {
        if state.isPaused {
            resume()
        } else {
            pause()
        }
    }

    /// Increases scroll speed
    public func speedUp() {
        state.speedUp()
        scrollController.speed = state.currentSpeed
    }

    /// Decreases scroll speed
    public func slowDown() {
        state.slowDown()
        scrollController.speed = state.currentSpeed
    }

    /// Manually scrolls by a delta amount
    public func manualScroll(delta: CGFloat) {
        scrollController.manualScroll(delta: delta)
    }

    /// Resets scroll position to the beginning
    public func resetScroll() {
        state.scrollOffset = 0
        scrollController.reset()
    }

    // MARK: - Private Implementation

    private func setupBindings() {
        // Bind audio detector to scroll controller
        scrollController.bind(to: audioDetector)

        // Observe scroll offset changes from the controller
        stateUpdateCancellable = scrollController.$scrollOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak self] offset in
                self?.state.scrollOffset = offset
            }

        // Observe speaking state
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await isSpeaking in self.audioDetector.speakingStateStream() {
                self.state.isSpeaking = isSpeaking
            }
        }

        // Observe audio level
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await level in self.audioDetector.audioLevelStream() {
                self.state.audioLevel = level
            }
        }
    }

    private func startCountdown() {
        state.isCountingDown = true
        state.countdownValue = settingsManager.countdownSeconds.rawValue

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                self.state.countdownValue -= 1

                if self.state.countdownValue <= 0 {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.beginPrompting()
                }
            }
        }
    }

    private func beginPrompting() {
        state.isCountingDown = false
        state.isActive = true
        onActiveStateChanged?(true)

        // Update audio threshold from settings
        audioDetector.updateThreshold(settingsManager.micSensitivity)

        // Start audio detection
        do {
            try audioDetector.start()
        } catch {
            showError(.audioEngineFailure(error.localizedDescription))
            stopPrompting()
            return
        }

        // Start scroll controller
        scrollController.speed = state.currentSpeed
        scrollController.start()
    }
}

// MARK: - Keyboard Shortcut Handling

extension PrompterViewModel {
    /// Handles keyboard shortcuts
    public func handleKeyboardShortcut(_ shortcut: KeyboardShortcut) {
        switch shortcut {
        case .startStop:
            if state.isActive {
                stopPrompting()
            } else {
                startPrompting()
            }
        case .pauseResume:
            togglePause()
        case .speedUp:
            speedUp()
        case .speedDown:
            slowDown()
        case .toggleMode:
            toggleMode()
        }
    }
}

/// Keyboard shortcuts for the prompter
public enum KeyboardShortcut: Sendable {
    case startStop      // ⌘⏎
    case pauseResume    // Space
    case speedUp        // ⌘↑
    case speedDown      // ⌘↓
    case toggleMode     // ⌘T
}

import AppKit
import SwiftUI

/// Manages the prompter panel lifecycle and positioning
@MainActor
public final class PrompterWindowController {
    // MARK: - Properties

    /// The managed panel
    private var panel: PrompterPanel?

    /// Current prompter mode
    public private(set) var mode: PrompterMode

    /// Settings manager for persistence
    private let settingsManager: SettingsManager

    /// Callback when mouse enters the panel (for pause on hover)
    public var onMouseEntered: (() -> Void)?

    /// Callback when mouse exits the panel
    public var onMouseExited: (() -> Void)?

    /// Callback when the window is closed
    public var onClose: (() -> Void)?

    // MARK: - Initialization

    public init(mode: PrompterMode, settingsManager: SettingsManager) {
        self.mode = mode
        self.settingsManager = settingsManager
    }

    // MARK: - Public API

    /// Shows the prompter window with the given SwiftUI content
    public func showWindow<Content: View>(with content: Content) {
        guard let screen = NSScreen.cameraScreen else {
            print("No screen available for prompter")
            return
        }

        let frame = calculateFrame(for: screen)
        let isNotchMode = mode == .notch

        panel = PrompterPanel(contentRect: frame, isNotchMode: isNotchMode)
        panel?.setContent(content)

        // Set up callbacks
        panel?.onMouseEntered = { [weak self] in
            self?.onMouseEntered?()
        }
        panel?.onMouseExited = { [weak self] in
            self?.onMouseExited?()
        }
        panel?.onClose = { [weak self] in
            self?.saveWindowPosition()
            self?.onClose?()
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    /// Updates the content of the window
    public func updateContent<Content: View>(_ content: Content) {
        panel?.updateContent(content)
    }

    /// Closes the prompter window
    public func closeWindow() {
        saveWindowPosition()
        panel?.close()
        panel = nil
    }

    /// Toggles between notch and floating mode
    public func toggleMode() {
        let newMode: PrompterMode = mode == .notch ? .floating : .notch
        switchMode(to: newMode)
    }

    /// Switches to a specific mode
    public func switchMode(to newMode: PrompterMode) {
        guard newMode != mode else { return }

        mode = newMode
        settingsManager.preferredMode = newMode

        // Reposition the window
        repositionWindow()
    }

    /// Repositions the window based on current mode
    public func repositionWindow() {
        guard let screen = NSScreen.cameraScreen else { return }
        let frame = calculateFrame(for: screen)

        // Update panel configuration for new mode
        let isNotchMode = mode == .notch
        panel?.isMovableByWindowBackground = !isNotchMode

        if isNotchMode {
            panel?.level = .aboveStatusBar
        } else {
            panel?.level = .floating
        }

        panel?.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Private Implementation

    private func calculateFrame(for screen: NSScreen) -> NSRect {
        switch mode {
        case .notch:
            return NotchPositionCalculator.calculateNotchFrame(for: screen)

        case .floating:
            // Try to restore saved position
            if let savedFrame = settingsManager.savedFloatingWindowFrame {
                return NotchPositionCalculator.constrainFrame(savedFrame, to: screen)
            }
            return NotchPositionCalculator.calculateDefaultFloatingFrame(for: screen)
        }
    }

    private func saveWindowPosition() {
        guard mode == .floating, let frame = panel?.frame else { return }
        settingsManager.saveFloatingWindowFrame(frame)
    }
}

// MARK: - Window Position Observation

extension PrompterWindowController {
    /// Starts observing window frame changes to persist position
    public func startObservingWindowPosition() {
        guard mode == .floating else { return }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveWindowPosition()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveWindowPosition()
            }
        }
    }

    /// Stops observing window frame changes
    public func stopObservingWindowPosition() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didMoveNotification,
            object: panel
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResizeNotification,
            object: panel
        )
    }
}

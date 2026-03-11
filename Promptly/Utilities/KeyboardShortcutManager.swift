import AppKit
import Carbon.HIToolbox

/// Virtual key codes
private enum KeyCode {
    static let returnKey: UInt16 = 0x24
    static let space: UInt16 = 0x31
    static let upArrow: UInt16 = 0x7E
    static let downArrow: UInt16 = 0x7D
    static let t: UInt16 = 0x11
    static let n: UInt16 = 0x2D
    static let comma: UInt16 = 0x2B
}

/// Manages global keyboard shortcuts for the application
@MainActor
public final class KeyboardShortcutManager {
    /// Callback for handling shortcuts
    public var onShortcut: ((KeyboardShortcut) -> Void)?

    /// Local event monitor for key events
    private var localMonitor: Any?

    /// Global event monitor for key events (when app is not active)
    private var globalMonitor: Any?

    /// Whether monitoring is active
    private var isMonitoring = false

    public init() {}

    // MARK: - Public API

    /// Starts monitoring keyboard events
    public func startMonitoring() {
        guard !isMonitoring else { return }

        // Local monitor for when the app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }

        isMonitoring = true
    }

    /// Stops monitoring keyboard events
    public func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        isMonitoring = false
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        // Check for known shortcuts
        if let shortcut = matchShortcut(keyCode: keyCode, modifiers: modifiers) {
            onShortcut?(shortcut)
            return true
        }

        return false
    }

    private func matchShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> KeyboardShortcut? {
        // ⌘⏎ - Start/Stop Prompting
        if keyCode == KeyCode.returnKey && modifiers == .command {
            return .startStop
        }

        // Space - Pause/Resume (no modifiers)
        if keyCode == KeyCode.space && modifiers.isEmpty {
            return .pauseResume
        }

        // ⌘↑ - Speed Up
        if keyCode == KeyCode.upArrow && modifiers == .command {
            return .speedUp
        }

        // ⌘↓ - Speed Down
        if keyCode == KeyCode.downArrow && modifiers == .command {
            return .speedDown
        }

        // ⌘T - Toggle Mode
        if keyCode == KeyCode.t && modifiers == .command {
            return .toggleMode
        }

        return nil
    }
}

// MARK: - NSEvent Extension

extension NSEvent.ModifierFlags {
    /// Returns true if no modifier keys are pressed
    var isEmpty: Bool {
        intersection(.deviceIndependentFlagsMask).rawValue == 0
    }
}

// MARK: - Shortcut Description

extension KeyboardShortcut {
    /// Human-readable description of the shortcut
    public var description: String {
        switch self {
        case .startStop:
            return "⌘⏎ Start/Stop"
        case .pauseResume:
            return "Space Pause/Resume"
        case .speedUp:
            return "⌘↑ Speed Up"
        case .speedDown:
            return "⌘↓ Speed Down"
        case .toggleMode:
            return "⌘T Toggle Mode"
        }
    }

    /// The keyboard shortcut as a string
    public var keyEquivalent: String {
        switch self {
        case .startStop:
            return "⌘⏎"
        case .pauseResume:
            return "Space"
        case .speedUp:
            return "⌘↑"
        case .speedDown:
            return "⌘↓"
        case .toggleMode:
            return "⌘T"
        }
    }
}

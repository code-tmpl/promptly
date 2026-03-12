import AppKit
import Carbon.HIToolbox

/// Virtual key codes used for shortcut detection
private enum KeyCode {
    static let returnKey: UInt16 = 0x24
    static let space: UInt16 = 0x31
    static let upArrow: UInt16 = 0x7E
    static let downArrow: UInt16 = 0x7D
    static let t: UInt16 = 0x11
}

/// Manages keyboard shortcuts for the prompter window
@MainActor
public final class KeyboardShortcutManager {
    /// Callback for handling shortcuts
    public var onShortcut: ((KeyboardShortcut) -> Void)?

    /// Whether the prompter is currently active (shortcuts like Space only work when active)
    public var isPrompterActive: Bool = false

    /// Local event monitor for key events
    private var localMonitor: Any?

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
        // ONLY when prompter is active AND focus is NOT in a text editor
        // Otherwise, space is eaten and users can't type spaces in their scripts
        if keyCode == KeyCode.space && modifiers.isEmpty && isPrompterActive {
            // Check if the first responder is a text input — if so, don't consume
            if let firstResponder = NSApp.keyWindow?.firstResponder,
               firstResponder is NSTextView || firstResponder is NSTextField {
                return nil // Let the space through to the text editor
            }
            return .pauseResume
        }

        // ⌘↑ - Speed Up
        // Arrow keys may include .numericPad flag, so check contains rather than exact match
        // But ensure no other significant modifiers (shift, option, control) are pressed
        if keyCode == KeyCode.upArrow &&
           modifiers.contains(.command) &&
           !modifiers.contains(.shift) &&
           !modifiers.contains(.option) &&
           !modifiers.contains(.control) {
            return .speedUp
        }

        // ⌘↓ - Speed Down
        if keyCode == KeyCode.downArrow &&
           modifiers.contains(.command) &&
           !modifiers.contains(.shift) &&
           !modifiers.contains(.option) &&
           !modifiers.contains(.control) {
            return .speedDown
        }

        // ⌘T - Toggle Mode
        if keyCode == KeyCode.t && modifiers == .command {
            return .toggleMode
        }

        return nil
    }

    /// Exposes matchShortcut for testing without needing NSEvent
    public func matchShortcutForTesting(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> KeyboardShortcut? {
        matchShortcut(keyCode: keyCode, modifiers: modifiers)
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

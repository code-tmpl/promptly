import AppKit
import SwiftUI

/// Custom NSPanel for the prompter window with screen-share invisibility
public final class PrompterPanel: NSPanel {
    /// Callback when mouse enters the panel
    public var onMouseEntered: (() -> Void)?

    /// Callback when mouse exits the panel
    public var onMouseExited: (() -> Void)?

    /// Callback when the panel is closed
    public var onClose: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    public init(contentRect: NSRect, isNotchMode: Bool) {
        // Style mask: borderless panel that doesn't activate
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]

        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        configurePanel(isNotchMode: isNotchMode)
    }

    private func configurePanel(isNotchMode: Bool) {
        // Make invisible to screen capture
        sharingType = .none

        // Transparent background
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Window level based on mode
        if isNotchMode {
            level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        } else {
            level = .floating
        }

        // Collection behavior for multi-space and full-screen support
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        // Don't steal focus
        isReleasedWhenClosed = false
        hidesOnDeactivate = false

        // Allow dragging in floating mode
        isMovableByWindowBackground = !isNotchMode

        // No title bar
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Accept mouse events for hover detection
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false

        setupTrackingArea()
    }

    // MARK: - Mouse Tracking

    private func setupTrackingArea() {
        if let existingArea = trackingArea {
            contentView?.removeTrackingArea(existingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]

        trackingArea = NSTrackingArea(
            rect: .zero,
            options: options,
            owner: self,
            userInfo: nil
        )

        contentView?.addTrackingArea(trackingArea!)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMouseEntered?()
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }

    public override func close() {
        onClose?()
        super.close()
    }

    // MARK: - Key Handling

    /// Allow the panel to become key to receive keyboard events
    public override var canBecomeKey: Bool {
        true
    }

    /// Don't become main window
    public override var canBecomeMain: Bool {
        false
    }

    // MARK: - Resize Handling (for floating mode)

    public override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        setupTrackingArea()
    }

    public override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        setupTrackingArea()
    }
}

// MARK: - SwiftUI Hosting

extension PrompterPanel {
    /// Sets up the panel with a SwiftUI view as content
    public func setContent<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        contentView = hostingView
    }

    /// Updates the SwiftUI content
    public func updateContent<Content: View>(_ view: Content) {
        if let hostingView = contentView as? NSHostingView<Content> {
            hostingView.rootView = view
        } else {
            setContent(view)
        }
    }
}

// MARK: - Window Level Extension

extension NSWindow.Level {
    /// Level for notch mode (above status bar)
    public static var aboveStatusBar: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
    }
}

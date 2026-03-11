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
    private var isInNotchMode: Bool
    private var resizeHandleViews: [ResizeHandleView] = []

    /// Type-erased hosting view for content updates
    private var hostingView: NSHostingView<AnyView>?

    // Minimum size constraints for floating mode
    private let minWindowWidth: CGFloat = 300
    private let minWindowHeight: CGFloat = 80
    private let maxWindowWidth: CGFloat = 1200
    private let maxWindowHeight: CGFloat = 400

    public init(contentRect: NSRect, isNotchMode: Bool) {
        self.isInNotchMode = isNotchMode

        // Style mask: borderless panel that doesn't activate
        // Add resizable for floating mode
        var styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        if !isNotchMode {
            styleMask.insert(.resizable)
        }

        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        configurePanel(isNotchMode: isNotchMode)

        if !isNotchMode {
            setupResizeHandles()
        }
    }

    private func configurePanel(isNotchMode: Bool) {
        // Make invisible to screen capture
        sharingType = .none

        // Transparent background
        isOpaque = false
        backgroundColor = .clear
        hasShadow = !isNotchMode  // Add shadow for floating mode

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

        // Set min/max size for floating mode
        if !isNotchMode {
            minSize = NSSize(width: minWindowWidth, height: minWindowHeight)
            maxSize = NSSize(width: maxWindowWidth, height: maxWindowHeight)
        }

        setupTrackingArea()
    }

    // MARK: - Resize Handles

    private func setupResizeHandles() {
        guard !isInNotchMode else { return }

        // Remove existing handles
        resizeHandleViews.forEach { $0.removeFromSuperview() }
        resizeHandleViews.removeAll()

        // Create handles for corners and edges
        let handleSize: CGFloat = 12
        let positions: [(ResizeDirection, NSRect)] = [
            // Corners
            (.bottomLeft, NSRect(x: 0, y: 0, width: handleSize, height: handleSize)),
            (.bottomRight, NSRect(x: frame.width - handleSize, y: 0, width: handleSize, height: handleSize)),
            (.topLeft, NSRect(x: 0, y: frame.height - handleSize, width: handleSize, height: handleSize)),
            (.topRight, NSRect(x: frame.width - handleSize, y: frame.height - handleSize, width: handleSize, height: handleSize)),
            // Edges
            (.left, NSRect(x: 0, y: handleSize, width: handleSize, height: frame.height - handleSize * 2)),
            (.right, NSRect(x: frame.width - handleSize, y: handleSize, width: handleSize, height: frame.height - handleSize * 2)),
            (.bottom, NSRect(x: handleSize, y: 0, width: frame.width - handleSize * 2, height: handleSize)),
            (.top, NSRect(x: handleSize, y: frame.height - handleSize, width: frame.width - handleSize * 2, height: handleSize))
        ]

        for (direction, rect) in positions {
            let handleView = ResizeHandleView(direction: direction)
            handleView.frame = rect
            handleView.autoresizingMask = autoresizingMask(for: direction)
            handleView.onResize = { [weak self] delta in
                self?.handleResize(direction: direction, delta: delta)
            }
            contentView?.addSubview(handleView)
            resizeHandleViews.append(handleView)
        }
    }

    private func autoresizingMask(for direction: ResizeDirection) -> NSView.AutoresizingMask {
        switch direction {
        case .topLeft: return [.maxXMargin, .minYMargin]
        case .topRight: return [.minXMargin, .minYMargin]
        case .bottomLeft: return [.maxXMargin, .maxYMargin]
        case .bottomRight: return [.minXMargin, .maxYMargin]
        case .left: return [.maxXMargin, .height]
        case .right: return [.minXMargin, .height]
        case .top: return [.width, .minYMargin]
        case .bottom: return [.width, .maxYMargin]
        }
    }

    private func handleResize(direction: ResizeDirection, delta: NSPoint) {
        var newFrame = frame

        switch direction {
        case .topLeft:
            newFrame.origin.x += delta.x
            newFrame.size.width -= delta.x
            newFrame.size.height += delta.y
        case .topRight:
            newFrame.size.width += delta.x
            newFrame.size.height += delta.y
        case .bottomLeft:
            newFrame.origin.x += delta.x
            newFrame.origin.y += delta.y
            newFrame.size.width -= delta.x
            newFrame.size.height -= delta.y
        case .bottomRight:
            newFrame.origin.y += delta.y
            newFrame.size.width += delta.x
            newFrame.size.height -= delta.y
        case .left:
            newFrame.origin.x += delta.x
            newFrame.size.width -= delta.x
        case .right:
            newFrame.size.width += delta.x
        case .top:
            newFrame.size.height += delta.y
        case .bottom:
            newFrame.origin.y += delta.y
            newFrame.size.height -= delta.y
        }

        // Apply constraints
        newFrame.size.width = max(minWindowWidth, min(maxWindowWidth, newFrame.size.width))
        newFrame.size.height = max(minWindowHeight, min(maxWindowHeight, newFrame.size.height))

        // Ensure we don't move off screen
        if let screen = screen {
            newFrame = constrainToScreen(newFrame, screen: screen)
        }

        setFrame(newFrame, display: true, animate: false)
    }

    private func constrainToScreen(_ frame: NSRect, screen: NSScreen) -> NSRect {
        var constrained = frame
        let visibleFrame = screen.visibleFrame

        if constrained.maxX > visibleFrame.maxX {
            constrained.origin.x = visibleFrame.maxX - constrained.width
        }
        if constrained.minX < visibleFrame.minX {
            constrained.origin.x = visibleFrame.minX
        }
        if constrained.maxY > visibleFrame.maxY {
            constrained.origin.y = visibleFrame.maxY - constrained.height
        }
        if constrained.minY < visibleFrame.minY {
            constrained.origin.y = visibleFrame.minY
        }

        return constrained
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

        let newTrackingArea = NSTrackingArea(
            rect: .zero,
            options: options,
            owner: self,
            userInfo: nil
        )

        trackingArea = newTrackingArea
        contentView?.addTrackingArea(newTrackingArea)
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
        // Wrap in AnyView for type-erased storage
        let anyView = AnyView(view)
        let newHostingView = NSHostingView(rootView: anyView)
        newHostingView.translatesAutoresizingMaskIntoConstraints = false

        hostingView = newHostingView
        contentView = newHostingView

        // Re-setup resize handles after setting content
        if !isInNotchMode {
            DispatchQueue.main.async { [weak self] in
                self?.setupResizeHandles()
            }
        }
    }

    /// Updates the SwiftUI content without recreating the hosting view
    public func updateContent<Content: View>(_ view: Content) {
        if let hostingView = hostingView {
            // Update the rootView directly using the stored type-erased reference
            hostingView.rootView = AnyView(view)
        } else {
            // Fallback: create new hosting view if none exists
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

// MARK: - Resize Direction

internal enum ResizeDirection {
    case topLeft, topRight, bottomLeft, bottomRight
    case left, right, top, bottom

    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            return .crosshair  // Ideally would use diagonal resize cursor
        case .topRight, .bottomLeft:
            return .crosshair
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        }
    }
}

// MARK: - Resize Handle View

internal final class ResizeHandleView: NSView {
    let direction: ResizeDirection
    var onResize: ((NSPoint) -> Void)?
    private var lastMouseLocation: NSPoint?
    private var isHovering = false

    init(direction: ResizeDirection) {
        self.direction = direction
        super.init(frame: .zero)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw subtle resize handle indicator when hovering
        if isHovering {
            let handleColor = NSColor.white.withAlphaComponent(0.3)
            handleColor.setFill()

            // Draw corner dots or edge lines
            switch direction {
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                let dotSize: CGFloat = 6
                let dotRect = NSRect(
                    x: (bounds.width - dotSize) / 2,
                    y: (bounds.height - dotSize) / 2,
                    width: dotSize,
                    height: dotSize
                )
                let path = NSBezierPath(ovalIn: dotRect)
                path.fill()
            default:
                break
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        direction.cursor.push()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        NSCursor.pop()
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        lastMouseLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let lastLocation = lastMouseLocation else { return }

        let currentLocation = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentLocation.x - lastLocation.x,
            y: currentLocation.y - lastLocation.y
        )

        onResize?(delta)
        lastMouseLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        lastMouseLocation = nil
    }
}

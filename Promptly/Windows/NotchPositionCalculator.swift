import AppKit

/// Calculates window frames for notch-mode positioning
public struct NotchPositionCalculator: Sendable {
    /// Default height for the prompter window
    public static let defaultWindowHeight: CGFloat = 80

    /// Minimum height for the prompter window
    public static let minimumWindowHeight: CGFloat = 40

    /// Maximum height for the prompter window
    public static let maximumWindowHeight: CGFloat = 200

    /// Default width for floating mode
    public static let defaultFloatingWidth: CGFloat = 600

    /// Default height for floating mode
    public static let defaultFloatingHeight: CGFloat = 150

    /// Approximate width of the MacBook notch (based on 14"/16" MacBook Pro)
    public static let approximateNotchWidth: CGFloat = 180

    private init() {}

    // MARK: - Notch Detection

    /// Checks if the given screen has a notch (safe area at the top)
    public static func hasNotch(_ screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0
        }
        return false
    }

    /// Returns the notch height for the given screen, or 0 if no notch
    public static func notchHeight(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top
        }
        return 0
    }

    /// Returns the approximate notch rectangle for the screen, if present
    public static func notchRect(for screen: NSScreen) -> NSRect? {
        guard hasNotch(screen) else { return nil }

        // The notch is centered at the top of the screen
        let notchHeight = notchHeight(for: screen)
        let screenFrame = screen.frame
        let notchX = screenFrame.origin.x + (screenFrame.width - approximateNotchWidth) / 2
        let notchY = screenFrame.origin.y + screenFrame.height - notchHeight

        return NSRect(x: notchX, y: notchY, width: approximateNotchWidth, height: notchHeight)
    }

    // MARK: - Frame Calculation

    /// Calculates the frame for notch mode on the given screen
    @MainActor
    public static func calculateNotchFrame(for screen: NSScreen, height: CGFloat = defaultWindowHeight) -> NSRect {
        let screenFrame = screen.frame
        let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 24
        let safeAreaTop = notchHeight(for: screen)

        // Position the window at the top of the screen, below the menu bar
        // If there's a notch, position just below it
        let windowY: CGFloat
        if hasNotch(screen) {
            // Position below the notch
            windowY = screenFrame.origin.y + screenFrame.height - safeAreaTop - height
        } else {
            // Position below the menu bar
            windowY = screenFrame.origin.y + screenFrame.height - menuBarHeight - height
        }

        return NSRect(
            x: screenFrame.origin.x,
            y: windowY,
            width: screenFrame.width,
            height: height
        )
    }

    /// Calculates the left text region frame (left of the notch)
    @MainActor
    public static func leftTextRegion(for screen: NSScreen, windowHeight: CGFloat = defaultWindowHeight) -> NSRect {
        let windowFrame = calculateNotchFrame(for: screen, height: windowHeight)

        guard let notch = notchRect(for: screen) else {
            // No notch, use the full width
            return windowFrame
        }

        // Left region: from left edge to notch
        let leftWidth = notch.origin.x - windowFrame.origin.x
        return NSRect(
            x: windowFrame.origin.x,
            y: windowFrame.origin.y,
            width: leftWidth,
            height: windowFrame.height
        )
    }

    /// Calculates the right text region frame (right of the notch)
    @MainActor
    public static func rightTextRegion(for screen: NSScreen, windowHeight: CGFloat = defaultWindowHeight) -> NSRect {
        let windowFrame = calculateNotchFrame(for: screen, height: windowHeight)

        guard let notch = notchRect(for: screen) else {
            // No notch, return empty rect
            return .zero
        }

        // Right region: from end of notch to right edge
        let rightX = notch.origin.x + notch.width
        let rightWidth = (windowFrame.origin.x + windowFrame.width) - rightX

        return NSRect(
            x: rightX,
            y: windowFrame.origin.y,
            width: rightWidth,
            height: windowFrame.height
        )
    }

    /// Returns text regions for laying out content around the notch
    @MainActor
    public static func textRegions(for screen: NSScreen, windowHeight: CGFloat = defaultWindowHeight) -> [NSRect] {
        if hasNotch(screen) {
            return [
                leftTextRegion(for: screen, windowHeight: windowHeight),
                rightTextRegion(for: screen, windowHeight: windowHeight)
            ]
        } else {
            return [calculateNotchFrame(for: screen, height: windowHeight)]
        }
    }

    // MARK: - Floating Mode

    /// Calculates the default frame for floating mode
    public static func calculateDefaultFloatingFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame

        // Center horizontally, position in upper third of screen
        let x = screenFrame.origin.x + (screenFrame.width - defaultFloatingWidth) / 2
        let y = screenFrame.origin.y + screenFrame.height * 0.7

        return NSRect(
            x: x,
            y: y,
            width: defaultFloatingWidth,
            height: defaultFloatingHeight
        )
    }

    /// Validates and constrains a frame to be within the screen bounds
    public static func constrainFrame(_ frame: NSRect, to screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        var constrained = frame

        // Ensure minimum size
        constrained.size.width = max(200, constrained.size.width)
        constrained.size.height = max(minimumWindowHeight, min(maximumWindowHeight, constrained.size.height))

        // Constrain to screen bounds
        if constrained.maxX > screenFrame.maxX {
            constrained.origin.x = screenFrame.maxX - constrained.width
        }
        if constrained.origin.x < screenFrame.origin.x {
            constrained.origin.x = screenFrame.origin.x
        }
        if constrained.maxY > screenFrame.maxY {
            constrained.origin.y = screenFrame.maxY - constrained.height
        }
        if constrained.origin.y < screenFrame.origin.y {
            constrained.origin.y = screenFrame.origin.y
        }

        return constrained
    }
}

// MARK: - Screen Extension

extension NSScreen {
    /// Returns the screen with the camera (the built-in display on MacBooks)
    public static var cameraScreen: NSScreen? {
        // Prefer the built-in display (the one with the notch/camera)
        // On MacBooks, the built-in display is identifiable by having a notch
        // (safeAreaInsets.top > 0) or by being the localizedName "Built-in"
        for screen in NSScreen.screens {
            if NotchPositionCalculator.hasNotch(screen) {
                return screen
            }
        }
        // Fallback: look for built-in display by name
        for screen in NSScreen.screens {
            if screen.localizedName.lowercased().contains("built-in") ||
               screen.localizedName.lowercased().contains("built in") {
                return screen
            }
        }
        // Final fallback: main screen (the one with the focused window)
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Checks if this screen has a notch
    public var hasNotch: Bool {
        NotchPositionCalculator.hasNotch(self)
    }
}

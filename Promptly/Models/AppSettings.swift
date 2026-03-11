import Foundation
import SwiftUI

/// The mode in which the prompter window operates
public enum PrompterMode: String, Codable, CaseIterable, Sendable {
    case notch
    case floating

    public var displayName: String {
        switch self {
        case .notch: return "Notch Mode"
        case .floating: return "Floating Mode"
        }
    }
}

/// Available countdown durations before prompting begins
public enum CountdownDuration: Int, Codable, CaseIterable, Sendable {
    case three = 3
    case five = 5
    case ten = 10

    public var displayName: String {
        "\(rawValue) seconds"
    }
}

/// Application settings stored in UserDefaults
public struct AppSettings: Codable, Equatable, Sendable {
    // MARK: - Appearance

    /// Font size for the prompter text (points)
    public var fontSize: CGFloat

    /// Text color as hex string (e.g., "#FFFFFF")
    public var textColor: String

    /// Background color as hex string (e.g., "#000000")
    public var backgroundColor: String

    /// Background opacity (0.0 to 1.0)
    public var backgroundOpacity: Double

    // MARK: - Scrolling

    /// Base scroll speed multiplier (1.0 = normal)
    public var scrollSpeed: Double

    // MARK: - Audio

    /// Microphone sensitivity threshold in decibels (typically -50 to -10)
    public var micSensitivity: Float

    // MARK: - Behavior

    /// Countdown duration before prompting starts
    public var countdownSeconds: CountdownDuration

    /// Preferred prompter window mode
    public var preferredMode: PrompterMode

    /// Whether to show the speed indicator in the prompter
    public var showSpeedIndicator: Bool

    /// Whether to show the progress indicator in the prompter
    public var showProgressIndicator: Bool

    // MARK: - Window Position (for floating mode)

    /// Last known floating window X position
    public var floatingWindowX: Double?

    /// Last known floating window Y position
    public var floatingWindowY: Double?

    /// Last known floating window width
    public var floatingWindowWidth: Double?

    /// Last known floating window height
    public var floatingWindowHeight: Double?

    // MARK: - Defaults

    public static let defaults = AppSettings(
        fontSize: 32,
        textColor: "#FFFFFF",
        backgroundColor: "#000000",
        backgroundOpacity: 0.85,
        scrollSpeed: 1.0,
        micSensitivity: -30.0,
        countdownSeconds: .three,
        preferredMode: .notch,
        showSpeedIndicator: true,
        showProgressIndicator: true,
        floatingWindowX: nil,
        floatingWindowY: nil,
        floatingWindowWidth: nil,
        floatingWindowHeight: nil
    )

    public init(
        fontSize: CGFloat = 32,
        textColor: String = "#FFFFFF",
        backgroundColor: String = "#000000",
        backgroundOpacity: Double = 0.85,
        scrollSpeed: Double = 1.0,
        micSensitivity: Float = -30.0,
        countdownSeconds: CountdownDuration = .three,
        preferredMode: PrompterMode = .notch,
        showSpeedIndicator: Bool = true,
        showProgressIndicator: Bool = true,
        floatingWindowX: Double? = nil,
        floatingWindowY: Double? = nil,
        floatingWindowWidth: Double? = nil,
        floatingWindowHeight: Double? = nil
    ) {
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.scrollSpeed = scrollSpeed
        self.micSensitivity = micSensitivity
        self.countdownSeconds = countdownSeconds
        self.preferredMode = preferredMode
        self.showSpeedIndicator = showSpeedIndicator
        self.showProgressIndicator = showProgressIndicator
        self.floatingWindowX = floatingWindowX
        self.floatingWindowY = floatingWindowY
        self.floatingWindowWidth = floatingWindowWidth
        self.floatingWindowHeight = floatingWindowHeight
    }
}

// MARK: - Color Conversion Helpers

extension AppSettings {
    /// Converts hex color string to SwiftUI Color
    public static func color(from hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
        default:
            r = 1.0
            g = 1.0
            b = 1.0
        }

        return Color(red: r, green: g, blue: b)
    }

    /// Converts SwiftUI Color to hex string
    public static func hexString(from color: Color) -> String {
        guard let components = color.cgColor?.components else {
            return "#FFFFFF"
        }

        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }

    /// The text color as a SwiftUI Color
    public var textSwiftUIColor: Color {
        Self.color(from: textColor)
    }

    /// The background color as a SwiftUI Color
    public var backgroundSwiftUIColor: Color {
        Self.color(from: backgroundColor)
    }
}

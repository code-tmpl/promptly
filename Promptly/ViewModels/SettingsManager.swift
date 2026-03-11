import Foundation
import SwiftUI
import Combine

/// Manages application settings with UserDefaults persistence
@MainActor
@Observable
public final class SettingsManager {
    private static let settingsKey = "com.promptly.settings"

    /// Debounce interval for save operations (prevents excessive disk writes)
    private static let saveDebounceInterval: TimeInterval = 0.5

    /// The current application settings
    public var settings: AppSettings {
        didSet {
            debouncedSave()
        }
    }

    private let userDefaults: UserDefaults
    private var saveTask: Task<Void, Never>?

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.settings = Self.loadSettings(from: userDefaults)
    }

    // MARK: - Persistence

    private static func loadSettings(from userDefaults: UserDefaults) -> AppSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return AppSettings.defaults
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error). Using defaults.")
            return AppSettings.defaults
        }
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.saveDebounceInterval))
            guard !Task.isCancelled else { return }
            self?.saveSettingsImmediately()
        }
    }

    private func saveSettingsImmediately() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: Self.settingsKey)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }

    /// Forces an immediate save of settings (useful before app termination)
    public func saveImmediately() {
        saveTask?.cancel()
        saveSettingsImmediately()
    }

    /// Resets all settings to defaults
    public func resetToDefaults() {
        settings = AppSettings.defaults
    }

    // MARK: - Convenience Accessors

    /// Font size for prompter text
    public var fontSize: CGFloat {
        get { settings.fontSize }
        set { settings.fontSize = newValue }
    }

    /// Text color as SwiftUI Color
    public var textColor: Color {
        get { settings.textSwiftUIColor }
        set { settings.textColor = AppSettings.hexString(from: newValue) }
    }

    /// Background color as SwiftUI Color
    public var backgroundColor: Color {
        get { settings.backgroundSwiftUIColor }
        set { settings.backgroundColor = AppSettings.hexString(from: newValue) }
    }

    /// Background opacity
    public var backgroundOpacity: Double {
        get { settings.backgroundOpacity }
        set { settings.backgroundOpacity = newValue }
    }

    /// Scroll speed multiplier
    public var scrollSpeed: Double {
        get { settings.scrollSpeed }
        set { settings.scrollSpeed = newValue }
    }

    /// Microphone sensitivity threshold (dB)
    public var micSensitivity: Float {
        get { settings.micSensitivity }
        set { settings.micSensitivity = newValue }
    }

    /// Countdown duration
    public var countdownSeconds: CountdownDuration {
        get { settings.countdownSeconds }
        set { settings.countdownSeconds = newValue }
    }

    /// Preferred prompter mode
    public var preferredMode: PrompterMode {
        get { settings.preferredMode }
        set { settings.preferredMode = newValue }
    }

    /// Show speed indicator
    public var showSpeedIndicator: Bool {
        get { settings.showSpeedIndicator }
        set { settings.showSpeedIndicator = newValue }
    }

    /// Show progress indicator
    public var showProgressIndicator: Bool {
        get { settings.showProgressIndicator }
        set { settings.showProgressIndicator = newValue }
    }

    // MARK: - Floating Window Position

    /// Saves the floating window frame
    public func saveFloatingWindowFrame(_ frame: NSRect) {
        settings.floatingWindowX = Double(frame.origin.x)
        settings.floatingWindowY = Double(frame.origin.y)
        settings.floatingWindowWidth = Double(frame.width)
        settings.floatingWindowHeight = Double(frame.height)
    }

    /// Retrieves the saved floating window frame, if any
    public var savedFloatingWindowFrame: NSRect? {
        guard let x = settings.floatingWindowX,
              let y = settings.floatingWindowY,
              let width = settings.floatingWindowWidth,
              let height = settings.floatingWindowHeight else {
            return nil
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Clears the saved floating window position
    public func clearFloatingWindowFrame() {
        settings.floatingWindowX = nil
        settings.floatingWindowY = nil
        settings.floatingWindowWidth = nil
        settings.floatingWindowHeight = nil
    }
}

// MARK: - Testing Support

extension SettingsManager {
    /// Creates a settings manager with an ephemeral UserDefaults for testing
    public static func forTesting() -> SettingsManager {
        let suiteName = "com.promptly.test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            // Fallback to standard UserDefaults if suite creation fails
            return SettingsManager(userDefaults: .standard)
        }
        return SettingsManager(userDefaults: defaults)
    }
}

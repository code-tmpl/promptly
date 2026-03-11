import SwiftUI
import AVFoundation

/// Settings view for customizing prompter appearance and behavior
public struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var availableAudioDevices: [AudioDevice] = []

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    public var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                scrollingSection
                audioSection
                behaviorSection
                keyboardShortcutsSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close settings")
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                    .accessibilityLabel("Reset all settings to default values")
                }
            }
            .onAppear {
                loadAudioDevices()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    // MARK: - Audio Device Loading

    private func loadAudioDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        availableAudioDevices = discoverySession.devices.map { device in
            AudioDevice(id: device.uniqueID, name: device.localizedName)
        }

        // If no device is persisted, leave as nil (system default)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            // Font Size
            HStack {
                Text("Font Size")
                Spacer()
                Text("\(Int(settingsManager.fontSize)) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $settingsManager.fontSize,
                in: 16...72,
                step: 2
            )
            .accessibilityLabel("Font size")
            .accessibilityValue("\(Int(settingsManager.fontSize)) points")

            // Text Color
            ColorPicker("Text Color", selection: $settingsManager.textColor)

            // Background Color
            ColorPicker("Background Color", selection: $settingsManager.backgroundColor)

            // Background Opacity
            HStack {
                Text("Background Opacity")
                Spacer()
                Text("\(Int(settingsManager.backgroundOpacity * 100))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $settingsManager.backgroundOpacity,
                in: 0.3...1.0,
                step: 0.05
            )
            .accessibilityLabel("Background opacity")
            .accessibilityValue("\(Int(settingsManager.backgroundOpacity * 100)) percent")

            // Preview
            previewSection
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                settingsManager.backgroundColor
                    .opacity(settingsManager.backgroundOpacity)

                Text("Hello, welcome to the teleprompter...")
                    .font(.system(size: min(settingsManager.fontSize, 24)))
                    .foregroundStyle(settingsManager.textColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.quaternary)
            )
        }
    }

    // MARK: - Scrolling Section

    private var scrollingSection: some View {
        Section("Scrolling") {
            // Scroll Speed
            HStack {
                Text("Default Speed")
                Spacer()
                Text(String(format: "%.2fx", settingsManager.scrollSpeed))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: $settingsManager.scrollSpeed,
                in: 0.25...3.0,
                step: 0.25
            )
            .accessibilityLabel("Scroll speed")
            .accessibilityValue(String(format: "%.2f times normal", settingsManager.scrollSpeed))

            // Show Speed Indicator
            Toggle("Show Speed Indicator", isOn: $settingsManager.showSpeedIndicator)

            // Show Progress Indicator
            Toggle("Show Progress Indicator", isOn: $settingsManager.showProgressIndicator)
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section("Microphone") {
            // Microphone Source Picker
            if !availableAudioDevices.isEmpty {
                Picker("Audio Input", selection: $settingsManager.settings.preferredAudioDeviceID) {
                    Text("System Default").tag(nil as String?)
                    ForEach(availableAudioDevices) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }
                .pickerStyle(.menu)
            } else {
                HStack {
                    Text("Audio Input")
                    Spacer()
                    Text("No devices found")
                        .foregroundStyle(.secondary)
                }
            }

            // Mic Sensitivity
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Voice Detection Sensitivity")
                    Spacer()
                    Text("\(Int(settingsManager.micSensitivity)) dB")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { Double(settingsManager.micSensitivity) },
                        set: { settingsManager.micSensitivity = Float($0) }
                    ),
                    in: -50...(-10),
                    step: 5
                )
                .accessibilityLabel("Voice detection sensitivity")
                .accessibilityValue("\(Int(settingsManager.micSensitivity)) decibels")

                HStack {
                    Text("Less sensitive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("More sensitive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Lower values require louder speech to trigger scrolling. Adjust this if the prompter scrolls when you're not speaking.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        Section("Behavior") {
            // Countdown Duration
            Picker("Countdown Duration", selection: $settingsManager.countdownSeconds) {
                ForEach(CountdownDuration.allCases, id: \.self) { duration in
                    Text(duration.displayName).tag(duration)
                }
            }

            // Preferred Mode
            Picker("Preferred Mode", selection: $settingsManager.preferredMode) {
                ForEach(PrompterMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            // Clear floating window position
            if settingsManager.savedFloatingWindowFrame != nil {
                Button("Reset Floating Window Position") {
                    settingsManager.clearFloatingWindowFrame()
                }
            }
        }
    }

    // MARK: - Keyboard Shortcuts Section

    private var keyboardShortcutsSection: some View {
        Section("Keyboard Shortcuts") {
            shortcutRow("Start/Stop Prompting", shortcut: "⌘⏎")
            shortcutRow("Pause/Resume", shortcut: "Space")
            shortcutRow("Speed Up", shortcut: "⌘↑")
            shortcutRow("Speed Down", shortcut: "⌘↓")
            shortcutRow("Toggle Mode", shortcut: "⌘T")
            shortcutRow("New Script", shortcut: "⌘N")
            shortcutRow("Settings", shortcut: "⌘,")
        }
    }

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Promptly")
                        .font(.headline)
                    Text("Professional Teleprompter for macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Build \(buildNumber)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack {
                Text("Developer")
                Spacer()
                Text("Your Name")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Copyright")
                Spacer()
                Text("© 2025 All Rights Reserved")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Audio Device Model

struct AudioDevice: Identifiable, Hashable {
    let id: String
    let name: String
}

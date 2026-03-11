import SwiftUI

/// Settings view for customizing prompter appearance and behavior
public struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

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
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Reset to Defaults") {
                        settingsManager.resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
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
            }
            Slider(
                value: $settingsManager.fontSize,
                in: 16...72,
                step: 2
            )

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
            }
            Slider(
                value: $settingsManager.backgroundOpacity,
                in: 0.3...1.0,
                step: 0.05
            )

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
            }
            Slider(
                value: $settingsManager.scrollSpeed,
                in: 0.25...3.0,
                step: 0.25
            )

            // Show Speed Indicator
            Toggle("Show Speed Indicator", isOn: $settingsManager.showSpeedIndicator)

            // Show Progress Indicator
            Toggle("Show Progress Indicator", isOn: $settingsManager.showProgressIndicator)
        }
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        Section("Microphone") {
            // Mic Sensitivity
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Voice Detection Sensitivity")
                    Spacer()
                    Text("\(Int(settingsManager.micSensitivity)) dB")
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(settingsManager.micSensitivity) },
                        set: { settingsManager.micSensitivity = Float($0) }
                    ),
                    in: -50...(-10),
                    step: 5
                )

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
}

// MARK: - Keyboard Shortcuts Section (Future)

extension SettingsView {
    @ViewBuilder
    private var keyboardShortcutsSection: some View {
        Section("Keyboard Shortcuts") {
            shortcutRow("Start/Stop Prompting", shortcut: "⌘⏎")
            shortcutRow("Pause/Resume", shortcut: "Space")
            shortcutRow("Speed Up", shortcut: "⌘↑")
            shortcutRow("Speed Down", shortcut: "⌘↓")
            shortcutRow("Toggle Mode", shortcut: "⌘T")
            shortcutRow("Settings", shortcut: "⌘,")
            shortcutRow("New Script", shortcut: "⌘N")
        }
    }

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}


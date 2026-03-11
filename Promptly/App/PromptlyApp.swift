import SwiftUI
import AppKit
import AVFoundation

/// Main application entry point
@main
struct PromptlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.scriptStore)
                .environment(appDelegate.settingsManager)
                .environment(appDelegate.prompterViewModel)
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Script") {
                    appDelegate.scriptStore.createScript()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            // View menu
            CommandMenu("View") {
                Button("Increase Font Size") {
                    appDelegate.settingsManager.fontSize = min(72, appDelegate.settingsManager.fontSize + 2)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Font Size") {
                    appDelegate.settingsManager.fontSize = max(16, appDelegate.settingsManager.fontSize - 2)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Font Size") {
                    appDelegate.settingsManager.fontSize = AppSettings.defaults.fontSize
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Toggle("Show Speed Indicator", isOn: Binding(
                    get: { appDelegate.settingsManager.showSpeedIndicator },
                    set: { appDelegate.settingsManager.showSpeedIndicator = $0 }
                ))

                Toggle("Show Progress Indicator", isOn: Binding(
                    get: { appDelegate.settingsManager.showProgressIndicator },
                    set: { appDelegate.settingsManager.showProgressIndicator = $0 }
                ))
            }

            // Format menu
            CommandMenu("Format") {
                Menu("Text Color") {
                    Button("White") {
                        appDelegate.settingsManager.textColor = .white
                    }
                    Button("Yellow") {
                        appDelegate.settingsManager.textColor = .yellow
                    }
                    Button("Cyan") {
                        appDelegate.settingsManager.textColor = .cyan
                    }
                    Button("Green") {
                        appDelegate.settingsManager.textColor = .green
                    }
                }

                Menu("Background Color") {
                    Button("Black") {
                        appDelegate.settingsManager.backgroundColor = .black
                    }
                    Button("Dark Gray") {
                        appDelegate.settingsManager.backgroundColor = Color(white: 0.15)
                    }
                    Button("Navy") {
                        appDelegate.settingsManager.backgroundColor = Color(red: 0, green: 0, blue: 0.3)
                    }
                }

                Divider()

                Menu("Background Opacity") {
                    Button("100%") { appDelegate.settingsManager.backgroundOpacity = 1.0 }
                    Button("85%") { appDelegate.settingsManager.backgroundOpacity = 0.85 }
                    Button("70%") { appDelegate.settingsManager.backgroundOpacity = 0.70 }
                    Button("50%") { appDelegate.settingsManager.backgroundOpacity = 0.50 }
                }
            }

            // Prompter menu (after app settings)
            CommandGroup(after: .appSettings) {
                Divider()

                Button("Start Prompting") {
                    appDelegate.prompterViewModel.startPrompting()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(appDelegate.scriptStore.currentScript == nil)

                Button("Stop Prompting") {
                    appDelegate.prompterViewModel.stopPrompting()
                }
                .disabled(!appDelegate.prompterViewModel.state.isActive)

                Divider()

                Button("Toggle Mode") {
                    appDelegate.prompterViewModel.toggleMode()
                }
                .keyboardShortcut("t", modifiers: .command)

                Menu("Prompter Mode") {
                    Button("Notch Mode") {
                        appDelegate.settingsManager.preferredMode = .notch
                        if appDelegate.prompterViewModel.state.isActive {
                            appDelegate.prompterViewModel.toggleMode()
                        }
                    }
                    Button("Floating Mode") {
                        appDelegate.settingsManager.preferredMode = .floating
                        if appDelegate.prompterViewModel.state.isActive {
                            appDelegate.prompterViewModel.toggleMode()
                        }
                    }
                }

                Divider()

                Menu("Scroll Speed") {
                    Button("Very Slow (0.5x)") { appDelegate.settingsManager.scrollSpeed = 0.5 }
                    Button("Slow (0.75x)") { appDelegate.settingsManager.scrollSpeed = 0.75 }
                    Button("Normal (1.0x)") { appDelegate.settingsManager.scrollSpeed = 1.0 }
                    Button("Fast (1.5x)") { appDelegate.settingsManager.scrollSpeed = 1.5 }
                    Button("Very Fast (2.0x)") { appDelegate.settingsManager.scrollSpeed = 2.0 }
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Promptly Help") {
                    appDelegate.showHelpWindow()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Keyboard Shortcuts") {
                    appDelegate.showKeyboardShortcutsWindow()
                }
                .keyboardShortcut("/", modifiers: .command)

                Divider()

                Button("Check for Updates...") {
                    // Placeholder for update check
                }
                .disabled(true)

                Button("Report an Issue...") {
                    if let url = URL(string: "https://github.com/promptly/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            SettingsView(settingsManager: appDelegate.settingsManager)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(ScriptStore.self) private var scriptStore
    @Environment(PrompterViewModel.self) private var prompterViewModel

    var body: some View {
        EditorView(scriptStore: scriptStore, prompterViewModel: prompterViewModel)
            .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let scriptStore: ScriptStore
    let settingsManager: SettingsManager
    let prompterViewModel: PrompterViewModel
    let keyboardShortcutManager: KeyboardShortcutManager

    // Error handling
    @Published var showMicPermissionAlert = false
    @Published var showAudioErrorAlert = false
    @Published var audioErrorMessage = ""

    private var helpWindow: NSWindow?
    private var shortcutsWindow: NSWindow?

    override init() {
        self.scriptStore = ScriptStore()
        self.settingsManager = SettingsManager()
        self.prompterViewModel = PrompterViewModel(
            scriptStore: scriptStore,
            settingsManager: settingsManager
        )
        self.keyboardShortcutManager = KeyboardShortcutManager()

        super.init()

        setupKeyboardShortcuts()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request microphone permission on first launch
        requestMicrophonePermission()

        // Create initial script if none exist
        if scriptStore.scripts.isEmpty {
            scriptStore.createScript(
                title: "Welcome to Promptly",
                content: """
                Welcome to Promptly, your personal teleprompter!

                Start typing or paste your script here. When you're ready to present, press ⌘⏎ to start the prompter.

                The text will scroll automatically when you speak, and pause when you stop.

                Hover over the prompter window to pause scrolling. Use ⌘↑ and ⌘↓ to adjust speed.

                Press ⌘T to toggle between notch mode and floating mode.

                Happy presenting!
                """
            )
        }

        // Observe screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save any pending changes
        scriptStore.saveImmediately()

        // Stop audio monitoring
        prompterViewModel.stopPrompting()

        // Stop keyboard monitoring
        keyboardShortcutManager.stopMonitoring()

        // Remove observers
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Screen Change Handling

    @objc private func screenParametersDidChange(_ notification: Notification) {
        // Reposition prompter window if active
        if prompterViewModel.state.isActive {
            // Brief delay to let screen changes settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                // The window controller will handle repositioning on next frame
            }
        }
    }

    // MARK: - Help Windows

    func showHelpWindow() {
        if helpWindow == nil {
            let helpView = HelpView()
            let hostingController = NSHostingController(rootView: helpView)

            helpWindow = NSWindow(contentViewController: hostingController)
            helpWindow?.title = "Promptly Help"
            helpWindow?.styleMask = [.titled, .closable, .miniaturizable]
            helpWindow?.setContentSize(NSSize(width: 500, height: 400))
            helpWindow?.center()
        }

        helpWindow?.makeKeyAndOrderFront(nil)
    }

    func showKeyboardShortcutsWindow() {
        if shortcutsWindow == nil {
            let shortcutsView = KeyboardShortcutsView()
            let hostingController = NSHostingController(rootView: shortcutsView)

            shortcutsWindow = NSWindow(contentViewController: hostingController)
            shortcutsWindow?.title = "Keyboard Shortcuts"
            shortcutsWindow?.styleMask = [.titled, .closable]
            shortcutsWindow?.setContentSize(NSSize(width: 400, height: 350))
            shortcutsWindow?.center()
        }

        shortcutsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Private

    private func setupKeyboardShortcuts() {
        keyboardShortcutManager.onShortcut = { [weak self] shortcut in
            self?.prompterViewModel.handleKeyboardShortcut(shortcut)
        }
        keyboardShortcutManager.startMonitoring()
    }

    private func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    if granted {
                        print("Microphone access granted")
                    } else {
                        print("Microphone access denied")
                        self.showMicPermissionDeniedAlert()
                    }
                }
            }
        case .restricted, .denied:
            print("Microphone access restricted or denied")
            showMicPermissionDeniedAlert()
        case .authorized:
            print("Microphone access already authorized")
        @unknown default:
            break
        }
    }

    private func showMicPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "Promptly needs microphone access to detect when you're speaking and automatically scroll the teleprompter. Please grant access in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Getting Started with Promptly")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    helpSection(
                        title: "Creating Scripts",
                        content: "Click the + button in the sidebar or press ⌘N to create a new script. Type or paste your presentation text in the editor."
                    )

                    helpSection(
                        title: "Starting the Teleprompter",
                        content: "Press ⌘⏎ or click 'Start Prompting' to begin. A countdown will appear, then your script will start scrolling."
                    )

                    helpSection(
                        title: "Voice-Activated Scrolling",
                        content: "The prompter scrolls automatically when you speak. When you pause, the scrolling pauses too. Adjust sensitivity in Settings if needed."
                    )

                    helpSection(
                        title: "Prompter Modes",
                        content: "Notch Mode: Positions text at the top of your screen near the camera for eye contact.\nFloating Mode: A resizable window you can position anywhere."
                    )

                    helpSection(
                        title: "Tips",
                        content: "• Hover over the prompter to pause\n• Use ⌘↑/⌘↓ to adjust speed\n• The prompter is invisible to screen recordings"
                    )
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Keyboard Shortcuts View

struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            List {
                Section("General") {
                    shortcutRow("New Script", "⌘N")
                    shortcutRow("Settings", "⌘,")
                    shortcutRow("Help", "⌘?")
                }

                Section("Teleprompter") {
                    shortcutRow("Start/Stop", "⌘⏎")
                    shortcutRow("Pause/Resume", "Space")
                    shortcutRow("Speed Up", "⌘↑")
                    shortcutRow("Speed Down", "⌘↓")
                    shortcutRow("Toggle Mode", "⌘T")
                }

                Section("View") {
                    shortcutRow("Increase Font", "⌘+")
                    shortcutRow("Decrease Font", "⌘-")
                    shortcutRow("Reset Font", "⌘0")
                }
            }
            .listStyle(.inset)
        }
    }

    private func shortcutRow(_ action: String, _ shortcut: String) -> some View {
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
}

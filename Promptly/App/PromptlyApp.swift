import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

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

                Divider()

                Button("Open...") {
                    appDelegate.importScript()
                }
                .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save As...") {
                    appDelegate.exportCurrentScript()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appDelegate.scriptStore.currentScript == nil)

                Button("Export as Plain Text...") {
                    appDelegate.exportCurrentScriptAsText()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appDelegate.scriptStore.currentScript == nil)
            }

            // Undo/Redo support
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(#selector(UndoManager.redo), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Select All") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            // View menu items (appended to default View menu)
            CommandGroup(after: .toolbar) {
                Divider()
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

            // Window menu
            CommandGroup(after: .windowArrangement) {
                Divider()

                Button("Minimize") {
                    NSApp.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("Zoom") {
                    NSApp.keyWindow?.zoom(nil)
                }

                Divider()

                Button("Bring All to Front") {
                    NSApp.arrangeInFront(nil)
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

            // About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About Promptly") {
                    appDelegate.showAboutPanel()
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

    /// Key for tracking first launch in UserDefaults
    private static let hasLaunchedBeforeKey = "com.promptly.hasLaunchedBefore"

    // Error handling
    @Published var showMicPermissionAlert = false
    @Published var showAudioErrorAlert = false
    @Published var audioErrorMessage = ""

    private var helpWindow: NSWindow?
    private var shortcutsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

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
        // Check if this is first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: Self.hasLaunchedBeforeKey)

        if !hasLaunchedBefore {
            // Show onboarding
            showOnboardingWindow()
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedBeforeKey)
        }

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

        // Observe app becoming active for mic permission check
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save any pending changes
        scriptStore.saveImmediately()
        settingsManager.saveImmediately()

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
                guard let self else { return }
                // Restart prompting to reposition window on potentially new screen
                if self.prompterViewModel.state.isActive {
                    self.prompterViewModel.stopPrompting()
                    self.prompterViewModel.startPrompting()
                }
            }
        }
    }

    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // Re-check microphone permission when app becomes active
        // This handles the case where user granted permission in System Settings
        checkMicrophonePermission()
    }

    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            // If prompting is active and permission was revoked, stop
            if prompterViewModel.state.isActive {
                prompterViewModel.stopPrompting()
                prompterViewModel.showError(.microphonePermissionDenied)
            }
        }
    }

    // MARK: - Import/Export

    /// Imports a script from a text file
    func importScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.title = "Open Script"
        panel.message = "Select a text file to import as a script"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor [weak self] in
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let title = url.deletingPathExtension().lastPathComponent
                    self?.scriptStore.createScript(title: title, content: content)
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Import Failed"
                    alert.informativeText = "Could not read the file: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    /// Exports the current script to a file
    func exportCurrentScript() {
        guard let script = scriptStore.currentScript else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(script.title).txt"
        panel.title = "Save Script As"
        panel.message = "Choose a location to save your script"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try script.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                Task { @MainActor in
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not save the file: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    /// Exports the current script as plain text
    func exportCurrentScriptAsText() {
        exportCurrentScript()
    }

    // MARK: - About Panel

    func showAboutPanel() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let creditsText = """
        Professional teleprompter for macOS.

        Designed for seamless presentations with voice-activated scrolling and screen-share invisible windows.

        © 2025 All Rights Reserved
        """
        let credits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Promptly",
            .applicationVersion: appVersion,
            .version: buildNumber,
            .credits: credits
        ]

        NSApp.orderFrontStandardAboutPanel(options: options)
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

    // MARK: - Onboarding

    func showOnboardingWindow() {
        if onboardingWindow == nil {
            let onboardingView = OnboardingView { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
            let hostingController = NSHostingController(rootView: onboardingView)

            onboardingWindow = NSWindow(contentViewController: hostingController)
            onboardingWindow?.title = "Welcome to Promptly"
            onboardingWindow?.styleMask = [.titled, .closable]
            onboardingWindow?.setContentSize(NSSize(width: 550, height: 500))
            onboardingWindow?.center()
        }

        onboardingWindow?.makeKeyAndOrderFront(nil)
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
            // Use async overload to avoid @MainActor capture in background callback
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                    self.showMicPermissionDeniedAlert()
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

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    private let pages: [(title: String, description: String, systemImage: String)] = [
        (
            title: "Welcome to Promptly",
            description: "Your professional teleprompter for macOS. Create scripts, start prompting, and deliver seamless presentations.",
            systemImage: "play.rectangle.fill"
        ),
        (
            title: "Voice-Activated Scrolling",
            description: "Promptly listens to your voice and scrolls automatically when you speak. When you pause, the scrolling pauses too.",
            systemImage: "waveform"
        ),
        (
            title: "Microphone Permission",
            description: "Promptly needs microphone access to detect your voice. You'll be prompted to grant access. This is required for voice-activated scrolling.",
            systemImage: "mic.fill"
        ),
        (
            title: "Notch & Floating Modes",
            description: "Position text at the top of your screen near the camera (Notch Mode) or use a floating window you can place anywhere (Floating Mode).",
            systemImage: "macwindow"
        ),
        (
            title: "Screen-Share Invisible",
            description: "The prompter window is invisible to screen recordings and screen sharing. Your audience only sees you, not the script.",
            systemImage: "eye.slash.fill"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        Spacer()

                        Image(systemName: page.systemImage)
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)

                        Text(page.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(page.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)

                        Spacer()
                    }
                    .padding(32)
                    .tag(index)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(page.title). \(page.description)")
                }
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }

                Spacer()

                // Navigation buttons
                HStack(spacing: 12) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Go to previous page")
                    }

                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Go to next page")
                    } else {
                        Button("Get Started") {
                            onComplete()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Complete onboarding and start using Promptly")
                    }
                }
            }
            .padding(20)
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
        .accessibilityElement(children: .contain)
    }

    private func helpSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
                    shortcutRow("Open...", "⌘O")
                    shortcutRow("Save As...", "⇧⌘S")
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

                Section("Edit") {
                    shortcutRow("Undo", "⌘Z")
                    shortcutRow("Redo", "⇧⌘Z")
                    shortcutRow("Cut", "⌘X")
                    shortcutRow("Copy", "⌘C")
                    shortcutRow("Paste", "⌘V")
                    shortcutRow("Select All", "⌘A")
                }
            }
            .listStyle(.inset)
        }
        .accessibilityElement(children: .contain)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action), keyboard shortcut \(shortcut)")
    }
}

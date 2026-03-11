import SwiftUI
import AppKit

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
            CommandGroup(replacing: .newItem) {
                Button("New Script") {
                    appDelegate.scriptStore.createScript()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save any pending changes
        scriptStore.saveImmediately()

        // Stop audio monitoring
        prompterViewModel.stopPrompting()

        // Stop keyboard monitoring
        keyboardShortcutManager.stopMonitoring()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                }
            }
        case .restricted, .denied:
            print("Microphone access restricted or denied")
        case .authorized:
            print("Microphone access already authorized")
        @unknown default:
            break
        }
    }
}

// MARK: - AVCaptureDevice Import

import AVFoundation

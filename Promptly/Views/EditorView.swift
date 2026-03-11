import SwiftUI

/// Main editor view with script list sidebar and text editor
public struct EditorView: View {
    @Bindable var scriptStore: ScriptStore
    @Bindable var prompterViewModel: PrompterViewModel

    @State private var isShowingSettings = false
    @State private var isShowingDeleteConfirmation = false
    @State private var scriptToDelete: Script?
    @State private var isRenaming = false
    @State private var renameText = ""

    public init(scriptStore: ScriptStore, prompterViewModel: PrompterViewModel) {
        self.scriptStore = scriptStore
        self.prompterViewModel = prompterViewModel
    }

    public var body: some View {
        NavigationSplitView {
            scriptListSidebar
        } detail: {
            scriptEditor
        }
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(settingsManager: prompterViewModel.settingsManager)
        }
        .alert("Delete Script?", isPresented: $isShowingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                scriptToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let script = scriptToDelete {
                    scriptStore.deleteScript(script)
                }
                scriptToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Sidebar

    private var scriptListSidebar: some View {
        List(selection: Binding(
            get: { scriptStore.currentScript?.id },
            set: { id in
                if let id, let script = scriptStore.scripts.first(where: { $0.id == id }) {
                    scriptStore.selectScript(script)
                }
            }
        )) {
            ForEach(scriptStore.scripts) { script in
                scriptRow(script)
                    .tag(script.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Scripts")
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewScript) {
                    Image(systemName: "plus")
                }
                .help("New Script (⌘N)")
            }
        }
    }

    private func scriptRow(_ script: Script) -> some View {
        HStack {
            if isRenaming && scriptStore.currentScript?.id == script.id {
                TextField("Title", text: $renameText, onCommit: commitRename)
                    .textFieldStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(script.title)
                        .font(.headline)
                    Text("\(script.wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button("Rename") {
                startRenaming(script)
            }
            Divider()
            Button("Delete", role: .destructive) {
                scriptToDelete = script
                isShowingDeleteConfirmation = true
            }
        }
    }

    private func startRenaming(_ script: Script) {
        scriptStore.selectScript(script)
        renameText = script.title
        isRenaming = true
    }

    private func commitRename() {
        if let script = scriptStore.currentScript, !renameText.isEmpty {
            scriptStore.renameScript(script, to: renameText)
        }
        isRenaming = false
        renameText = ""
    }

    // MARK: - Editor

    @ViewBuilder
    private var scriptEditor: some View {
        if let script = scriptStore.currentScript {
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text(script.title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    scriptStats(script)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Text editor
                TextEditor(text: Binding(
                    get: { script.content },
                    set: { newContent in
                        scriptStore.updateContent(of: script, to: newContent)
                    }
                ))
                .font(.system(size: 16))
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            emptyState
        }
    }

    private func scriptStats(_ script: Script) -> some View {
        HStack(spacing: 16) {
            Label("\(script.wordCount) words", systemImage: "text.word.spacing")
                .font(.caption)
                .foregroundStyle(.secondary)

            Label("\(script.characterCount) chars", systemImage: "character")
                .font(.caption)
                .foregroundStyle(.secondary)

            if script.estimatedReadingMinutes >= 1 {
                Label(String(format: "~%.0f min", script.estimatedReadingMinutes), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if scriptStore.isSaving {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Script Selected")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Create a new script or select one from the sidebar")
                .font(.body)
                .foregroundStyle(.tertiary)

            Button("Create New Script") {
                createNewScript()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: startPrompting) {
                Label("Start Prompting", systemImage: "play.fill")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(scriptStore.currentScript == nil)
            .help("Start Prompting (⌘⏎)")

            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings (⌘,)")
        }
    }

    // MARK: - Actions

    private func createNewScript() {
        scriptStore.createScript()
    }

    private func startPrompting() {
        prompterViewModel.startPrompting()
    }
}


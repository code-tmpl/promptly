import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Sorting options for the script list
internal enum ScriptSortOption: String, CaseIterable {
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case name = "Name"
    case wordCount = "Word Count"
}

/// Main editor view with script list sidebar and text editor
public struct EditorView: View {
    @Bindable var scriptStore: ScriptStore
    @Bindable var prompterViewModel: PrompterViewModel

    @State private var isShowingSettings = false
    @State private var isShowingDeleteConfirmation = false
    @State private var scriptToDelete: Script?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var searchText = ""
    @State private var sortOption: ScriptSortOption = .dateModified
    @State private var sortAscending = false
    @State private var selectedScriptID: UUID?
    @State private var editorContent: String = ""
    @State private var lastEditedScriptID: UUID?

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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scriptStore.deleteScript(script)
                    }
                }
                scriptToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        // Error alert from PrompterViewModel
        .alert(
            "Error",
            isPresented: $prompterViewModel.showErrorAlert,
            presenting: prompterViewModel.currentError
        ) { error in
            if error.canOpenSettings {
                Button("Open System Settings") {
                    openMicrophoneSettings()
                    prompterViewModel.clearError()
                }
                Button("Cancel", role: .cancel) {
                    prompterViewModel.clearError()
                }
            } else {
                Button("OK", role: .cancel) {
                    prompterViewModel.clearError()
                }
            }
        } message: { error in
            VStack {
                if let description = error.errorDescription {
                    Text(description)
                }
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                }
            }
        }
        // Script save error alert
        .alert(
            "Save Error",
            isPresented: Binding(
                get: { scriptStore.errorMessage != nil },
                set: { if !$0 { scriptStore.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                scriptStore.errorMessage = nil
            }
        } message: {
            if let errorMessage = scriptStore.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            syncEditorContent()
        }
        .onChange(of: scriptStore.currentScript?.id) { _, newID in
            syncEditorContent()
        }
    }

    /// Syncs the local editor content with the current script
    private func syncEditorContent() {
        let currentID = scriptStore.currentScript?.id
        if lastEditedScriptID != currentID {
            editorContent = scriptStore.currentScript?.content ?? ""
            lastEditedScriptID = currentID
        }
    }

    // MARK: - Filtered and Sorted Scripts

    private var filteredAndSortedScripts: [Script] {
        var scripts = scriptStore.scripts

        // Apply search filter
        if !searchText.isEmpty {
            scripts = scripts.filter { script in
                script.title.localizedCaseInsensitiveContains(searchText) ||
                script.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sorting
        scripts.sort { lhs, rhs in
            let comparison: Bool
            switch sortOption {
            case .dateModified:
                comparison = lhs.updatedAt > rhs.updatedAt
            case .dateCreated:
                comparison = lhs.createdAt > rhs.createdAt
            case .name:
                comparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .wordCount:
                comparison = lhs.wordCount > rhs.wordCount
            }
            return sortAscending ? !comparison : comparison
        }

        return scripts
    }

    // MARK: - Sidebar

    private var scriptListSidebar: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search scripts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search scripts")
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Sort options
            HStack {
                Menu {
                    ForEach(ScriptSortOption.allCases, id: \.self) { option in
                        Button(action: { sortOption = option }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button(action: { sortAscending.toggle() }) {
                        HStack {
                            Text(sortAscending ? "Ascending" : "Descending")
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOption.rawValue)
                            .font(.caption)
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Text("\(filteredAndSortedScripts.count) scripts")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Script list
            if filteredAndSortedScripts.isEmpty {
                emptyListState
            } else {
                List(selection: Binding(
                    get: { selectedScriptID },
                    set: { id in
                        if let id, let script = scriptStore.scripts.first(where: { $0.id == id }) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScriptID = id
                                scriptStore.selectScript(script)
                            }
                        }
                    }
                )) {
                    ForEach(filteredAndSortedScripts) { script in
                        scriptRow(script)
                            .tag(script.id)
                    }
                    .onMove(perform: moveScripts)
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Scripts")
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewScript) {
                    Image(systemName: "plus")
                }
                .help("New Script (⌘N)")
                .accessibilityLabel("Create new script")
            }
        }
    }

    private var emptyListState: some View {
        VStack(spacing: 16) {
            Spacer()

            if searchText.isEmpty {
                // No scripts at all
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.quaternary)

                Text("No Scripts Yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Create your first script to get started with teleprompter presentations.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: createNewScript) {
                    Label("Create Script", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                // No search results
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.quaternary)

                Text("No Results")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("No scripts match \"\(searchText)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button(action: { searchText = "" }) {
                    Text("Clear Search")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func scriptRow(_ script: Script) -> some View {
        HStack {
            if isRenaming && scriptStore.currentScript?.id == script.id {
                TextField("Title", text: $renameText, onCommit: commitRename)
                    .textFieldStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.title)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(script.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(script.updatedAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedScriptID == script.id ? Color.accentColor.opacity(0.15) : Color.clear)
                .animation(.easeInOut(duration: 0.15), value: selectedScriptID)
        )
        .contextMenu {
            Button("Rename") {
                startRenaming(script)
            }
            Divider()
            Button("Duplicate") {
                duplicateScript(script)
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

    private func duplicateScript(_ script: Script) {
        scriptStore.createScript(
            title: "\(script.title) (Copy)",
            content: script.content
        )
    }

    private func moveScripts(from source: IndexSet, to destination: Int) {
        // Note: This is for visual feedback; the actual order is determined by sort option
        // In a future version, we could add a "manual" sort option that respects drag order
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

                // Text editor with stable @State binding to prevent cursor reset
                TextEditor(text: $editorContent)
                    .font(.system(size: 16))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: editorContent) { _, newContent in
                        // Sync changes back to the store
                        // Fetch the CURRENT script from the store (not the stale struct snapshot)
                        // to avoid overwriting title changes with old data
                        if let currentScript = scriptStore.scripts.first(where: { $0.id == lastEditedScriptID }) {
                            scriptStore.updateContent(of: currentScript, to: newContent)
                        }
                    }
                    .accessibilityLabel("Script editor")
                    .accessibilityHint("Edit your script text here")
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
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Saving...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: scriptStore.isSaving)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

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
            .accessibilityLabel("Create new script")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
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
            .accessibilityLabel("Start prompting")
            .accessibilityHint("Starts the teleprompter with the current script")

            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings (⌘,)")
            .accessibilityLabel("Open settings")
        }
    }

    // MARK: - Actions

    private func createNewScript() {
        withAnimation(.easeInOut(duration: 0.25)) {
            scriptStore.createScript()
            selectedScriptID = scriptStore.currentScript?.id
        }
    }

    private func startPrompting() {
        prompterViewModel.startPrompting()
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

import Foundation
import Combine

/// Manages script persistence to ~/Library/Application Support/Promptly/
@MainActor
@Observable
public final class ScriptStore {
    /// All loaded scripts
    public private(set) var scripts: [Script] = []

    /// Currently selected script for editing/prompting
    public var currentScript: Script?

    /// Error message if any operation failed
    public var errorMessage: String?

    /// Whether a save operation is pending
    public private(set) var isSaving: Bool = false

    private let fileManager = FileManager.default
    private var saveTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval

    /// The directory where scripts are stored
    public var storageDirectory: URL {
        didSet {
            createStorageDirectoryIfNeeded()
        }
    }

    public init(
        storageDirectory: URL? = nil,
        debounceInterval: TimeInterval = 1.0
    ) {
        self.debounceInterval = debounceInterval

        if let customDir = storageDirectory {
            self.storageDirectory = customDir
        } else if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.storageDirectory = appSupport.appendingPathComponent("Promptly", isDirectory: true)
        } else {
            // Fallback to temporary directory if Application Support is unavailable
            self.storageDirectory = fileManager.temporaryDirectory.appendingPathComponent("Promptly", isDirectory: true)
        }

        createStorageDirectoryIfNeeded()
        loadScripts()
    }

    // MARK: - Public API

    /// Creates a new script and selects it
    public func createScript(title: String = "Untitled Script", content: String = "") {
        let script = Script(title: title, content: content)
        scripts.insert(script, at: 0)
        currentScript = script
        saveScript(script)
    }

    /// Updates an existing script with debounced save
    public func updateScript(_ script: Script) {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
            if currentScript?.id == script.id {
                currentScript = script
            }
            debouncedSave(script)
        }
    }

    /// Renames a script
    public func renameScript(_ script: Script, to newTitle: String) {
        let updated = script.withUpdatedTitle(newTitle)
        updateScript(updated)
    }

    /// Updates script content
    public func updateContent(of script: Script, to newContent: String) {
        let updated = script.withUpdatedContent(newContent)
        updateScript(updated)
    }

    /// Deletes a script
    public func deleteScript(_ script: Script) {
        scripts.removeAll { $0.id == script.id }
        if currentScript?.id == script.id {
            currentScript = scripts.first
        }
        deleteScriptFile(script)
    }

    /// Selects a script for editing/prompting
    public func selectScript(_ script: Script) {
        currentScript = script
    }

    /// Reloads scripts from disk
    public func reload() {
        loadScripts()
    }

    /// Immediately saves all pending changes
    public func saveImmediately() {
        saveTask?.cancel()
        for script in scripts {
            saveScriptToDisk(script)
        }
    }

    // MARK: - Private Implementation

    private func createStorageDirectoryIfNeeded() {
        do {
            if !fileManager.fileExists(atPath: storageDirectory.path) {
                try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            }
        } catch {
            errorMessage = "Failed to create storage directory: \(error.localizedDescription)"
        }
    }

    private func loadScripts() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ).filter { $0.pathExtension == "json" }

            var loadedScripts: [Script] = []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for url in fileURLs {
                do {
                    let data = try Data(contentsOf: url)
                    let script = try decoder.decode(Script.self, from: data)
                    loadedScripts.append(script)
                } catch {
                    // Skip malformed files but log the error
                    print("Failed to load script at \(url): \(error)")
                }
            }

            // Sort by most recently updated
            scripts = loadedScripts.sorted { $0.updatedAt > $1.updatedAt }

            // Select the first script if none selected
            if currentScript == nil {
                currentScript = scripts.first
            }

            errorMessage = nil
        } catch {
            errorMessage = "Failed to load scripts: \(error.localizedDescription)"
        }
    }

    private func saveScript(_ script: Script) {
        saveScriptToDisk(script)
    }

    private func debouncedSave(_ script: Script) {
        saveTask?.cancel()
        isSaving = true

        saveTask = Task { [weak self, debounceInterval] in
            try? await Task.sleep(for: .seconds(debounceInterval))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.saveScriptToDisk(script)
                self?.isSaving = false
            }
        }
    }

    private func saveScriptToDisk(_ script: Script) {
        let url = storageDirectory.appendingPathComponent("\(script.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(script)
            try data.write(to: url, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to save script: \(error.localizedDescription)"
        }
    }

    private func deleteScriptFile(_ script: Script) {
        let url = storageDirectory.appendingPathComponent("\(script.id.uuidString).json")

        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete script: \(error.localizedDescription)"
        }
    }
}

// MARK: - Script Store for Testing

extension ScriptStore {
    /// Creates a store with a temporary directory for testing
    public static func forTesting() -> ScriptStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptlyTests-\(UUID().uuidString)", isDirectory: true)
        return ScriptStore(storageDirectory: tempDir, debounceInterval: 0)
    }
}

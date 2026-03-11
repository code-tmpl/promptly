import XCTest
@testable import Promptly

@MainActor
final class ScriptStoreTests: XCTestCase {

    private func createTempStore() -> (ScriptStore, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptlyTests-\(UUID().uuidString)", isDirectory: true)
        let store = ScriptStore(storageDirectory: tempDir, debounceInterval: 0)
        return (store, tempDir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func testCreateScript() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        XCTAssertTrue(store.scripts.isEmpty)

        store.createScript(title: "Test Script", content: "Test content")

        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertEqual(store.scripts.first?.title, "Test Script")
        XCTAssertEqual(store.scripts.first?.content, "Test content")
        XCTAssertEqual(store.currentScript?.title, "Test Script")
    }

    func testCreateMultipleScripts() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Script 1")
        store.createScript(title: "Script 2")
        store.createScript(title: "Script 3")

        XCTAssertEqual(store.scripts.count, 3)
        // Most recent should be first
        XCTAssertEqual(store.scripts.first?.title, "Script 3")
    }

    func testDeleteScript() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Script to delete")
        let scriptToDelete = store.scripts.first!

        store.deleteScript(scriptToDelete)

        XCTAssertTrue(store.scripts.isEmpty)
        XCTAssertNil(store.currentScript)
    }

    func testDeleteCurrentScriptSelectsAnother() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Script 1")
        store.createScript(title: "Script 2")

        let currentScript = store.currentScript!
        store.deleteScript(currentScript)

        XCTAssertEqual(store.scripts.count, 1)
        XCTAssertNotNil(store.currentScript)
        XCTAssertEqual(store.currentScript?.title, "Script 1")
    }

    func testRenameScript() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Original Title")
        let script = store.scripts.first!

        store.renameScript(script, to: "New Title")

        XCTAssertEqual(store.scripts.first?.title, "New Title")
    }

    func testUpdateContent() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Test", content: "Original content")
        let script = store.scripts.first!

        store.updateContent(of: script, to: "Updated content")

        XCTAssertEqual(store.scripts.first?.content, "Updated content")
    }

    func testSelectScript() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Script 1")
        store.createScript(title: "Script 2")

        let script1 = store.scripts.first { $0.title == "Script 1" }!

        store.selectScript(script1)

        XCTAssertEqual(store.currentScript?.title, "Script 1")
    }

    func testPersistence() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptlyTests-\(UUID().uuidString)", isDirectory: true)
        defer { cleanup(tempDir) }

        // Create and save scripts
        do {
            let store = ScriptStore(storageDirectory: tempDir, debounceInterval: 0)
            store.createScript(title: "Persisted Script", content: "Persisted content")
            store.saveImmediately()
        }

        // Small delay to ensure file is written
        try await Task.sleep(for: .milliseconds(100))

        // Reload scripts in new store
        let newStore = ScriptStore(storageDirectory: tempDir, debounceInterval: 0)

        XCTAssertEqual(newStore.scripts.count, 1)
        XCTAssertEqual(newStore.scripts.first?.title, "Persisted Script")
        XCTAssertEqual(newStore.scripts.first?.content, "Persisted content")
    }

    func testFileDeletion() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptlyTests-\(UUID().uuidString)", isDirectory: true)
        defer { cleanup(tempDir) }

        let store = ScriptStore(storageDirectory: tempDir, debounceInterval: 0)
        store.createScript(title: "Script to delete")
        store.saveImmediately()

        try await Task.sleep(for: .milliseconds(50))

        // Verify file exists
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)

        // Delete script
        store.deleteScript(store.scripts.first!)

        try await Task.sleep(for: .milliseconds(50))

        // Verify file is removed
        let filesAfter = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(filesAfter.isEmpty)
    }

    func testUpdateScriptUpdatesCurrentScript() {
        let (store, tempDir) = createTempStore()
        defer { cleanup(tempDir) }

        store.createScript(title: "Test", content: "Original")
        let script = store.currentScript!

        store.updateContent(of: script, to: "Updated")

        XCTAssertEqual(store.currentScript?.content, "Updated")
    }

    func testStorageDirectoryCreation() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptlyTests-\(UUID().uuidString)", isDirectory: true)
        defer { cleanup(tempDir) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))

        _ = ScriptStore(storageDirectory: tempDir, debounceInterval: 0)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }

    func testForTestingFactory() {
        let store = ScriptStore.forTesting()
        XCTAssertTrue(store.scripts.isEmpty)

        // Verify it uses a temp directory
        store.createScript(title: "Test")
        XCTAssertEqual(store.scripts.count, 1)
    }
}

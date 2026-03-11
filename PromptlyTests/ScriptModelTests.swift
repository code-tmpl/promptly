import XCTest
@testable import Promptly

final class ScriptModelTests: XCTestCase {

    func testDefaultCreation() {
        let script = Script()

        XCTAssertEqual(script.title, "Untitled Script")
        XCTAssertTrue(script.content.isEmpty)
    }

    func testCustomCreation() {
        let id = UUID()
        let title = "Test Script"
        let content = "Hello, world!"
        let created = Date()
        let updated = Date()

        let script = Script(
            id: id,
            title: title,
            content: content,
            createdAt: created,
            updatedAt: updated
        )

        XCTAssertEqual(script.id, id)
        XCTAssertEqual(script.title, title)
        XCTAssertEqual(script.content, content)
        XCTAssertEqual(script.createdAt, created)
        XCTAssertEqual(script.updatedAt, updated)
    }

    func testWordCount() {
        let script = Script(content: "Hello world this is a test")
        XCTAssertEqual(script.wordCount, 6)

        let emptyScript = Script(content: "")
        XCTAssertEqual(emptyScript.wordCount, 0)

        let multilineScript = Script(content: "Line one\nLine two\nLine three")
        XCTAssertEqual(multilineScript.wordCount, 6)
    }

    func testCharacterCount() {
        let script = Script(content: "Hello")
        XCTAssertEqual(script.characterCount, 5)

        let emptyScript = Script(content: "")
        XCTAssertEqual(emptyScript.characterCount, 0)
    }

    func testEstimatedReadingMinutes() {
        // 150 words = 1 minute at 150 wpm
        let words = Array(repeating: "word", count: 150).joined(separator: " ")
        let script = Script(content: words)

        XCTAssertEqual(script.estimatedReadingMinutes, 1.0)
    }

    func testWithUpdatedContent() async throws {
        let original = Script(content: "Original content")
        let originalUpdatedAt = original.updatedAt

        // Small delay to ensure different timestamp
        try await Task.sleep(for: .milliseconds(10))

        let updated = original.withUpdatedContent("New content")

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.content, "New content")
        XCTAssertGreaterThan(updated.updatedAt, originalUpdatedAt)
        XCTAssertEqual(updated.createdAt, original.createdAt)
    }

    func testWithUpdatedTitle() async throws {
        let original = Script(title: "Original Title")
        let originalUpdatedAt = original.updatedAt

        try await Task.sleep(for: .milliseconds(10))

        let updated = original.withUpdatedTitle("New Title")

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.title, "New Title")
        XCTAssertGreaterThan(updated.updatedAt, originalUpdatedAt)
    }

    func testEquality() {
        let id = UUID()
        let date = Date()

        let script1 = Script(id: id, title: "Test", content: "Content", createdAt: date, updatedAt: date)
        let script2 = Script(id: id, title: "Test", content: "Content", createdAt: date, updatedAt: date)
        let script3 = Script(title: "Test", content: "Content")

        XCTAssertEqual(script1, script2)
        XCTAssertNotEqual(script1, script3)
    }

    func testCodable() throws {
        let date = Date(timeIntervalSince1970: 1000000000)
        let original = Script(
            id: UUID(),
            title: "Test Script",
            content: "This is test content",
            createdAt: date,
            updatedAt: date
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Script.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testHashable() {
        let script1 = Script(title: "Test")
        let script2 = Script(title: "Test")

        var set = Set<Script>()
        set.insert(script1)
        set.insert(script2)

        XCTAssertEqual(set.count, 2) // Different IDs means different hashes
    }

    func testSampleScript() {
        let sample = Script.sample
        XCTAssertFalse(sample.title.isEmpty)
        XCTAssertFalse(sample.content.isEmpty)
        XCTAssertGreaterThan(sample.wordCount, 0)
    }
}

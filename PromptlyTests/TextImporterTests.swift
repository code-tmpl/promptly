import XCTest
@testable import Promptly

final class TextImporterTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextImporterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    // MARK: - Plain Text Tests

    func testExtractTextFromPlainTextFile() throws {
        let content = "Hello, this is a test script.\nLine two."
        let fileURL = tempDirectory.appendingPathComponent("test_script.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.title, "test_script")
        XCTAssertEqual(result.content, content)
    }

    func testExtractTextFromMarkdownFile() throws {
        let content = """
        # My Script

        This is **bold** text and *italic* text.

        - Point one
        - Point two
        """
        let fileURL = tempDirectory.appendingPathComponent("presentation.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.title, "presentation")
        XCTAssertEqual(result.content, content)
    }

    func testMarkdownIsImportedAsIs() throws {
        // Markdown should be imported as plain text without any parsing
        let markdownContent = "# Header\n\n**Bold** and _italic_"
        let fileURL = tempDirectory.appendingPathComponent("markdown.md")
        try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        // Content should be unchanged - no markdown parsing
        XCTAssertEqual(result.content, markdownContent)
        XCTAssertTrue(result.content.contains("#"))
        XCTAssertTrue(result.content.contains("**"))
        XCTAssertTrue(result.content.contains("_"))
    }

    // MARK: - RTF Tests

    func testExtractTextFromRTFData() throws {
        // Create RTF data with formatting
        let rtfString = #"{\rtf1\ansi\deff0 {\fonttbl {\f0 Times New Roman;}} \f0\fs24 Hello World with \b bold\b0  and \i italic\i0  text.}"#
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let plainText = try TextImporter.extractTextFromRTFData(rtfData)

        // RTF formatting should be stripped, leaving plain text
        XCTAssertTrue(plainText.contains("Hello World"))
        XCTAssertTrue(plainText.contains("bold"))
        XCTAssertTrue(plainText.contains("italic"))
        // Should not contain RTF markup
        XCTAssertFalse(plainText.contains("\\rtf"))
        XCTAssertFalse(plainText.contains("\\b"))
        XCTAssertFalse(plainText.contains("\\i"))
    }

    func testExtractTextFromRTFFile() throws {
        // Create a simple RTF file
        let rtfContent = #"{\rtf1\ansi\deff0 This is plain text from an RTF file.}"#
        let fileURL = tempDirectory.appendingPathComponent("document.rtf")
        try rtfContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.title, "document")
        XCTAssertTrue(result.content.contains("This is plain text from an RTF file"))
        // Should not contain RTF markup
        XCTAssertFalse(result.content.contains("\\rtf"))
    }

    func testRTFFormattingIsStripped() throws {
        // More complex RTF with various formatting
        let rtfString = #"{\rtf1\ansi {\fonttbl {\f0 Helvetica;}} \f0\fs28\cf1 Welcome to the presentation.\par \b Key Points:\b0\par - First point\par - Second point}"#
        guard let rtfData = rtfString.data(using: .utf8) else {
            XCTFail("Failed to create RTF data")
            return
        }

        let plainText = try TextImporter.extractTextFromRTFData(rtfData)

        XCTAssertTrue(plainText.contains("Welcome to the presentation"))
        XCTAssertTrue(plainText.contains("Key Points"))
        XCTAssertTrue(plainText.contains("First point"))
        // No formatting codes should remain
        XCTAssertFalse(plainText.contains("\\par"))
        XCTAssertFalse(plainText.contains("\\f0"))
    }

    // MARK: - Error Handling Tests

    func testFileNotFoundError() {
        let nonExistentURL = tempDirectory.appendingPathComponent("does_not_exist.txt")

        XCTAssertThrowsError(try TextImporter.extractText(from: nonExistentURL)) { error in
            guard let importError = error as? TextImporter.ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            XCTAssertEqual(importError, .fileNotFound)
        }
    }

    func testUnsupportedFormatError() throws {
        // Create a file with an unsupported extension
        let fileURL = tempDirectory.appendingPathComponent("image.png")
        try "not really an image".write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try TextImporter.extractText(from: fileURL)) { error in
            guard let importError = error as? TextImporter.ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            XCTAssertEqual(importError, .unsupportedFormat)
        }
    }

    func testInvalidRTFDataError() {
        let invalidRTFData = "This is not valid RTF data".data(using: .utf8)!

        XCTAssertThrowsError(try TextImporter.extractTextFromRTFData(invalidRTFData)) { error in
            guard let importError = error as? TextImporter.ImportError else {
                XCTFail("Expected ImportError")
                return
            }
            XCTAssertEqual(importError, .rtfParsingError)
        }
    }

    // MARK: - Title Extraction Tests

    func testTitleExtractedFromFilename() throws {
        // Test plain text files for title extraction
        let plainTextCases = [
            ("my_script.txt", "my_script"),
            ("Presentation Notes.md", "Presentation Notes"),
            ("file.with.dots.txt", "file.with.dots")
        ]

        for (filename, expectedTitle) in plainTextCases {
            let fileURL = tempDirectory.appendingPathComponent(filename)
            try "content".write(to: fileURL, atomically: true, encoding: .utf8)

            let result = try TextImporter.extractText(from: fileURL)

            XCTAssertEqual(result.title, expectedTitle, "Failed for filename: \(filename)")
        }

        // Test RTF file separately with valid RTF content
        let rtfContent = #"{\rtf1\ansi RTF content}"#
        let rtfURL = tempDirectory.appendingPathComponent("document.rtf")
        try rtfContent.write(to: rtfURL, atomically: true, encoding: .utf8)

        let rtfResult = try TextImporter.extractText(from: rtfURL)
        XCTAssertEqual(rtfResult.title, "document")
    }

    // MARK: - Supported Types Tests

    func testSupportedTypesIncludesExpectedTypes() {
        let supportedTypes = TextImporter.supportedTypes

        XCTAssertTrue(supportedTypes.contains(.plainText))
        XCTAssertTrue(supportedTypes.contains(.rtf))
    }

    func testMarkdownTypeExists() {
        // Markdown type might be nil on some systems
        // but we should handle it gracefully
        let _ = TextImporter.markdownType
        // No assertion needed - just verify it doesn't crash
    }

    // MARK: - Edge Cases

    func testEmptyFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("empty.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.title, "empty")
        XCTAssertEqual(result.content, "")
    }

    func testUnicodeContent() throws {
        let content = "Hello 世界 🌍 Émojis and accénts"
        let fileURL = tempDirectory.appendingPathComponent("unicode.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.content, content)
    }

    func testLargeFile() throws {
        // Create a file with substantial content
        let lines = (1...1000).map { "This is line \($0) of the script." }
        let content = lines.joined(separator: "\n")
        let fileURL = tempDirectory.appendingPathComponent("large.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let result = try TextImporter.extractText(from: fileURL)

        XCTAssertEqual(result.content, content)
        XCTAssertTrue(result.content.contains("line 1 of"))
        XCTAssertTrue(result.content.contains("line 1000 of"))
    }
}

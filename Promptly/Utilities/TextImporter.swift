import Foundation
import UniformTypeIdentifiers
import AppKit

/// Utility for importing text content from various file formats
public enum TextImporter {

    /// Supported file types for import
    public static var supportedTypes: [UTType] {
        [.plainText, .text, .rtf, markdownType].compactMap { $0 }
    }

    /// UTType for markdown files
    public static var markdownType: UTType? {
        UTType("net.daringfireball.markdown") ?? UTType(filenameExtension: "md")
    }

    /// Errors that can occur during text import
    public enum ImportError: Error, LocalizedError {
        case fileNotFound
        case unsupportedFormat
        case encodingError
        case rtfParsingError

        public var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "The file could not be found."
            case .unsupportedFormat:
                return "The file format is not supported."
            case .encodingError:
                return "The file could not be read with the expected encoding."
            case .rtfParsingError:
                return "The RTF file could not be parsed."
            }
        }
    }

    /// Result of a successful text import
    public struct ImportResult: Sendable {
        public let title: String
        public let content: String

        public init(title: String, content: String) {
            self.title = title
            self.content = content
        }
    }

    /// Extracts plain text from a file URL
    /// - Parameter url: The URL of the file to import
    /// - Returns: ImportResult containing the title (filename without extension) and content
    /// - Throws: ImportError if the file cannot be read or parsed
    public static func extractText(from url: URL) throws -> ImportResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }

        let title = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension.lowercased()

        let content: String

        switch pathExtension {
        case "rtf":
            content = try extractTextFromRTF(at: url)
        case "txt", "md", "markdown", "text":
            content = try extractTextFromPlainText(at: url)
        default:
            // Try to determine type from UTType
            if let uttype = UTType(filenameExtension: pathExtension) {
                if uttype.conforms(to: .rtf) {
                    content = try extractTextFromRTF(at: url)
                } else if uttype.conforms(to: .plainText) || uttype.conforms(to: .text) {
                    content = try extractTextFromPlainText(at: url)
                } else {
                    throw ImportError.unsupportedFormat
                }
            } else {
                throw ImportError.unsupportedFormat
            }
        }

        return ImportResult(title: title, content: content)
    }

    /// Extracts plain text from RTF data
    /// - Parameter data: RTF data to parse
    /// - Returns: Plain text content with formatting stripped
    /// - Throws: ImportError.rtfParsingError if the RTF cannot be parsed
    public static func extractTextFromRTFData(_ data: Data) throws -> String {
        guard let attributedString = NSAttributedString(
            rtf: data,
            documentAttributes: nil
        ) else {
            throw ImportError.rtfParsingError
        }

        return attributedString.string
    }

    // MARK: - Private Helpers

    private static func extractTextFromRTF(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try extractTextFromRTFData(data)
    }

    private static func extractTextFromPlainText(at url: URL) throws -> String {
        // Try UTF-8 first, then fall back to other encodings
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }

        // Try UTF-16
        if let content = try? String(contentsOf: url, encoding: .utf16) {
            return content
        }

        // Try ISO Latin 1 as last resort
        if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
            return content
        }

        throw ImportError.encodingError
    }
}

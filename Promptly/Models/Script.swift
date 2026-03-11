import Foundation

/// A teleprompter script with title, content, and metadata
public struct Script: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var content: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String = "Untitled Script",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates a new script with updated content and timestamp
    public func withUpdatedContent(_ newContent: String) -> Script {
        var copy = self
        copy.content = newContent
        copy.updatedAt = Date()
        return copy
    }

    /// Creates a new script with updated title and timestamp
    public func withUpdatedTitle(_ newTitle: String) -> Script {
        var copy = self
        copy.title = newTitle
        copy.updatedAt = Date()
        return copy
    }

    /// Word count of the script content
    public var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Character count of the script content
    public var characterCount: Int {
        content.count
    }

    /// Estimated reading time in minutes at average speaking pace (150 wpm)
    public var estimatedReadingMinutes: Double {
        Double(wordCount) / 150.0
    }
}

extension Script {
    /// Sample script for previews and testing
    public static let sample = Script(
        title: "Welcome Script",
        content: """
        Hello everyone, and welcome to today's presentation.

        I'm excited to share with you some important updates about our project.

        Let's dive right in and explore the key topics we'll be covering today.

        First, we'll discuss the current state of affairs.

        Then, we'll look at our plans for the future.

        Finally, we'll have time for questions and discussion.
        """
    )
}

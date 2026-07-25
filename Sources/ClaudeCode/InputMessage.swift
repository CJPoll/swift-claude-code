import Foundation

/// A message to write to a multi-turn `claude -p --input-format stream-json`
/// session's stdin.
///
/// Use ``toJSON()`` to serialize into the single-line JSON envelope the CLI
/// expects. Each emitted line is the JSON encoding of:
///
///     { "type": "user",
///       "message": { "role": "user",
///                    "content": [ ...content blocks... ] } }
public struct InputMessage: Sendable, Equatable {
    /// Either a plain text string (auto-wrapped in a single text block) or a
    /// fully-formed array of content blocks (for image / mixed-content input).
    public enum Content: Sendable, Equatable {
        case text(String)
        case blocks([JSONValue])
    }

    public let content: Content

    public init(content: Content) {
        self.content = content
    }

    /// Convenience: a plain-text user message.
    public init(text: String) {
        self.content = .text(text)
    }

    /// Convenience: a pre-built array of content blocks.
    public init(blocks: [JSONValue]) {
        self.content = .blocks(blocks)
    }

    /// Serialize to the single-line JSON envelope the CLI expects on stdin.
    public func toJSON() throws -> String {
        let blocks: [JSONValue]
        switch content {
        case .text(let text):
            blocks = [
                .object([
                    "type": .string("text"),
                    "text": .string(text)
                ])
            ]
        case .blocks(let bs):
            blocks = bs
        }

        let envelope: JSONValue = .object([
            "type": .string("user"),
            "message": .object([
                "role": .string("user"),
                "content": .array(blocks)
            ])
        ])

        let encoder = JSONEncoder()
        // Stable key order so tests can be deterministic.
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        guard let string = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                envelope,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Encoded JSON was not valid UTF-8"
                )
            )
        }
        return string
    }
}

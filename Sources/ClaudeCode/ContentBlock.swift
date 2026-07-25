import Foundation

/// A content block inside an assistant or user message.
///
/// Maps to the Anthropic API content block schema. The `type` discriminator
/// is preserved on encode so round-trips produce the same JSON shape.
public enum ContentBlock: Codable, Equatable, Sendable {
    case text(TextContent)
    case thinking(ThinkingContent)
    case toolUse(ToolUseContent)
    case toolResult(ToolResultContent)

    private enum TypeKey: String, CodingKey { case type }
    private enum RedactedThinkingKey: String, CodingKey { case data }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: TypeKey.self)
        let type = try keyed.decode(String.self, forKey: .type)
        let single = try decoder.singleValueContainer()
        switch type {
        case "text":
            self = .text(try single.decode(TextContent.self))
        case "thinking":
            self = .thinking(try single.decode(ThinkingContent.self))
        case "redacted_thinking":
            // Fully-encrypted thinking emitted by recent models (Fable 5,
            // Opus 4.7+): no plaintext, only an opaque `data` blob. Model it
            // as an empty thinking block (carrying the blob as its signature)
            // so a message containing one is not rejected as an "unknown type"
            // and dropped wholesale. It has no displayable content and is
            // filtered out before rendering.
            let c = try decoder.container(keyedBy: RedactedThinkingKey.self)
            let data = try c.decodeIfPresent(String.self, forKey: .data)
            self = .thinking(ThinkingContent(thinking: "", signature: data))
        case "tool_use":
            self = .toolUse(try single.decode(ToolUseContent.self))
        case "tool_result":
            self = .toolResult(try single.decode(ToolResultContent.self))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: keyed,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let v): try container.encode(v)
        case .thinking(let v): try container.encode(v)
        case .toolUse(let v): try container.encode(v)
        case .toolResult(let v): try container.encode(v)
        }
    }
}

public struct TextContent: Codable, Equatable, Sendable {
    public let text: String

    public init(text: String) { self.text = text }

    private enum CodingKeys: String, CodingKey { case type, text }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try c.decode(String.self, forKey: .text)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("text", forKey: .type)
        try c.encode(text, forKey: .text)
    }
}

public struct ThinkingContent: Codable, Equatable, Sendable {
    public let thinking: String
    public let signature: String?

    public init(thinking: String, signature: String? = nil) {
        self.thinking = thinking
        self.signature = signature
    }

    private enum CodingKeys: String, CodingKey { case type, thinking, signature }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.thinking = try c.decode(String.self, forKey: .thinking)
        self.signature = try c.decodeIfPresent(String.self, forKey: .signature)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("thinking", forKey: .type)
        try c.encode(thinking, forKey: .thinking)
        try c.encodeIfPresent(signature, forKey: .signature)
    }
}

public struct ToolUseContent: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let input: JSONValue

    public init(id: String, name: String, input: JSONValue) {
        self.id = id
        self.name = name
        self.input = input
    }

    private enum CodingKeys: String, CodingKey { case type, id, name, input }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.input = try c.decodeIfPresent(JSONValue.self, forKey: .input) ?? .object([:])
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("tool_use", forKey: .type)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(input, forKey: .input)
    }
}

public struct ToolResultContent: Codable, Equatable, Sendable {
    public let toolUseId: String
    /// The result content. Typically a string, but the API allows structured
    /// content blocks; modeled as JSONValue to accept both shapes.
    public let content: JSONValue?
    public let isError: Bool?

    public init(toolUseId: String, content: JSONValue? = nil, isError: Bool? = nil) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.toolUseId = try c.decode(String.self, forKey: .toolUseId)
        self.content = try c.decodeIfPresent(JSONValue.self, forKey: .content)
        self.isError = try c.decodeIfPresent(Bool.self, forKey: .isError)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("tool_result", forKey: .type)
        try c.encode(toolUseId, forKey: .toolUseId)
        try c.encodeIfPresent(content, forKey: .content)
        try c.encodeIfPresent(isError, forKey: .isError)
    }
}

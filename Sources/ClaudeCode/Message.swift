import Foundation

/// An API message carried inside `AssistantEvent` or `UserEvent`.
///
/// Mirrors Anthropic's message envelope. `content` is a heterogeneous list
/// of typed `ContentBlock` values.
public struct Message: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable {
        case assistant
        case user
    }

    public var id: String?
    public var model: String?
    public var role: Role
    public var content: [ContentBlock]
    public var stopReason: String?
    public var usage: JSONValue?

    public init(
        id: String? = nil,
        model: String? = nil,
        role: Role,
        content: [ContentBlock],
        stopReason: String? = nil,
        usage: JSONValue? = nil
    ) {
        self.id = id
        self.model = model
        self.role = role
        self.content = content
        self.stopReason = stopReason
        self.usage = usage
    }

    private enum CodingKeys: String, CodingKey {
        case id, model, role, content
        case stopReason = "stop_reason"
        case usage
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id)
        self.model = try c.decodeIfPresent(String.self, forKey: .model)
        self.role = try c.decode(Role.self, forKey: .role)
        self.content = try c.decodeIfPresent([ContentBlock].self, forKey: .content) ?? []
        self.stopReason = try c.decodeIfPresent(String.self, forKey: .stopReason)
        self.usage = try c.decodeIfPresent(JSONValue.self, forKey: .usage)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(model, forKey: .model)
        try c.encode(role, forKey: .role)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(stopReason, forKey: .stopReason)
        try c.encodeIfPresent(usage, forKey: .usage)
    }
}

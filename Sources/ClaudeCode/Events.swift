import Foundation

/// The `init` event — always first in a `--output-format stream-json` session.
public struct SystemEvent: Codable, Equatable, Sendable {
    public let subtype: String?
    public let sessionId: String
    public let model: String?
    public let cwd: String?
    public let tools: [String]?
    public let mcpServers: [JSONValue]?
    public let permissionMode: String?
    public let apiKeySource: String?
    public let claudeCodeVersion: String?
    public let agents: [String]?
    public let skills: [String]?

    public init(
        subtype: String? = nil,
        sessionId: String,
        model: String? = nil,
        cwd: String? = nil,
        tools: [String]? = nil,
        mcpServers: [JSONValue]? = nil,
        permissionMode: String? = nil,
        apiKeySource: String? = nil,
        claudeCodeVersion: String? = nil,
        agents: [String]? = nil,
        skills: [String]? = nil
    ) {
        self.subtype = subtype
        self.sessionId = sessionId
        self.model = model
        self.cwd = cwd
        self.tools = tools
        self.mcpServers = mcpServers
        self.permissionMode = permissionMode
        self.apiKeySource = apiKeySource
        self.claudeCodeVersion = claudeCodeVersion
        self.agents = agents
        self.skills = skills
    }

    private enum CodingKeys: String, CodingKey {
        case type, subtype
        case sessionId = "session_id"
        case model
        case cwd
        case tools
        case mcpServers = "mcp_servers"
        case permissionMode = "permissionMode"
        case apiKeySource = "apiKeySource"
        case claudeCodeVersion = "claude_code_version"
        case agents
        case skills
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.subtype = try c.decodeIfPresent(String.self, forKey: .subtype)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.model = try c.decodeIfPresent(String.self, forKey: .model)
        self.cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        self.tools = try c.decodeIfPresent([String].self, forKey: .tools)
        self.mcpServers = try c.decodeIfPresent([JSONValue].self, forKey: .mcpServers)
        self.permissionMode = try c.decodeIfPresent(String.self, forKey: .permissionMode)
        self.apiKeySource = try c.decodeIfPresent(String.self, forKey: .apiKeySource)
        self.claudeCodeVersion = try c.decodeIfPresent(String.self, forKey: .claudeCodeVersion)
        self.agents = try c.decodeIfPresent([String].self, forKey: .agents)
        self.skills = try c.decodeIfPresent([String].self, forKey: .skills)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("system", forKey: .type)
        try c.encodeIfPresent(subtype, forKey: .subtype)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encode(model, forKey: .model)
        try c.encodeIfPresent(cwd, forKey: .cwd)
        try c.encodeIfPresent(tools, forKey: .tools)
        try c.encodeIfPresent(mcpServers, forKey: .mcpServers)
        try c.encodeIfPresent(permissionMode, forKey: .permissionMode)
        try c.encodeIfPresent(apiKeySource, forKey: .apiKeySource)
        try c.encodeIfPresent(claudeCodeVersion, forKey: .claudeCodeVersion)
        try c.encodeIfPresent(agents, forKey: .agents)
        try c.encodeIfPresent(skills, forKey: .skills)
    }
}

/// A complete assistant message event.
public struct AssistantEvent: Codable, Equatable, Sendable {
    public let message: Message
    public let sessionId: String
    public let parentToolUseId: String?
    public let uuid: String?

    public init(message: Message, sessionId: String, parentToolUseId: String? = nil, uuid: String? = nil) {
        self.message = message
        self.sessionId = sessionId
        self.parentToolUseId = parentToolUseId
        self.uuid = uuid
    }

    private enum CodingKeys: String, CodingKey {
        case type, message
        case sessionId = "session_id"
        case parentToolUseId = "parent_tool_use_id"
        case uuid
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try c.decode(Message.self, forKey: .message)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.parentToolUseId = try c.decodeIfPresent(String.self, forKey: .parentToolUseId)
        self.uuid = try c.decodeIfPresent(String.self, forKey: .uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("assistant", forKey: .type)
        try c.encode(message, forKey: .message)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encodeIfPresent(parentToolUseId, forKey: .parentToolUseId)
        try c.encodeIfPresent(uuid, forKey: .uuid)
    }
}

/// A user message event — usually a tool result or a replayed user message.
public struct UserEvent: Codable, Equatable, Sendable {
    public let message: Message
    public let sessionId: String
    public let toolUseResult: JSONValue?
    public let uuid: String?

    public init(message: Message, sessionId: String, toolUseResult: JSONValue? = nil, uuid: String? = nil) {
        self.message = message
        self.sessionId = sessionId
        self.toolUseResult = toolUseResult
        self.uuid = uuid
    }

    private enum CodingKeys: String, CodingKey {
        case type, message
        case sessionId = "session_id"
        case toolUseResult = "tool_use_result"
        case uuid
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try c.decode(Message.self, forKey: .message)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.toolUseResult = try c.decodeIfPresent(JSONValue.self, forKey: .toolUseResult)
        self.uuid = try c.decodeIfPresent(String.self, forKey: .uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("user", forKey: .type)
        try c.encode(message, forKey: .message)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encodeIfPresent(toolUseResult, forKey: .toolUseResult)
        try c.encodeIfPresent(uuid, forKey: .uuid)
    }
}

/// The terminal event for a turn — carries cost, usage, stop reason, errors.
public struct ResultEvent: Codable, Equatable, Sendable {
    public let subtype: String
    public let isError: Bool
    public let sessionId: String
    public let durationMs: Int?
    public let durationApiMs: Int?
    public let numTurns: Int?
    public let result: String?
    public let structuredOutput: JSONValue?
    public let stopReason: String?
    public let totalCostUsd: Double?
    public let usage: JSONValue?
    public let modelUsage: JSONValue?
    public let permissionDenials: [JSONValue]?
    public let terminalReason: String?
    public let fastModeState: String?
    public let uuid: String?
    public let errors: [String]?

    public init(
        subtype: String,
        isError: Bool,
        sessionId: String,
        durationMs: Int? = nil,
        durationApiMs: Int? = nil,
        numTurns: Int? = nil,
        result: String? = nil,
        structuredOutput: JSONValue? = nil,
        stopReason: String? = nil,
        totalCostUsd: Double? = nil,
        usage: JSONValue? = nil,
        modelUsage: JSONValue? = nil,
        permissionDenials: [JSONValue]? = nil,
        terminalReason: String? = nil,
        fastModeState: String? = nil,
        uuid: String? = nil,
        errors: [String]? = nil
    ) {
        self.subtype = subtype
        self.isError = isError
        self.sessionId = sessionId
        self.durationMs = durationMs
        self.durationApiMs = durationApiMs
        self.numTurns = numTurns
        self.result = result
        self.structuredOutput = structuredOutput
        self.stopReason = stopReason
        self.totalCostUsd = totalCostUsd
        self.usage = usage
        self.modelUsage = modelUsage
        self.permissionDenials = permissionDenials
        self.terminalReason = terminalReason
        self.fastModeState = fastModeState
        self.uuid = uuid
        self.errors = errors
    }

    private enum CodingKeys: String, CodingKey {
        case type, subtype
        case isError = "is_error"
        case sessionId = "session_id"
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case numTurns = "num_turns"
        case result
        case structuredOutput = "structured_output"
        case stopReason = "stop_reason"
        case totalCostUsd = "total_cost_usd"
        case usage
        case modelUsage = "modelUsage"
        case permissionDenials = "permission_denials"
        case terminalReason = "terminal_reason"
        case fastModeState = "fast_mode_state"
        case uuid
        case errors
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.subtype = try c.decode(String.self, forKey: .subtype)
        self.isError = try c.decode(Bool.self, forKey: .isError)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.durationMs = try c.decodeIfPresent(Int.self, forKey: .durationMs)
        self.durationApiMs = try c.decodeIfPresent(Int.self, forKey: .durationApiMs)
        self.numTurns = try c.decodeIfPresent(Int.self, forKey: .numTurns)
        self.result = try c.decodeIfPresent(String.self, forKey: .result)
        self.structuredOutput = try c.decodeIfPresent(JSONValue.self, forKey: .structuredOutput)
        self.stopReason = try c.decodeIfPresent(String.self, forKey: .stopReason)
        self.totalCostUsd = try c.decodeIfPresent(Double.self, forKey: .totalCostUsd)
        self.usage = try c.decodeIfPresent(JSONValue.self, forKey: .usage)
        self.modelUsage = try c.decodeIfPresent(JSONValue.self, forKey: .modelUsage)
        self.permissionDenials = try c.decodeIfPresent([JSONValue].self, forKey: .permissionDenials)
        self.terminalReason = try c.decodeIfPresent(String.self, forKey: .terminalReason)
        self.fastModeState = try c.decodeIfPresent(String.self, forKey: .fastModeState)
        self.uuid = try c.decodeIfPresent(String.self, forKey: .uuid)
        self.errors = try c.decodeIfPresent([String].self, forKey: .errors)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("result", forKey: .type)
        try c.encode(subtype, forKey: .subtype)
        try c.encode(isError, forKey: .isError)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encodeIfPresent(durationMs, forKey: .durationMs)
        try c.encodeIfPresent(durationApiMs, forKey: .durationApiMs)
        try c.encodeIfPresent(numTurns, forKey: .numTurns)
        try c.encodeIfPresent(result, forKey: .result)
        try c.encodeIfPresent(structuredOutput, forKey: .structuredOutput)
        try c.encodeIfPresent(stopReason, forKey: .stopReason)
        try c.encodeIfPresent(totalCostUsd, forKey: .totalCostUsd)
        try c.encodeIfPresent(usage, forKey: .usage)
        try c.encodeIfPresent(modelUsage, forKey: .modelUsage)
        try c.encodeIfPresent(permissionDenials, forKey: .permissionDenials)
        try c.encodeIfPresent(terminalReason, forKey: .terminalReason)
        try c.encodeIfPresent(fastModeState, forKey: .fastModeState)
        try c.encodeIfPresent(uuid, forKey: .uuid)
        try c.encodeIfPresent(errors, forKey: .errors)
    }
}

/// Raw API streaming chunk emitted when `--include-partial-messages` is set.
/// The payload is opaque; we preserve the whole JSON object as-is.
public struct StreamEvent: Codable, Equatable, Sendable {
    public let raw: JSONValue

    public init(raw: JSONValue) { self.raw = raw }

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        self.raw = try single.decode(JSONValue.self)
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        // Ensure type tag is present even if the raw value lacks it.
        switch raw {
        case .object(var dict):
            dict["type"] = .string("stream_event")
            try single.encode(JSONValue.object(dict))
        default:
            try single.encode(raw)
        }
    }
}

/// Rate-limit status event emitted after API calls.
public struct RateLimitEvent: Codable, Equatable, Sendable {
    public let rateLimitInfo: JSONValue
    public let sessionId: String
    public let uuid: String?

    public init(rateLimitInfo: JSONValue, sessionId: String, uuid: String? = nil) {
        self.rateLimitInfo = rateLimitInfo
        self.sessionId = sessionId
        self.uuid = uuid
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case rateLimitInfo = "rate_limit_info"
        case sessionId = "session_id"
        case uuid
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rateLimitInfo = try c.decode(JSONValue.self, forKey: .rateLimitInfo)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.uuid = try c.decodeIfPresent(String.self, forKey: .uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode("rate_limit_event", forKey: .type)
        try c.encode(rateLimitInfo, forKey: .rateLimitInfo)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encodeIfPresent(uuid, forKey: .uuid)
    }
}

/// A control-protocol permission request emitted by the CLI when
/// `--permission-prompt-tool stdio` is set. Arrives as either
/// `"type":"sdk_control_request"` or `"type":"control_request"`.
///
/// Wire format (actual CLI output):
/// ```json
/// {
///   "type": "control_request",
///   "request_id": "...",
///   "request": {
///     "subtype": "can_use_tool",
///     "tool_name": "Bash",
///     "display_name": "Bash",
///     "input": { "command": "ls" }
///   }
/// }
/// ```
///
/// `request_id` lives at the envelope level; the inner `request` carries
/// tool details. This struct flattens both levels into a single domain type.
public struct ControlRequestEvent: Codable, Equatable, Sendable {
    public let requestId: String
    public let toolName: String
    public let toolInput: JSONValue

    /// `true` when the CLI marks this request as the model asking the user
    /// something rather than gating a side effect — `AskUserQuestion` is the
    /// only such tool today. These cannot be resolved by a plain allow: the
    /// response has to carry the user's `answers`, so they route to an answer
    /// dialog instead of an Approve/Deny prompt.
    public let requiresUserInteraction: Bool

    public init(
        requestId: String,
        toolName: String,
        toolInput: JSONValue,
        requiresUserInteraction: Bool = false
    ) {
        self.requestId = requestId
        self.toolName = toolName
        self.toolInput = toolInput
        self.requiresUserInteraction = requiresUserInteraction
    }

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case requiresUserInteraction = "requires_user_interaction"
    }

    // Explicit decoding so the flag's absence means `false` rather than a
    // decode failure — older CLI builds omit the key entirely.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try c.decode(String.self, forKey: .requestId)
        toolName = try c.decode(String.self, forKey: .toolName)
        toolInput = try c.decode(JSONValue.self, forKey: .toolInput)
        requiresUserInteraction =
            try c.decodeIfPresent(Bool.self, forKey: .requiresUserInteraction) ?? false
    }
}

/// A single line of text output, used when claude is in plain text output mode.
/// Not part of the `stream-json` schema — constructed by the event parser
/// from non-JSON stdout lines.
public struct TextChunkEvent: Equatable, Sendable {
    public let text: String
    public init(text: String) { self.text = text }
}

/// Tagged union over every event type the CLI can emit.
///
/// Decoding inspects the top-level `type` field to dispatch into the right
/// case. `.textChunk` is never produced by JSON decoding — it is constructed
/// externally for the plain-text output mode.
public enum Event: Equatable, Sendable {
    case system(SystemEvent)
    case assistant(AssistantEvent)
    case user(UserEvent)
    case result(ResultEvent)
    case stream(StreamEvent)
    case rateLimit(RateLimitEvent)
    case controlRequest(ControlRequestEvent)
    case textChunk(TextChunkEvent)
}

/// Inner payload of the control request envelope — the `"request"` object.
private struct ControlRequestPayload: Decodable {
    let toolName: String
    let input: JSONValue
    let requiresUserInteraction: Bool?

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input
        case requiresUserInteraction = "requires_user_interaction"
    }
}

/// Envelope wrapper for control request JSON. `request_id` is at the
/// top level; tool details sit under the nested `"request"` object.
private struct ControlRequestEnvelope: Decodable {
    let requestId: String
    let request: ControlRequestPayload

    enum CodingKeys: String, CodingKey {
        case requestId = "request_id"
        case request
    }
}

/// Encoding-side mirror that emits the wire format so encoded values
/// round-trip back into `Event`.
private struct ControlRequestEncoded: Encodable {
    let type: String
    let requestId: String
    let request: ControlRequestEncodedPayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case request
    }
}

private struct ControlRequestEncodedPayload: Encodable {
    let toolName: String
    let input: JSONValue
    let requiresUserInteraction: Bool

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input
        case requiresUserInteraction = "requires_user_interaction"
    }
}

extension Event: Decodable {
    private enum TypeKey: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: TypeKey.self)
        let type = try keyed.decode(String.self, forKey: .type)
        let single = try decoder.singleValueContainer()
        switch type {
        case "system":
            self = .system(try single.decode(SystemEvent.self))
        case "assistant":
            self = .assistant(try single.decode(AssistantEvent.self))
        case "user":
            self = .user(try single.decode(UserEvent.self))
        case "result":
            self = .result(try single.decode(ResultEvent.self))
        case "stream_event":
            self = .stream(try single.decode(StreamEvent.self))
        case "rate_limit_event":
            self = .rateLimit(try single.decode(RateLimitEvent.self))
        case "sdk_control_request", "control_request":
            let envelope = try single.decode(ControlRequestEnvelope.self)
            self = .controlRequest(ControlRequestEvent(
                requestId: envelope.requestId,
                toolName: envelope.request.toolName,
                toolInput: envelope.request.input,
                requiresUserInteraction: envelope.request.requiresUserInteraction ?? false
            ))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: keyed,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }
}

extension Event: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .system(let v): try c.encode(v)
        case .assistant(let v): try c.encode(v)
        case .user(let v): try c.encode(v)
        case .result(let v): try c.encode(v)
        case .stream(let v): try c.encode(v)
        case .rateLimit(let v): try c.encode(v)
        case .controlRequest(let v):
            try c.encode(ControlRequestEncoded(
                type: "control_request",
                requestId: v.requestId,
                request: ControlRequestEncodedPayload(
                    toolName: v.toolName,
                    input: v.toolInput,
                    requiresUserInteraction: v.requiresUserInteraction
                )
            ))
        case .textChunk(let v):
            // No JSON shape defined for text chunks; emit a minimal envelope
            // so encoding never throws but round-tripping is not expected.
            try c.encode(["type": "text_chunk", "text": v.text])
        }
    }
}

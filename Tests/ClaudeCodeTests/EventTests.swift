import Foundation
import Testing
@testable import ClaudeCode

@Suite("Event")
struct EventTests {
    private func decode(_ json: String) throws -> Event {
        try JSONDecoder().decode(Event.self, from: Data(json.utf8))
    }

    @Test("decodes system init event")
    func decodesSystem() throws {
        let json = #"""
        {
          "type":"system","subtype":"init","session_id":"sess-1","model":"claude-sonnet-4-5",
          "cwd":"/Users/me/dev/x","tools":["Read","Bash"],"mcp_servers":[],
          "permissionMode":"acceptEdits","apiKeySource":"none",
          "claude_code_version":"1.2.3","agents":["a"],"skills":["s"]
        }
        """#
        guard case .system(let ev) = try decode(json) else {
            Issue.record("expected .system"); return
        }
        #expect(ev.subtype == "init")
        #expect(ev.sessionId == "sess-1")
        #expect(ev.model == "claude-sonnet-4-5")
        #expect(ev.cwd == "/Users/me/dev/x")
        #expect(ev.tools == ["Read", "Bash"])
        #expect(ev.permissionMode == "acceptEdits")
        #expect(ev.apiKeySource == "none")
        #expect(ev.claudeCodeVersion == "1.2.3")
        #expect(ev.agents == ["a"])
        #expect(ev.skills == ["s"])
    }

    @Test("decodes assistant event with text + tool_use content")
    func decodesAssistant() throws {
        let json = #"""
        {
          "type":"assistant",
          "session_id":"sess-1",
          "uuid":"u-1",
          "message":{
            "id":"msg_1","model":"claude-sonnet-4-5","role":"assistant",
            "stop_reason":"end_turn","usage":{"input_tokens":12,"output_tokens":34},
            "content":[
              {"type":"text","text":"sure"},
              {"type":"tool_use","id":"toolu_1","name":"Bash","input":{"cmd":"ls"}}
            ]
          }
        }
        """#
        guard case .assistant(let ev) = try decode(json) else {
            Issue.record("expected .assistant"); return
        }
        #expect(ev.sessionId == "sess-1")
        #expect(ev.uuid == "u-1")
        #expect(ev.message.role == .assistant)
        #expect(ev.message.id == "msg_1")
        #expect(ev.message.content.count == 2)
        guard case .text(let t) = ev.message.content[0] else {
            Issue.record("expected text block"); return
        }
        #expect(t.text == "sure")
        guard case .toolUse(let u) = ev.message.content[1] else {
            Issue.record("expected tool_use block"); return
        }
        #expect(u.id == "toolu_1")
    }

    @Test("decodes user event carrying a tool_result")
    func decodesUser() throws {
        let json = #"""
        {
          "type":"user",
          "session_id":"sess-1",
          "message":{
            "role":"user",
            "content":[
              {"type":"tool_result","tool_use_id":"toolu_1","content":"output","is_error":false}
            ]
          },
          "tool_use_result":{"exit_code":0}
        }
        """#
        guard case .user(let ev) = try decode(json) else {
            Issue.record("expected .user"); return
        }
        #expect(ev.sessionId == "sess-1")
        #expect(ev.message.role == .user)
        guard case .toolResult(let r) = ev.message.content.first else {
            Issue.record("expected tool_result"); return
        }
        #expect(r.toolUseId == "toolu_1")
        #expect(r.isError == false)
    }

    @Test("decodes result event")
    func decodesResult() throws {
        let json = #"""
        {
          "type":"result","subtype":"success","is_error":false,
          "session_id":"sess-1","duration_ms":1200,"duration_api_ms":900,
          "num_turns":1,"result":"done","stop_reason":"end_turn",
          "total_cost_usd":0.0042,
          "usage":{"input_tokens":12,"output_tokens":34},
          "modelUsage":{"claude-sonnet-4-5":{"input":12,"output":34}},
          "permission_denials":[],"errors":[]
        }
        """#
        guard case .result(let ev) = try decode(json) else {
            Issue.record("expected .result"); return
        }
        #expect(ev.subtype == "success")
        #expect(ev.isError == false)
        #expect(ev.sessionId == "sess-1")
        #expect(ev.durationMs == 1200)
        #expect(ev.durationApiMs == 900)
        #expect(ev.numTurns == 1)
        #expect(ev.totalCostUsd == 0.0042)
        #expect(ev.stopReason == "end_turn")
        #expect(ev.errors == [])
    }

    @Test("decodes stream_event preserving raw payload")
    func decodesStream() throws {
        let json = #"""
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"hi"}}}
        """#
        guard case .stream(let ev) = try decode(json) else {
            Issue.record("expected .stream"); return
        }
        guard case .object(let obj) = ev.raw else {
            Issue.record("expected object raw"); return
        }
        #expect(obj["type"] == .string("stream_event"))
    }

    @Test("decodes rate_limit_event")
    func decodesRateLimit() throws {
        let json = #"""
        {"type":"rate_limit_event","session_id":"sess-1","rate_limit_info":{"remaining":42}}
        """#
        guard case .rateLimit(let ev) = try decode(json) else {
            Issue.record("expected .rateLimit"); return
        }
        #expect(ev.sessionId == "sess-1")
        #expect(ev.rateLimitInfo == .object(["remaining": .int(42)]))
    }

    @Test("unknown event type throws DecodingError")
    func unknownEventThrows() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                Event.self,
                from: Data(#"{"type":"mystery","session_id":"x"}"#.utf8)
            )
        }
    }

    @Test("non-JSON throws DecodingError")
    func nonJSONThrows() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Event.self, from: Data("not json".utf8))
        }
    }

    @Test("system event round-trips")
    func roundTripSystem() throws {
        let original = SystemEvent(
            subtype: "init",
            sessionId: "sess-1",
            model: "claude-sonnet-4-5",
            tools: ["Read"]
        )
        let data = try JSONEncoder().encode(Event.system(original))
        guard case .system(let decoded) = try JSONDecoder().decode(Event.self, from: data) else {
            Issue.record("expected .system"); return
        }
        #expect(decoded == original)
    }

    @Test("decodes sdk_control_request as controlRequest")
    func decodesSdkControlRequest() throws {
        let json = #"""
        {
          "type":"sdk_control_request",
          "request_id":"perm_1",
          "request":{
            "subtype":"can_use_tool",
            "tool_name":"Bash",
            "input":{"command":"ls"}
          }
        }
        """#
        guard case .controlRequest(let ev) = try decode(json) else {
            Issue.record("expected .controlRequest"); return
        }
        #expect(ev.requestId == "perm_1")
        #expect(ev.toolName == "Bash")
        guard case .object(let dict) = ev.toolInput else {
            Issue.record("expected object tool_input"); return
        }
        #expect(dict["command"] == .string("ls"))
    }

    @Test("decodes control_request as controlRequest")
    func decodesControlRequestAlternativeType() throws {
        let json = #"""
        {
          "type":"control_request",
          "request_id":"perm_2",
          "request":{
            "subtype":"can_use_tool",
            "tool_name":"Read",
            "input":{"file_path":"/tmp/x"}
          }
        }
        """#
        guard case .controlRequest(let ev) = try decode(json) else {
            Issue.record("expected .controlRequest"); return
        }
        #expect(ev.requestId == "perm_2")
        #expect(ev.toolName == "Read")
    }

    @Test("controlRequest decodes requires_user_interaction")
    func decodesRequiresUserInteraction() throws {
        // The CLI marks requests that are the model asking the user something
        // (AskUserQuestion) rather than a permission gate. Consumers route
        // these to an answer dialog, so the flag has to survive decoding.
        let json = #"""
        {
          "type":"control_request",
          "request_id":"q_1",
          "request":{
            "subtype":"can_use_tool",
            "tool_name":"AskUserQuestion",
            "input":{"questions":[]},
            "requires_user_interaction":true
          }
        }
        """#
        guard case .controlRequest(let ev) = try decode(json) else {
            Issue.record("expected .controlRequest"); return
        }
        #expect(ev.requiresUserInteraction)
    }

    @Test("controlRequest defaults requires_user_interaction to false")
    func defaultsRequiresUserInteractionToFalse() throws {
        let json = #"""
        {
          "type":"control_request",
          "request_id":"perm_9",
          "request":{
            "subtype":"can_use_tool",
            "tool_name":"Bash",
            "input":{"command":"ls"}
          }
        }
        """#
        guard case .controlRequest(let ev) = try decode(json) else {
            Issue.record("expected .controlRequest"); return
        }
        #expect(ev.requiresUserInteraction == false)
    }

    @Test("controlRequest decodes nested object tool_input")
    func decodesNestedToolInput() throws {
        let json = #"""
        {
          "type":"sdk_control_request",
          "request_id":"perm_3",
          "request":{
            "subtype":"can_use_tool",
            "tool_name":"Edit",
            "input":{"changes":{"a":1,"b":[true,false]}}
          }
        }
        """#
        guard case .controlRequest(let ev) = try decode(json) else {
            Issue.record("expected .controlRequest"); return
        }
        guard case .object(let outer) = ev.toolInput,
              case .object(let inner) = outer["changes"] else {
            Issue.record("expected nested object"); return
        }
        #expect(inner["a"] == .int(1))
    }

    @Test("controlRequest round-trips")
    func roundTripControlRequest() throws {
        let original = ControlRequestEvent(
            requestId: "perm_rt",
            toolName: "Bash",
            toolInput: .object(["command": .string("ls -la")])
        )
        let data = try JSONEncoder().encode(Event.controlRequest(original))
        guard case .controlRequest(let decoded) = try JSONDecoder().decode(Event.self, from: data) else {
            Issue.record("expected .controlRequest"); return
        }
        #expect(decoded == original)
    }
}

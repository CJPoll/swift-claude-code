import Foundation
import Testing
@testable import ClaudeCode

@Suite("ContentBlock")
struct ContentBlockTests {
    @Test("decodes text block")
    func decodesText() throws {
        let json = #"{"type":"text","text":"Hello, world"}"#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .text(let text) = block else { Issue.record("expected text"); return }
        #expect(text.text == "Hello, world")
    }

    @Test("decodes thinking block with signature")
    func decodesThinking() throws {
        let json = #"""
        {"type":"thinking","thinking":"hmm","signature":"sig-1"}
        """#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .thinking(let t) = block else { Issue.record("expected thinking"); return }
        #expect(t.thinking == "hmm")
        #expect(t.signature == "sig-1")
    }

    @Test("decodes tool_use with structured input")
    func decodesToolUse() throws {
        let json = #"""
        {"type":"tool_use","id":"toolu_1","name":"Bash","input":{"cmd":"ls","flags":["-la"]}}
        """#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .toolUse(let use) = block else { Issue.record("expected tool_use"); return }
        #expect(use.id == "toolu_1")
        #expect(use.name == "Bash")
        guard case .object(let obj) = use.input else {
            Issue.record("expected object input")
            return
        }
        #expect(obj["cmd"] == .string("ls"))
        #expect(obj["flags"] == .array([.string("-la")]))
    }

    @Test("decodes tool_result with string content")
    func decodesToolResult() throws {
        let json = #"""
        {"type":"tool_result","tool_use_id":"toolu_1","content":"ok","is_error":false}
        """#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .toolResult(let r) = block else { Issue.record("expected tool_result"); return }
        #expect(r.toolUseId == "toolu_1")
        #expect(r.content == .string("ok"))
        #expect(r.isError == false)
    }

    @Test("decodes omitted thinking block (empty plaintext, signature only)")
    func decodesOmittedThinking() throws {
        // Fable 5 / Opus 4.7+ default to omitted thinking: empty `thinking`
        // text with only a signature.
        let json = #"{"type":"thinking","thinking":"","signature":"CAIS..."}"#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .thinking(let t) = block else { Issue.record("expected thinking"); return }
        #expect(t.thinking == "")
        #expect(t.signature == "CAIS...")
    }

    @Test("decodes redacted_thinking into an empty thinking block")
    func decodesRedactedThinking() throws {
        // Recent models can emit fully-encrypted thinking as a distinct
        // `redacted_thinking` block carrying only an opaque `data` blob. It
        // must decode (not throw) so the enclosing message survives.
        let json = #"{"type":"redacted_thinking","data":"EncryptedBlob=="}"#.data(using: .utf8)!
        let block = try JSONDecoder().decode(ContentBlock.self, from: json)
        guard case .thinking(let t) = block else { Issue.record("expected thinking"); return }
        #expect(t.thinking == "")
        #expect(t.signature == "EncryptedBlob==")
    }

    @Test("unknown block type throws")
    func unknownTypeThrows() {
        let json = #"{"type":"mystery","x":1}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ContentBlock.self, from: json)
        }
    }

    @Test("text block round-trips through JSON")
    func roundTripText() throws {
        let original = ContentBlock.text(TextContent(text: "hi"))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        #expect(decoded == original)
    }

    @Test("tool_use round-trips and preserves input shape")
    func roundTripToolUse() throws {
        let original = ContentBlock.toolUse(
            ToolUseContent(
                id: "toolu_2",
                name: "Read",
                input: .object(["path": .string("/tmp/x"), "limit": .int(10)])
            )
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContentBlock.self, from: data)
        #expect(decoded == original)
    }
}

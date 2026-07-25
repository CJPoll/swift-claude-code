import XCTest
@testable import ClaudeCode

final class EventParserTests: XCTestCase {
    func testParsesSystemEvent() {
        let json = #"{"type":"system","subtype":"init","session_id":"s1","model":"claude-opus-4-1"}"#
        guard case .system(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .system")
        }
        XCTAssertEqual(ev.sessionId, "s1")
        XCTAssertEqual(ev.model, "claude-opus-4-1")
        XCTAssertEqual(ev.subtype, "init")
    }

    func testParsesAssistantEvent() {
        let json = #"""
        {"type":"assistant","session_id":"s1","message":{"id":"m1","role":"assistant","model":"claude-opus-4-1","content":[{"type":"text","text":"hi"}]}}
        """#
        guard case .assistant(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .assistant")
        }
        XCTAssertEqual(ev.sessionId, "s1")
        XCTAssertEqual(ev.message.content.count, 1)
    }

    func testParsesAssistantEventContainingRedactedThinking() {
        // A redacted_thinking block must not cause the whole assistant event
        // (text + tool calls included) to be dropped as unparseable.
        let json = #"""
        {"type":"assistant","session_id":"s1","message":{"id":"m1","role":"assistant","model":"claude-fable-5","content":[{"type":"redacted_thinking","data":"blob"},{"type":"text","text":"hi"}]}}
        """#
        guard case .assistant(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .assistant — event was dropped")
        }
        XCTAssertEqual(ev.message.content.count, 2)
    }

    func testParsesUserEvent() {
        let json = #"""
        {"type":"user","session_id":"s1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"ok"}]}}
        """#
        guard case .user(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .user")
        }
        XCTAssertEqual(ev.sessionId, "s1")
    }

    func testParsesResultEvent() {
        let json = #"""
        {"type":"result","subtype":"success","is_error":false,"session_id":"s1","duration_ms":100,"total_cost_usd":0.01}
        """#
        guard case .result(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .result")
        }
        XCTAssertEqual(ev.subtype, "success")
        XCTAssertEqual(ev.totalCostUsd, 0.01)
    }

    func testParsesStreamEvent() {
        let json = #"{"type":"stream_event","delta":{"type":"text_delta","text":"chunk"}}"#
        guard case .stream = EventParser.parse(json) else {
            return XCTFail("expected .stream")
        }
    }

    func testParsesRateLimitEvent() {
        let json = #"{"type":"rate_limit_event","session_id":"s1","rate_limit_info":{"remaining":42}}"#
        guard case .rateLimit(let ev) = EventParser.parse(json) else {
            return XCTFail("expected .rateLimit")
        }
        XCTAssertEqual(ev.sessionId, "s1")
    }

    func testReturnsNilForNonJSONLine() {
        XCTAssertNil(EventParser.parse("not json at all"))
        XCTAssertNil(EventParser.parse("ERROR: claude crashed"))
    }

    func testReturnsNilForEmptyLine() {
        XCTAssertNil(EventParser.parse(""))
        XCTAssertNil(EventParser.parse("   \n  "))
    }

    func testReturnsNilForUnknownEventType() {
        let json = #"{"type":"future_event","session_id":"s1"}"#
        XCTAssertNil(EventParser.parse(json))
    }

    func testReturnsNilForJSONMissingTypeField() {
        let json = #"{"session_id":"s1"}"#
        XCTAssertNil(EventParser.parse(json))
    }

    func testReturnsNilForMalformedJSON() {
        XCTAssertNil(EventParser.parse(#"{"type":"system",}"#))
        XCTAssertNil(EventParser.parse(#"{"type": "#))
    }

    func testHandlesLineWithTrailingNewline() {
        let json = "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"s1\",\"model\":\"m\"}\n"
        XCTAssertNotNil(EventParser.parse(json))
    }

    func testParseTextLineWrapsAsTextChunk() {
        guard case .textChunk(let ev) = EventParser.parseTextLine("hello world") else {
            return XCTFail("expected .textChunk")
        }
        XCTAssertEqual(ev.text, "hello world")
    }
}

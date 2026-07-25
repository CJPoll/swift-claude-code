import XCTest
@testable import ClaudeCode

final class InputMessageTests: XCTestCase {

    private func decode(_ json: String) throws -> JSONValue {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    func testTextContentWrapsInTextBlock() throws {
        let msg = InputMessage(text: "Hello")
        let json = try msg.toJSON()
        let decoded = try decode(json)

        let expected: JSONValue = .object([
            "type": .string("user"),
            "message": .object([
                "role": .string("user"),
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string("Hello")
                    ])
                ])
            ])
        ])
        XCTAssertEqual(decoded, expected)
    }

    func testBlocksContentUsedAsIs() throws {
        let blocks: [JSONValue] = [
            .object(["type": .string("text"), "text": .string("Hello")]),
            .object(["type": .string("image"), "url": .string("http://example.com/img.png")])
        ]
        let msg = InputMessage(blocks: blocks)
        let json = try msg.toJSON()
        let decoded = try decode(json)

        guard case .object(let envelope) = decoded,
              case .object(let message) = envelope["message"],
              case .array(let arr) = message["content"]
        else {
            XCTFail("Unexpected envelope shape: \(decoded)")
            return
        }
        XCTAssertEqual(envelope["type"], .string("user"))
        XCTAssertEqual(message["role"], .string("user"))
        XCTAssertEqual(arr, blocks)
    }

    func testOutputIsSingleLine() throws {
        let msg = InputMessage(text: "Line one\nLine two")
        let json = try msg.toJSON()
        // No raw newlines in the encoded envelope — content newlines are escaped.
        XCTAssertFalse(json.contains("\n"))
    }
}

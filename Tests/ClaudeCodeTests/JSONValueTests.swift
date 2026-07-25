import Foundation
import Testing
@testable import ClaudeCode

@Suite("JSONValue")
struct JSONValueTests {
    @Test("round-trips a nested object preserving types")
    func roundTripsNested() throws {
        let original: JSONValue = .object([
            "s": .string("hi"),
            "i": .int(7),
            "d": .double(1.5),
            "b": .bool(true),
            "n": .null,
            "arr": .array([.int(1), .int(2), .int(3)]),
            "obj": .object(["k": .string("v")])
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == original)
    }

    @Test("decodes scalar values")
    func decodesScalars() throws {
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("null".utf8)) == .null)
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8)) == .bool(true))
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("42".utf8)) == .int(42))
        #expect(try JSONDecoder().decode(JSONValue.self, from: Data("\"hi\"".utf8)) == .string("hi"))
    }
}

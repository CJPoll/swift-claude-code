import Testing
@testable import ClaudeCode

@Test func versionIsNonEmpty() {
    #expect(!ClaudeCode.version.isEmpty)
}

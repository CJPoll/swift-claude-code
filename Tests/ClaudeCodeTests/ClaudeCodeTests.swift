import Testing
import ClaudeCode

/// The module name must stay usable as a qualifier.
///
/// Until 0.1.1 this package shipped a `public enum ClaudeCode` as a "namespace
/// marker". A type carrying the module's own name shadows the module at every
/// consumer call site: `ClaudeCode.SessionOptions` resolves to the *enum* and
/// fails to compile, and there is then no way at all to name a type of ours
/// that the consumer also declares — a bare reference silently picks the
/// consumer's own. `JSONValue` is exactly that case for KodeMonkee.
///
/// Deliberately a plain `import`, not `@testable`: the claim is about what a
/// consumer sees. This is a compile-time test — if the shadow comes back, this
/// file stops building.
@Test func theModuleNameIsUsableAsAQualifier() {
    let options = ClaudeCode.SessionOptions(model: "claude-sonnet-5")

    #expect(options.model == "claude-sonnet-5")
    #expect(ClaudeCode.JSONValue.int(1) == ClaudeCode.JSONValue.int(1))
}

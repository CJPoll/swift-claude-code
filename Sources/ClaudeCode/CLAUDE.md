# ClaudeCode

Pure CLI client library for `claude -p`. **No UI framework, no consuming
app's types, no UI concepts.** This package is consumed by more than one
app; anything app-specific belongs in the app, not here.

Published publicly at `github.com/CJPoll/swift-claude-code`. Consumers pin
it by exact version, so **a released tag is immutable** — fix a mistake by
tagging forward, never by moving a tag out from under a resolved
`Package.resolved`.

## Patterns

### Never declare a type named `ClaudeCode`

The module is already called that, and a public type of the same name shadows
it everywhere. `ClaudeCode.SessionOptions` in a consumer then resolves to the
*type* and fails to compile — and, worse, a consumer that declares its own
`JSONValue` (KodeMonkee does) gets its own silently, with no syntax left to
name ours.

0.1.0 shipped exactly that: a `public enum ClaudeCode` namespace marker, left
over from the first source file the target ever had. Removed in 0.1.1.
`ClaudeCodeTests.swift` guards it — it qualifies through the module name with
a plain `import`, so reintroducing the shadow stops the suite compiling.

Swift has no "namespace" construct separate from types. The module *is* the
namespace; nothing needs to be declared to get one.

### JSON modeling

- Use `JSONValue` (in `JSONValue.swift`) for any field whose shape is not
  part of the stable schema — tool `input`, `usage`, `rate_limit_info`,
  arbitrary `structured_output`, etc. Do not reach for `[String: Any]`;
  it is not `Sendable` or `Codable`.
- All event/content types are value types (`struct` or `enum`) and conform
  to `Codable, Equatable, Sendable`.

### Tagged-union Codable

The `Event` enum and `ContentBlock` enum both dispatch on a `"type"` string
discriminator. Pattern:

1. Read `type` with a small keyed container (`TypeKey`).
2. Re-decode the whole value through a `singleValueContainer` into the
   concrete struct for that type.
3. The concrete struct's custom `encode(to:)` re-emits `"type"` as a literal
   so round-trips preserve the tag.

This keeps each case's payload self-contained and lets us add cases without
touching unrelated branches.

### Snake_case mapping

The CLI mixes `snake_case` (e.g. `session_id`, `is_error`) with `camelCase`
(e.g. `permissionMode`, `apiKeySource`, `modelUsage`). We map each field
explicitly via `CodingKeys` rather than relying on a global key strategy.
When adding fields, check the actual JSON shape — do not assume.

### Unknown values

- Unknown event `type` values throw `DecodingError`. `EventParser.parse`
  catches these and returns `nil` so a streaming consumer can keep flowing
  past forward-compatible additions.
- Unknown `ContentBlock` types also throw — content blocks are part of the
  Anthropic API surface, so an unknown type is a real schema mismatch.

### Line-oriented parsing

`EventParser.parse(_:)` is the single entry point for converting one line
of stream-JSON stdout into an `Event`. It tolerates:

- empty / whitespace-only lines
- non-JSON diagnostic lines the CLI occasionally interleaves
- malformed JSON
- valid JSON with an unknown or missing `type`

…all of which return `nil`. Callers (the CLI adapter) should treat `nil`
as "skip this line, keep reading."

For plain-text output mode (no `--output-format stream-json`), use
`EventParser.parseTextLine(_:)` to wrap a raw line as a
`TextChunkEvent`.

### Command construction

`CommandBuilder.build(_:)` translates a `SessionOptions` value into a
`(executable, arguments)` pair for `Process`. Conventions:

- `--print` is always the first argument; `prompt` (if any) is always
  last. Everything else slots between them in a fixed order driven by
  `optionArgs(for:)`.
- Boolean-or-value flags are modeled as small enums (`Resume.mostRecent` /
  `.sessionID(_)`, `Worktree.current` / `.branch(_)`) rather than overloaded
  primitives, so callers can't accidentally pass `true` where a string is
  expected.
- Cross-option constraints (stream-json ↔ verbose, input-format vs.
  output-format, etc.) are enforced up-front in `validate(_:)` which throws
  `CommandBuilder.BuildError`. The builder itself remains a pure function;
  the throwing surface is the constraint check.
- Caller-supplied JSON blobs (`--json-schema`, `--agents`) are accepted as
  pre-encoded `String`. We don't take Swift dictionaries here — the consumer
  knows the schema and can serialize at the call site, which avoids dragging
  `JSONEncoder` configuration into the builder.

### Session adapter (side effect)

`ClaudeSession` is the **side-effects adapter** that spawns and supervises
the `claude -p` subprocess. It is an `actor` so its mutable state
(process handle, stdin file handle, status) is isolated; stdout/stderr
draining and exit watching happen on `DispatchQueue.global` because
`FileHandle.availableData` is a blocking call that would starve the Swift
concurrency thread pool if it ran on a `Task`.

`ClaudeSessionProtocol` is the **seam between this adapter and a consuming
app's Manager layer.** A Manager depends only on the protocol, never on
`ClaudeSession` itself. Tests inject `FakeClaudeSession` (under
`Tests/ClaudeCodeTests/FakeClaudeSession.swift`) — a deterministic
in-memory actor that drives its event stream from scripted helpers
(`emit`, `emitExit`) and records `sendMessage` / `interrupt` / `stop`
calls for assertion.

**Do not write automated tests that spawn a real subprocess for
`ClaudeSession`.** Per the 5-bucket architecture, the side-effects bucket
is exercised through its protocol contract (using the fake) plus manual
integration testing against a live `claude -p` install. Subprocess-driven
tests are non-deterministic, slow, and can hang the suite if a pipe never
closes — exactly the failure mode we hit during the first pass at this
task.

### Reading `swift test` output

The suite is split across **two runners**, and each reports its own total:

- swift-testing (`@Suite` / `@Test`) — `JSONValueTests`, `ContentBlockTests`,
  `EventTests`. Reports `Test run with N tests in M suites`.
- XCTest (`XCTestCase`) — everything else. Reports `Executed N tests`.

So the trailing line of `swift test` is **not** the whole count. When
checking that a move or refactor dropped nothing, compare *both* numbers
against the baseline — a whole file failing to compile into the bundle can
otherwise look like a green run. The baseline is **27 swift-testing + 80
XCTest**; bump this line when you add tests.

### Enumerated flag values come from the CLI, not the docs

Enums that model a fixed set of CLI flag values (`Effort`,
`PermissionMode`, …) are only correct if they match the installed
`claude`. `Effort` was missing `xhigh` for exactly this reason — it is
accepted by the CLI and absent from the published docs. Verify a value
set by running `claude --help` (or the flag with a bogus value, which
prints the accepted list) before adding or trusting cases.

Where such an enum is exhaustively mapped in a loop-driven test, conform
it to `CaseIterable` and assert `allCases` against the expected list. The
mapping test only covers the levels it names, so a newly added case
otherwise passes untested.

### Verifying a release

`git push` plus `git push --tags` proves the objects left the machine. It
does **not** prove the package is consumable — a wrong product name, a
`platforms:` floor above the consumer's, or a tag that resolves to the
wrong commit all survive that check and fail later in whatever repo tries
to depend on it.

Verify a release by resolving it the way a consumer will: a throwaway
package in `/tmp` whose manifest pins the **published URL** at the exact
version, with one source file that imports `ClaudeCode` and touches the
API the next task needs, then `swift build`. This exercises the remote
fetch, the version resolution and the module interface in one step. Delete
it afterwards.

### README samples are typechecked, not written from memory

Sample code in the README is API documentation, and a sample that does not
compile is worse than none. Check one by extracting it into a scratch file
and typechecking it against the built module:

```
swift build
swiftc -typecheck -swift-version 6 -target arm64-apple-macosx14.0 \
  -I .build/arm64-apple-macosx/debug/Modules /tmp/sample.swift
```

This caught `await session.events` in the first draft — `events` is
`nonisolated`, so the `await` is wrong.

### stdin envelope

`InputMessage.toJSON()` produces the single-line `{"type":"user",
"message":{"role":"user","content":[...]}}` envelope expected by
`claude --input-format stream-json`. Plain strings auto-wrap into a single
`{"type":"text","text":...}` block; for image/mixed input pass an explicit
`[JSONValue]` of blocks. Encoded with `[.sortedKeys]` so output is
byte-stable and tests can compare strings if needed.

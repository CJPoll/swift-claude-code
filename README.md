# swift-claude-code

A Swift client for the [Claude Code](https://claude.com/claude-code) CLI's
streaming JSON protocol.

The package models `claude -p` as a long-lived subprocess: user turns are
written to stdin as JSON envelopes, and the CLI's stdout is read back as
newline-delimited JSON events. That shape — rather than one process per turn —
is what makes interactive permission prompts and `AskUserQuestion` possible,
since a text-input `claude -p` run has no channel to answer them on.

It is deliberately app-agnostic: no SwiftUI, no UI concepts, no host
application types. The library gives you an argument builder, a typed event
union, a line parser, and an actor that owns the subprocess — the layers above
that are yours.

## Verified against

**Claude Code CLI 2.1.219.** The flag values and event types here were
confirmed by running that binary, not by reading the published documentation,
which lags it in at least three places:

- `--effort` accepts `xhigh` between `high` and `max`.
- `--permission-mode` accepts `default` as an undocumented alias.
- The stream emits `system/status` and `rate_limit_event` frames that no
  published schema mentions.

`EventParser.parse` returns `nil` for event types it does not recognise rather
than throwing, so a CLI that grows a new frame type does not break a consumer
that has not been rebuilt.

## Requirements

- macOS 14+
- Swift 6.0+ toolchain (the package builds in Swift 6 language mode)
- The `claude` CLI on the host

## Installation

```swift
.package(url: "https://github.com/CJPoll/swift-claude-code", exact: "0.1.0")
```

and add `"ClaudeCode"` to your target's dependencies.

## Usage

Configure a session with `SessionOptions`, which is a pure value type — every
flag defaults to off, so you only state what you care about:

```swift
import ClaudeCode

var options = SessionOptions()
options.outputFormat = .streamJSON
options.inputFormat = .streamJSON      // required for multi-turn and control responses
options.model = "claude-sonnet-5"
options.effort = .high
options.permissionMode = .default
options.permissionPromptTool = "stdio" // routes permission asks over the same channel
options.verbose = true
options.includePartialMessages = true  // token-by-token `stream_event` frames

let session = try ClaudeSession(options: options, cwd: "/path/to/worktree")
```

Consume the lifetime event stream, then start the process and send a turn:

```swift
Task {
    for await sessionEvent in session.events {   // `events` is nonisolated
        switch sessionEvent {
        case .event(let event):   handle(event)
        case .stderr(let line):   log(line)
        case .parseError(let ln): log("unparsed: \(ln)")
        case .exit(let code):     log("exited \(code)")
        case .error(let err):     log(err.description)
        }
    }
}

try await session.start()
try await session.sendMessage(InputMessage(text: "What does this module do?"))
```

`Event` is a closed union over the CLI's frames:

| Case | Carries |
|---|---|
| `.system` | `session_id`, model, cwd, tools, permission mode, capabilities |
| `.assistant` / `.user` | a complete `Message` of `[ContentBlock]` |
| `.stream` | a partial-message frame, including text deltas |
| `.result` | `is_error`, `total_cost_usd`, `permission_denials`, `session_id` |
| `.rateLimit` | rate limit info |
| `.controlRequest` | a tool permission ask, with `request_id` and tool input |
| `.textChunk` | a raw line, when the session runs in text output mode |

### Stopping a turn

`interrupt()` sends SIGINT: the current turn aborts and the process stays
alive, so the next prompt does not pay for a respawn and a `--resume`.
`stop()` terminates the subprocess and finishes the event stream.

### Testing against it

`ClaudeSessionProtocol` is the seam. Depend on it from your orchestration
layer and substitute a fake in tests — the package's own suite never spawns a
real `claude`, because subprocess-driven tests are non-deterministic, slow,
and can hang a suite outright if a pipe never closes.

For tests that genuinely need a process, `ClaudeSession`'s low-level
initialiser takes an arbitrary executable and argument vector, so a
deterministic fixture command can stand in for the CLI.

## Contributing

`Sources/ClaudeCode/CLAUDE.md` documents the conventions this package holds
itself to: the tagged-union `Codable` pattern, the snake_case-to-camelCase
mapping rule, the line-oriented parsing contract, and how to read `swift
test`'s two independent totals.

```
swift build
swift test
```

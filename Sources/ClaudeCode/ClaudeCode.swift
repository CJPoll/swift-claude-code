// ClaudeCode library target — standalone client for the `claude -p` CLI.
//
// This file exists to give the target an initial source file. Concrete
// types (events, parser, command builder, session adapter) are added in
// subsequent tasks.

/// Namespace marker for the ClaudeCode library.
public enum ClaudeCode {
    /// Library version string. Bumped manually as the public surface evolves.
    public static let version = "0.0.1"
}

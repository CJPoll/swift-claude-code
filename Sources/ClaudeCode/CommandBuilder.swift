import Foundation

/// Builds the executable name + argument vector for spawning `claude -p`.
///
/// Pure function with no side effects: a `SessionOptions` value in, an
/// `(executable, arguments)` pair out, with cross-flag constraints checked
/// up front by `validate(_:)`.
public enum CommandBuilder {
    /// Result of `build(_:)`: the executable to invoke and its arguments.
    public struct Command: Sendable, Equatable {
        public let executable: String
        public let arguments: [String]

        public init(executable: String, arguments: [String]) {
            self.executable = executable
            self.arguments = arguments
        }
    }

    /// Errors raised when option combinations are incompatible.
    public enum BuildError: Error, Equatable, Sendable, CustomStringConvertible {
        case streamJSONRequiresVerbose
        case inputFormatRequiresStreamJSON
        case includePartialMessagesRequiresStreamJSON
        case replayUserMessagesRequiresStreamJSON

        public var description: String {
            switch self {
            case .streamJSONRequiresVerbose:
                return "output_format streamJSON requires verbose: true"
            case .inputFormatRequiresStreamJSON:
                return "input_format streamJSON requires output_format streamJSON"
            case .includePartialMessagesRequiresStreamJSON:
                return "includePartialMessages requires output_format streamJSON"
            case .replayUserMessagesRequiresStreamJSON:
                return "replayUserMessages requires both input_format and output_format streamJSON"
            }
        }
    }

    /// Build the command for spawning `claude` with the supplied options.
    /// Throws `BuildError` if any incompatible option combination is detected.
    public static func build(_ options: SessionOptions = SessionOptions()) throws -> Command {
        try validate(options)

        var args: [String] = ["--print"]
        args.append(contentsOf: optionArgs(for: options))
        if let prompt = options.prompt {
            args.append(prompt)
        }

        return Command(executable: options.cliPath, arguments: args)
    }

    // MARK: - Validation

    private static func validate(_ options: SessionOptions) throws {
        if options.outputFormat == .streamJSON, options.verbose == false {
            throw BuildError.streamJSONRequiresVerbose
        }
        if options.inputFormat == .streamJSON, options.outputFormat != .streamJSON {
            throw BuildError.inputFormatRequiresStreamJSON
        }
        if options.includePartialMessages, options.outputFormat != .streamJSON {
            throw BuildError.includePartialMessagesRequiresStreamJSON
        }
        if options.replayUserMessages,
           options.inputFormat != .streamJSON || options.outputFormat != .streamJSON {
            throw BuildError.replayUserMessagesRequiresStreamJSON
        }
    }

    // MARK: - Argument emission

    private static func optionArgs(for opts: SessionOptions) -> [String] {
        var args: [String] = []

        if let v = opts.outputFormat { args.append(contentsOf: ["--output-format", v.argValue]) }
        if let v = opts.inputFormat { args.append(contentsOf: ["--input-format", v.argValue]) }
        if let v = opts.model { args.append(contentsOf: ["--model", v]) }
        if let v = opts.systemPrompt { args.append(contentsOf: ["--system-prompt", v]) }
        if let v = opts.appendSystemPrompt { args.append(contentsOf: ["--append-system-prompt", v]) }
        if let v = opts.maxBudgetUSD {
            args.append(contentsOf: ["--max-budget-usd", formatBudget(v)])
        }
        if let v = opts.allowedTools { args.append(contentsOf: ["--allowed-tools", v.joined(separator: ",")]) }
        if let v = opts.disallowedTools { args.append(contentsOf: ["--disallowed-tools", v.joined(separator: ",")]) }
        if let v = opts.tools { args.append(contentsOf: ["--tools", v.joined(separator: ",")]) }
        if let v = opts.permissionMode { args.append(contentsOf: ["--permission-mode", v.argValue]) }
        if let v = opts.sessionID { args.append(contentsOf: ["--session-id", v]) }
        if let v = opts.resume {
            switch v {
            case .mostRecent: args.append("--resume")
            case .sessionID(let id): args.append(contentsOf: ["--resume", id])
            }
        }
        if opts.continue { args.append("--continue") }
        for dir in opts.addDir { args.append(contentsOf: ["--add-dir", dir]) }
        if let v = opts.mcpConfig { args.append(contentsOf: ["--mcp-config", v]) }
        if let v = opts.permissionPromptTool {
            args.append(contentsOf: ["--permission-prompt-tool", v])
        }
        if let v = opts.jsonSchema { args.append(contentsOf: ["--json-schema", v]) }
        if opts.verbose { args.append("--verbose") }
        if opts.includePartialMessages { args.append("--include-partial-messages") }
        if opts.replayUserMessages { args.append("--replay-user-messages") }
        if opts.noSessionPersistence { args.append("--no-session-persistence") }
        if let v = opts.fallbackModel { args.append(contentsOf: ["--fallback-model", v]) }
        if opts.bare { args.append("--bare") }
        if let v = opts.effort { args.append(contentsOf: ["--effort", v.argValue]) }
        if let v = opts.agent { args.append(contentsOf: ["--agent", v]) }
        if let v = opts.agents { args.append(contentsOf: ["--agents", v]) }
        if let v = opts.name { args.append(contentsOf: ["--name", v]) }
        if opts.forkSession { args.append("--fork-session") }
        if let v = opts.worktree {
            switch v {
            case .current: args.append("--worktree")
            case .branch(let name): args.append(contentsOf: ["--worktree", name])
            }
        }

        return args
    }

    /// Format a budget number the way Elixir's `to_string/1` formats floats:
    /// integral values render as `"1"` not `"1.0"`, and trailing zeros are
    /// trimmed (`0.50` → `"0.5"`).
    private static func formatBudget(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e16 {
            return String(Int64(value))
        }
        // Trim trailing zeros from a fixed representation.
        var s = String(value)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }
}

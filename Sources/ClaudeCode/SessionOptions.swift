import Foundation

/// All configuration knobs for spawning `claude -p`.
///
/// This is a pure value type — `CommandBuilder.build(_:)` translates it into an
/// argument vector for `Process`. Fields default to `nil` / `false` so callers
/// only specify what they care about.
public struct SessionOptions: Sendable, Equatable {
    // MARK: - Nested types

    /// Output format expected from the CLI on stdout.
    public enum OutputFormat: Sendable, Equatable {
        case json
        case text
        case streamJSON

        var argValue: String {
            switch self {
            case .json: return "json"
            case .text: return "text"
            case .streamJSON: return "stream-json"
            }
        }
    }

    /// Input format the CLI should expect on stdin.
    public enum InputFormat: Sendable, Equatable {
        case streamJSON

        var argValue: String {
            switch self {
            case .streamJSON: return "stream-json"
            }
        }
    }

    /// Permission mode for the CLI.
    public enum PermissionMode: Sendable, Equatable {
        case acceptEdits
        case auto
        case bypassPermissions
        case `default`
        case dontAsk
        case plan

        var argValue: String {
            switch self {
            case .acceptEdits: return "acceptEdits"
            case .auto: return "auto"
            case .bypassPermissions: return "bypassPermissions"
            case .default: return "default"
            case .dontAsk: return "dontAsk"
            case .plan: return "plan"
            }
        }
    }

    /// Reasoning effort level.
    public enum Effort: Sendable, Equatable {
        case low
        case medium
        case high
        case max

        var argValue: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            case .max: return "max"
            }
        }
    }

    /// `--resume` may be passed alone (resume most recent) or with a session id.
    public enum Resume: Sendable, Equatable {
        case mostRecent
        case sessionID(String)
    }

    /// `--worktree` may be passed alone (use current) or with a branch name.
    public enum Worktree: Sendable, Equatable {
        case current
        case branch(String)
    }

    // MARK: - Properties

    /// Path or name of the `claude` executable. Defaults to `"claude"`.
    public var cliPath: String

    /// Environment variables for the subprocess. When non-nil, replaces the
    /// inherited process environment. Callers that want to augment rather than
    /// replace should start from `ProcessInfo.processInfo.environment`.
    public var environment: [String: String]?

    /// If set, appended as the final positional argument.
    public var prompt: String?

    public var outputFormat: OutputFormat?
    public var inputFormat: InputFormat?
    public var model: String?
    public var systemPrompt: String?
    public var appendSystemPrompt: String?
    public var maxBudgetUSD: Double?
    public var allowedTools: [String]?
    public var disallowedTools: [String]?
    public var tools: [String]?
    public var permissionMode: PermissionMode?
    public var sessionID: String?
    public var resume: Resume?
    public var `continue`: Bool
    public var addDir: [String]
    public var mcpConfig: String?
    /// Permission-prompt tool passed via `--permission-prompt-tool`. The
    /// control-protocol transport uses `"stdio"`.
    public var permissionPromptTool: String?
    /// Already-encoded JSON string for `--json-schema`.
    public var jsonSchema: String?
    public var verbose: Bool
    public var includePartialMessages: Bool
    public var replayUserMessages: Bool
    public var noSessionPersistence: Bool
    public var fallbackModel: String?
    public var bare: Bool
    public var effort: Effort?
    public var agent: String?
    /// Already-encoded JSON string for `--agents`.
    public var agents: String?
    public var name: String?
    public var forkSession: Bool
    public var worktree: Worktree?

    // MARK: - Init

    public init(
        cliPath: String = "claude",
        environment: [String: String]? = nil,
        prompt: String? = nil,
        outputFormat: OutputFormat? = nil,
        inputFormat: InputFormat? = nil,
        model: String? = nil,
        systemPrompt: String? = nil,
        appendSystemPrompt: String? = nil,
        maxBudgetUSD: Double? = nil,
        allowedTools: [String]? = nil,
        disallowedTools: [String]? = nil,
        tools: [String]? = nil,
        permissionMode: PermissionMode? = nil,
        sessionID: String? = nil,
        resume: Resume? = nil,
        continue continueFlag: Bool = false,
        addDir: [String] = [],
        mcpConfig: String? = nil,
        permissionPromptTool: String? = nil,
        jsonSchema: String? = nil,
        verbose: Bool = false,
        includePartialMessages: Bool = false,
        replayUserMessages: Bool = false,
        noSessionPersistence: Bool = false,
        fallbackModel: String? = nil,
        bare: Bool = false,
        effort: Effort? = nil,
        agent: String? = nil,
        agents: String? = nil,
        name: String? = nil,
        forkSession: Bool = false,
        worktree: Worktree? = nil
    ) {
        self.cliPath = cliPath
        self.environment = environment
        self.prompt = prompt
        self.outputFormat = outputFormat
        self.inputFormat = inputFormat
        self.model = model
        self.systemPrompt = systemPrompt
        self.appendSystemPrompt = appendSystemPrompt
        self.maxBudgetUSD = maxBudgetUSD
        self.allowedTools = allowedTools
        self.disallowedTools = disallowedTools
        self.tools = tools
        self.permissionMode = permissionMode
        self.sessionID = sessionID
        self.resume = resume
        self.continue = continueFlag
        self.addDir = addDir
        self.mcpConfig = mcpConfig
        self.permissionPromptTool = permissionPromptTool
        self.jsonSchema = jsonSchema
        self.verbose = verbose
        self.includePartialMessages = includePartialMessages
        self.replayUserMessages = replayUserMessages
        self.noSessionPersistence = noSessionPersistence
        self.fallbackModel = fallbackModel
        self.bare = bare
        self.effort = effort
        self.agent = agent
        self.agents = agents
        self.name = name
        self.forkSession = forkSession
        self.worktree = worktree
    }
}

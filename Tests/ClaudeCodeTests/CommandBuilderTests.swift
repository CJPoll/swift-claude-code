import XCTest
@testable import ClaudeCode

final class CommandBuilderTests: XCTestCase {

    // MARK: - Helpers

    /// Asserts that `sequence` appears as a contiguous subsequence in `args`.
    private func assertContainsSequence(
        _ args: [String],
        _ sequence: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !sequence.isEmpty, args.count >= sequence.count else {
            XCTFail("Expected \(args) to contain \(sequence)", file: file, line: line)
            return
        }
        for start in 0...(args.count - sequence.count) {
            if Array(args[start..<(start + sequence.count)]) == sequence { return }
        }
        XCTFail("Expected \(args) to contain sequence \(sequence)", file: file, line: line)
    }

    private func build(_ options: SessionOptions = SessionOptions()) throws -> CommandBuilder.Command {
        try CommandBuilder.build(options)
    }

    // MARK: - Defaults

    func testNoOptionsReturnsClaudeWithPrint() throws {
        let cmd = try build()
        XCTAssertEqual(cmd.executable, "claude")
        XCTAssertEqual(cmd.arguments, ["--print"])
    }

    func testAlwaysIncludesPrint() throws {
        let cmd = try build(SessionOptions(model: "sonnet"))
        XCTAssertTrue(cmd.arguments.contains("--print"))
    }

    // MARK: - Prompt

    func testPromptIsLastArgument() throws {
        let cmd = try build(SessionOptions(prompt: "hello world"))
        XCTAssertEqual(cmd.arguments, ["--print", "hello world"])
    }

    func testPromptIsLastWithOtherOptions() throws {
        let cmd = try build(SessionOptions(
            prompt: "do something",
            outputFormat: .streamJSON,
            model: "claude-sonnet-4-20250514",
            verbose: true
        ))
        XCTAssertEqual(cmd.arguments.last, "do something")
    }

    // MARK: - cliPath

    func testCustomCLIPath() throws {
        let cmd = try build(SessionOptions(cliPath: "/usr/local/bin/claude"))
        XCTAssertEqual(cmd.executable, "/usr/local/bin/claude")
        XCTAssertEqual(cmd.arguments, ["--print"])
    }

    // MARK: - Output format

    func testOutputFormatJSON() throws {
        let cmd = try build(SessionOptions(outputFormat: .json))
        assertContainsSequence(cmd.arguments, ["--output-format", "json"])
    }

    func testOutputFormatText() throws {
        let cmd = try build(SessionOptions(outputFormat: .text))
        assertContainsSequence(cmd.arguments, ["--output-format", "text"])
    }

    func testOutputFormatStreamJSONWithVerbose() throws {
        let cmd = try build(SessionOptions(outputFormat: .streamJSON, verbose: true))
        assertContainsSequence(cmd.arguments, ["--output-format", "stream-json"])
        XCTAssertTrue(cmd.arguments.contains("--verbose"))
    }

    func testOutputFormatStreamJSONWithoutVerboseThrows() {
        XCTAssertThrowsError(try build(SessionOptions(outputFormat: .streamJSON))) { error in
            XCTAssertEqual(error as? CommandBuilder.BuildError, .streamJSONRequiresVerbose)
        }
    }

    // MARK: - Input format

    func testInputFormatStreamJSONWithoutMatchingOutputThrows() {
        XCTAssertThrowsError(try build(SessionOptions(
            outputFormat: .json,
            inputFormat: .streamJSON
        ))) { error in
            XCTAssertEqual(error as? CommandBuilder.BuildError, .inputFormatRequiresStreamJSON)
        }
    }

    func testInputFormatStreamJSONWithStreamJSONOutput() throws {
        let cmd = try build(SessionOptions(
            outputFormat: .streamJSON,
            inputFormat: .streamJSON,
            verbose: true
        ))
        assertContainsSequence(cmd.arguments, ["--input-format", "stream-json"])
        assertContainsSequence(cmd.arguments, ["--output-format", "stream-json"])
    }

    // MARK: - Model

    func testModelProducesFlag() throws {
        let cmd = try build(SessionOptions(model: "claude-sonnet-4-20250514"))
        assertContainsSequence(cmd.arguments, ["--model", "claude-sonnet-4-20250514"])
    }

    // MARK: - System prompts

    func testSystemPrompt() throws {
        let cmd = try build(SessionOptions(systemPrompt: "You are helpful"))
        assertContainsSequence(cmd.arguments, ["--system-prompt", "You are helpful"])
    }

    func testAppendSystemPrompt() throws {
        let cmd = try build(SessionOptions(appendSystemPrompt: "Be concise"))
        assertContainsSequence(cmd.arguments, ["--append-system-prompt", "Be concise"])
    }

    // MARK: - Max budget

    func testMaxBudgetUSDTrimsTrailingZero() throws {
        let cmd = try build(SessionOptions(maxBudgetUSD: 0.50))
        assertContainsSequence(cmd.arguments, ["--max-budget-usd", "0.5"])
    }

    func testMaxBudgetUSDIntegralRendersWithoutDecimal() throws {
        let cmd = try build(SessionOptions(maxBudgetUSD: 5.0))
        assertContainsSequence(cmd.arguments, ["--max-budget-usd", "5"])
    }

    // MARK: - Tool lists

    func testAllowedTools() throws {
        let cmd = try build(SessionOptions(allowedTools: ["Bash", "Edit"]))
        assertContainsSequence(cmd.arguments, ["--allowed-tools", "Bash,Edit"])
    }

    func testDisallowedTools() throws {
        let cmd = try build(SessionOptions(disallowedTools: ["WebSearch"]))
        assertContainsSequence(cmd.arguments, ["--disallowed-tools", "WebSearch"])
    }

    func testTools() throws {
        let cmd = try build(SessionOptions(tools: ["Bash", "Edit", "Read"]))
        assertContainsSequence(cmd.arguments, ["--tools", "Bash,Edit,Read"])
    }

    // MARK: - Permission modes

    func testPermissionModeMappings() throws {
        let cases: [(SessionOptions.PermissionMode, String)] = [
            (.acceptEdits, "acceptEdits"),
            (.auto, "auto"),
            (.bypassPermissions, "bypassPermissions"),
            (.default, "default"),
            (.dontAsk, "dontAsk"),
            (.plan, "plan")
        ]
        for (mode, expected) in cases {
            let cmd = try build(SessionOptions(permissionMode: mode))
            assertContainsSequence(cmd.arguments, ["--permission-mode", expected])
        }
    }

    // MARK: - Session id

    func testSessionID() throws {
        let cmd = try build(SessionOptions(sessionID: "abc-123"))
        assertContainsSequence(cmd.arguments, ["--session-id", "abc-123"])
    }

    // MARK: - Resume

    func testResumeWithSessionID() throws {
        let cmd = try build(SessionOptions(resume: .sessionID("session-uuid")))
        assertContainsSequence(cmd.arguments, ["--resume", "session-uuid"])
    }

    func testResumeMostRecentDoesNotEmitValue() throws {
        let cmd = try build(SessionOptions(resume: .mostRecent))
        XCTAssertTrue(cmd.arguments.contains("--resume"))
        let idx = cmd.arguments.firstIndex(of: "--resume")!
        let next = idx + 1 < cmd.arguments.count ? cmd.arguments[idx + 1] : nil
        XCTAssertNotEqual(next, "true")
    }

    // MARK: - Continue

    func testContinueTrue() throws {
        let cmd = try build(SessionOptions(continue: true))
        XCTAssertTrue(cmd.arguments.contains("--continue"))
    }

    func testContinueFalse() throws {
        let cmd = try build(SessionOptions(continue: false))
        XCTAssertFalse(cmd.arguments.contains("--continue"))
    }

    // MARK: - Add dir

    func testAddDir() throws {
        let cmd = try build(SessionOptions(addDir: ["/tmp/a", "/tmp/b"]))
        assertContainsSequence(cmd.arguments, ["--add-dir", "/tmp/a"])
        assertContainsSequence(cmd.arguments, ["--add-dir", "/tmp/b"])
    }

    // MARK: - mcp_config

    func testMcpConfig() throws {
        let cmd = try build(SessionOptions(mcpConfig: "/path/config.json"))
        assertContainsSequence(cmd.arguments, ["--mcp-config", "/path/config.json"])
    }

    // MARK: - permission_prompt_tool

    func testPermissionPromptToolStdio() throws {
        let cmd = try build(SessionOptions(permissionPromptTool: "stdio"))
        assertContainsSequence(cmd.arguments, ["--permission-prompt-tool", "stdio"])
    }

    func testPermissionPromptToolOmittedWhenNil() throws {
        let cmd = try build(SessionOptions())
        XCTAssertFalse(cmd.arguments.contains("--permission-prompt-tool"))
    }

    // MARK: - json_schema

    func testJSONSchemaPassesStringThrough() throws {
        let schema = #"{"type":"object"}"#
        let cmd = try build(SessionOptions(jsonSchema: schema))
        assertContainsSequence(cmd.arguments, ["--json-schema", schema])
    }

    // MARK: - includePartialMessages

    func testIncludePartialMessagesRequiresStreamJSON() {
        XCTAssertThrowsError(try build(SessionOptions(
            outputFormat: .json,
            includePartialMessages: true
        ))) { error in
            XCTAssertEqual(
                error as? CommandBuilder.BuildError,
                .includePartialMessagesRequiresStreamJSON
            )
        }
    }

    func testIncludePartialMessagesWithStreamJSON() throws {
        let cmd = try build(SessionOptions(
            outputFormat: .streamJSON,
            verbose: true,
            includePartialMessages: true
        ))
        XCTAssertTrue(cmd.arguments.contains("--include-partial-messages"))
    }

    // MARK: - replayUserMessages

    func testReplayUserMessagesRequiresBothStreamJSON() {
        XCTAssertThrowsError(try build(SessionOptions(
            outputFormat: .json,
            inputFormat: .streamJSON,
            replayUserMessages: true
        ))) { error in
            // (input/output format mismatch trips first — same intent for the caller.)
            XCTAssertNotNil(error as? CommandBuilder.BuildError)
        }

        XCTAssertThrowsError(try build(SessionOptions(
            outputFormat: .streamJSON,
            verbose: true,
            replayUserMessages: true
        ))) { error in
            XCTAssertEqual(
                error as? CommandBuilder.BuildError,
                .replayUserMessagesRequiresStreamJSON
            )
        }
    }

    func testReplayUserMessagesWithBothStreamJSON() throws {
        let cmd = try build(SessionOptions(
            outputFormat: .streamJSON,
            inputFormat: .streamJSON,
            verbose: true,
            replayUserMessages: true
        ))
        XCTAssertTrue(cmd.arguments.contains("--replay-user-messages"))
    }

    // MARK: - Boolean flags

    func testVerboseToggle() throws {
        XCTAssertTrue(
            try build(SessionOptions(outputFormat: .streamJSON, verbose: true))
                .arguments.contains("--verbose")
        )
        XCTAssertFalse(try build(SessionOptions(verbose: false)).arguments.contains("--verbose"))
    }

    func testBareToggle() throws {
        XCTAssertTrue(try build(SessionOptions(bare: true)).arguments.contains("--bare"))
        XCTAssertFalse(try build(SessionOptions(bare: false)).arguments.contains("--bare"))
    }

    func testNoSessionPersistenceToggle() throws {
        XCTAssertTrue(
            try build(SessionOptions(noSessionPersistence: true))
                .arguments.contains("--no-session-persistence")
        )
        XCTAssertFalse(
            try build(SessionOptions(noSessionPersistence: false))
                .arguments.contains("--no-session-persistence")
        )
    }

    func testForkSessionToggle() throws {
        XCTAssertTrue(try build(SessionOptions(forkSession: true)).arguments.contains("--fork-session"))
        XCTAssertFalse(try build(SessionOptions(forkSession: false)).arguments.contains("--fork-session"))
    }

    // MARK: - Fallback model

    func testFallbackModel() throws {
        let cmd = try build(SessionOptions(fallbackModel: "claude-haiku-3-5"))
        assertContainsSequence(cmd.arguments, ["--fallback-model", "claude-haiku-3-5"])
    }

    // MARK: - Effort

    func testEffortMappings() throws {
        for (level, expected) in [
            (SessionOptions.Effort.low, "low"),
            (.medium, "medium"),
            (.high, "high"),
            (.max, "max")
        ] {
            let cmd = try build(SessionOptions(effort: level))
            assertContainsSequence(cmd.arguments, ["--effort", expected])
        }
    }

    // MARK: - Agent / agents / name

    func testAgent() throws {
        let cmd = try build(SessionOptions(agent: "reviewer"))
        assertContainsSequence(cmd.arguments, ["--agent", "reviewer"])
    }

    func testAgentsPassesStringThrough() throws {
        let json = #"{"reviewer":{}}"#
        let cmd = try build(SessionOptions(agents: json))
        assertContainsSequence(cmd.arguments, ["--agents", json])
    }

    func testName() throws {
        let cmd = try build(SessionOptions(name: "my-session"))
        assertContainsSequence(cmd.arguments, ["--name", "my-session"])
    }

    // MARK: - Worktree

    func testWorktreeCurrentDoesNotEmitValue() throws {
        let cmd = try build(SessionOptions(worktree: .current))
        XCTAssertTrue(cmd.arguments.contains("--worktree"))
        let idx = cmd.arguments.firstIndex(of: "--worktree")!
        let next = idx + 1 < cmd.arguments.count ? cmd.arguments[idx + 1] : nil
        XCTAssertNotEqual(next, "true")
    }

    func testWorktreeBranchEmitsValue() throws {
        let cmd = try build(SessionOptions(worktree: .branch("feature-branch")))
        assertContainsSequence(cmd.arguments, ["--worktree", "feature-branch"])
    }

    // MARK: - Combined

    func testCombinedOptionsProduceAllFlags() throws {
        let cmd = try build(SessionOptions(
            prompt: "go",
            outputFormat: .streamJSON,
            inputFormat: .streamJSON,
            model: "sonnet",
            systemPrompt: "sys",
            allowedTools: ["Bash"],
            permissionMode: .acceptEdits,
            sessionID: "sess",
            verbose: true,
            agent: "ralph"
        ))

        // --print first, prompt last.
        XCTAssertEqual(cmd.arguments.first, "--print")
        XCTAssertEqual(cmd.arguments.last, "go")

        assertContainsSequence(cmd.arguments, ["--output-format", "stream-json"])
        assertContainsSequence(cmd.arguments, ["--input-format", "stream-json"])
        assertContainsSequence(cmd.arguments, ["--model", "sonnet"])
        assertContainsSequence(cmd.arguments, ["--system-prompt", "sys"])
        assertContainsSequence(cmd.arguments, ["--allowed-tools", "Bash"])
        assertContainsSequence(cmd.arguments, ["--permission-mode", "acceptEdits"])
        assertContainsSequence(cmd.arguments, ["--session-id", "sess"])
        assertContainsSequence(cmd.arguments, ["--agent", "ralph"])
        XCTAssertTrue(cmd.arguments.contains("--verbose"))
    }
}

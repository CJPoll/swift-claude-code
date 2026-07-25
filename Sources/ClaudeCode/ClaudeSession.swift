import Foundation

/// Spawns and supervises a `claude -p` subprocess, exposing its event stream
/// as an `AsyncStream<SessionEvent>`.
///
/// The session is an actor: all mutable state (process, stdin handle, status)
/// is actor-isolated. Two detached `Task`s read stdout line-by-line and watch
/// for process exit, feeding everything back into the actor's event stream.
///
/// Typical usage:
///
///     let session = ClaudeSession(
///         options: SessionOptions(
///             prompt: "hello",
///             outputFormat: .streamJSON,
///             inputFormat: .streamJSON,
///             verbose: true
///         )
///     )
///     try await session.start()
///     for await event in session.events {
///         switch event {
///         case .event(let e): // ... apply via EventProcessor
///         case .parseError: break
///         case .stderr: break
///         case .exit: break
///         case .error: break
///         }
///     }
///
/// `start()` is idempotent: a second call on an already-running session is a
/// no-op. After exit, the session is single-use — create a new instance to
/// restart.
public actor ClaudeSession {
    // MARK: - Public types

    /// Events delivered through `events`. Wraps parsed CLI events plus
    /// session-level lifecycle signals (errors, stderr, exit).
    public enum SessionEvent: Sendable, Equatable {
        case event(Event)
        case parseError(line: String)
        case stderr(String)
        case exit(Int32)
        case error(SessionError)
    }

    public enum SessionError: Error, Sendable, Equatable, CustomStringConvertible {
        case notRunning
        case notStreamJSONInput
        case spawnFailed(String)
        case writeFailed(String)

        public var description: String {
            switch self {
            case .notRunning: return "Session is not running"
            case .notStreamJSONInput: return "Session input format is not streamJSON"
            case .spawnFailed(let why): return "Failed to spawn subprocess: \(why)"
            case .writeFailed(let why): return "Failed to write to subprocess stdin: \(why)"
            }
        }
    }

    public enum Status: Sendable, Equatable {
        case idle
        case running
        case stopping
        case stopped
    }

    /// How stdout lines should be interpreted.
    public enum OutputMode: Sendable, Equatable {
        case json
        case text
    }

    /// Whether stdin accepts `--input-format stream-json` envelopes.
    public enum InputMode: Sendable, Equatable {
        case streamJSON
        case none
    }

    // MARK: - Public stream

    /// Lifetime stream of session events. Finishes when the subprocess exits
    /// (or fails to spawn). Safe to read from outside the actor.
    public nonisolated let events: AsyncStream<SessionEvent>

    // MARK: - Internal state

    private let executable: String
    private let arguments: [String]
    private let cwd: String?
    private let outputMode: OutputMode
    private let inputMode: InputMode
    private let environment: [String: String]?

    private var process: Process?
    private var stdinHandle: FileHandle?
    private var status: Status = .idle
    private let continuation: AsyncStream<SessionEvent>.Continuation

    // MARK: - Inits

    /// Construct from `SessionOptions`. Uses `CommandBuilder` to derive the
    /// executable + arguments. The `outputMode` / `inputMode` are inferred
    /// from `options.outputFormat` and `options.inputFormat`.
    public init(options: SessionOptions, cwd: String? = nil) throws {
        let command = try CommandBuilder.build(options)
        let output: OutputMode = (options.outputFormat == .text) ? .text : .json
        let input: InputMode = (options.inputFormat == .streamJSON) ? .streamJSON : .none
        self.init(
            executable: command.executable,
            arguments: command.arguments,
            cwd: cwd,
            outputMode: output,
            inputMode: input,
            environment: options.environment
        )
    }

    /// Low-level init: spawn an arbitrary executable. Useful for tests that
    /// substitute `claude -p` with a deterministic fixture command.
    public init(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        outputMode: OutputMode = .json,
        inputMode: InputMode = .none,
        environment: [String: String]? = nil
    ) {
        self.executable = executable
        self.arguments = arguments
        self.cwd = cwd
        self.outputMode = outputMode
        self.inputMode = inputMode
        self.environment = environment

        let (stream, cont) = AsyncStream<SessionEvent>.makeStream(bufferingPolicy: .unbounded)
        self.events = stream
        self.continuation = cont
    }

    // MARK: - Lifecycle

    /// Spawn the subprocess and begin streaming events. No-op if already
    /// running. Throws if the executable can't be resolved or the process
    /// fails to launch.
    public func start() throws {
        guard status == .idle else { return }

        let env = environment ?? Self.augmentedEnvironment()
        let resolved = Self.resolveExecutable(executable, in: env["PATH"] ?? "")
        guard let resolvedURL = resolved else {
            let err = SessionError.spawnFailed("'\(executable)' not found in PATH")
            continuation.yield(.error(err))
            continuation.finish()
            status = .stopped
            throw err
        }

        let process = Process()
        process.executableURL = resolvedURL
        process.arguments = arguments
        process.environment = env
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        do {
            try process.run()
        } catch {
            let err = SessionError.spawnFailed(error.localizedDescription)
            continuation.yield(.error(err))
            continuation.finish()
            status = .stopped
            throw err
        }

        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.status = .running

        // Drain stdout and stderr on dispatch queues, not Swift concurrency
        // tasks. `FileHandle.availableData` blocks the calling thread; using
        // Task.detached for blocking I/O competes with the cooperative
        // thread pool and can starve other sessions running in parallel.
        let cont = continuation
        let outMode = outputMode
        DispatchQueue.global(qos: .userInitiated).async {
            Self.drain(
                handle: stdoutPipe.fileHandleForReading,
                outputMode: outMode,
                continuation: cont
            )
        }

        DispatchQueue.global(qos: .userInitiated).async {
            Self.drainStderr(
                handle: stderrPipe.fileHandleForReading,
                continuation: cont
            )
        }

        // Watch for process exit and report the termination status. After
        // emitting the exit event, finish the stream. Likewise on a dispatch
        // queue — `waitUntilExit` is a blocking poll.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            process.waitUntilExit()
            let code = process.terminationStatus
            Task { await self?.handleExit(code) }
        }
    }

    /// Write a follow-up message to the subprocess's stdin in `--stream-json`
    /// envelope form. Requires `inputMode == .streamJSON`.
    public func sendMessage(_ message: InputMessage) throws {
        guard status == .running else { throw SessionError.notRunning }
        guard inputMode == .streamJSON else { throw SessionError.notStreamJSONInput }
        guard let handle = stdinHandle else { throw SessionError.notRunning }

        let json = try message.toJSON()
        let payload = json + "\n"
        guard let data = payload.data(using: .utf8) else {
            throw SessionError.writeFailed("encoding failed")
        }
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw SessionError.writeFailed(error.localizedDescription)
        }
    }

    /// Write a pre-encoded JSON string to the subprocess's stdin, followed
    /// by a newline. Used by the Manager layer to deliver control protocol
    /// envelopes (e.g. `control_response`) alongside ordinary user messages
    /// on the same `--input-format stream-json` channel. The caller owns
    /// envelope construction; this method is intentionally agnostic to the
    /// payload shape.
    public func sendRawJSON(_ json: String) throws {
        guard status == .running else { throw SessionError.notRunning }
        guard inputMode == .streamJSON else { throw SessionError.notStreamJSONInput }
        guard let handle = stdinHandle else { throw SessionError.notRunning }

        let payload = json + "\n"
        guard let data = payload.data(using: .utf8) else {
            throw SessionError.writeFailed("encoding failed")
        }
        do {
            try handle.write(contentsOf: data)
        } catch {
            throw SessionError.writeFailed(error.localizedDescription)
        }
    }

    /// Send SIGINT to the subprocess. The stream continues to drain any
    /// already-buffered events before the eventual exit signal.
    public func interrupt() {
        guard let process, process.isRunning else { return }
        process.interrupt()
    }

    /// Terminate the subprocess (SIGTERM) and close stdin.
    public func stop() {
        guard status == .running else { return }
        status = .stopping
        try? stdinHandle?.close()
        if let process, process.isRunning {
            process.terminate()
        }
    }

    /// Observable session status.
    public var currentStatus: Status { status }

    // MARK: - Internals

    private func handleExit(_ code: Int32) {
        status = .stopped
        continuation.yield(.exit(code))
        continuation.finish()
        process = nil
        stdinHandle = nil
    }

    /// Returns the inherited environment with common tool directories prepended
    /// to PATH. Apps launched from Finder/Dock receive a minimal system PATH
    /// that omits user package manager prefixes; this ensures `claude` and any
    /// tools it spawns can still be found.
    nonisolated private static func augmentedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extras = [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
        ]
        let existing = env["PATH"] ?? ""
        env["PATH"] = (extras + [existing]).joined(separator: ":")
        return env
    }

    /// Resolve a possibly-bare executable name to a full URL.
    /// `pathEnv` is the colon-separated PATH to search for bare names.
    nonisolated private static func resolveExecutable(_ name: String, in pathEnv: String) -> URL? {
        if name.hasPrefix("/") {
            let url = URL(fileURLWithPath: name)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        for dir in pathEnv.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Read `handle` line-by-line and forward each non-empty line as an
    /// event (or parse-error) on `continuation`. Returns on EOF.
    nonisolated private static func drain(
        handle: FileHandle,
        outputMode: OutputMode,
        continuation: AsyncStream<SessionEvent>.Continuation
    ) {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                break
            }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                emit(lineData: Data(lineData), outputMode: outputMode, continuation: continuation)
            }
        }
        // Flush any trailing partial line at EOF.
        if !buffer.isEmpty {
            emit(lineData: buffer, outputMode: outputMode, continuation: continuation)
        }
    }

    nonisolated private static func emit(
        lineData: Data,
        outputMode: OutputMode,
        continuation: AsyncStream<SessionEvent>.Continuation
    ) {
        guard let raw = String(data: lineData, encoding: .utf8) else { return }
        let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
        guard !line.isEmpty else { return }

        switch outputMode {
        case .text:
            continuation.yield(.event(EventParser.parseTextLine(line)))
        case .json:
            if let event = EventParser.parse(line) {
                continuation.yield(.event(event))
            } else {
                continuation.yield(.parseError(line: line))
            }
        }
    }

    nonisolated private static func drainStderr(
        handle: FileHandle,
        continuation: AsyncStream<SessionEvent>.Continuation
    ) {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                if let str = String(data: Data(lineData), encoding: .utf8), !str.isEmpty {
                    continuation.yield(.stderr(str))
                }
            }
        }
        if !buffer.isEmpty,
           let str = String(data: buffer, encoding: .utf8),
           !str.isEmpty {
            continuation.yield(.stderr(str))
        }
    }
}

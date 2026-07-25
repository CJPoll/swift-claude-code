import Foundation
@testable import ClaudeCode

/// Deterministic in-memory fake conforming to ``ClaudeSessionProtocol``.
///
/// Tests (here, and a consuming app's Manager-layer mock-based tests)
/// inject this in place of the real ``ClaudeSession`` so the suite never
/// spawns a subprocess. The fake drives its event stream entirely from
/// scripted method calls, giving each test full control over timing and
/// ordering.
///
/// Typical usage:
///
///     let fake = FakeClaudeSession()
///     try await fake.start()
///     await fake.emit(.event(.system(.init(...))))
///     await fake.emitExit(0)
///     for await event in fake.events { ... }
actor FakeClaudeSession: ClaudeSessionProtocol {
    nonisolated let events: AsyncStream<ClaudeSession.SessionEvent>
    private let continuation: AsyncStream<ClaudeSession.SessionEvent>.Continuation

    private(set) var status: ClaudeSession.Status = .idle
    private(set) var sentMessages: [InputMessage] = []
    private(set) var sentRawJSON: [String] = []
    private(set) var interruptCount: Int = 0
    private(set) var stopCount: Int = 0
    private(set) var startCount: Int = 0

    /// If set, ``start()`` throws this error and the stream finishes.
    var startError: ClaudeSession.SessionError?

    /// If set, ``sendMessage(_:)`` throws this error.
    var sendError: ClaudeSession.SessionError?

    init() {
        let (stream, cont) = AsyncStream<ClaudeSession.SessionEvent>.makeStream(
            bufferingPolicy: .unbounded
        )
        self.events = stream
        self.continuation = cont
    }

    var currentStatus: ClaudeSession.Status { status }

    func start() throws {
        startCount += 1
        if let err = startError {
            continuation.yield(.error(err))
            continuation.finish()
            status = .stopped
            throw err
        }
        guard status == .idle else { return }
        status = .running
    }

    func sendMessage(_ message: InputMessage) throws {
        if let err = sendError { throw err }
        guard status == .running else { throw ClaudeSession.SessionError.notRunning }
        sentMessages.append(message)
    }

    func sendRawJSON(_ json: String) throws {
        if let err = sendError { throw err }
        guard status == .running else { throw ClaudeSession.SessionError.notRunning }
        sentRawJSON.append(json)
    }

    func interrupt() {
        interruptCount += 1
    }

    func stop() {
        stopCount += 1
        guard status == .running else { return }
        status = .stopped
        continuation.finish()
    }

    // MARK: - Scripting helpers (test-only)

    /// Push a single event onto the stream.
    func emit(_ event: ClaudeSession.SessionEvent) {
        continuation.yield(event)
    }

    /// Push a parsed `Event` (most common case).
    func emit(_ event: Event) {
        continuation.yield(.event(event))
    }

    /// Push an exit signal and finish the stream.
    func emitExit(_ code: Int32) {
        status = .stopped
        continuation.yield(.exit(code))
        continuation.finish()
    }
}

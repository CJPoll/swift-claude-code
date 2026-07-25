import Foundation

/// Abstraction over a Claude CLI session. The concrete implementation
/// (``ClaudeSession``) spawns a real `claude -p` subprocess; tests and the
/// Manager layer interact through this protocol so the subprocess can be
/// substituted with a deterministic fake.
///
/// Per the 5-bucket architecture, this is the seam between the side-effects
/// bucket (``ClaudeSession``, an actor that owns a real subprocess) and the
/// Manager bucket (`SessionManager`, which orchestrates streams and state).
/// Managers should depend on this protocol, never on the concrete type.
public protocol ClaudeSessionProtocol: Actor {
    /// Lifetime stream of session events. Finishes when the underlying
    /// process exits or the session is stopped.
    nonisolated var events: AsyncStream<ClaudeSession.SessionEvent> { get }

    /// Start the session. No-op if already running. Throws on spawn failure.
    func start() throws

    /// Send a multi-turn follow-up message over the session's stdin.
    /// Requires `--input-format stream-json`.
    func sendMessage(_ message: InputMessage) throws

    /// Write a pre-encoded JSON string to the session's stdin, followed by a
    /// newline. This is the transport for non-message envelopes — most
    /// notably the control protocol's `control_response` payloads. The
    /// caller is responsible for constructing the envelope. Requires
    /// `--input-format stream-json`.
    func sendRawJSON(_ json: String) throws

    /// Send SIGINT to the subprocess. The stream continues to drain.
    func interrupt()

    /// Terminate the subprocess and finish the event stream.
    func stop()

    /// Current session status, observable by the manager.
    var currentStatus: ClaudeSession.Status { get }
}

extension ClaudeSession: ClaudeSessionProtocol {}

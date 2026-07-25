import XCTest
@testable import ClaudeCode

/// Contract tests for ``ClaudeSessionProtocol`` exercised through the
/// in-memory ``FakeClaudeSession``.
///
/// These tests *intentionally do not spawn a subprocess*. The real
/// ``ClaudeSession`` is a side-effects adapter (5-bucket architecture) and
/// is exercised by manual integration testing against a live `claude -p`
/// binary. The automated test suite verifies the protocol surface that the
/// Manager layer depends on.
final class ClaudeSessionProtocolTests: XCTestCase {

    // MARK: - Helpers

    /// Collect events from `session` until the stream finishes, bounded by
    /// `timeout`. Returns whatever was buffered if the timeout fires.
    private func collect(
        from session: any ClaudeSessionProtocol,
        timeout: TimeInterval = 2.0
    ) async -> [ClaudeSession.SessionEvent] {
        let stream = session.events
        let timeoutNs = UInt64(timeout * 1_000_000_000)

        return await withTaskGroup(of: [ClaudeSession.SessionEvent]?.self) { group in
            group.addTask {
                var events: [ClaudeSession.SessionEvent] = []
                for await event in stream {
                    events.append(event)
                }
                return events
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNs)
                return nil
            }
            defer { group.cancelAll() }
            if let first = await group.next(), let events = first {
                return events
            }
            return []
        }
    }

    // MARK: - Lifecycle

    func testStartTransitionsToRunning() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        let status = await fake.currentStatus
        XCTAssertEqual(status, .running)
    }

    func testStartIsIdempotent() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        try await fake.start()
        let count = await fake.startCount
        XCTAssertEqual(count, 2)
        let status = await fake.currentStatus
        XCTAssertEqual(status, .running)
    }

    func testStartPropagatesSpawnFailure() async {
        let fake = FakeClaudeSession()
        await fake.setStartError(.spawnFailed("missing"))

        do {
            try await fake.start()
            XCTFail("expected throw")
        } catch ClaudeSession.SessionError.spawnFailed {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let events = await collect(from: fake)
        XCTAssertTrue(events.contains { event in
            if case .error(.spawnFailed) = event { return true }
            return false
        })
    }

    func testStopFinishesStream() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.stop()
        let events = await collect(from: fake)
        // No events ever yielded, but the stream must finish or `for await`
        // would never return.
        XCTAssertTrue(events.isEmpty)
        let status = await fake.currentStatus
        XCTAssertEqual(status, .stopped)
    }

    // MARK: - Event stream

    func testEmittedEventsArriveOnStream() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()

        let system = SystemEvent(
            sessionId: "s1",
            model: "m1"
        )
        await fake.emit(.system(system))
        await fake.emitExit(0)

        let events = await collect(from: fake)
        let parsed = events.compactMap { event -> Event? in
            if case .event(let e) = event { return e } else { return nil }
        }
        XCTAssertEqual(parsed.count, 1)
        if case .system(let s) = parsed.first {
            XCTAssertEqual(s.sessionId, "s1")
        } else {
            XCTFail("expected system event")
        }
        XCTAssertEqual(events.last, .exit(0))
    }

    func testExitEmittedWithNonZeroCode() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.emitExit(7)

        let events = await collect(from: fake)
        XCTAssertEqual(events.last, .exit(7))
    }

    // MARK: - Stdin

    func testSendMessageRecordsPayload() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        try await fake.sendMessage(InputMessage(text: "hello"))
        try await fake.sendMessage(InputMessage(text: "world"))

        let sent = await fake.sentMessages
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0].content, .text("hello"))
        XCTAssertEqual(sent[1].content, .text("world"))
    }

    func testSendMessageThrowsWhenNotRunning() async {
        let fake = FakeClaudeSession()
        do {
            try await fake.sendMessage(InputMessage(text: "hi"))
            XCTFail("expected throw")
        } catch ClaudeSession.SessionError.notRunning {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSendMessagePropagatesConfiguredError() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.setSendError(.notStreamJSONInput)
        do {
            try await fake.sendMessage(InputMessage(text: "hi"))
            XCTFail("expected throw")
        } catch ClaudeSession.SessionError.notStreamJSONInput {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Raw JSON stdin (control protocol transport)

    func testSendRawJSONRecordsPayload() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        try await fake.sendRawJSON(#"{"type":"control_response","response":{"subtype":"success"}}"#)
        try await fake.sendRawJSON(#"{"type":"control_response","response":{"subtype":"error"}}"#)

        let sent = await fake.sentRawJSON
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0], #"{"type":"control_response","response":{"subtype":"success"}}"#)
        XCTAssertEqual(sent[1], #"{"type":"control_response","response":{"subtype":"error"}}"#)
    }

    func testSendRawJSONThrowsWhenNotRunning() async {
        let fake = FakeClaudeSession()
        do {
            try await fake.sendRawJSON("{}")
            XCTFail("expected throw")
        } catch ClaudeSession.SessionError.notRunning {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testSendRawJSONPropagatesConfiguredError() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.setSendError(.notStreamJSONInput)
        do {
            try await fake.sendRawJSON("{}")
            XCTFail("expected throw")
        } catch ClaudeSession.SessionError.notStreamJSONInput {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Interrupt / stop counters

    func testInterruptIncrementsCounter() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.interrupt()
        await fake.interrupt()
        let count = await fake.interruptCount
        XCTAssertEqual(count, 2)
    }

    func testStopIncrementsCounter() async throws {
        let fake = FakeClaudeSession()
        try await fake.start()
        await fake.stop()
        let count = await fake.stopCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - SessionOptions wiring (concrete adapter)

    /// `ClaudeSession(options:)` must run options through `CommandBuilder`
    /// without spawning anything (start() is what spawns). This is the only
    /// place we touch the concrete type from tests — and we never call
    /// `start()` on it.
    func testInitFromSessionOptionsDoesNotThrowForValidOptions() throws {
        let opts = SessionOptions(cliPath: "/bin/echo", prompt: "hi")
        _ = try ClaudeSession(options: opts)
    }

    func testInitFromSessionOptionsRejectsInvalidCombination() {
        // stream-json output requires verbose -> should throw from builder.
        let opts = SessionOptions(
            outputFormat: .streamJSON,
            verbose: false
        )
        XCTAssertThrowsError(try ClaudeSession(options: opts))
    }
}

// MARK: - Fake mutators

extension FakeClaudeSession {
    func setStartError(_ err: ClaudeSession.SessionError?) {
        self.startError = err
    }

    func setSendError(_ err: ClaudeSession.SessionError?) {
        self.sendError = err
    }
}

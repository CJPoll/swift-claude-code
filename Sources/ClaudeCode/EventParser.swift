import Foundation

/// Parses raw lines from `claude -p`'s stdout into typed `Event` values.
///
/// `claude -p` with `--output-format stream-json` emits one JSON object per
/// line. Occasional non-JSON diagnostic lines may also appear; those return
/// `nil` rather than throwing so a consuming stream can keep flowing.
///
/// In plain-text output mode (no `--output-format stream-json`), use
/// `parseTextLine(_:)` to wrap a raw line as a `TextChunkEvent`.
public enum EventParser {
    /// Parse a single line of stream-JSON output.
    ///
    /// Returns `nil` when:
    /// - The line is empty or whitespace-only.
    /// - The line is not valid JSON.
    /// - The JSON is valid but has no recognized `type` discriminator.
    public static func parse(_ jsonLine: String) -> Event? {
        let trimmed = jsonLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let data = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Event.self, from: data)
    }

    /// Wrap a raw line of plain-text CLI output as a `TextChunkEvent`.
    ///
    /// Used when the CLI is run without `--output-format stream-json`.
    public static func parseTextLine(_ line: String) -> Event {
        .textChunk(TextChunkEvent(text: line))
    }
}

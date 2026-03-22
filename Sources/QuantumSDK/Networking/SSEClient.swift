import Foundation

/// Parses Server-Sent Events from a URLSession byte stream.
///
/// Yields `SSEEvent` values as an `AsyncSequence`. Handles the SSE wire format
/// including `data:` prefixes, multi-line data, and `[DONE]` sentinels.
struct SSEParser: AsyncSequence {
    typealias Element = SSEEvent

    let bytes: URLSession.AsyncBytes

    struct AsyncIterator: AsyncIteratorProtocol {
        var lineIterator: URLSession.AsyncBytes.AsyncIterator
        var buffer = ""

        mutating func next() async throws -> SSEEvent? {
            while true {
                // Read characters until we have a complete line
                var line = ""
                var foundLine = false

                while true {
                    guard let byte = try await lineIterator.next() else {
                        // Stream ended
                        if !buffer.isEmpty {
                            // Process remaining buffer
                            let remaining = buffer
                            buffer = ""
                            if remaining.hasPrefix("data: ") {
                                let payload = String(remaining.dropFirst(6))
                                if let event = parsePayload(payload) {
                                    return event
                                }
                            }
                        }
                        return nil
                    }

                    let char = Character(UnicodeScalar(byte))
                    if char == "\n" {
                        foundLine = true
                        break
                    }
                    line.append(char)
                }

                guard foundLine else { continue }

                // Skip empty lines (SSE event separators)
                if line.isEmpty { continue }

                // Skip comments
                if line.hasPrefix(":") { continue }

                // Handle event/id/retry fields (ignore for now)
                if line.hasPrefix("event:") || line.hasPrefix("id:") || line.hasPrefix("retry:") {
                    continue
                }

                // Handle data lines
                if line.hasPrefix("data: ") || line.hasPrefix("data:") {
                    let payload: String
                    if line.hasPrefix("data: ") {
                        payload = String(line.dropFirst(6))
                    } else {
                        payload = String(line.dropFirst(5))
                    }

                    if let event = parsePayload(payload) {
                        return event
                    }
                }
            }
        }

        private func parsePayload(_ payload: String) -> SSEEvent? {
            let trimmed = payload.trimmingCharacters(in: .whitespaces)

            if trimmed == "[DONE]" {
                return .done
            }

            guard let data = trimmed.data(using: .utf8) else {
                return .error("Invalid UTF-8 in SSE payload")
            }

            return .data(data)
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(lineIterator: bytes.makeAsyncIterator())
    }
}

/// A parsed SSE event.
enum SSEEvent {
    /// A JSON data payload.
    case data(Data)

    /// The stream is complete.
    case done

    /// A parse error occurred.
    case error(String)
}

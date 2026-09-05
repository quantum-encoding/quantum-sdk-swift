import Foundation

/// Parses Server-Sent Events from a URLSession byte stream.
///
/// Yields ``SSEEvent`` values as an `AsyncSequence`. Follows the SSE
/// framing rules: an event is the `data:` lines up to the next blank line,
/// joined with `\n`; `event:`, `id:` and `retry:` fields and `:` comments
/// (the gateway's `: ping` keep-alives) are skipped; a final event that the
/// connection cut off before its blank line is still delivered; and the
/// `[DONE]` sentinel ends the stream.
struct SSEParser: AsyncSequence {
    typealias Element = SSEEvent

    let bytes: URLSession.AsyncBytes

    struct AsyncIterator: AsyncIteratorProtocol {
        var byteIterator: URLSession.AsyncBytes.AsyncIterator
        /// `data:` lines of the event being assembled.
        private var dataLines: [String] = []
        private var finished = false

        init(byteIterator: URLSession.AsyncBytes.AsyncIterator) {
            self.byteIterator = byteIterator
        }

        mutating func next() async throws -> SSEEvent? {
            while !finished {
                guard let line = try await readLine() else {
                    // Connection ended. An unterminated final event is
                    // delivered rather than dropped.
                    finished = true
                    return flush()
                }

                if line.isEmpty {
                    if let event = flush() { return event }
                    continue
                }
                if line.hasPrefix(":") { continue }
                if line.hasPrefix("data:") {
                    var payload = line.dropFirst("data:".count)
                    if payload.first == " " { payload = payload.dropFirst() }
                    dataLines.append(String(payload))
                }
                // event:, id:, retry: and unknown fields are not surfaced.
            }
            return nil
        }

        /// The assembled event, if any `data:` lines are pending.
        private mutating func flush() -> SSEEvent? {
            guard !dataLines.isEmpty else { return nil }
            let payload = dataLines.joined(separator: "\n")
            dataLines.removeAll()
            let trimmed = payload.trimmingCharacters(in: .whitespaces)
            if trimmed == "[DONE]" {
                finished = true
                return .done
            }
            return .data(Data(trimmed.utf8))
        }

        /// One line without its terminator, or `nil` at end of stream.
        /// Assembled from bytes so a multi-byte UTF-8 sequence is never
        /// split; an unterminated last line is returned as a line.
        private mutating func readLine() async throws -> String? {
            var lineBytes: [UInt8] = []
            var sawAny = false
            while let byte = try await byteIterator.next() {
                sawAny = true
                if byte == 0x0A { break }
                if byte == 0x0D { continue }
                lineBytes.append(byte)
            }
            guard sawAny else { return nil }
            return String(decoding: lineBytes, as: UTF8.self)
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(byteIterator: bytes.makeAsyncIterator())
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

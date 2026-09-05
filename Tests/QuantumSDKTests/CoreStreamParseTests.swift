import XCTest
@testable import QuantumSDK

/// The SSE framing and the stream-event vocabulary, through `chatStream`
/// and `chatSessionStream` against the scripted mock.
final class CoreStreamParseTests: XCTestCase {

    private func collect(_ body: String, headers: [String: String] = [:]) async throws -> [StreamEvent] {
        var sse = headers
        sse["Content-Type"] = "text/event-stream"
        CoreMockProtocol.script([.init(status: 200, body: body, headers: sse)])
        let client = try makeMockClient()
        var events: [StreamEvent] = []
        for try await event in client.chatStream(model: "m", messages: [.user("hi")]) {
            events.append(event)
        }
        return events
    }

    func testAFailedStreamCarriesItsMessageWhateverTheType() async throws {
        let events = try await collect(
            "data: {\"type\":\"invalid_request\",\"message\":\"stream failed: bad model\"}\n\n"
            + "data: {\"type\":\"rate_limit\",\"message\":\"stream failed: 429\"}\n\n"
            + "data: {\"type\":\"error\",\"message\":\"request timeout\"}\n\n"
            + "data: [DONE]\n\n"
        )
        XCTAssertEqual(events.count, 4)
        for (event, expected) in zip(events, [
            ("invalid_request", "stream failed: bad model"),
            ("rate_limit", "stream failed: 429"),
            ("error", "request timeout"),
        ]) {
            XCTAssertEqual(event.eventType, expected.0)
            XCTAssertTrue(event.isError)
            XCTAssertEqual(event.error, expected.1)
        }
        XCTAssertTrue(events[3].done)
    }

    func testCitationsSessionUsageAndTheToolTripletAreParsed() async throws {
        let events = try await collect(
            "data: {\"type\":\"session\",\"session_id\":\"sess_1\",\"compacted\":true}\n\n"
            + "data: {\"type\":\"citations\",\"citations\":[{\"title\":\"Rust\",\"url\":\"https://rust-lang.org\",\"text\":\"snippet\",\"index\":1}]}\n\n"
            + ": ping\n\n"
            + "data: {\"type\":\"content_delta\",\"delta\":{\"text\":\"hi\"}}\n\n"
            + "data: {\"type\":\"tool_use_start\",\"id\":\"t1\",\"name\":\"get_weather\"}\n\n"
            + "data: {\"type\":\"tool_use_input_delta\",\"id\":\"t1\",\"partial_json\":\"{\\\"city\\\":\"}\n\n"
            + "data: {\"type\":\"tool_use_complete\",\"id\":\"t1\",\"name\":\"get_weather\",\"input\":{\"city\":\"Dublin\"}}\n\n"
            + "data: {\"type\":\"heartbeat\"}\n\n"
            + "data: {\"type\":\"usage\",\"input_tokens\":3,\"output_tokens\":1,\"reasoning_tokens\":7,\"cost_ticks\":42}\n\n"
            + "data: [DONE]\n\n"
        )
        XCTAssertEqual(events.map(\.eventType), [
            "session", "citations", "content_delta", "tool_use_start", "tool_use_input_delta",
            "tool_use_complete", "heartbeat", "usage", "done",
        ])
        let session = try XCTUnwrap(events[0].session)
        XCTAssertEqual(session.sessionId, "sess_1")
        XCTAssertTrue(session.compacted)
        XCTAssertEqual(events[1].citations.count, 1)
        XCTAssertEqual(events[1].citations[0].url, "https://rust-lang.org")
        XCTAssertEqual(events[1].citations[0].index, 1)
        XCTAssertEqual(events[2].delta?.text, "hi")
        XCTAssertEqual(events[3].toolUseStart?.name, "get_weather")
        XCTAssertNil(events[3].toolUse)
        XCTAssertEqual(events[4].toolUseInputDelta?.partialJSON, "{\"city\":")
        XCTAssertEqual(events[5].toolUseComplete?.input["city"]?.value as? String, "Dublin")
        let usage = try XCTUnwrap(events[7].usage)
        XCTAssertEqual(usage.outputTokens, 1)
        XCTAssertEqual(usage.reasoningTokens, 7)
        XCTAssertNil(usage.cachedTokens)
        XCTAssertTrue(events[8].done)
    }

    func testMultiLineDataIsJoinedAndAnUnterminatedFinalEventIsDelivered() async throws {
        // Two `data:` lines make one event; the last event has no blank
        // line after it because the connection was cut.
        let events = try await collect(
            "event: message\ndata: {\"type\":\"content_delta\",\ndata: \"delta\":{\"text\":\"a\"}}\n\n"
            + "data: {\"type\":\"content_delta\",\"delta\":{\"text\":\"b\"}}"
        )
        XCTAssertEqual(events.map { $0.delta?.text }, ["a", "b"])
    }

    func testAnUnparsablePayloadIsAnErrorEventNotTheEndOfTheStream() async throws {
        let events = try await collect(
            "data: {not json\n\n"
            + "data: {\"type\":\"content_delta\",\"delta\":{\"text\":\"still here\"}}\n\n"
            + "data: [DONE]\n\n"
        )
        XCTAssertEqual(events.map(\.eventType), ["error", "content_delta", "done"])
        XCTAssertTrue(events[0].isError)
        XCTAssertEqual(events[1].delta?.text, "still here")
    }

    func testARejectedStreamThrowsBeforeTheFirstEvent() async throws {
        CoreMockProtocol.script([
            .init(status: 402, body: #"{"error":{"message":"no funds","type":"insufficient_balance","code":"INSUFFICIENT_BALANCE"}}"#),
        ])
        let client = try makeMockClient()
        do {
            for try await _ in client.chatStream(model: "m", messages: [.user("hi")]) {
                XCTFail("no event expected")
            }
            XCTFail("expected an error")
        } catch let error as QuantumError {
            XCTAssertTrue(error.isInsufficientBalance)
        }
    }

    func testASessionStreamReportsTheSessionIdFromTheHeader() async throws {
        CoreMockProtocol.script([
            .init(
                status: 200,
                body: "data: {\"type\":\"session\",\"session_id\":\"sess_9\"}\n\ndata: {\"type\":\"content_delta\",\"delta\":{\"text\":\"yo\"}}\n\ndata: [DONE]\n\n",
                headers: ["Content-Type": "text/event-stream", "X-QAI-Session-Id": "sess_9"]
            ),
        ])
        let client = try makeMockClient()
        let stream = try await client.chatSessionStream(message: "hi")
        XCTAssertEqual(stream.sessionId, "sess_9")
        var text = ""
        for try await event in stream.events {
            text += event.delta?.text ?? ""
        }
        XCTAssertEqual(text, "yo")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: CoreMockProtocol.requests[0].body) as? [String: Any])
        XCTAssertEqual(sent["stream"] as? Bool, true)
        XCTAssertEqual(CoreMockProtocol.requests[0].url.path, "/qai/v1/chat/session")
    }
}

import XCTest
@testable import QuantumSDK

/// Regression guards for the SDK-parity audit wire-shape fixes:
/// flat `ChatTool`, header-derived `ChatResponse` fields, typed 402,
/// and signed `X-QAI-Balance-After` round-trip.
final class ChatToolShapeVerifyTests: XCTestCase {
    func testChatToolEncodesFlatShape() throws {
        let tool = ChatTool(name: "get_weather", description: "Get weather",
                            parameters: ["type": AnyCodable("object")], strict: true)
        let data = try JSONEncoder().encode(tool)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        // Flat shape, NOT nested {"type":"function","function":{...}}
        XCTAssertTrue(json.contains("\"name\":\"get_weather\""))
        XCTAssertTrue(json.contains("\"strict\":true"))
        XCTAssertFalse(json.contains("\"function\""))
        XCTAssertFalse(json.contains("\"type\":\"function\""))
    }

    func testChatResponseDecodesBackendBodyWithoutTopLevelRequestOrCost() throws {
        let body = """
        {"id":"qai_req_abc","model":"claude-sonnet-4-6","content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":5,"cost_ticks":42},"cached":true}
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(ChatResponse.self, from: body)
        XCTAssertEqual(resp.id, "qai_req_abc")
        XCTAssertEqual(resp.model, "claude-sonnet-4-6")
        XCTAssertEqual(resp.stopReason, "end_turn")
        XCTAssertEqual(resp.usage.inputTokens, 10)
        XCTAssertEqual(resp.usage.outputTokens, 5)
        XCTAssertEqual(resp.usage.costTicks, 42)
        XCTAssertEqual(resp.cached, true)
        // Body carries no top-level request_id / cost_ticks → nil until apply().
        XCTAssertNil(resp.requestId)
        XCTAssertNil(resp.costTicks)
        XCTAssertNil(resp.balanceAfter)
    }

    func testChatResponseApplyPopulatesFromMeta() throws {
        let body = """
        {"id":"qai_req_abc","model":"","content":[],"stop_reason":"end_turn"}
        """.data(using: .utf8)!
        var resp = try JSONDecoder().decode(ChatResponse.self, from: body)
        resp.apply(ResponseMeta(costTicks: 42, requestId: "qai_req_abc",
                                 model: "claude-sonnet-4-6", balanceAfter: -100))
        XCTAssertEqual(resp.requestId, "qai_req_abc")
        XCTAssertEqual(resp.costTicks, 42)
        XCTAssertEqual(resp.balanceAfter, -100)
        XCTAssertEqual(resp.model, "claude-sonnet-4-6")
    }

    func testTyped402() {
        let err = QuantumError.api(statusCode: 402, code: "INSUFFICIENT_BALANCE", message: "no funds", requestId: nil)
        XCTAssertTrue(err.isInsufficientBalance)
        let err2 = QuantumError.api(statusCode: 402, code: "other", message: "x", requestId: nil)
        XCTAssertTrue(err2.isInsufficientBalance)
        let byCode = QuantumError.api(statusCode: 200, code: "INSUFFICIENT_BALANCE", message: "x", requestId: nil)
        XCTAssertTrue(byCode.isInsufficientBalance, "a 2xx envelope signals only through its code")
        XCTAssertEqual(byCode.typedCode, .insufficientBalance)
    }

    func testResponseMetaBalanceAfterRoundTrip() throws {
        let m = ResponseMeta(costTicks: 5, requestId: "r", model: "m", balanceAfter: -50)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(ResponseMeta.self, from: data)
        XCTAssertEqual(back.balanceAfter, -50)
    }
}
import XCTest
@testable import QuantumSDK

/// Wire shape of `POST /qai/v1/agent` (routes_agent.go `agentRequest` /
/// `agentResponse`) and the loose `AgentStreamEvent` the SSE surfaces share.
final class AgentsAgentStepTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testAgentRequestSerialisesTheKeysTheHandlerReads() throws {
        let request = AgentRequest(
            model: "claude-sonnet-4-6",
            messages: [
                .user("list the files"),
                .assistant("", toolUse: [AgentToolUse(id: "call_1", name: "ls", input: ["path": AnyCodable(".")])]),
                .toolResult(toolCallId: "call_1", content: "a.rs\nb.rs"),
            ],
            tools: [AgentToolDef(name: "ls", description: "list a directory", inputSchema: ["type": AnyCodable("object")])],
            capabilities: ["ls"],
            systemPrompt: "be brief",
            maxTokens: 256
        )
        let json = try encodeToObject(request)
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-4-6")
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[0]["role"] as? String, "user")
        XCTAssertEqual(messages[0]["content"] as? String, "list the files")
        XCTAssertNil(messages[0]["tool_use"])
        XCTAssertNil(messages[0]["tool_call_id"])
        XCTAssertEqual(messages[1]["role"] as? String, "assistant")
        let replayedCalls = try XCTUnwrap(messages[1]["tool_use"] as? [[String: Any]])
        XCTAssertEqual(replayedCalls[0]["id"] as? String, "call_1")
        XCTAssertEqual((replayedCalls[0]["input"] as? [String: Any])?["path"] as? String, ".")
        XCTAssertEqual(messages[2]["role"] as? String, "tool")
        XCTAssertEqual(messages[2]["tool_call_id"] as? String, "call_1")
        XCTAssertNil(messages[2]["is_error"], "a false is_error is omitted")
        let tools = try XCTUnwrap(json["tools"] as? [[String: Any]])
        XCTAssertEqual(tools[0]["name"] as? String, "ls")
        XCTAssertEqual((tools[0]["input_schema"] as? [String: Any])?["type"] as? String, "object")
        XCTAssertEqual(json["capabilities"] as? [String], ["ls"])
        XCTAssertEqual(json["system_prompt"] as? String, "be brief")
        XCTAssertEqual(json["max_tokens"] as? Int, 256)
        XCTAssertNil(json["temperature"])
        XCTAssertNil(json["stream"])
        XCTAssertEqual(Set(json.keys), ["model", "messages", "tools", "capabilities", "system_prompt", "max_tokens"])
    }

    func testSafeModeSendsAnEmptyCapabilityListAndNoToolsKey() throws {
        let request = AgentRequest(model: "m", messages: [.user("hi")], capabilities: [])
        let json = try encodeToObject(request)
        XCTAssertEqual(json["capabilities"] as? [String], [])
        XCTAssertNil(json["tools"])
    }

    func testOmittedCapabilitiesStayAbsent() throws {
        let json = try encodeToObject(AgentRequest(model: "m", messages: [.user("hi")]))
        XCTAssertFalse(json.keys.contains("capabilities"))
    }

    func testToolResultErrorFlagIsSentWhenTrue() throws {
        let json = try encodeToObject(AgentMessage.toolResult(toolCallId: "c", content: "boom", isError: true))
        XCTAssertEqual(json["is_error"] as? Bool, true)
    }

    func testAgentResponseDecodesAToolUseTurn() throws {
        let fixture = """
        {"id":"req_1","model":"claude-sonnet-4-6","stop_reason":"tool_use",
         "content":[],
         "tool_use":[{"id":"toolu_1","name":"ls","input":{"path":"src"}}],
         "usage":{"input_tokens":12,"output_tokens":7}}
        """
        let response = try JSONDecoder().decode(AgentResponse.self, from: Data(fixture.utf8))
        XCTAssertEqual(response.stopReason, "tool_use")
        XCTAssertEqual(response.toolUse[0].input["path"]?.value as? String, "src")
        XCTAssertEqual(response.usage.outputTokens, 7)
        XCTAssertEqual(response.text, "")
        XCTAssertEqual(response.costTicks, 0)
        let replay = response.toMessage()
        XCTAssertEqual(replay.role, "assistant")
        XCTAssertEqual(replay.toolUse[0].id, "toolu_1")
    }

    func testAgentResponseDecodesATextTurnWithoutToolUse() throws {
        let fixture = """
        {"id":"req_2","model":"m","stop_reason":"end_turn",
         "content":[{"type":"text","text":"hello "},{"type":"text","text":"there"}],
         "usage":{"input_tokens":1,"output_tokens":2}}
        """
        let response = try JSONDecoder().decode(AgentResponse.self, from: Data(fixture.utf8))
        XCTAssertTrue(response.toolUse.isEmpty)
        XCTAssertEqual(response.text, "hello there")
    }

    func testAgentResponseDecodesNullContentAndToolUse() throws {
        let fixture = #"{"id":"r","model":"m","stop_reason":"end_turn","content":null,"tool_use":null,"usage":{}}"#
        let response = try JSONDecoder().decode(AgentResponse.self, from: Data(fixture.utf8))
        XCTAssertTrue(response.content.isEmpty)
        XCTAssertTrue(response.toolUse.isEmpty)
        XCTAssertEqual(response.usage.inputTokens, 0)
    }

    // MARK: - AgentStreamEvent

    func testStreamEventFlattensEveryKeyBesideType() throws {
        let payload = Data(#"{"type":"agent_step","step":1,"content":"thinking"}"#.utf8)
        let event = QuantumClient.decodeAgentStreamEvent(payload)
        XCTAssertEqual(event.eventType, "agent_step")
        XCTAssertEqual(event.data["step"]?.value as? Int, 1)
        XCTAssertEqual(event.data["content"]?.value as? String, "thinking")
        XCTAssertNil(event.data["type"])
    }

    func testStreamEventParseFailureBecomesAnErrorEventWithoutTransportFlag() {
        let event = QuantumClient.decodeAgentStreamEvent(Data("not json".utf8))
        XCTAssertEqual(event.eventType, "error")
        XCTAssertTrue(event.error?.hasPrefix("parse SSE: ") ?? false)
        XCTAssertFalse(event.isTransportError)
    }

    func testTransportErrorEventCarriesTheFlag() {
        let event = QuantumClient.agentErrorEvent("transport: cut", transport: true)
        XCTAssertTrue(event.isError)
        XCTAssertTrue(event.isTransportError)
        XCTAssertEqual(event.error, "transport: cut")
    }

    func testMissionFailedReasonIsReadFromMessage() {
        let event = QuantumClient.decodeAgentStreamEvent(Data(#"{"type":"mission_failed","message":"budget"}"#.utf8))
        XCTAssertEqual(event.error, "budget")
    }
}

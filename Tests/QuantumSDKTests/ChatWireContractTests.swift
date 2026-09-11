// ChatWireContractTests — the chat wire contract the gateway added 2026-09-11.
//
// Covers the reasoning state a tool loop must hand back, the cache key that
// keeps a conversation on one provider shard, and the Gemini 3 signature that
// now rides text blocks as well as tool_use blocks. Source of truth: backend
// internal/server/convert.go (ChatRequest, ContentBlock) and
// internal/server/sse.go (the thought_signature event).
//
// Copyright (c) 2025-2026 Quantum Encoding Ltd

import XCTest
@testable import QuantumSDK

final class ChatWireContractTests: XCTestCase {
    private func encoded(_ request: ChatRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: prompt_cache_key

    /// Omitted, the gateway derives a key from the caller's identity — so an
    /// absent field is a real default, not an oversight to paper over.
    func testPromptCacheKeyRidesOnlyWhenSet() throws {
        let bare = try encoded(ChatRequest(model: "gpt-5.6", messages: [.user("hi")]))
        XCTAssertNil(bare["prompt_cache_key"])

        let keyed = try encoded(ChatRequest(
            model: "gpt-5.6",
            messages: [.user("hi")],
            promptCacheKey: "conv-7f3a"
        ))
        XCTAssertEqual(keyed["prompt_cache_key"] as? String, "conv-7f3a")
    }

    func testPromptCacheKeyDecodesBack() throws {
        let json = """
        {"model":"gpt-5.6","messages":[{"role":"user","content":"hi"}],
         "prompt_cache_key":"conv-7f3a"}
        """
        let request = try JSONDecoder().decode(ChatRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.promptCacheKey, "conv-7f3a")
    }

    // MARK: reasoning blocks

    /// The provider's reasoning item is opaque, and its POSITION among the
    /// tool calls is the state the provider reads back.
    func testReasoningBlockRoundTripsVerbatimAndInPlace() throws {
        let json = """
        {"id":"req_1","model":"gpt-5.6","stop_reason":"tool_use","content":[
          {"type":"reasoning",
           "reasoning":{"id":"rs_abc","summary":[],"encrypted_content":"Zm9v"},
           "minted_by":"gpt-5.6"},
          {"type":"tool_use","id":"call_1","name":"lookup","input":{"q":"x"}}
        ]}
        """
        let response = try JSONDecoder().decode(ChatResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.content.count, 2)

        let block = response.content[0]
        XCTAssertEqual(block.blockType, "reasoning")
        XCTAssertEqual(block.mintedBy, "gpt-5.6")
        let item = try XCTUnwrap(block.reasoning?.value as? [String: Any])
        XCTAssertEqual(item["id"] as? String, "rs_abc")
        XCTAssertEqual(item["encrypted_content"] as? String, "Zm9v")

        // Echoed back on the next turn's assistant message, unchanged and in
        // the same order.
        let message = ChatMessage(role: .assistant, contentBlocks: response.content)
        let data = try JSONEncoder().encode(message)
        let echoed = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let blocks = try XCTUnwrap(echoed["content_blocks"] as? [[String: Any]])
        XCTAssertEqual(blocks.map { $0["type"] as? String }, ["reasoning", "tool_use"])
        let sent = try XCTUnwrap(blocks[0]["reasoning"] as? [String: Any])
        XCTAssertEqual(sent["id"] as? String, "rs_abc")
        XCTAssertEqual(sent["encrypted_content"] as? String, "Zm9v")
        XCTAssertEqual(blocks[0]["minted_by"] as? String, "gpt-5.6")
    }

    /// Absent is not empty: a null reasoning item is not something a provider
    /// will accept back.
    func testBlockWithoutReasoningSendsNeitherField() throws {
        let block = ContentBlock(blockType: "text", text: "hello")
        let data = try JSONEncoder().encode(block)
        let encoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(encoded["reasoning"])
        XCTAssertNil(encoded["minted_by"])
        XCTAssertNil(encoded["thought_signature"])
    }

    // MARK: thought_signature

    /// Gemini 3 puts the signature on the TEXT block, not only on tool_use.
    func testThoughtSignatureRidesATextBlock() throws {
        let json = """
        {"id":"r","model":"gemini-3.5-flash","stop_reason":"end_turn",
         "content":[{"type":"text","text":"hi","thought_signature":"c2ln"}]}
        """
        let response = try JSONDecoder().decode(ChatResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.content[0].thoughtSignature, "c2ln")

        let data = try JSONEncoder().encode(response.content[0])
        let echoed = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(echoed["thought_signature"] as? String, "c2ln")
    }

    /// The gateway sends the signature as its own event just before `done`,
    /// and on the atomic tool_use event a streaming tool loop reads.
    func testThoughtSignatureStreamEvents() throws {
        let client = try QuantumClient(apiKey: "qai_k_test")

        let standalone = client.parseStreamEvent(
            Data(#"{"type":"thought_signature","thought_signature":"c2ln"}"#.utf8))
        XCTAssertEqual(standalone.eventType, "thought_signature")
        XCTAssertEqual(standalone.thoughtSignature, "c2ln")

        let toolUse = client.parseStreamEvent(
            Data(#"{"type":"tool_use","id":"call_1","name":"lookup","input":{},"thought_signature":"c2ln"}"#.utf8))
        XCTAssertEqual(toolUse.thoughtSignature, "c2ln")

        let plain = client.parseStreamEvent(
            Data(#"{"type":"content_delta","delta":{"text":"hi"}}"#.utf8))
        XCTAssertNil(plain.thoughtSignature)
    }

    // MARK: provider_options

    /// The map is open: nested per-provider objects, a non-object value, and
    /// a key this SDK version never heard of all reach the gateway.
    func testProviderOptionsIsAnOpenMap() throws {
        let request = ChatRequest(
            model: "gpt-5.6",
            messages: [.user("hi")],
            providerOptions: [
                "openai": [
                    "reasoning_summary": "detailed",
                    "reasoning_mode": "pro",
                    "verbosity": "low",
                    "text_format": "json_object",
                    "a_key_this_sdk_never_heard_of": 42,
                ],
                "xai": ["native_files": true],
            ]
        )
        let options = try XCTUnwrap(try encoded(request)["provider_options"] as? [String: Any])
        let openai = try XCTUnwrap(options["openai"] as? [String: Any])
        XCTAssertEqual(openai["reasoning_mode"] as? String, "pro")
        XCTAssertEqual(openai["text_format"] as? String, "json_object")
        XCTAssertEqual(openai["a_key_this_sdk_never_heard_of"] as? Int, 42)
        let xai = try XCTUnwrap(options["xai"] as? [String: Any])
        XCTAssertEqual(xai["native_files"] as? Bool, true)
    }

    /// A decoded provider entry survives whatever its JSON shape — the old
    /// nested-only type dropped anything that was not an object.
    func testProviderOptionsDecodeKeepsNonObjectEntries() throws {
        let json = """
        {"model":"gpt-5.6","messages":[{"role":"user","content":"hi"}],
         "provider_options":{"openai":{"verbosity":"low"},
                             "some_future_flag":true,
                             "another":["a","b"]}}
        """
        let request = try JSONDecoder().decode(ChatRequest.self, from: Data(json.utf8))
        let options = try XCTUnwrap(request.providerOptions)
        XCTAssertEqual(options["some_future_flag"]?.value as? Bool, true)
        XCTAssertEqual((options["another"]?.value as? [Any])?.count, 2)
        let openai = try XCTUnwrap(options["openai"]?.value as? [String: Any])
        XCTAssertEqual(openai["verbosity"] as? String, "low")
    }

    // MARK: reasoning_effort

    func testReasoningEffortCarriesEveryTier() throws {
        for tier in ["none", "low", "medium", "high", "xhigh", "max"] {
            let request = ChatRequest(model: "gpt-5.6", messages: [.user("hi")], reasoningEffort: tier)
            XCTAssertEqual(try encoded(request)["reasoning_effort"] as? String, tier)
        }
    }
}

// RegionRoutingEncodingTests — wire shapes for region-scoped routing.
//
// The gateway (EU AI Act Art 50, shipped 2026-08-19) reads region from two
// places: `region` at key mint, and `provider_options.region` on chat
// requests. There is NO region header and NO standalone chat field — the
// chat override rides INSIDE provider_options as the one entry whose value
// is a plain string, which ChatRequest's custom Codable merges in (the
// nested-dictionary type of `providerOptions` cannot represent it).
//
// Copyright (c) 2025-2026 Quantum Encoding Ltd

import XCTest
@testable import QuantumSDK

final class RegionRoutingEncodingTests: XCTestCase {

    // MARK: Region parsing

    func testCanonicalRegionsRoundTrip() {
        for region in Region.allCases {
            XCTAssertEqual(Region(parsing: region.rawValue), region)
        }
    }

    func testBackendAliasesAreToleratedCaseInsensitively() {
        XCTAssertEqual(Region(parsing: "US"), .americas)
        XCTAssertEqual(Region(parsing: "america"), .americas)
        XCTAssertEqual(Region(parsing: "eu"), .europe)
        XCTAssertEqual(Region(parsing: "EEA"), .europe)
        XCTAssertEqual(Region(parsing: "apac"), .asia)
        XCTAssertEqual(Region(parsing: "Asia-Pacific"), .asia)
        XCTAssertEqual(Region(parsing: "  europe "), .europe)
    }

    /// The backend silently degrades unknown regions to unscoped routing —
    /// the SDK refuses them instead, so a typo can't route unscoped.
    func testUnknownRegionsAreRejectedNotDegraded() {
        XCTAssertNil(Region(parsing: "africa"))
        XCTAssertNil(Region(parsing: ""))
        XCTAssertNil(Region(parsing: " orbital "))
    }

    // MARK: Key mint

    func testCreateKeyRequestCarriesTheRegionField() throws {
        let request = CreateKeyRequest(name: "fleet-asia", region: .asia)
        let data = try JSONEncoder().encode(request)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(decoded["region"] as? String, "asia")
        XCTAssertEqual(decoded["name"] as? String, "fleet-asia")
    }

    func testCreateKeyRequestOmitsRegionWhenUnscoped() throws {
        let request = CreateKeyRequest(name: "legacy")
        let data = try JSONEncoder().encode(request)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(decoded["region"])
    }

    func testKeyDetailsExposeTheScopeRegion() throws {
        let json = """
        {"id": "k1", "name": "fleet-eu", "scope": {"region": "europe", "endpoints": ["chat"]}}
        """
        let details = try JSONDecoder().decode(KeyDetails.self, from: Data(json.utf8))
        XCTAssertEqual(details.scopeRegion, .europe)

        let unscoped = """
        {"id": "k2", "name": "legacy", "scope": {"endpoints": ["chat"]}}
        """
        let legacy = try JSONDecoder().decode(KeyDetails.self, from: Data(unscoped.utf8))
        XCTAssertNil(legacy.scopeRegion)
    }

    // MARK: Chat override

    func testChatRegionRidesInsideProviderOptions() throws {
        let request = ChatRequest(
            model: "qwen3.8-27b",
            messages: [.user("hi")],
            region: .asia
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        // No standalone field — the override lives in provider_options.
        XCTAssertNil(decoded["region"])
        let options = try XCTUnwrap(decoded["provider_options"] as? [String: Any])
        XCTAssertEqual(options["region"] as? String, "asia")
    }

    /// A region override must not disturb the per-provider options it rides
    /// alongside, and vice versa.
    func testChatRegionCoexistsWithProviderOptions() throws {
        let request = ChatRequest(
            model: "claude-sonnet-4-6",
            messages: [.user("hi")],
            providerOptions: ["anthropic": ["thinking": AnyCodable(true)]],
            region: .europe
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let options = try XCTUnwrap(decoded["provider_options"] as? [String: Any])
        XCTAssertEqual(options["region"] as? String, "europe")
        let anthropic = try XCTUnwrap(options["anthropic"] as? [String: Any])
        XCTAssertEqual(anthropic["thinking"] as? Bool, true)
    }

    func testChatWithoutRegionEncodesNoRegionKey() throws {
        let request = ChatRequest(model: "gemini-flash-latest", messages: [.user("hi")])
        let data = try JSONEncoder().encode(request)
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(decoded["region"])
        XCTAssertNil(decoded["provider_options"])
    }

    func testChatRegionDecodesBackOutOfProviderOptions() throws {
        let json = """
        {"model": "qwen3.8-27b", "messages": [{"role": "user", "content": "hi"}],
         "provider_options": {"region": "asia", "anthropic": {"thinking": true}}}
        """
        let request = try JSONDecoder().decode(ChatRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.region, .asia)
        XCTAssertEqual(request.providerOptions?["anthropic"]?["thinking"]?.value as? Bool, true)
    }

    // MARK: Client-level hook

    func testClientRegionAppliesToChatRequests() throws {
        let client = try QuantumClient(apiKey: "qai_k_test")
        client.setRegion(.asia)
        let request = ChatRequest(model: "qwen3.8-27b", messages: [.user("hi")])
        let applied = client.applyRegion(request)
        XCTAssertEqual(applied.region, .asia)
        XCTAssertNil(request.region, "the caller's request stays untouched")
        // And the applied request encodes the override on the wire.
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try JSONEncoder().encode(applied))
                as? [String: Any]
        )
        let options = try XCTUnwrap(decoded["provider_options"] as? [String: Any])
        XCTAssertEqual(options["region"] as? String, "asia")
    }

    func testRequestLevelRegionWinsOverClientLevel() throws {
        let client = try QuantumClient(apiKey: "qai_k_test")
        client.setRegion(.europe)
        let request = ChatRequest(
            model: "claude-sonnet-4-6",
            messages: [.user("hi")],
            region: .americas
        )
        XCTAssertEqual(client.applyRegion(request).region, .americas)
    }

    func testClientWithoutRegionLeavesRequestsAlone() throws {
        let client = try QuantumClient(apiKey: "qai_k_test")
        let request = ChatRequest(model: "gemini-flash-latest", messages: [.user("hi")])
        XCTAssertNil(client.applyRegion(request).region)
        XCTAssertNil(client.region)
    }

    func testSetRegionNilClearsTheHook() throws {
        let client = try QuantumClient(apiKey: "qai_k_test")
        client.setRegion(.asia)
        XCTAssertEqual(client.region, .asia)
        client.setRegion(nil)
        XCTAssertNil(client.region)
    }
}

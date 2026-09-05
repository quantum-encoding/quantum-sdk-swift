import XCTest
@testable import QuantumSDK

/// Every rebuilt request serialises exactly the keys its handler reads.
final class CoreEncodeTests: XCTestCase {

    private func encode(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testAppleSignInSendsNonceDeviceAndCode() throws {
        let obj = try encode(AuthAppleRequest(idToken: "t", name: "Ada", nonce: "n", deviceId: "d", authorizationCode: "c"))
        XCTAssertEqual(Set(obj.keys), ["id_token", "name", "nonce", "device_id", "authorization_code"])
        XCTAssertEqual(obj["authorization_code"] as? String, "c")
        let minimal = try encode(AuthAppleRequest(idToken: "t"))
        XCTAssertEqual(Set(minimal.keys), ["id_token"])
    }

    func testAGoogleSignInSendsOnlyWhatItHas() throws {
        let obj = try encode(AuthGoogleRequest(idToken: "t", clientId: "c"))
        XCTAssertEqual(Set(obj.keys), ["id_token", "client_id"])
        let firebase = try encode(AuthFirebaseRequest(idToken: "t", deviceId: "d"))
        XCTAssertEqual(Set(firebase.keys), ["id_token", "device_id"])
        let verify = try encode(VerifyKeyRequest())
        XCTAssertTrue(verify.isEmpty)
        XCTAssertEqual(try encode(VerifyKeyRequest(apiKey: "qai_k_x"))["api_key"] as? String, "qai_k_x")
    }

    func testDevProgramSpendUsesTheGatewaysFieldName() throws {
        let obj = try encode(DevProgramApplyRequest(useCase: "agents", expectedMonthlyUsd: 250))
        XCTAssertEqual(Set(obj.keys), ["use_case", "expected_monthly_usd"])
        XCTAssertEqual(obj["expected_monthly_usd"] as? Double, 250)
    }

    func testKeyRequests() throws {
        XCTAssertEqual(try encode(CreateKeyRequest(name: "n", region: .asia))["region"] as? String, "asia")
        XCTAssertEqual(try encode(RotateKeyRequest(graceSeconds: 300))["grace_seconds"] as? Int, 300)
        XCTAssertEqual(Set(try encode(RotateKeyRequest()).keys), ["grace_seconds"])
        let ephemeral = try encode(EphemeralKeyRequest(ttl: 600, userRef: "u", spendCap: 1.5, endpoints: ["chat"], rateLimit: 10))
        XCTAssertEqual(Set(ephemeral.keys), ["ttl", "user_ref", "spend_cap", "endpoints", "rate_limit"])
        let partner = try encode(PartnerKeyRequest(partnerId: "cosmicduck", partnerRef: "u1"))
        XCTAssertEqual(Set(partner.keys), ["partner_id", "partner_ref"])
    }

    func testLifetimePurchaseRequest() throws {
        let obj = try encode(LifetimePurchaseRequest(planId: "lt1", successUrl: "https://ok"))
        XCTAssertEqual(Set(obj.keys), ["plan_id", "success_url"])
    }

    func testContextConfigUsesTheGatewaysKeys() throws {
        let obj = try encode(ContextConfig(compactAtTokens: 50_000, keepRecentToolResults: 3, clearThinking: true, summarizeStrategy: "plan_and_tools", summarizeModel: "gemini-2.5-flash"))
        XCTAssertEqual(Set(obj.keys), ["compact_at_tokens", "keep_recent_tool_results", "clear_thinking", "summarize_strategy", "summarize_model"])
        XCTAssertTrue(try encode(ContextConfig()).isEmpty)
    }

    func testChatRequestHasNoCapabilitiesKey() throws {
        let obj = try encode(ChatRequest(model: "m", messages: [.user("hi")], reasoningEffort: "max"))
        XCTAssertNil(obj["capabilities"])
        XCTAssertEqual(obj["reasoning_effort"] as? String, "max")
    }

    func testAccountDeleteSendsTheConfirmationPhrase() throws {
        XCTAssertEqual(try encode(AccountDeleteRequest(confirm: "DELETE"))["confirm"] as? String, "DELETE")
    }

    // MARK: Through the client

    func testTheMethodOwnsTheSessionStreamFlag() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"session_id":"s1","response":{"id":"r","model":"m","content":[],"stop_reason":"end_turn"},"context":{"turn_count":1,"estimated_tokens":1}}"#),
        ])
        let client = try makeMockClient()
        var request = SessionChatRequest(message: "hi")
        request.stream = true
        let resp = try await client.chatSession(request)
        XCTAssertEqual(resp.sessionId, "s1")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: CoreMockProtocol.requests[0].body) as? [String: Any])
        XCTAssertEqual(sent["stream"] as? Bool, false, "the buffered call never asks for SSE")
    }

    func testEstimateOmitsStreamAndRidesTheClientRegion() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"estimated_cost_ticks":10,"estimated_cost_usd":0.000000001,"model":"m"}"#),
        ])
        let client = try makeMockClient(region: .europe)
        var request = ChatRequest(model: "m", messages: [.user("hi")])
        request.stream = true
        let estimate = try await client.estimateChat(request)
        XCTAssertEqual(estimate.estimatedCostTicks, 10)
        let seen = CoreMockProtocol.requests[0]
        XCTAssertEqual(seen.url.path, "/qai/v1/chat/estimate")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: seen.body) as? [String: Any])
        XCTAssertNil(sent["stream"])
        XCTAssertEqual((sent["provider_options"] as? [String: Any])?["region"] as? String, "europe")
    }

    func testAccountDeleteGoesToTheRouteWithTheConfirmation() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"status":"deleted"}"#)])
        let client = try makeMockClient()
        let resp = try await client.accountDelete()
        XCTAssertEqual(resp.status, "deleted")
        let seen = CoreMockProtocol.requests[0]
        XCTAssertEqual(seen.method, "POST")
        XCTAssertEqual(seen.url.path, "/qai/v1/account/delete")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: seen.body) as? [String: Any])
        XCTAssertEqual(sent["confirm"] as? String, "DELETE")
    }

    func testRevokeSessionIsADelete() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"status":"revoked"}"#)])
        let client = try makeMockClient()
        _ = try await client.revokeSession()
        XCTAssertEqual(CoreMockProtocol.requests[0].method, "DELETE")
        XCTAssertEqual(CoreMockProtocol.requests[0].url.path, "/qai/v1/auth/session")
    }

    func testKeyRoutes() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"devices":[]}"#),
            .init(status: 200, body: #"{"key":"qai_k_new","details":{"id":"k2","name":"n"},"old_key_id":"k 1"}"#),
            .init(status: 200, body: #"{"days":[],"models":[],"total_cost_usd":0}"#),
            .init(status: 200, body: #"{"token":"qai_eph_x","expires_at":"t"}"#),
            .init(status: 200, body: #"{"key":"qai_k_p","details":{"id":"k5","name":"partner:u"}}"#),
        ])
        let client = try makeMockClient()
        _ = try await client.listDeviceKeys()
        _ = try await client.rotateKey(id: "k 1", RotateKeyRequest(graceSeconds: 60))
        _ = try await client.keyUsage(id: "k 1")
        _ = try await client.createEphemeralKey(EphemeralKeyRequest(ttl: 60))
        _ = try await client.createPartnerKey(PartnerKeyRequest(partnerId: "p", partnerRef: "u"))
        let paths = CoreMockProtocol.requests.map { "\($0.method) \($0.url.path)" }
        XCTAssertEqual(paths, [
            "GET /qai/v1/keys/devices",
            "POST /qai/v1/keys/k 1/rotate",
            "GET /qai/v1/keys/k 1/usage",
            "POST /qai/v1/keys/ephemeral",
            "POST /qai/v1/keys/partner",
        ])
        XCTAssertEqual(CoreMockProtocol.requests[1].url.absoluteString, "https://mock.gateway.invalid/qai/v1/keys/k%201/rotate")
    }

    func testUsageCursorIsQueryEscaped() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"entries":[],"has_more":false}"#)])
        let client = try makeMockClient()
        _ = try await client.accountUsage(query: UsageQuery(limit: 5, startAfter: "a&b=c"))
        XCTAssertEqual(CoreMockProtocol.requests[0].url.query, "limit=5&start_after=a%26b%3Dc")
    }

    func testGetPricingUnwrapsTheMap() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"pricing":{"m":{"provider":"p","model":"m","display_name":"M"}}}"#)])
        let client = try makeMockClient()
        let pricing = try await client.getPricing()
        XCTAssertEqual(pricing["m"]?.provider, "p")
    }
}

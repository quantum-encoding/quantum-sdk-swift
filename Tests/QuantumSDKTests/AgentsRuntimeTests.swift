import XCTest
@testable import QuantumSDK

/// Agent runtime (internal/agentruntime/runtime.go, routes_agentruntime.go),
/// Cloud Run (routes_cloudrun.go) and licences (routes_licenses.go).
final class AgentsRuntimeTests: XCTestCase {

    private func encodeToObject(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Agent runtime

    func testAgentRequestOmitsEmptyPromptAndTools() throws {
        let json = try encodeToObject(RuntimeAgentRequest(name: "reviewer", model: "claude-sonnet-4-6"))
        XCTAssertEqual(json["name"] as? String, "reviewer")
        XCTAssertNil(json["system_prompt"])
        XCTAssertNil(json["tools"])
        XCTAssertEqual(Set(json.keys), ["name", "model"])
    }

    func testUpdateCarriesStoredPromptAndToolsForward() throws {
        let stored = try JSONDecoder().decode(RuntimeAgent.self, from: Data("""
        {"id":"a1","user_id":"u1","name":"reviewer","model":"claude-sonnet-4-6",
         "system_prompt":"be strict","tools":[{"type":"bash_20250124","name":"bash"}],
         "version":3,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
        """.utf8))
        XCTAssertNil(stored.upstreamId)
        let body = try encodeToObject(RuntimeAgentUpdate(model: "claude-opus-5").apply(to: stored))
        XCTAssertEqual(body["name"] as? String, "reviewer")
        XCTAssertEqual(body["model"] as? String, "claude-opus-5")
        XCTAssertEqual(body["system_prompt"] as? String, "be strict")
        XCTAssertEqual((body["tools"] as? [[String: Any]])?.first?["name"] as? String, "bash")
    }

    func testUpdateCanClearPromptAndToolsExplicitly() throws {
        let stored = RuntimeAgent(id: "a1", name: "reviewer", model: "m", systemPrompt: "be strict",
                                  tools: [RuntimeTool(type: "bash_20250124", name: "bash")])
        let body = try encodeToObject(RuntimeAgentUpdate(systemPrompt: "", tools: []).apply(to: stored))
        XCTAssertNil(body["system_prompt"])
        XCTAssertEqual((body["tools"] as? [Any])?.count, 0)
    }

    func testAgentListDecodesNullTools() throws {
        let response = try JSONDecoder().decode(RuntimeAgentsResponse.self, from: Data(
            #"{"agents":[{"id":"a1","user_id":"u1","name":"n","model":"m","system_prompt":"","tools":null,"version":1}]}"#.utf8
        ))
        XCTAssertTrue(response.agents[0].tools.isEmpty)
        let update = try JSONDecoder().decode(RuntimeAgentUpdateResponse.self, from: Data(#"{"id":"a1","version":2}"#.utf8))
        XCTAssertEqual(update.version, 2)
    }

    func testSessionRoundTripsAsTheDescriptorTheGatewayExpects() throws {
        let session = RuntimeSession(id: "s1", userId: "u1", agentId: "a1", environmentId: "e1",
                                     backend: "coding-session", status: "running",
                                     upstreamId: "sesn_123", createdAt: "2026-01-01T00:00:00Z")
        let json = try encodeToObject(session)
        XCTAssertEqual(Set(json.keys), ["id", "user_id", "agent_id", "environment_id", "backend", "status", "upstream_id", "created_at"])
        let decoded = try JSONDecoder().decode(RuntimeSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded.upstreamId, "sesn_123")
        XCTAssertEqual(decoded.backend, "coding-session")

        let path = try QuantumClient.agentRuntimeStreamPath(session: session, since: 7)
        XCTAssertTrue(path.hasPrefix("/qai/v1/agent-runtime/sessions/stream?session="))
        XCTAssertTrue(path.hasSuffix("&since=7"))
        let value = try XCTUnwrap(URLComponents(string: "https://g.test" + path)?.queryItems?.first(where: { $0.name == "session" })?.value)
        let roundTripped = try JSONDecoder().decode(RuntimeSession.self, from: Data(value.utf8))
        XCTAssertEqual(roundTripped.id, "s1")
    }

    func testEphemeralEventOmitsItsZeroIndex() throws {
        let json = try encodeToObject(RuntimeEvent(type: "message", role: "user", content: "run the tests"))
        XCTAssertEqual(json["type"] as? String, "message")
        XCTAssertNil(json["index"])
        XCTAssertNil(json["data"])
        XCTAssertNil(json["timestamp"])
        XCTAssertEqual(Set(json.keys), ["type", "role", "content"])

        let append = try encodeToObject(AppendEventRequest(
            session: RuntimeSession(id: "s1"), event: RuntimeEvent(type: "message", content: "hi")
        ))
        XCTAssertEqual(Set(append.keys), ["session", "event"])
    }

    func testEnvironmentDecodesWithoutAnOverlay() throws {
        let env = try JSONDecoder().decode(RuntimeEnvironment.self, from: Data("""
        {"id":"e1","user_id":"u1","name":"hosted","backend":"managed-agents","vault_ids":null,"created_at":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(env.backend, "managed-agents")
        XCTAssertNil(env.overlay)
        XCTAssertTrue(env.vaultIds.isEmpty)
    }

    func testEnvironmentRequestOverlayOmitsEmptyWorkspaceObject() throws {
        let request = RuntimeEnvironmentRequest(
            name: "code", backend: "coding-session", tier: "m",
            overlay: OverlayConfig(coreRepo: "https://github.com/o/r", corePinnedRef: "main", overlayPath: "src", branchPrefix: "agent/")
        )
        let json = try encodeToObject(request)
        XCTAssertEqual(Set(json.keys), ["name", "backend", "tier", "overlay"])
        let overlay = try XCTUnwrap(json["overlay"] as? [String: Any])
        XCTAssertEqual(overlay["push_branch"] as? Bool, false)
        XCTAssertNil(overlay["workspace_object"])
    }

    func testUnparsablePayloadBecomesAnUnknownEvent() {
        let event = QuantumClient.runtimeEvent(fromPayload: Data("not json".utf8))
        XCTAssertEqual(event.type, "unknown")
        XCTAssertEqual(event.content, "not json")

        let terminal = QuantumClient.runtimeEvent(fromPayload: Data(
            #"{"type":"error","content":"upstream closed","timestamp":"2026-01-01T00:00:00Z","index":9}"#.utf8
        ))
        XCTAssertEqual(terminal.type, "error")
        XCTAssertEqual(terminal.content, "upstream closed")
        XCTAssertEqual(terminal.index, 9)
    }

    func testOkAndStageResponses() throws {
        XCTAssertTrue(try JSONDecoder().decode(RuntimeOkResponse.self, from: Data(#"{"ok":true}"#.utf8)).ok)
        XCTAssertEqual(
            try JSONDecoder().decode(StageWorkspaceResponse.self, from: Data(#"{"workspace_object":"ws/abc.tar.gz"}"#.utf8)).workspaceObject,
            "ws/abc.tar.gz"
        )
    }

    func testManagedAgentsPathIsForwardedVerbatim() {
        XCTAssertEqual(QuantumClient.managedAgentsPath("agents?limit=20"), "/qai/v1/managed-agents/agents?limit=20")
    }

    // MARK: - Cloud Run

    func testCloudRunSafeModeSendsAnEmptyCapabilityList() throws {
        let json = try encodeToObject(CloudRunRequest(task: "audit the repo", capabilities: []))
        XCTAssertEqual(json["capabilities"] as? [String], [])
        XCTAssertNil(json["workspace_path"])
        XCTAssertEqual(Set(json.keys), ["task", "capabilities"])
    }

    func testCloudRunOmittedCapabilitiesStayAbsent() throws {
        let json = try encodeToObject(CloudRunRequest(task: "audit the repo"))
        XCTAssertNil(json["capabilities"])
        XCTAssertEqual(json["task"] as? String, "audit the repo")
    }

    func testCloudRunWorkersSerializeWithTheirTiers() throws {
        let json = try encodeToObject(CloudRunRequest(
            task: "port the module",
            workers: [CloudRunWorker(name: "coder", model: "claude-sonnet-4-6", tier: "mid", description: "writes code")],
            maxSteps: 12, workspacePath: "proj"
        ))
        let worker = try XCTUnwrap((json["workers"] as? [[String: Any]])?.first)
        XCTAssertEqual(worker["tier"] as? String, "mid")
        XCTAssertEqual(Set(worker.keys), ["name", "model", "tier", "description"])
        XCTAssertEqual(json["max_steps"] as? Int, 12)
        XCTAssertEqual(json["workspace_path"] as? String, "proj")
    }

    // MARK: - Licences

    func testRevokedLicenseCarriesNoKey() throws {
        let response = try JSONDecoder().decode(LicensesResponse.self, from: Data("""
        {"licenses":[{"id":"lic_1","app":"kitchenshare","sku":"pro","source":"stripe",
                      "source_transaction":"pi_1","issued_at":"2026-01-01T00:00:00Z",
                      "expires_at":"2027-01-01T00:00:00Z","status":"revoked"}]}
        """.utf8))
        XCTAssertEqual(response.licenses.count, 1)
        XCTAssertEqual(response.licenses[0].status, "revoked")
        XCTAssertNil(response.licenses[0].licenseKey)
    }

    func testJwksUseFieldMapsFromReservedName() throws {
        let response = try JSONDecoder().decode(LicensePublicKeyResponse.self, from: Data(
            #"{"keys":[{"kty":"OKP","crv":"Ed25519","alg":"EdDSA","use":"sig","kid":"k1","x":"AAAA"}]}"#.utf8
        ))
        XCTAssertEqual(response.keys[0].keyUse, "sig")
        XCTAssertEqual(response.keys[0].kid, "k1")
    }

    func testRevocationsDecodeNullList() throws {
        let response = try JSONDecoder().decode(LicenseRevocationsResponse.self, from: Data(
            #"{"revoked_ids":null,"since":"2026-01-01T00:00:00Z","as_of":"2026-02-01T00:00:00Z"}"#.utf8
        ))
        XCTAssertTrue(response.revokedIds.isEmpty)
        XCTAssertEqual(response.asOf, "2026-02-01T00:00:00Z")
    }
}

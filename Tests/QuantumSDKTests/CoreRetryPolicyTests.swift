import XCTest
@testable import QuantumSDK

/// The replay policy and the wire headers, against the scripted mock.
final class CoreRetryPolicyTests: XCTestCase {

    func testAPostAnswered502IsNotReplayed() async throws {
        CoreMockProtocol.script([
            .init(status: 502, body: #"{"error":{"message":"upstream","type":"provider_error"}}"#),
        ])
        let client = try makeMockClient()
        do {
            let _: (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(
                method: "POST", path: "/qai/v1/chat", body: ["model": "m"]
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(apiStatus(error), 502)
        }
        let seen = CoreMockProtocol.requests
        XCTAssertEqual(seen.count, 1, "a 502 on a POST must reach the caller unreplayed")
        XCTAssertEqual(seen[0].method, "POST")
        XCTAssertEqual(seen[0].url.path, "/qai/v1/chat")
    }

    func testAPostAnswered429WaitsForRetryAfterThenReplays() async throws {
        CoreMockProtocol.script([
            .init(
                status: 429,
                body: #"{"error":{"message":"slow down","type":"rate_limit_exceeded","code":"RATE_LIMITED_PER_KEY"}}"#,
                headers: ["Retry-After": "1"]
            ),
            .init(status: 200, body: #"{"ok":true}"#),
        ])
        let client = try makeMockClient()
        let started = Date()
        let (resp, _): (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(
            method: "POST", path: "/qai/v1/chat", body: [String: String]()
        )
        XCTAssertTrue(resp.ok)
        XCTAssertGreaterThanOrEqual(
            Date().timeIntervalSince(started), 1.0,
            "must wait the server's Retry-After before replaying"
        )
        let seen = CoreMockProtocol.requests
        XCTAssertEqual(seen.count, 2)
        XCTAssertNotNil(seen[0].header("Idempotency-Key"))
        XCTAssertEqual(
            seen[0].header("Idempotency-Key"), seen[1].header("Idempotency-Key"),
            "the replay carries the same Idempotency-Key"
        )
    }

    func testAnExplicitIdempotencyKeyOptsAPostInto5xxReplay() async throws {
        CoreMockProtocol.script([
            .init(status: 503, body: "busy"),
            .init(status: 200, body: #"{"ok":true}"#),
        ])
        let client = try makeMockClient()
        let (resp, _): (OkBody, HTTPClient.ResponseMeta) = try await client.doReqIdempotent(
            path: "/qai/v1/search", body: [String: String](), idempotencyKey: "job-42"
        )
        XCTAssertTrue(resp.ok)
        let seen = CoreMockProtocol.requests
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(seen[0].header("Idempotency-Key"), "job-42")
        XCTAssertEqual(seen[1].header("Idempotency-Key"), "job-42")
    }

    func testACallerKeyOnThePlainPathDoesNotOptInto5xxReplay() async throws {
        CoreMockProtocol.script([
            .init(status: 503, body: "busy"),
        ])
        let client = try makeMockClient()
        do {
            let _: (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(
                method: "POST", path: "/qai/v1/images/generate", body: [String: String](),
                idempotencyKey: "media-1"
            )
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(apiStatus(error), 503)
        }
        XCTAssertEqual(CoreMockProtocol.requests.count, 1)
        XCTAssertEqual(CoreMockProtocol.requests[0].header("Idempotency-Key"), "media-1")
    }

    func testAGetAnswered503IsReplayed() async throws {
        CoreMockProtocol.script([
            .init(status: 503, body: "busy"),
            .init(status: 200, body: #"{"ok":true}"#),
        ])
        let client = try makeMockClient()
        let (resp, _): (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(
            method: "GET", path: "/qai/v1/models"
        )
        XCTAssertTrue(resp.ok)
        XCTAssertEqual(CoreMockProtocol.requests.count, 2)
        XCTAssertNil(CoreMockProtocol.requests[0].header("Idempotency-Key"), "a GET carries no key")
    }

    func testA5xxWrappingAPermanentErrorIsNotReplayedOnGet() async throws {
        CoreMockProtocol.script([
            .init(status: 502, body: #"{"error":{"message":"content moderation blocked this","type":"provider_error"}}"#),
        ])
        let client = try makeMockClient()
        do {
            let _: (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(method: "GET", path: "/qai/v1/models")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(apiStatus(error), 502)
        }
        XCTAssertEqual(CoreMockProtocol.requests.count, 1)
    }

    func testADeleteIsASingleAttempt() async throws {
        CoreMockProtocol.script([
            .init(status: 503, body: "busy"),
        ])
        let client = try makeMockClient()
        do {
            _ = try await client.revokeKey(id: "k1")
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(apiStatus(error), 503)
        }
        XCTAssertEqual(CoreMockProtocol.requests.count, 1)
        XCTAssertEqual(CoreMockProtocol.requests[0].method, "DELETE")
    }

    func testStreamingSendsTheSameHeadersAsEveryOtherRequest() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: "data: [DONE]\n\n", headers: ["Content-Type": "text/event-stream"]),
        ])
        let client = try makeMockClient()
        var events: [StreamEvent] = []
        for try await event in client.chatStream(model: "m", messages: [.user("hi")]) {
            events.append(event)
        }
        XCTAssertEqual(events.last?.done, true)
        let req = try XCTUnwrap(CoreMockProtocol.requests.first)
        XCTAssertEqual(req.header("Authorization"), "Bearer qai_k_test")
        XCTAssertEqual(req.header("X-API-Key"), "qai_k_test")
        XCTAssertEqual(req.header("X-Quantum-App"), "recipe-box")
        XCTAssertEqual(req.header("X-Correlation-Id"), "abc-123")
        XCTAssertEqual(req.header("Accept"), "text/event-stream")
        XCTAssertNotNil(req.header("Idempotency-Key"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: req.body) as? [String: Any])
        XCTAssertEqual(body["stream"] as? Bool, true)
    }

    func testBufferedRequestsCarryAppAndExtraHeaders() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"ok":true}"#)])
        let client = try makeMockClient()
        let _: (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(method: "GET", path: "/qai/v1/models")
        let req = try XCTUnwrap(CoreMockProtocol.requests.first)
        XCTAssertEqual(req.header("Authorization"), "Bearer qai_k_test")
        XCTAssertEqual(req.header("X-API-Key"), "qai_k_test")
        XCTAssertEqual(req.header("X-Quantum-App"), "recipe-box")
        XCTAssertEqual(req.header("X-Correlation-Id"), "abc-123")
    }

    func testCloudRunTokenTakesAuthorizationAndTheKeyStaysOnXAPIKey() async throws {
        CoreMockProtocol.script([.init(status: 200, body: #"{"ok":true}"#)])
        let client = try makeMockClient()
        client.setCloudRunToken("id-token")
        let _: (OkBody, HTTPClient.ResponseMeta) = try await client.doReq(method: "GET", path: "/qai/v1/models")
        let req = try XCTUnwrap(CoreMockProtocol.requests.first)
        XCTAssertEqual(req.header("Authorization"), "Bearer id-token")
        XCTAssertEqual(req.header("X-API-Key"), "qai_k_test")
    }

    func testADecodeFailureNeverCarriesTheBody() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"token":"qai_s_LIVE_SESSION","user":42}"#),
        ])
        let client = try makeMockClient()
        do {
            _ = try await client.authGoogle(AuthGoogleRequest(idToken: "t", clientId: "c"))
            XCTFail("expected a decode error")
        } catch let error as QuantumError {
            guard case .decodingFailed = error else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
            let shown = "\(error) / \(error.localizedDescription) / \(String(reflecting: error))"
            XCTAssertFalse(shown.contains("LIVE_SESSION"), "a decode error must not echo the response body: \(shown)")
        }
    }

    func testA2xxErrorEnvelopeSurfacesAsTheAPIError() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"error":{"message":"blocked by moderation","type":"content_policy","code":"CONTENT_REJECTED"}}"#),
        ])
        let client = try makeMockClient()
        do {
            _ = try await client.chat(model: "m", messages: [.user("hi")])
            XCTFail("expected an error")
        } catch let error as QuantumError {
            XCTAssertEqual(error.statusCode, 200)
            XCTAssertEqual(error.code, "CONTENT_REJECTED")
            XCTAssertEqual(error.typedCode, .contentRejected)
        }
        XCTAssertEqual(CoreMockProtocol.requests.count, 1, "a moderation block is never replayed")
    }

    func testAFlatErrorEnvelopeYieldsItsCode() async throws {
        CoreMockProtocol.script([
            .init(status: 400, body: #"{"error":"invalid_request","message":"model is required"}"#,
                  headers: ["X-QAI-Request-Id": "req_1"]),
        ])
        let client = try makeMockClient()
        do {
            _ = try await client.chat(model: "", messages: [.user("hi")])
            XCTFail("expected an error")
        } catch let error as QuantumError {
            guard case let .api(status, code, message, requestId) = error else {
                return XCTFail("expected api, got \(error)")
            }
            XCTAssertEqual(status, 400)
            XCTAssertEqual(code, "invalid_request")
            XCTAssertEqual(message, "model is required")
            XCTAssertEqual(requestId, "req_1")
            XCTAssertEqual(error.typedCode, .invalidRequest)
        }
    }

    func testAnHTMLErrorBodyIsSummarisedNotEchoed() async throws {
        CoreMockProtocol.script([
            .init(status: 503, body: "<!DOCTYPE html><html><body>Cloud Run upstream busy</body></html>"),
        ])
        let client = try makeMockClient()
        do {
            _ = try await client.creditPurchase(CreditPurchaseRequest(packId: "p"))
            XCTFail("expected an error")
        } catch let error as QuantumError {
            XCTAssertEqual(error.statusCode, 503)
            XCTAssertFalse(error.localizedDescription.contains("<html>"))
            XCTAssertTrue(error.localizedDescription.contains("non-JSON response body"))
        }
    }

    func testLastResponseMetaIsRecordedByEveryHelper() async throws {
        CoreMockProtocol.script([
            .init(status: 200, body: #"{"ok":true}"#, headers: [
                "X-QAI-Request-Id": "req_meta", "X-QAI-Cost-Ticks": "77", "X-QAI-Balance-After": "-5",
            ]),
        ])
        let client = try makeMockClient()
        XCTAssertNil(client.lastResponseMeta)
        let _: (OkBody, HTTPClient.ResponseMeta) = try await client.http.doJSON(method: "GET", path: "/x")
        let meta = try XCTUnwrap(client.lastResponseMeta)
        XCTAssertEqual(meta.requestId, "req_meta")
        XCTAssertEqual(meta.costTicks, 77)
        XCTAssertEqual(meta.balanceAfter, -5)
    }

    // MARK: Unit

    func testRetryAfterReadsDelaySecondsAndClamps() {
        func response(_ headers: [String: String]) -> HTTPURLResponse {
            HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 429, httpVersion: nil, headerFields: headers)!
        }
        XCTAssertNil(HTTPClient.retryAfter(response([:])))
        XCTAssertEqual(HTTPClient.retryAfter(response(["Retry-After": "5"])), 5)
        XCTAssertEqual(HTTPClient.retryAfter(response(["Retry-After": "86400"])), HTTPClient.maxRetryAfter)
        XCTAssertNil(
            HTTPClient.retryAfter(response(["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"])),
            "the HTTP-date form is not parsed"
        )
        XCTAssertEqual(HTTPClient.backoff(attempt: 1), 0.5)
        XCTAssertEqual(HTTPClient.backoff(attempt: 2), 1.0)
        XCTAssertEqual(HTTPClient.backoff(attempt: 3), 2.0)
    }

    func testABadKeyIsAnErrorNotACrash() {
        XCTAssertThrowsError(try QuantumClient(apiKey: "qai_k_from_a_file\n")) { error in
            XCTAssertEqual((error as? QuantumError)?.code, "invalid_api_key")
            XCTAssertEqual((error as? QuantumError)?.statusCode, 0)
        }
    }

    func testABadBaseURLIsAnErrorNotACrash() {
        XCTAssertThrowsError(try QuantumClient(apiKey: "qai_k_test", baseURL: "")) { error in
            guard case .invalidArgument = error as? QuantumError else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
        }
        XCTAssertThrowsError(try QuantumClient(apiKey: "qai_k_test", baseURL: "file:///etc"))
    }

    func testReservedHeadersRejectedAtBuild() {
        for name in ["Authorization", "authorization", "X-API-Key", "x-api-key"] {
            var configuration = ClientConfiguration(apiKey: "qai_test")
            configuration.extraHeaders = [(name: name, value: "anything")]
            XCTAssertThrowsError(try QuantumClient(configuration: configuration), "expected reject for '\(name)'") { error in
                XCTAssertEqual((error as? QuantumError)?.code, "invalid_header")
            }
        }
    }

    func testInvalidHeaderNameRejectedAtBuild() {
        var configuration = ClientConfiguration(apiKey: "qai_test")
        configuration.extraHeaders = [(name: "bad name with spaces", value: "v")]
        XCTAssertThrowsError(try QuantumClient(configuration: configuration)) { error in
            XCTAssertEqual((error as? QuantumError)?.code, "invalid_header")
        }
        configuration.extraHeaders = [(name: "X-Fine", value: "line\nbreak")]
        XCTAssertThrowsError(try QuantumClient(configuration: configuration))
    }

    func testAppAndExtraHeaderBuildSucceeds() throws {
        var configuration = ClientConfiguration(apiKey: "qai_test")
        configuration.app = "recipe-box"
        configuration.extraHeaders = [(name: "X-Correlation-Id", value: "abc-123")]
        configuration.region = .europe
        let client = try QuantumClient(configuration: configuration)
        XCTAssertEqual(client.region, .europe)
    }

    func testPermanentErrorDetection() {
        XCTAssertTrue(HTTPClient.isPermanentError(Data("provider rejected: content moderation".utf8)))
        XCTAssertTrue(HTTPClient.isPermanentError(Data(#"{"error":{"type":"invalid_request"}}"#.utf8)))
        XCTAssertFalse(HTTPClient.isPermanentError(Data("busy".utf8)))
    }
}

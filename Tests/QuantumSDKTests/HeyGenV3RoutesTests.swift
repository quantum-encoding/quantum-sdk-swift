import XCTest
@testable import QuantumSDK

// MARK: - Mock Gateway (URLProtocol)

/// URLProtocol-based mock gateway: captures the outgoing request (method,
/// path, query, headers, body) and returns a canned response, so tests can
/// assert the full wire contract without ever touching production.
final class MockGatewayProtocol: URLProtocol {
    struct Stub {
        var statusCode: Int
        var body: Data
        var headers: [String: String]
    }

    struct CapturedRequest {
        var method: String
        var url: URL
        var headers: [String: String]
        var body: Data
    }

    private static let lock = NSLock()
    private static var _stub = Stub(statusCode: 200, body: Data("{}".utf8), headers: [:])
    private static var _captured: CapturedRequest?

    static func stub(status: Int, json: String, headers: [String: String] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        _stub = Stub(statusCode: status, body: Data(json.utf8), headers: headers)
        _captured = nil
    }

    static var captured: CapturedRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _captured
    }

    private static func record(_ request: CapturedRequest) -> Stub {
        lock.lock()
        defer { lock.unlock() }
        _captured = request
        return _stub
    }

    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let stub = Self.record(CapturedRequest(
            method: request.httpMethod ?? "",
            url: request.url!,
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.readBody(of: request)
        ))

        var headers = stub.headers
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json"
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - HeyGen v3 Route Tests

/// End-to-end tests for the 9 HeyGen v3 gateway routes against the mock
/// gateway: assert HTTP method, path, query, auth headers, request body wire
/// format, and typed response decoding per the contract.
final class HeyGenV3RoutesTests: XCTestCase {
    private var client: QuantumClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockGatewayProtocol.self]
        client = try QuantumClient(
            apiKey: "qai_k_test",
            baseURL: "https://mock.gateway.invalid",
            session: URLSession(configuration: config)
        )
    }

    private func bodyObject() throws -> [String: Any] {
        let data = MockGatewayProtocol.captured?.body ?? Data()
        let obj = try JSONSerialization.jsonObject(with: data)
        return obj as? [String: Any] ?? [:]
    }

    private func assertAuth(file: StaticString = #filePath, line: UInt = #line) {
        let headers = MockGatewayProtocol.captured?.headers ?? [:]
        XCTAssertEqual(headers["Authorization"], "Bearer qai_k_test", file: file, line: line)
        XCTAssertEqual(headers["X-API-Key"], "qai_k_test", file: file, line: line)
    }

    // MARK: 1. POST /qai/v1/avatar/realtime

    func testCreateAvatarRealtimeSession() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "stream_id": "rt_9f2c1a",
          "status": "pending",
          "prepaid_seconds": 300,
          "cost_ticks": 345000000000,
          "request_id": "req_abc123def456"
        }
        """, headers: [
            "X-QAI-Cost-Ticks": "345000000000",
            "X-QAI-Balance-After": "655000000000",
        ])

        let resp = try await client.createAvatarRealtimeSession(AvatarRealtimeRequest(
            sessionType: "text_stream",
            avatarId: "Abigail_expressive_2024112501",
            maxDurationSeconds: 300,
            voiceId: "73c0b6a2e29d4d38aca41454bf58c955",
            text: "Hello! Let me think about that..."
        ))

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/avatar/realtime")
        assertAuth()
        XCTAssertEqual(captured?.headers["Content-Type"], "application/json")
        XCTAssertNotNil(captured?.headers["Idempotency-Key"], "billing POST must send an Idempotency-Key")

        let body = try bodyObject()
        XCTAssertEqual(body["type"] as? String, "text_stream")
        XCTAssertEqual(body["avatar_id"] as? String, "Abigail_expressive_2024112501")
        XCTAssertEqual(body["voice_id"] as? String, "73c0b6a2e29d4d38aca41454bf58c955")
        XCTAssertEqual(body["text"] as? String, "Hello! Let me think about that...")
        XCTAssertEqual(body["max_duration_seconds"] as? Int, 300)
        XCTAssertFalse(body.keys.contains("audio"))

        XCTAssertEqual(resp.streamId, "rt_9f2c1a")
        XCTAssertEqual(resp.status, "pending")
        XCTAssertEqual(resp.prepaidSeconds, 300)
        XCTAssertEqual(resp.costTicks, 345_000_000_000)
        XCTAssertEqual(resp.balanceAfter, 655_000_000_000, "balance_after fills from the X-QAI-Balance-After header")
        XCTAssertEqual(resp.requestId, "req_abc123def456")
    }

    func testCreateAvatarRealtimeSessionFillsCostFromHeader() async throws {
        // Body cost_ticks 0 (settle result unavailable) — the header value wins.
        MockGatewayProtocol.stub(status: 200, json: """
        {"stream_id":"rt_1","status":"pending","prepaid_seconds":60,"cost_ticks":0,"request_id":""}
        """, headers: ["X-QAI-Cost-Ticks": "69000000000", "X-QAI-Request-Id": "req_hdr"])

        let resp = try await client.createAvatarRealtimeSession(AvatarRealtimeRequest(
            sessionType: "tts", avatarId: "av_1", maxDurationSeconds: 60,
            voiceId: "v_1", text: "hi"
        ))
        XCTAssertEqual(resp.costTicks, 69_000_000_000)
        XCTAssertEqual(resp.requestId, "req_hdr")
    }

    func testCreateAvatarRealtimeInsufficientBalanceError() async throws {
        MockGatewayProtocol.stub(status: 402, json: """
        {"error":{"message":"out of credits — top up to continue","type":"insufficient_balance","code":"INSUFFICIENT_BALANCE"}}
        """)

        do {
            _ = try await client.createAvatarRealtimeSession(AvatarRealtimeRequest(
                sessionType: "tts", avatarId: "av_1", maxDurationSeconds: 3600,
                voiceId: "v_1", text: "hi"
            ))
            XCTFail("expected a 402 error")
        } catch let QuantumError.api(statusCode, code, message, _) {
            XCTAssertEqual(statusCode, 402)
            XCTAssertEqual(code, "INSUFFICIENT_BALANCE")
            XCTAssertEqual(message, "out of credits — top up to continue")
        }
    }

    // MARK: 2. GET /qai/v1/avatar/realtime/{id}

    func testGetAvatarRealtimeSessionStreaming() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "stream_id": "rt_9f2c1a",
          "status": "streaming",
          "hls_url": "https://cdn.heygen.com/realtime/rt_9f2c1a/index.m3u8",
          "request_id": "req_abc123def457"
        }
        """)

        let resp = try await client.getAvatarRealtimeSession(streamId: "rt_9f2c1a")

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "GET")
        XCTAssertEqual(captured?.url.path, "/qai/v1/avatar/realtime/rt_9f2c1a")
        assertAuth()
        XCTAssertTrue(captured?.body.isEmpty ?? true, "GET must send no body")

        XCTAssertEqual(resp.streamId, "rt_9f2c1a")
        XCTAssertEqual(resp.status, "streaming")
        XCTAssertEqual(resp.hlsUrl, "https://cdn.heygen.com/realtime/rt_9f2c1a/index.m3u8")
        XCTAssertNil(resp.errorMessage)
        XCTAssertNil(resp.endReason)
    }

    func testGetAvatarRealtimeSessionCompletedWithEndReason() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"stream_id":"rt_1","status":"completed","end_reason":"idle_timeout","request_id":"req_x"}
        """)
        let resp = try await client.getAvatarRealtimeSession(streamId: "rt_1")
        XCTAssertEqual(resp.status, "completed")
        XCTAssertEqual(resp.endReason, "idle_timeout")
        XCTAssertNil(resp.hlsUrl, "omitted hls_url must decode as nil")
    }

    func testGetAvatarRealtimeSessionNotFound() async throws {
        MockGatewayProtocol.stub(status: 404, json: """
        {"error":{"message":"session rt_x not found","type":"not_found","code":"not_found"}}
        """)
        do {
            _ = try await client.getAvatarRealtimeSession(streamId: "rt_x")
            XCTFail("expected a 404 error")
        } catch let QuantumError.api(statusCode, code, _, _) {
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(code, "not_found")
        }
    }

    // MARK: 3. POST /qai/v1/avatar/realtime/{id}/text

    func testSendAvatarRealtimeTextDelta() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"ok":true,"buffered_bytes":512,"final":false,"request_id":"req_abc123def458"}
        """)

        let resp = try await client.sendAvatarRealtimeText(streamId: "rt_9f2c1a", delta: " and more")

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/avatar/realtime/rt_9f2c1a/text")
        assertAuth()

        let body = try bodyObject()
        XCTAssertEqual(body["delta"] as? String, " and more")
        XCTAssertEqual(body["final"] as? Bool, false)

        XCTAssertTrue(resp.ok)
        XCTAssertEqual(resp.bufferedBytes, 512)
        XCTAssertFalse(resp.isFinal)
        XCTAssertEqual(resp.requestId, "req_abc123def458")
    }

    func testSendAvatarRealtimeTextFinalMarker() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"ok":true,"buffered_bytes":512,"final":true,"request_id":"req_1"}
        """)

        let resp = try await client.sendAvatarRealtimeText(streamId: "rt_1", .finalMarker())

        let body = try bodyObject()
        XCTAssertFalse(body.keys.contains("delta"), "final marker omits the empty delta")
        XCTAssertEqual(body["final"] as? Bool, true)
        XCTAssertTrue(resp.isFinal)
    }

    func testSendAvatarRealtimeTextClosedStream410() async throws {
        // Upstream 410 on a closed text stream passes through as provider_error.
        MockGatewayProtocol.stub(status: 410, json: """
        {"error":{"message":"text stream closed","type":"provider_error","code":"provider_error"}}
        """)
        do {
            _ = try await client.sendAvatarRealtimeText(streamId: "rt_1", delta: "late")
            XCTFail("expected a 410 error")
        } catch let QuantumError.api(statusCode, code, _, _) {
            XCTAssertEqual(statusCode, 410)
            XCTAssertEqual(code, "provider_error")
        }
    }

    // MARK: 4. POST /qai/v1/avatar/realtime/{id}/cancel

    func testCancelAvatarRealtimeSession() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"stream_id":"rt_9f2c1a","cancelled":true,"request_id":"req_abc123def459"}
        """)

        let resp = try await client.cancelAvatarRealtimeSession(streamId: "rt_9f2c1a")

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/avatar/realtime/rt_9f2c1a/cancel")
        assertAuth()
        XCTAssertTrue(captured?.body.isEmpty ?? true, "cancel sends no request body")

        XCTAssertEqual(resp.streamId, "rt_9f2c1a")
        XCTAssertTrue(resp.cancelled)
        XCTAssertEqual(resp.requestId, "req_abc123def459")
    }

    func testCancelAvatarRealtimeSessionIdempotent() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"stream_id":"rt_1","cancelled":false,"request_id":"req_1"}
        """)
        let resp = try await client.cancelAvatarRealtimeSession(streamId: "rt_1")
        XCTAssertFalse(resp.cancelled, "already-terminal session reports cancelled: false")
    }

    // MARK: 5. GET /qai/v1/audio/sounds

    func testSearchAudioSounds() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "sounds": [
            {
              "id": "trk_8842aa",
              "name": "Uplifting Corporate",
              "description": "Bright, optimistic corporate track with piano and strings",
              "audio_url": "https://resource.heygen.ai/sounds/trk_8842aa.wav?sig=abc",
              "duration": 94.5,
              "score": 0.91,
              "type": "music"
            }
          ],
          "has_more": true,
          "next_token": "eyJvZmZzZXQiOjEwfQ",
          "request_id": "req_abc123def45a"
        }
        """)

        let resp = try await client.searchAudioSounds(AudioSoundsQuery(
            query: "calm piano",
            soundType: "music",
            limit: 10,
            minScore: 0.7
        ))

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "GET")
        XCTAssertEqual(captured?.url.path, "/qai/v1/audio/sounds")
        assertAuth()
        let query = captured?.url.query ?? ""
        XCTAssertTrue(query.contains("query=calm%20piano"), "query must be percent-encoded, got: \(query)")
        XCTAssertTrue(query.contains("type=music"))
        XCTAssertTrue(query.contains("limit=10"))
        XCTAssertTrue(query.contains("min_score=0.7"))
        XCTAssertFalse(query.contains("token="), "token omitted when nil")

        XCTAssertEqual(resp.sounds.count, 1)
        XCTAssertEqual(resp.sounds[0].id, "trk_8842aa")
        XCTAssertEqual(resp.sounds[0].name, "Uplifting Corporate")
        XCTAssertEqual(resp.sounds[0].audioUrl, "https://resource.heygen.ai/sounds/trk_8842aa.wav?sig=abc")
        XCTAssertEqual(resp.sounds[0].duration, 94.5)
        XCTAssertEqual(resp.sounds[0].score, 0.91)
        XCTAssertEqual(resp.sounds[0].soundType, "music")
        XCTAssertTrue(resp.hasMore)
        XCTAssertEqual(resp.nextToken, "eyJvZmZzZXQiOjEwfQ")
        XCTAssertEqual(resp.requestId, "req_abc123def45a")
    }

    func testSearchAudioSoundsEmptyPageAndToken() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {"sounds":[],"has_more":false,"next_token":"","request_id":"req_1"}
        """)
        let resp = try await client.searchAudioSounds(AudioSoundsQuery(query: "x", token: "cur sor"))
        let query = MockGatewayProtocol.captured?.url.query ?? ""
        XCTAssertTrue(query.contains("token=cur%20sor"), "token must be percent-encoded, got: \(query)")
        XCTAssertTrue(resp.sounds.isEmpty)
        XCTAssertFalse(resp.hasMore)
        XCTAssertEqual(resp.nextToken, "")
    }

    // MARK: 6. GET /qai/v1/video/template/{id}

    func testVideoTemplateDetail() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "template": {
            "id": "tmpl_5f0a",
            "name": "Product Launch",
            "aspect_ratio": "16:9",
            "variables": {
              "headline": { "type": "text", "content": "Default headline" },
              "narrator": { "type": "voice", "voice_id": "73c0b6a2", "locale": "en-US" }
            },
            "scenes": [
              {
                "scene_id": "scene_1",
                "script": "Introducing {{headline}}...",
                "variables": [ { "name": "headline", "variable_type": "text" } ]
              }
            ]
          },
          "request_id": "req_abc123def45b"
        }
        """)

        let resp = try await client.videoTemplateDetail(templateId: "tmpl_5f0a")

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "GET")
        XCTAssertEqual(captured?.url.path, "/qai/v1/video/template/tmpl_5f0a")
        assertAuth()

        XCTAssertEqual(resp.template.id, "tmpl_5f0a")
        XCTAssertEqual(resp.template.name, "Product Launch")
        XCTAssertEqual(resp.template.aspectRatio, "16:9")
        let narrator = resp.template.variables["narrator"]?.value as? [String: Any]
        XCTAssertEqual(narrator?["type"] as? String, "voice")
        XCTAssertEqual(narrator?["voice_id"] as? String, "73c0b6a2")
        XCTAssertEqual(resp.template.scenes[0].sceneId, "scene_1")
        XCTAssertEqual(resp.template.scenes[0].script, "Introducing {{headline}}...")
        XCTAssertEqual(resp.requestId, "req_abc123def45b")
    }

    func testVideoTemplateDetailUnknownTemplateProviderError() async throws {
        // Unknown template id: upstream 4xx passes through as provider_error.
        MockGatewayProtocol.stub(status: 404, json: """
        {"error":{"message":"template not found","type":"provider_error","code":"provider_error"}}
        """)
        do {
            _ = try await client.videoTemplateDetail(templateId: "tmpl_missing")
            XCTFail("expected a provider_error")
        } catch let QuantumError.api(statusCode, code, _, _) {
            XCTAssertEqual(statusCode, 404)
            XCTAssertEqual(code, "provider_error")
        }
    }

    // MARK: 7. POST /qai/v1/video/template/{id} (async job)

    func testVideoTemplateGenerate() async throws {
        MockGatewayProtocol.stub(status: 202, json: """
        {
          "job_id": "qai_job_3def45c00112",
          "status": "pending",
          "type": "video/template-v3",
          "request_id": "req_abc123def45c"
        }
        """)

        let resp = try await client.videoTemplateGenerate(
            templateId: "tmpl_5f0a",
            VideoTemplateGenerateRequest(
                variables: ["headline": AnyCodable(["type": "text", "content": "New!"])],
                title: "Launch video",
                fps: 30
            )
        )

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/video/template/tmpl_5f0a")
        assertAuth()
        XCTAssertNotNil(captured?.headers["Idempotency-Key"], "billing POST must send an Idempotency-Key")

        let body = try bodyObject()
        let headline = (body["variables"] as? [String: Any])?["headline"] as? [String: Any]
        XCTAssertEqual(headline?["type"] as? String, "text")
        XCTAssertEqual(headline?["content"] as? String, "New!")
        XCTAssertEqual(body["title"] as? String, "Launch video")
        XCTAssertEqual(body["fps"] as? Int, 30)
        XCTAssertFalse(body.keys.contains("subtitles"))

        XCTAssertEqual(resp.jobId, "qai_job_3def45c00112")
        XCTAssertEqual(resp.status, "pending")
        XCTAssertEqual(resp.jobType, "video/template-v3")
        XCTAssertEqual(resp.requestId, "req_abc123def45c")
    }

    func testVideoTemplateJobResultDecode() async throws {
        // The template job completes on the standard jobs rails — verify the
        // job status envelope + result payload decode through getJob.
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "job_id": "qai_job_3def45c00112",
          "type": "video/template-v3",
          "status": "completed",
          "result": {
            "video_id": "vid_77aa01",
            "video_url": "https://resource.heygen.ai/video/vid_77aa01.mp4?sig=x",
            "thumbnail_url": "https://resource.heygen.ai/thumb/vid_77aa01.jpg",
            "duration_seconds": 42.7,
            "model": "heygen-template",
            "cost_ticks": 22500000000,
            "request_id": "req_abc123def45c"
          },
          "cost_ticks": 22500000000,
          "created_at": "2026-07-17T10:00:00Z",
          "started_at": "2026-07-17T10:00:01Z",
          "completed_at": "2026-07-17T10:03:41Z",
          "request_id": "req_abc123def45c"
        }
        """)

        let job = try await client.getJob(jobId: "qai_job_3def45c00112")
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/jobs/qai_job_3def45c00112")
        XCTAssertEqual(job.status, "completed")
        XCTAssertEqual(job.costTicks, 22_500_000_000)
        let result = job.result?.value as? [String: Any]
        XCTAssertEqual(result?["video_url"] as? String, "https://resource.heygen.ai/video/vid_77aa01.mp4?sig=x")
        XCTAssertEqual(result?["model"] as? String, "heygen-template")
        XCTAssertEqual(result?["duration_seconds"] as? Double, 42.7)
    }

    // MARK: 8. POST /qai/v1/video/batch

    func testVideoBatchSubmit() async throws {
        MockGatewayProtocol.stub(status: 202, json: """
        {
          "batch_id": "batch_66aa1c",
          "status": "processing",
          "total_items": 2,
          "request_id": "req_abc123def45d"
        }
        """)

        let resp = try await client.videoBatchSubmit(VideoBatchSubmitRequest(
            videos: [
                AnyCodable(["type": "avatar", "avatar_id": "av_1", "voice_id": "v_1", "script": "Welcome!"]),
                AnyCodable(["type": "avatar", "avatar_id": "av_1", "voice_id": "v_1", "script": "Billing 101."]),
            ],
            title: "Onboarding videos"
        ))

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/video/batch")
        assertAuth()
        XCTAssertNotNil(captured?.headers["Idempotency-Key"], "billing POST must send an Idempotency-Key")

        let body = try bodyObject()
        XCTAssertEqual(body["title"] as? String, "Onboarding videos")
        let videos = body["videos"] as? [[String: Any]]
        XCTAssertEqual(videos?.count, 2)
        XCTAssertEqual(videos?[0]["type"] as? String, "avatar")
        XCTAssertEqual(videos?[1]["script"] as? String, "Billing 101.")

        XCTAssertEqual(resp.batchId, "batch_66aa1c")
        XCTAssertEqual(resp.status, "processing")
        XCTAssertEqual(resp.totalItems, 2)
        XCTAssertEqual(resp.requestId, "req_abc123def45d")
    }

    // MARK: 9. GET /qai/v1/video/batch/{id}

    func testVideoBatchStatusSettled() async throws {
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "batch_id": "batch_66aa1c",
          "title": "Onboarding videos",
          "status": "completed",
          "total_items": 3,
          "counts_by_status": { "completed": 2, "failed": 1 },
          "created_at": 1752741600,
          "items": [
            { "item_index": 0, "status": "completed", "video_id": "vid_001", "video_url": "https://resource.heygen.ai/video/vid_001.mp4?sig=x" },
            { "item_index": 1, "status": "completed", "video_id": "vid_002", "video_url": "https://resource.heygen.ai/video/vid_002.mp4?sig=x" },
            { "item_index": 2, "status": "failed", "error": { "code": "avatar_not_found", "message": "avatar id not found" } }
          ],
          "has_more": false,
          "next_token": "",
          "billing_status": "settled",
          "cost_ticks": 46000000000,
          "request_id": "req_abc123def45e"
        }
        """)

        let resp = try await client.videoBatchStatus(
            batchId: "batch_66aa1c",
            query: VideoBatchStatusQuery(limit: 100, token: "pg 2")
        )

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "GET")
        XCTAssertEqual(captured?.url.path, "/qai/v1/video/batch/batch_66aa1c")
        assertAuth()
        let query = captured?.url.query ?? ""
        XCTAssertTrue(query.contains("limit=100"))
        XCTAssertTrue(query.contains("token=pg%202"), "token must be percent-encoded, got: \(query)")

        XCTAssertEqual(resp.batchId, "batch_66aa1c")
        XCTAssertEqual(resp.title, "Onboarding videos")
        XCTAssertEqual(resp.status, "completed")
        XCTAssertEqual(resp.totalItems, 3)
        XCTAssertEqual(resp.countsByStatus, ["completed": 2, "failed": 1])
        XCTAssertEqual(resp.createdAt, 1_752_741_600)
        XCTAssertEqual(resp.items.count, 3)
        XCTAssertEqual(resp.items[0].itemIndex, 0)
        XCTAssertEqual(resp.items[0].videoId, "vid_001")
        XCTAssertEqual(resp.items[0].videoUrl, "https://resource.heygen.ai/video/vid_001.mp4?sig=x")
        XCTAssertNil(resp.items[0].error)
        XCTAssertEqual(resp.items[2].status, "failed")
        XCTAssertNil(resp.items[2].videoUrl)
        XCTAssertEqual(resp.items[2].error?.code, "avatar_not_found")
        XCTAssertEqual(resp.items[2].error?.message, "avatar id not found")
        XCTAssertFalse(resp.hasMore)
        XCTAssertEqual(resp.nextToken, "")
        XCTAssertEqual(resp.billingStatus, "settled")
        XCTAssertEqual(resp.costTicks, 46_000_000_000)
        XCTAssertEqual(resp.requestId, "req_abc123def45e")
    }

    func testVideoBatchStatusUnsettledWithholdsUrls() async throws {
        // Before settlement, statuses flow but video_url is withheld and
        // cost_ticks is 0 — the SDK must keep those optional/zero.
        MockGatewayProtocol.stub(status: 200, json: """
        {
          "batch_id": "batch_1",
          "title": "",
          "status": "completed",
          "total_items": 1,
          "counts_by_status": { "completed": 1 },
          "created_at": 1752741600,
          "items": [ { "item_index": 0, "status": "completed", "video_id": "vid_001" } ],
          "has_more": false,
          "next_token": "",
          "billing_status": "settlement_pending",
          "cost_ticks": 0,
          "request_id": "req_1"
        }
        """)

        let resp = try await client.videoBatchStatus(batchId: "batch_1")
        XCTAssertNil(MockGatewayProtocol.captured?.url.query, "no query params when the query struct is nil")
        XCTAssertEqual(resp.billingStatus, "settlement_pending")
        XCTAssertEqual(resp.costTicks, 0)
        XCTAssertEqual(resp.items[0].videoId, "vid_001")
        XCTAssertNil(resp.items[0].videoUrl, "URLs are withheld until billing_status == settled")
    }
}

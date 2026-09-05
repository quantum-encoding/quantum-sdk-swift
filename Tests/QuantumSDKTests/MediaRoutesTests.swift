import XCTest
@testable import QuantumSDK

/// Wire contract of the rebuilt media routes against the mock gateway:
/// method, path, query, content type and body per the Go handlers.
final class MediaRoutesTests: XCTestCase {
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
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func bodyText() -> String {
        String(decoding: MockGatewayProtocol.captured?.body ?? Data(), as: UTF8.self)
    }

    // MARK: Batch JSONL is a raw ndjson body

    func testBatchSubmitJsonlSendsRawBody() async throws {
        MockGatewayProtocol.stub(status: 202, json: #"{"batch_id":"batch_2","jobs":2,"job_ids":["a","b"],"pricing":"50%","status":"queued"}"#)
        let jsonl = "{\"model\":\"m\",\"prompt\":\"a\"}\n{\"model\":\"m\",\"prompt\":\"b\"}\n"
        let resp = try await client.batchSubmitJsonl(jsonl)

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "POST")
        XCTAssertEqual(captured?.url.path, "/qai/v1/batch/jsonl")
        XCTAssertEqual(captured?.headers["Content-Type"], "application/x-ndjson")
        XCTAssertEqual(captured?.headers["Authorization"], "Bearer qai_k_test")
        XCTAssertEqual(bodyText(), jsonl)
        XCTAssertEqual(resp.jobIds, ["a", "b"])
    }

    // MARK: Documents are multipart, field `file`

    func testExtractDocumentPostsMultipartFile() async throws {
        MockGatewayProtocol.stub(status: 200, json: ##"{"markdown":"# T","format":"markdown","meta":{"extraction_method":"pdf"}}"##,
                                 headers: ["X-QAI-Cost-Ticks": "1000", "X-QAI-Request-Id": "req_doc"])
        let resp = try await client.extractDocument(DocumentRequest(
            content: Data("%PDF-1.4".utf8), filename: "a.pdf", mimeType: "application/pdf", extractImages: true
        ))

        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.url.path, "/qai/v1/documents/extract")
        XCTAssertTrue(captured?.headers["Content-Type"]?.hasPrefix("multipart/form-data; boundary=") ?? false)
        let body = bodyText()
        XCTAssertTrue(body.contains("name=\"file\"; filename=\"a.pdf\""), body)
        XCTAssertTrue(body.contains("Content-Type: application/pdf"), body)
        XCTAssertTrue(body.contains("name=\"extract_images\"\r\n\r\ntrue"), body)
        XCTAssertFalse(body.contains("chunk_size"))
        XCTAssertEqual(resp.costTicks, 1000, "cost fills from the header when the body omits it")
        XCTAssertEqual(resp.requestId, "req_doc")
    }

    func testChunkAndProcessSendCharacterSizedFields() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"format":"markdown","meta":{"chunk_count":1},"chunks":[{"index":0,"text":"t"}]}"#)
        _ = try await client.chunkDocument(ChunkDocumentRequest(content: Data("x".utf8), filename: "a.docx", chunkSize: 1500, overlap: 100))
        var body = bodyText()
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/documents/chunk")
        XCTAssertTrue(body.contains("name=\"chunk_size\"\r\n\r\n1500"), body)
        XCTAssertTrue(body.contains("name=\"overlap\"\r\n\r\n100"), body)
        XCTAssertTrue(body.contains("Content-Type: application/octet-stream"), body)

        MockGatewayProtocol.stub(status: 200, json: #"{"markdown":"m","format":"markdown","meta":{},"chunks":null}"#)
        let processed = try await client.processDocument(ProcessDocumentRequest(content: Data("x".utf8), filename: "a.pdf", extractImages: true, chunkSize: 500))
        body = bodyText()
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/documents/process")
        XCTAssertTrue(body.contains("name=\"extract_images\""), body)
        XCTAssertTrue(body.contains("name=\"chunk_size\"\r\n\r\n500"), body)
        XCTAssertEqual(processed.chunks, [])
    }

    // MARK: Files / media sessions / caches

    func testFileUploadIsMultipartFieldFile() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"file_uri":"files/abc","name":"files/abc","mime_type":"image/png","size_bytes":3}"#)
        let resp = try await client.fileUpload(filename: "duck.png", mimeType: "image/png", content: Data([1, 2, 3]))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/files")
        let body = bodyText()
        XCTAssertTrue(body.contains("name=\"file\"; filename=\"duck.png\""), body)
        XCTAssertTrue(body.contains("Content-Type: image/png"), body)
        XCTAssertEqual(resp.fileUri, "files/abc")
    }

    func testMediaSessionRoutes() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"id":"s1","file_uri":"files/a","mime_type":"video/mp4","cache_name":"c","model":"gemini-3.1-flash-lite","history":null,"message_count":0}"#)
        let created = try await client.mediaSessionCreate(MediaSessionCreateRequest(fileUri: "files/a", mimeType: "video/mp4", model: "gemini-3.1-flash-lite"))
        XCTAssertEqual(MockGatewayProtocol.captured?.method, "POST")
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/media-sessions")
        XCTAssertEqual(try bodyObject()["file_uri"] as? String, "files/a")
        XCTAssertEqual(created.id, "s1")

        MockGatewayProtocol.stub(status: 200, json: #"{"sessions":null}"#)
        _ = try await client.mediaSessionList()
        XCTAssertEqual(MockGatewayProtocol.captured?.method, "GET")

        MockGatewayProtocol.stub(status: 200, json: #"{"session_id":"s1","answer":"duck","history":null}"#)
        let chat = try await client.mediaSessionChat(id: "s1", MediaSessionChatRequest(message: "what?"))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/media-sessions/s1/chat")
        XCTAssertEqual(try bodyObject()["message"] as? String, "what?")
        XCTAssertEqual(chat.answer, "duck")

        MockGatewayProtocol.stub(status: 200, json: #"{"deleted":true}"#)
        let deleted = try await client.mediaSessionDelete(id: "s1")
        XCTAssertEqual(MockGatewayProtocol.captured?.method, "DELETE")
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/media-sessions/s1")
        XCTAssertTrue(deleted.deleted)
    }

    func testCacheRoutes() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"cache_name":"cachedContents/x","model":"gemini-3.1-flash-lite","expires_at":"t"}"#)
        let created = try await client.cacheCreate(CacheCreateRequest(fileUri: "files/a", mimeType: "video/mp4", model: "gemini-3.1-flash-lite"))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/caches")
        XCTAssertEqual(created.cacheName, "cachedContents/x")

        MockGatewayProtocol.stub(status: 200, json: #"{"deleted":true}"#)
        _ = try await client.cacheDelete(cacheName: "cachedContents/x")
        XCTAssertEqual(MockGatewayProtocol.captured?.method, "DELETE")
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/caches/cachedContents/x")
    }

    // MARK: Search / STT token / voice library

    func testGoogleSearchAndSttTokenRoutes() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"answer":"a","citations":null,"web_search_queries":["q"]}"#)
        let google = try await client.googleSearch(GoogleSearchRequest(query: "ducks"))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/search/google")
        XCTAssertEqual(try bodyObject()["query"] as? String, "ducks")
        XCTAssertEqual(google.webSearchQueries, ["q"])

        MockGatewayProtocol.stub(status: 200, json: #"{"token":"tok","expires_in":900,"ws_endpoint":"wss://api.elevenlabs.io/v1/speech-to-text/realtime","cost_ticks":0,"request_id":""}"#,
                                 headers: ["X-QAI-Cost-Ticks": "600000000", "X-QAI-Request-Id": "req_tok"])
        let token = try await client.audioSTTRealtimeToken()
        XCTAssertEqual(MockGatewayProtocol.captured?.method, "POST")
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/audio/stt/realtime-token")
        XCTAssertEqual(token.costTicks, 600_000_000)
        XCTAssertEqual(token.requestId, "req_tok")
    }

    func testVoiceLibrarySendsQ() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"voices":null,"has_more":false,"last_sort_id":""}"#)
        _ = try await client.voiceLibrary(query: VoiceLibraryQuery(query: "deep narrator", pageSize: 10))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.query, "q=deep%20narrator&page_size=10")
    }

    // MARK: Jobs

    func testGetJobDecodesAPendingJobAndPollJobThrowsOnTimeout() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"job_id":"j1","status":"pending","type":"chat","created_at":"2026-09-05T10:00:00Z"}"#)
        let pending = try await client.getJob(jobId: "j1")
        XCTAssertEqual(pending.costTicks, 0)

        do {
            _ = try await client.pollJob(jobId: "j1", interval: 0.001, maxAttempts: 2)
            XCTFail("pollJob must throw when attempts run out")
        } catch let error as QuantumError {
            guard case let .api(status, code, _, _) = error else { return XCTFail("expected api error, got \(error)") }
            XCTAssertEqual(status, 0)
            XCTAssertEqual(code, "poll_timeout")
        }
    }

    func testStreamJobIsAGetEventStream() async throws {
        MockGatewayProtocol.stub(
            status: 200,
            json: "data: {\"type\":\"progress\",\"job_id\":\"j1\",\"status\":\"running\"}\n\ndata: {\"type\":\"complete\",\"job_id\":\"j1\",\"status\":\"completed\",\"cost_ticks\":5}\n\n",
            headers: ["Content-Type": "text/event-stream"]
        )
        var events: [JobStreamEvent] = []
        for try await event in client.streamJob(jobId: "j1") {
            events.append(event)
        }
        let captured = MockGatewayProtocol.captured
        XCTAssertEqual(captured?.method, "GET")
        XCTAssertEqual(captured?.url.path, "/qai/v1/jobs/j1/stream")
        XCTAssertEqual(captured?.headers["Authorization"], "Bearer qai_k_test")
        XCTAssertEqual(captured?.headers["X-API-Key"], "qai_k_test")
        XCTAssertEqual(captured?.headers["Accept"], "text/event-stream")
        XCTAssertEqual(events.map(\.eventType), ["progress", "complete"])
        XCTAssertEqual(events.last?.costTicks, 5)
    }

    func testStreamJobSurfacesTheGatewayError() async {
        MockGatewayProtocol.stub(status: 404, json: #"{"error":{"message":"job not found","type":"not_found"}}"#)
        do {
            for try await _ in client.streamJob(jobId: "missing") {}
            XCTFail("expected an error")
        } catch let error as QuantumError {
            XCTAssertTrue(error.isNotFound)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: Realtime token routes

    func testRealtimeSessionElevenLabsAndEndSendInteger() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"session_id":"vs_2","signed_url":"wss://api.elevenlabs.io/x?token=s","provider":"elevenlabs"}"#)
        let session = try await client.realtimeSession(provider: "elevenlabs")
        XCTAssertEqual(try bodyObject()["provider"] as? String, "elevenlabs")
        XCTAssertEqual(session.provider, "elevenlabs")
        XCTAssertTrue(session.wsUrl.hasPrefix("wss://api.elevenlabs.io"))

        MockGatewayProtocol.stub(status: 200, json: #"{"status":"ended"}"#)
        try await client.realtimeEnd(sessionId: "vs_2", durationSeconds: 12)
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/realtime/end")
        XCTAssertTrue(bodyText().contains("\"duration_seconds\":12"), bodyText())
        XCTAssertFalse(bodyText().contains("12.0"))
    }

    // MARK: Video catalogs / twin

    func testVideoTemplatesReturnsTypedCatalogAndTwinCreateBackfillsRequestId() async throws {
        MockGatewayProtocol.stub(status: 200, json: #"{"templates":[{"template_id":"t1","name":"Promo","thumbnail_image_url":"https://x/t.png"}],"request_id":"r"}"#)
        let templates = try await client.videoTemplates()
        XCTAssertEqual(templates.templates.first?.thumbnailUrl, "https://x/t.png")

        MockGatewayProtocol.stub(status: 200, json: #"{"name":"Rich","consent_url":"https://c","model":"heygen-digital-twin","group_id":"g"}"#,
                                 headers: ["X-QAI-Request-Id": "req_twin"])
        let twin = try await client.videoDigitalTwin(DigitalTwinCreateRequest(name: "Rich", videoUrl: "https://x/v.mp4"))
        XCTAssertEqual(MockGatewayProtocol.captured?.url.path, "/qai/v1/video/digital-twin")
        XCTAssertEqual(try bodyObject().keys.sorted(), ["name", "video_url"])
        XCTAssertEqual(twin.requestId, "req_twin")
    }
}

import XCTest
@testable import QuantumSDK

/// Every rebuilt request serialises exactly the keys its gateway handler
/// decodes — no more (silently dropped) and no fewer (400).
final class MediaRequestEncodingTests: XCTestCase {

    private func keys(_ value: some Encodable) throws -> [String] {
        let data = try JSONEncoder().encode(value)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return obj.keys.sorted()
    }

    private func object(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: Audio

    func testRemixSendsTheGatewayKnobsOnly() throws {
        let req = RemixVoiceRequest(
            audioBase64: "AQID", filename: "in.mp3", gender: "female", accent: "british",
            style: "calm", pacing: "slow", audioQuality: "high", promptStrength: "strong", script: "Hello"
        )
        XCTAssertEqual(try keys(req), [
            "accent", "audio_base64", "audio_quality", "filename", "gender",
            "pacing", "prompt_strength", "script", "style",
        ])
        XCTAssertEqual(try keys(RemixVoiceRequest(audioBase64: "AQID")), ["audio_base64"])
    }

    func testSpeechToSpeechAndStarfishSendVoiceId() throws {
        XCTAssertEqual(try keys(SpeechToSpeechRequest(voiceId: "v1", audioBase64: "AQID")), ["audio_base64", "voice_id"])
        XCTAssertEqual(try keys(StarfishTTSRequest(text: "hi", voiceId: "hv1", speed: 1.1)), ["speed", "text", "voice_id"])
        XCTAssertEqual(
            try keys(StarfishTTSRequest(text: "hi", voiceId: "hv1", inputType: "ssml", language: "en", locale: "en-GB")),
            ["input_type", "language", "locale", "text", "voice_id"]
        )
    }

    func testIsolateAndVoiceDesignSendNoFormat() throws {
        XCTAssertEqual(try keys(IsolateVoiceRequest(audioBase64: "AQID", filename: "noisy.wav")), ["audio_base64", "filename"])
        XCTAssertEqual(try keys(VoiceDesignRequest(description: "warm baritone", text: "Sample line")), ["sample_text", "voice_description"])
    }

    func testDubUsesTargetLangAndSourceLang() throws {
        let req = DubRequest(targetLang: "es", audioBase64: "AQID", filename: "a.mp3", sourceUrl: nil, sourceLang: "en", numSpeakers: 2, highestResolution: true)
        XCTAssertEqual(try keys(req), ["audio_base64", "filename", "highest_resolution", "num_speakers", "source_lang", "target_lang"])
        XCTAssertEqual(try keys(DubRequest(targetLang: "de", sourceUrl: "https://x/a.mp4")), ["source_url", "target_lang"])
    }

    func testAlignCarriesFilename() throws {
        XCTAssertEqual(try keys(AlignRequest(audioBase64: "AQID", text: "hi", filename: "a.wav")), ["audio_base64", "filename", "text"])
    }

    func testElevenMusicHasNoEditFieldsAndOptionalModel() throws {
        XCTAssertEqual(try keys(ElevenMusicRequest(prompt: "lofi", durationSeconds: 60)), ["duration_seconds", "prompt"])
        let full = ElevenMusicRequest(
            prompt: "lofi", model: "music_v1", sections: [MusicSection(sectionType: "verse", lyrics: "la")],
            durationSeconds: 30, language: "en", vocals: true, style: "chill", styleExclude: "metal", finetuneId: "ft_1"
        )
        XCTAssertEqual(try keys(full), [
            "duration_seconds", "finetune_id", "language", "model", "prompt", "sections", "style", "style_exclude", "vocals",
        ])
        XCTAssertEqual(try keys(MusicFinetuneCreateRequest(name: "mine", samples: ["AQID"])), ["name", "samples"])
    }

    func testDialogueFromTurnsMapsEverySpeaker() throws {
        let req = try DialogueRequest(turns: [
            DialogueTurn(speaker: "A", text: "Hi"),
            DialogueTurn(speaker: "B", text: "Hello", voice: "vb"),
            DialogueTurn(speaker: "A", text: "Bye", voice: "va"),
        ])
        XCTAssertEqual(req.text, "A: Hi\nB: Hello\nA: Bye")
        XCTAssertEqual(req.voices.map(\.name), ["B", "A"])
        XCTAssertEqual(req.voices.map(\.voiceId), ["vb", "va"])
        XCTAssertEqual(try keys(req), ["text", "voices"])

        XCTAssertThrowsError(try DialogueRequest(turns: [DialogueTurn(speaker: "A", text: "Hi")])) { error in
            guard case .invalidArgument = error as? QuantumError else { return XCTFail("expected invalidArgument, got \(error)") }
        }
        XCTAssertThrowsError(try DialogueRequest(turns: [
            DialogueTurn(speaker: "A", text: "Hi", voice: "v1"),
            DialogueTurn(speaker: "A", text: "Again", voice: "v2"),
        ]))
    }

    // MARK: Video

    func testStudioRequestCarriesTheThreeRequiredKeys() throws {
        XCTAssertEqual(try keys(VideoStudioRequest(avatarId: "av", script: "Hello", voiceId: "vc")), ["avatar_id", "script", "voice_id"])
    }

    func testTranslateUsesVideoUrlAndOutputLanguage() throws {
        let req = VideoTranslateRequest(videoUrl: "https://x/v.mp4", outputLanguage: "es", title: "t")
        XCTAssertEqual(try keys(req), ["output_language", "title", "video_url"])
    }

    func testTwinCreateAndTwinVideoAreDifferentBodies() throws {
        XCTAssertEqual(try keys(DigitalTwinCreateRequest(name: "Rich", videoUrl: "https://x/train.mp4")), ["name", "video_url"])
        XCTAssertEqual(try keys(TwinVideoRequest(avatarId: "look_1", script: "Hi", voiceId: "v1")), ["avatar_id", "script", "voice_id"])
    }

    // MARK: Image / embeddings / voices

    func testImageEditRequiresInputImages() throws {
        let req = ImageEditRequest(model: "gpt-image-1", prompt: "bluer", inputImages: ["AQID"])
        XCTAssertEqual(try keys(req), ["input_images", "model", "prompt"])
    }

    func testEmbedSendsModelAndInputList() throws {
        let obj = try object(EmbedRequest(model: "text-embedding-3-small", input: ["a", "b"]))
        XCTAssertEqual(obj.keys.sorted(), ["input", "model"])
        XCTAssertEqual(obj["input"] as? [String], ["a", "b"])
    }

    func testCloneVoiceIsTheJsonShapeTheHandlerDecodes() throws {
        XCTAssertEqual(try keys(CloneVoiceRequest(name: "Me", audioSamples: ["AQID"])), ["audio_samples", "name"])
    }

    func testVoiceLibraryQuerySendsQAndEncodesValues() {
        let items = VoiceLibraryQuery(query: "deep narrator", cursor: "a&b", language: "en", useCase: "narration").queryItems
        XCTAssertEqual(items, ["q=deep%20narrator", "cursor=a%26b", "language=en", "use_case=narration"])
        XCTAssertEqual(VoiceLibraryQuery().queryItems, [])
    }

    // MARK: Documents

    func testDocumentFormFieldsMatchTheMultipartHandler() {
        XCTAssertEqual(documentFormFields(extractImages: false, chunkSize: nil, overlap: nil), [:])
        XCTAssertEqual(
            documentFormFields(extractImages: true, chunkSize: 1500, overlap: 100),
            ["extract_images": "true", "chunk_size": "1500", "overlap": "100"]
        )
    }

    // MARK: Search

    func testWebSearchOptionsUseTheRouteKeys() throws {
        let req = WebSearchRequest(query: "ducks", options: SearchOptions(count: 5, freshness: "pw", safesearch: "strict"))
        let obj = try object(req)
        XCTAssertEqual(obj.keys.sorted(), ["count", "freshness", "query", "safesearch"])
        XCTAssertEqual(obj["safesearch"] as? String, "strict")

        let ctx = SearchContextRequest(query: "ducks", options: ContextOptions(count: 3, freshness: "pd"))
        XCTAssertEqual(try keys(ctx), ["count", "freshness", "query"])
        XCTAssertEqual(try keys(GoogleSearchRequest(query: "ducks")), ["query"])
    }

    // MARK: Media sessions / caches

    func testMediaSessionCreateOmitsUnsetOptions() throws {
        let req = MediaSessionCreateRequest(fileUri: "files/abc123", mimeType: "video/mp4", model: "gemini-3.1-flash-lite")
        XCTAssertEqual(try keys(req), ["file_uri", "mime_type", "model"])
        let full = MediaSessionCreateRequest(
            fileUri: "files/abc123", mimeType: "video/mp4", model: "gemini-3.1-flash-lite",
            systemInstruction: "be brief", displayName: "clip", cacheTtlSeconds: 7200
        )
        XCTAssertEqual(try keys(full), ["cache_ttl_seconds", "display_name", "file_uri", "mime_type", "model", "system_instruction"])
    }

    func testMediaSessionChatCarriesPerTurnKnobs() throws {
        let req = MediaSessionChatRequest(message: "what is it?", maxTokens: 64, temperature: 0.2, outputSchema: ["type": "object"])
        XCTAssertEqual(try keys(req), ["max_tokens", "message", "output_schema", "temperature"])
        XCTAssertEqual(try keys(MediaSessionChatRequest(message: "hi")), ["message"])
    }

    func testCacheCreateOmitsUnsetOptions() throws {
        let req = CacheCreateRequest(fileUri: "files/abc123", mimeType: "video/mp4", model: "gemini-3.1-flash-lite", ttlSeconds: 7200)
        let obj = try object(req)
        XCTAssertEqual(obj.keys.sorted(), ["file_uri", "mime_type", "model", "ttl_seconds"])
        XCTAssertEqual(obj["ttl_seconds"] as? Int, 7200)
    }

    // MARK: Realtime

    func testElevenLabsConfigRendersOnlyTheFieldsThatAreSet() {
        XCTAssertEqual(ElevenLabsProxyConfig().queryString, "")
        let config = ElevenLabsProxyConfig(voiceId: "21m00Tcm4TlvDq8ikWAM", agentId: "agent 7")
        XCTAssertEqual(config.queryString, "?voice_id=21m00Tcm4TlvDq8ikWAM&agent_id=agent%207")
    }

    func testGrokModelsGetTheXaiFrameAndGptModelsTheOpenAIFrame() throws {
        var config = RealtimeConfig(model: "grok-realtime-beta")
        var frame = buildSessionUpdate(config)
        XCTAssertEqual(frame["type"]?.value as? String, "session.update")
        var session = try XCTUnwrap(frame["session"]?.value as? [String: Any])
        XCTAssertEqual(session["model"] as? String, "grok-realtime-beta")
        XCTAssertEqual(session["voice"] as? String, "Sal")
        XCTAssertNotNil(session["audio"] as? [String: Any])
        XCTAssertNil(session["modalities"])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let format = try XCTUnwrap(input["format"] as? [String: Any])
        XCTAssertEqual(format["rate"] as? Int, 24000)
        XCTAssertEqual((session["turn_detection"] as? [String: Any])?["type"] as? String, "server_vad")

        config.model = "gpt-4o-realtime-preview"
        frame = buildSessionUpdate(config)
        session = try XCTUnwrap(frame["session"]?.value as? [String: Any])
        XCTAssertEqual(session["input_audio_format"] as? String, "pcm16")
        XCTAssertEqual(session["modalities"] as? [String], ["text", "audio"])
        XCTAssertNil(session["audio"])

        // The frame must be JSON-serialisable exactly as the socket sends it.
        let data = try JSONEncoder().encode(frame)
        XCTAssertNotNil(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Empty model → no model key, xAI frame.
        session = try XCTUnwrap(buildSessionUpdate(RealtimeConfig())["session"]?.value as? [String: Any])
        XCTAssertNil(session["model"])
        XCTAssertNotNil(session["audio"])
    }

    func testRealtimeConfigEncodesOnlySetOptionals() throws {
        XCTAssertEqual(try keys(RealtimeConfig()), ["instructions", "sample_rate", "voice"])
        let config = RealtimeConfig(voice: "Eve", instructions: "Be helpful.", sampleRate: 16000, tools: [["type": "function", "name": "get_weather"]], model: "grok-realtime-beta")
        let obj = try object(config)
        XCTAssertEqual(obj.keys.sorted(), ["instructions", "model", "sample_rate", "tools", "voice"])
        XCTAssertEqual((obj["tools"] as? [[String: Any]])?.count, 1)
    }

    func testRealtimeEventParsing() {
        if case .sessionReady = parseRealtimeEvent(#"{"type":"session.updated","session":{}}"#) {} else { XCTFail("sessionReady") }
        if case let .audioDelta(delta) = parseRealtimeEvent(#"{"type":"response.audio.delta","delta":"AQID"}"#) {
            XCTAssertEqual(delta, "AQID")
        } else { XCTFail("audioDelta") }
        if case let .transcriptDone(transcript, source) = parseRealtimeEvent(#"{"type":"conversation.item.input_audio_transcription.completed","transcript":"hello"}"#) {
            XCTAssertEqual(transcript, "hello")
            XCTAssertEqual(source, "input")
        } else { XCTFail("transcriptDone") }
        if case let .functionCall(name, callId, arguments) = parseRealtimeEvent(#"{"type":"response.function_call_arguments.done","name":"get_weather","call_id":"call_123","arguments":"{\"location\":\"London\"}"}"#) {
            XCTAssertEqual(name, "get_weather")
            XCTAssertEqual(callId, "call_123")
            XCTAssertTrue(arguments.contains("London"))
        } else { XCTFail("functionCall") }
        if case let .error(message) = parseRealtimeEvent(#"{"type":"error","error":{"message":"rate limited"}}"#) {
            XCTAssertEqual(message, "rate limited")
        } else { XCTFail("error") }
        if case .speechStarted = parseRealtimeEvent(#"{"type":"input_audio_buffer.speech_started"}"#) {} else { XCTFail("speechStarted") }
        if case .responseDone = parseRealtimeEvent(#"{"type":"response.done"}"#) {} else { XCTFail("responseDone") }
        if case .unknown = parseRealtimeEvent(#"{"type":"some.future.event","data":42}"#) {} else { XCTFail("unknown") }
        if case let .unknown(raw) = parseRealtimeEvent("not json") {
            XCTAssertEqual(raw.value as? String, "not json")
        } else { XCTFail("unknown text") }
    }

    func testWebSocketBaseDerivation() {
        XCTAssertEqual(QuantumClient.webSocketBase(from: "https://api.quantumencoding.ai"), "wss://api.quantumencoding.ai")
        XCTAssertEqual(QuantumClient.webSocketBase(from: "http://localhost:8080/"), "ws://localhost:8080")
    }

    func testGatewayErrorMapsBothEnvelopesAndStatusOnlyRefusals() {
        let nested = gatewayError(
            statusCode: 402,
            body: Data(#"{"error":{"message":"out of credits","type":"insufficient_balance","code":"INSUFFICIENT_BALANCE"}}"#.utf8),
            requestId: "req_1"
        )
        guard case let .api(status, code, message, requestId) = nested else { return XCTFail("expected api error") }
        XCTAssertEqual(status, 402)
        XCTAssertEqual(code, "INSUFFICIENT_BALANCE")
        XCTAssertEqual(message, "out of credits")
        XCTAssertEqual(requestId, "req_1")
        XCTAssertTrue(nested.isInsufficientBalance)

        // The proxy handlers write the flat form.
        let flat = gatewayError(statusCode: 401, body: Data(#"{"error":"unauthorized"}"#.utf8), requestId: nil)
        guard case let .api(_, flatCode, flatMessage, _) = flat else { return XCTFail("expected api error") }
        XCTAssertEqual(flatCode, "authentication_error")
        XCTAssertEqual(flatMessage, "unauthorized")
        XCTAssertTrue(flat.isAuth)

        // URLSessionWebSocketTask exposes no body: the status alone decides.
        let statusOnly = gatewayError(statusCode: 503, body: nil, requestId: nil)
        guard case let .api(_, soCode, _, _) = statusOnly else { return XCTFail("expected api error") }
        XCTAssertEqual(soCode, "service_unavailable")
    }
}

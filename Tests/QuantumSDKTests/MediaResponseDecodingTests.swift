import XCTest
@testable import QuantumSDK

/// Every touched response type decodes a fixture in its Go handler's shape,
/// including the `null` the gateway writes for an empty list.
final class MediaResponseDecodingTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: Null-list helper

    private struct Holder: Codable {
        @NullToEmpty var items: [String]
    }

    func testNullToEmptyHandlesNullMissingAndPresent() throws {
        XCTAssertEqual(try decode(Holder.self, #"{"items":null}"#).items, [])
        XCTAssertEqual(try decode(Holder.self, #"{}"#).items, [])
        XCTAssertEqual(try decode(Holder.self, #"{"items":["a","b"]}"#).items, ["a", "b"])
        XCTAssertThrowsError(try decode(Holder.self, #"{"items":"nope"}"#))

        let encoded = try JSONEncoder().encode(Holder(items: NullToEmpty(wrappedValue: ["x"])))
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #"{"items":["x"]}"#)
    }

    // MARK: Realtime session

    func testRealtimeSessionDecodesBothProviderShapesAndMasksCredentials() throws {
        let xai = try decode(RealtimeSession.self, #"{"session_id":"vs_1","ephemeral_token":"sk-secret","url":"wss://api.x.ai/v1/realtime","model":"grok-realtime-beta","voice":"Sal","expires_in":300,"expires_at":1}"#)
        XCTAssertEqual(xai.wsUrl, "wss://api.x.ai/v1/realtime")
        XCTAssertEqual(xai.provider, "")
        XCTAssertEqual(xai.ephemeralToken, "sk-secret")

        let eleven = try decode(RealtimeSession.self, #"{"session_id":"vs_2","signed_url":"wss://api.elevenlabs.io/v1/convai/conversation?token=secret","provider":"elevenlabs"}"#)
        XCTAssertEqual(eleven.provider, "elevenlabs")
        XCTAssertTrue(eleven.wsUrl.hasPrefix("wss://api.elevenlabs.io"))
        XCTAssertEqual(eleven.ephemeralToken, "")

        for text in [String(describing: xai), "\(xai)", xai.debugDescription, String(reflecting: xai)] {
            XCTAssertFalse(text.contains("sk-secret"), text)
            XCTAssertTrue(text.contains("vs_1"), text)
        }
        let mirrored = Mirror(reflecting: eleven).children.map { "\($0.value)" }.joined()
        XCTAssertFalse(mirrored.contains("token=secret"))
        XCTAssertFalse("\(eleven)".contains("token=secret"))
    }

    func testSttRealtimeTokenCarriesTheDirectEndpointAndMasks() throws {
        let resp = try decode(RealtimeSttTokenResponse.self, #"{"token":"tok_abc","expires_in":900,"ws_endpoint":"wss://api.elevenlabs.io/v1/speech-to-text/realtime","cost_ticks":6000000,"request_id":"req_1"}"#)
        XCTAssertEqual(resp.expiresIn, 900)
        XCTAssertTrue(resp.wsEndpoint.hasPrefix("wss://"))
        XCTAssertEqual(resp.costTicks, 6_000_000)
        XCTAssertFalse("\(resp)".contains("tok_abc"))
    }

    // MARK: Vision (per-profile omitempty)

    func testVisionDecodesEveryProfileShape() throws {
        // ocr profile: no tags, no objects, empty metadata omitted.
        let ocr = try decode(VisionResponse.self, #"{"ocr":{"text":"MAIN ST","overlays":[{"text":"MAIN ST","type":"label"}]},"model":"gemini-2.5-flash","cost_ticks":10,"request_id":"r"}"#)
        XCTAssertEqual(ocr.tags, [])
        XCTAssertEqual(ocr.objects, [])
        XCTAssertEqual(ocr.ocr?.overlays.first?.text, "MAIN ST")
        XCTAssertEqual(ocr.ocr?.metadata, [:])

        // quality profile with no issues.
        let quality = try decode(VisionResponse.self, #"{"quality":{"overall":"good","score":0.9,"blur":"none","darkness":"well_lit","resolution":"high","exposure":"correct"},"model":"m","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(quality.quality?.issues, [])

        // objects profile.
        let objects = try decode(VisionResponse.self, #"{"objects":[{"label":"duck","confidence":0.8,"bounding_box":[1,2,3,4]}],"model":"m","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(objects.objects.first?.boundingBox, [1, 2, 3, 4])

        // combined with empty relevance arrays omitted.
        let combined = try decode(VisionResponse.self, #"{"caption":"a duck","tags":["duck"],"relevance":{"relevant":true,"score":1},"model":"m","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(combined.relevance?.expectedItems, [])
        XCTAssertEqual(combined.relevance?.relevant, true)
    }

    // MARK: Jobs

    func testJobAcceptedDecodesBothProducers() throws {
        let created = try decode(JobAcceptedResponse.self, #"{"job_id":"qai_job_1","status":"pending","type":"3d/generate","created_at":"2026-09-05T10:00:00Z","request_id":"req_1"}"#)
        XCTAssertEqual(created.createdAt, "2026-09-05T10:00:00Z")
        let media = try decode(JobAcceptedResponse.self, #"{"job_id":"qai_job_2","status":"pending","type":"video/studio","request_id":"req_2"}"#)
        XCTAssertEqual(media.jobType, "video/studio")
        XCTAssertNil(media.createdAt)
        let alias: JobCreateResponse = created
        XCTAssertEqual(alias.jobId, "qai_job_1")
    }

    func testJobStatusDecodesWithoutCostTicksAndListToleratesNull() throws {
        let pending = try decode(JobStatusResponse.self, #"{"job_id":"j1","type":"chat","status":"running","created_at":"2026-09-05T10:00:00Z","request_id":"r1"}"#)
        XCTAssertEqual(pending.costTicks, 0)
        XCTAssertEqual(pending.status, "running")

        let list = try decode(JobListResponse.self, #"{"jobs":[{"job_id":"j1","type":"chat","status":"completed","cost_ticks":5,"result":{"text":"hi"}}],"request_id":"req_l"}"#)
        XCTAssertEqual(list.jobs[0].costTicks, 5)
        XCTAssertEqual(try decode(JobListResponse.self, #"{"jobs":null,"request_id":"req_e"}"#).jobs.count, 0)
    }

    func testStreamTimeoutIsDistinguishableFromFailure() throws {
        let timeout = try decode(JobStreamEvent.self, #"{"type":"error","error":"stream timeout (10 minutes)"}"#)
        XCTAssertTrue(timeout.isStreamTimeout)
        let failed = try decode(JobStreamEvent.self, #"{"type":"error","job_id":"j1","status":"failed","error":"boom"}"#)
        XCTAssertFalse(failed.isStreamTimeout)
        let progress = try decode(JobStreamEvent.self, #"{"type":"progress","job_id":"j1","status":"running"}"#)
        XCTAssertEqual(progress.eventType, "progress")
        XCTAssertEqual(progress.costTicks, 0)
    }

    // MARK: Batch

    func testBatchSubmitDecodesThe202EnvelopeAndNullJobIds() throws {
        let resp = try decode(BatchSubmitResponse.self, #"{"batch_id":"batch_2","jobs":2,"job_ids":["a","b"],"pricing":"50% of real-time rates","status":"queued"}"#)
        XCTAssertEqual(resp.jobIds, ["a", "b"])
        XCTAssertEqual(resp.jobs, 2)
        let none = try decode(BatchJsonlResponse.self, #"{"batch_id":"batch_0","jobs":0,"job_ids":null,"pricing":"","status":"queued"}"#)
        XCTAssertEqual(none.jobIds, [])
    }

    func testBatchJobDecodesTheStoreShape() throws {
        let job = try decode(BatchJobInfo.self, #"{"id":"abc123","priority":10,"type":"user_batch","title":"Batch 1/1: hi","prompt":"hi","model":"claude-sonnet-4-6","status":"complete","output":"hello","created_by":"user_1","created_at":"2026-09-05T10:00:00Z","started_at":"2026-09-05T10:00:05Z","completed_at":"2026-09-05T10:00:09Z","tokens":42}"#)
        XCTAssertEqual(job.id, "abc123")
        XCTAssertEqual(job.status, "complete")
        XCTAssertEqual(job.output, "hello")
        XCTAssertNil(job.outputGcs)
        XCTAssertEqual(job.tokens, 42)

        XCTAssertEqual(try decode(BatchJobsResponse.self, #"{"jobs":null}"#).jobs.count, 0)
        let queued = try decode(BatchJobInfo.self, #"{"id":"q","priority":10,"type":"user_batch","title":"t","prompt":"p","model":"m","status":"queued","created_by":"u","created_at":"2026-09-05T10:00:00Z"}"#)
        XCTAssertNil(queued.completedAt)
    }

    // MARK: Documents

    func testDocumentResponsesReadTheGatewayShape() throws {
        let extract = try decode(DocumentResponse.self, ##"{"markdown":"# Title","format":"markdown","meta":{"extraction_method":"pdf","images_found":1},"images":[{"name":"img0","mime":"image/png","data":"AAAA"}]}"##)
        XCTAssertEqual(extract.markdown, "# Title")
        XCTAssertEqual(extract.meta.imagesFound, 1)
        XCTAssertEqual(extract.images.count, 1)
        XCTAssertEqual(extract.costTicks, 0)

        let chunk = try decode(ChunkDocumentResponse.self, #"{"format":"markdown","meta":{"extraction_method":"docx","chunk_count":0},"chunks":null}"#)
        XCTAssertEqual(chunk.chunks, [])
        XCTAssertEqual(chunk.meta.extractionMethod, "docx")

        let process = try decode(ProcessDocumentResponse.self, #"{"markdown":"body","format":"markdown","meta":{"extraction_method":"pdf","chunk_count":1},"chunks":[{"index":0,"text":"body"}]}"#)
        XCTAssertEqual(process.chunks.first?.text, "body")
        XCTAssertEqual(process.images, [])
    }

    // MARK: Search

    func testWebSearchDecodesBravesEnvelope() throws {
        let json = #"""
        {"type":"search",
         "query":{"original":"ducks","altered":null,"spellcheck_off":true},
         "web":{"type":"search","results":[{"title":"Duck","url":"https://d.example","description":"A bird","age":"1 day ago","extra_snippets":["quack"],"meta_url":{"scheme":"https","netloc":"d.example","hostname":"d.example","favicon":"https://d.example/favicon.ico","path":"/"},"thumbnail":{"src":"https://d.example/t.png","height":100,"width":100}}]},
         "news":null,
         "videos":{"results":[{"title":"Duck video","url":"https://v.example","thumbnail":{"src":"https://v.example/t.jpg"}}]},
         "infobox":{"type":"entity","title":"Duck","long_desc":"Waterfowl","images":null},
         "discussions":{"results":[]}}
        """#
        let resp = try decode(WebSearchResponse.self, json)
        XCTAssertEqual(resp.query?.original, "ducks")
        XCTAssertEqual(resp.query?.spellcheckOff, true)
        XCTAssertEqual(resp.web.count, 1)
        XCTAssertEqual(resp.web[0].favicon, "https://d.example/favicon.ico")
        XCTAssertEqual(resp.web[0].extraSnippets, ["quack"])
        XCTAssertEqual(resp.web[0].thumbnail?.width, 100)
        XCTAssertEqual(resp.news.count, 0)
        XCTAssertEqual(resp.videos[0].thumbnail?.src, "https://v.example/t.jpg")
        XCTAssertEqual(resp.infobox?.kind, "entity")
        XCTAssertEqual(resp.infobox?.longDesc, "Waterfowl")
        XCTAssertEqual(resp.infobox?.images, [])
        XCTAssertEqual(resp.discussions.count, 0)

        let bare = try decode(WebSearchResponse.self, #"{"query":{"original":"x"}}"#)
        XCTAssertEqual(bare.web, [])
        XCTAssertNil(bare.infobox)
    }

    func testContextAnswerAndGoogleDecodeNullLists() throws {
        let ctx = try decode(SearchContextResponse.self, #"{"chunks":[{"content":"c","url":"https://x","title":"t","score":0.5,"content_type":"text/html"}],"sources":null,"query":"q"}"#)
        XCTAssertEqual(ctx.sources, [])
        XCTAssertEqual(ctx.chunks[0].score, 0.5)
        let alias: LLMContextResponse = ctx
        XCTAssertEqual(alias.query, "q")

        let answer = try decode(SearchAnswerResponse.self, #"{"choices":[{"index":0,"message":{"role":"assistant","content":"hi"},"finish_reason":"stop"}],"model":"brave","id":"a1","citations":null}"#)
        XCTAssertEqual(answer.citations, [])
        XCTAssertEqual(answer.choices[0].message?.content, "hi")

        let google = try decode(GoogleSearchResponse.self, #"{"answer":"Ducks float.","citations":[{"url":"https://g/1","title":"Ducks"}],"search_entry_point":"<div/>","web_search_queries":["do ducks float"],"supports":[{"start_index":0,"end_index":12,"text":"Ducks float.","grounding_chunk_indices":[0]}]}"#)
        XCTAssertEqual(google.webSearchQueries, ["do ducks float"])
        XCTAssertEqual(google.supports[0].groundingChunkIndices, [0])
        let empty = try decode(GoogleSearchResponse.self, #"{"answer":"","citations":null,"search_entry_point":"","web_search_queries":null,"supports":null}"#)
        XCTAssertEqual(empty.citations, [])
    }

    // MARK: Audio

    func testFinetuneShapesMatchElevenLabsStatus() throws {
        let list = try decode(ListFinetunesResponse.self, #"{"finetunes":[{"id":"ft_1","status":"training"},{"id":"ft_2","status":"ready","model_id":"music_v1_ft_2"}]}"#)
        XCTAssertEqual(list.finetunes.count, 2)
        XCTAssertEqual(list.finetunes[1].modelId, "music_v1_ft_2")
        let created = try decode(FinetuneInfo.self, #"{"id":"ft_3","status":"queued"}"#)
        XCTAssertNil(created.modelId)
        XCTAssertEqual(try decode(MusicFinetuneListResponse.self, #"{"finetunes":null}"#).finetunes.count, 0)
    }

    func testTypedAudioResponsesDecodeHandlerShapes() throws {
        let remix = try decode(RemixVoiceResponse.self, #"{"format":"mp3","size_bytes":0,"cost_ticks":3000000000,"request_id":"req_r","provenance":{"model":"eleven_voice_remix"}}"#)
        XCTAssertNil(remix.audioBase64)
        XCTAssertNil(remix.voiceId)

        let align = try decode(AlignResponse.self, #"{"alignment":[{"text":"hi","start_time":0.0,"end_time":0.4}],"model":"scribe","cost_ticks":1,"request_id":"req_a"}"#)
        XCTAssertEqual(align.alignment[0].endTime, 0.4)
        XCTAssertEqual(align.alignment[0].confidence, 0)

        let design = try decode(VoiceDesignResponse.self, #"{"previews":null,"cost_ticks":0,"request_id":""}"#)
        XCTAssertEqual(design.previews, [])

        let music = try decode(ElevenMusicResponse.self, #"{"clips":null,"model":"music_v1","cost_ticks":0,"request_id":"r","provenance":{}}"#)
        XCTAssertEqual(music.clips, [])
        let clips = try decode(MusicAdvancedResponse.self, #"{"clips":[{"base64":"AQID","format":"mp3","size":3}],"model":"music_v1","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(clips.clips[0].size, 3)

        let lyria = try decode(MusicResponse.self, #"{"audio_clips":null,"model":"lyria","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(lyria.audioClips, [])

        let starfish = try decode(StarfishTTSResponse.self, #"{"format":"mp3","size_bytes":10,"duration":1.5,"model":"heygen-starfish","cost_ticks":1,"request_id":"req_st","url":"https://x/a.mp3"}"#)
        XCTAssertEqual(starfish.url, "https://x/a.mp3")
        XCTAssertNil(starfish.audioBase64)
    }

    // MARK: Voices

    func testVoiceCatalogShapes() throws {
        let list = try decode(VoicesResponse.self, #"{"voices":[{"voice_id":"alloy","name":"alloy","category":"premade","provider":"openai","model":"openai-tts-1","is_cloned":false}],"request_id":"req_l"}"#)
        XCTAssertEqual(list.voices[0].model, "openai-tts-1")
        XCTAssertEqual(list.voices[0].category, "premade")
        XCTAssertEqual(try decode(VoicesResponse.self, #"{"voices":null}"#).voices.count, 0)

        let cloned = try decode(CloneVoiceResponse.self, #"{"voice_id":"v_new","name":"Me","request_id":"req_c"}"#)
        XCTAssertEqual(cloned.requestId, "req_c")

        let library = try decode(SharedVoicesResponse.self, #"{"voices":[{"public_owner_id":"o1","voice_id":"v1","name":"N","category":"professional","preview_url":"https://x/p.mp3","usage_character_count":10,"cloned_by_count":2,"rate":4.5,"free_users_allowed":true,"live_moderation_enabled":false}],"has_more":true,"last_sort_id":"cursor_2"}"#)
        XCTAssertEqual(library.lastSortId, "cursor_2")
        XCTAssertEqual(library.voices[0].usageCharacterCount, 10)
        let emptyLibrary = try decode(SharedVoicesResponse.self, #"{"voices":null,"has_more":false,"last_sort_id":""}"#)
        XCTAssertEqual(emptyLibrary.voices, [])

        let added = try decode(AddVoiceFromLibraryResponse.self, #"{"voice_id":"v9","status":"added"}"#)
        XCTAssertEqual(added.status, "added")
    }

    // MARK: HeyGen catalogs

    func testHeyGenCatalogTypesReadTheWireNames() throws {
        let avatars = try decode(AvatarsResponse.self, #"{"avatars":[{"avatar_id":"a1","avatar_name":"Anna","gender":"female","preview_image_url":"https://x/a.png","type":"studio_avatar"}],"request_id":"r"}"#)
        XCTAssertEqual(avatars.avatars[0].name, "Anna")
        XCTAssertEqual(avatars.avatars[0].previewUrl, "https://x/a.png")
        XCTAssertEqual(avatars.avatars[0].avatarType, "studio_avatar")
        XCTAssertEqual(try decode(AvatarsResponse.self, #"{"avatars":null,"request_id":"r"}"#).avatars.count, 0)

        let templates = try decode(VideoTemplatesResponse.self, #"{"templates":[{"template_id":"t1","name":"Promo","thumbnail_image_url":"https://x/t.png"}],"request_id":"r"}"#)
        XCTAssertEqual(templates.templates[0].thumbnailUrl, "https://x/t.png")

        let voices = try decode(HeyGenVoicesResponse.self, #"{"voices":[{"voice_id":"v1","display_name":"Ava","language":"en","gender":"female","preview_audio":"https://x/v.mp3"}],"request_id":"r"}"#)
        XCTAssertEqual(voices.voices[0].name, "Ava")
        XCTAssertEqual(voices.voices[0].previewUrl, "https://x/v.mp3")
    }

    func testDigitalTwinCreateAndVideoResponses() throws {
        let twin = try decode(DigitalTwinCreateResponse.self, #"{"name":"Rich","consent_url":"https://heygen/consent/1","model":"heygen-digital-twin","request_id":"req_t","group_id":"grp_1","status":"pending","consent_status":"not_started","avatar_id":"look_1"}"#)
        XCTAssertEqual(twin.groupId, "grp_1")
        XCTAssertEqual(twin.model, "heygen-digital-twin")

        let video = try decode(VideoResponse.self, #"{"videos":[{"base64":"AAAA","format":"mp4","size_bytes":4,"index":0}],"model":"veo-2","cost_ticks":9,"request_id":"r"}"#)
        XCTAssertEqual(video.videos[0].format, "mp4")
        XCTAssertEqual(try decode(VideoResponse.self, #"{"videos":null,"model":"veo-2"}"#).videos.count, 0)

        let image = try decode(ImageResponse.self, #"{"images":[{"base64":"AAAA","format":"png","index":0}],"model":"gpt-image-1","cost_ticks":1,"request_id":"r"}"#)
        XCTAssertEqual(image.images[0].format, "png")
        XCTAssertNil(image.balanceAfter)
    }

    // MARK: Media sessions / files / caches

    func testMediaSessionShapes() throws {
        let session = try decode(MediaSession.self, #"{"id":"s1","file_uri":"files/a","mime_type":"video/mp4","cache_name":"cachedContents/x","model":"gemini-3.1-flash-lite","history":null,"message_count":0,"created_at":"2026-01-01T00:00:00Z"}"#)
        XCTAssertEqual(session.id, "s1")
        XCTAssertEqual(session.history, [])
        XCTAssertEqual(session.cacheTokenCount, 0)

        let chat = try decode(MediaSessionChatResponse.self, #"{"session_id":"s1","answer":"it is a duck","usage":{"input_tokens":10,"output_tokens":4,"cost_ticks":7},"history":[{"role":"user","content":"what is it?","at":"2026-01-01T00:00:00Z"}]}"#)
        XCTAssertEqual(chat.answer, "it is a duck")
        XCTAssertEqual(chat.history.count, 1)
        XCTAssertEqual(chat.usage?.costTicks, 7)

        XCTAssertEqual(try decode(MediaSessionListResponse.self, #"{"sessions":null}"#).sessions.count, 0)
        let deleted = try decode(MediaSessionDeleteResponse.self, #"{"deleted":true,"note":"already absent"}"#)
        XCTAssertTrue(deleted.deleted)
        XCTAssertEqual(deleted.note, "already absent")
    }

    func testFileUploadAndCacheShapes() throws {
        let file = try decode(FileUploadResponse.self, #"{"file_uri":"https://generativelanguage.googleapis.com/v1beta/files/abc","name":"files/abc","mime_type":"application/pdf","size_bytes":4096}"#)
        XCTAssertEqual(file.name, "files/abc")
        XCTAssertEqual(file.durationSeconds, 0)
        XCTAssertEqual(file.expiresAt, "")

        let cache = try decode(CacheCreateResponse.self, #"{"cache_name":"cachedContents/x","model":"gemini-3.1-flash-lite","expires_at":"2026-01-01T01:00:00Z","display_name":"clip","token_count":5000}"#)
        XCTAssertEqual(cache.tokenCount, 5000)
        let released = try decode(CacheDeleteResponse.self, #"{"deleted":true,"note":"already expired or unknown"}"#)
        XCTAssertEqual(released.note, "already expired or unknown")
    }
}

extension DetectedObject: Equatable {
    public static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
        lhs.label == rhs.label && lhs.confidence == rhs.confidence && lhs.boundingBox == rhs.boundingBox
    }
}

extension DocumentChunk: Equatable {
    public static func == (lhs: DocumentChunk, rhs: DocumentChunk) -> Bool {
        lhs.index == rhs.index && lhs.text == rhs.text
    }
}

extension DocumentImage: Equatable {
    public static func == (lhs: DocumentImage, rhs: DocumentImage) -> Bool {
        lhs.name == rhs.name && lhs.mime == rhs.mime && lhs.data == rhs.data
    }
}

extension WebResult: Equatable {
    public static func == (lhs: WebResult, rhs: WebResult) -> Bool { lhs.url == rhs.url }
}

extension Thumbnail: Equatable {
    public static func == (lhs: Thumbnail, rhs: Thumbnail) -> Bool { lhs.src == rhs.src }
}

extension SearchContextSource: Equatable {
    public static func == (lhs: SearchContextSource, rhs: SearchContextSource) -> Bool { lhs.url == rhs.url }
}

extension SearchAnswerCitation: Equatable {
    public static func == (lhs: SearchAnswerCitation, rhs: SearchAnswerCitation) -> Bool { lhs.url == rhs.url }
}

extension GoogleSearchCitation: Equatable {
    public static func == (lhs: GoogleSearchCitation, rhs: GoogleSearchCitation) -> Bool { lhs.url == rhs.url }
}

extension VoicePreview: Equatable {
    public static func == (lhs: VoicePreview, rhs: VoicePreview) -> Bool { lhs.generatedVoiceId == rhs.generatedVoiceId }
}

extension ElevenMusicClip: Equatable {
    public static func == (lhs: ElevenMusicClip, rhs: ElevenMusicClip) -> Bool { lhs.base64 == rhs.base64 }
}

extension MusicClip: Equatable {
    public static func == (lhs: MusicClip, rhs: MusicClip) -> Bool { lhs.base64 == rhs.base64 }
}

extension SharedVoice: Equatable {
    public static func == (lhs: SharedVoice, rhs: SharedVoice) -> Bool { lhs.voiceId == rhs.voiceId }
}

extension MediaSessionTurn: Equatable {
    public static func == (lhs: MediaSessionTurn, rhs: MediaSessionTurn) -> Bool {
        lhs.role == rhs.role && lhs.content == rhs.content
    }
}

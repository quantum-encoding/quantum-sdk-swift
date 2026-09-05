import Foundation

// Image, audio, video, voice, documents, search, jobs, batch and realtime
// token routes.
extension QuantumClient {
    // MARK: - Image

    /// Generate images from a text prompt.
    ///
    /// - Parameters:
    ///   - model: Model for image generation (e.g. "grok-imagine-image", "dall-e-3").
    ///   - prompt: Text prompt describing the image.
    ///   - n: Number of images to generate.
    ///   - size: Image size (e.g. "1024x1024").
    ///   - aspectRatio: Aspect ratio (e.g. "16:9", "1:1"). Gemini/Imagen honour this.
    ///   - quality: Quality level (e.g. "standard", "hd").
    ///   - outputFormat: Output image format (e.g. "png", "jpeg", "webp").
    ///   - compression: JPEG/WebP quality 0-100 (GPT-Image). Sent only when non-nil.
    ///   - style: DALL-E 3 preset — "vivid" or "natural". Sent only when non-nil.
    ///   - background: Background mode — "transparent", "opaque", or "auto".
    ///     GPT-Image (gpt-image-1) honours this; other providers ignore it.
    ///     Sent only when non-nil.
    ///   - seed: Deterministic seed (provider support varies). Sent only when non-nil.
    ///   - cfgScale: Classifier-free guidance scale (provider support varies).
    ///     Sent only when non-nil.
    /// - Returns: The image response with URLs or base64 data.
    public func generateImage(
        model: String,
        prompt: String,
        n: Int? = nil,
        size: String? = nil,
        aspectRatio: String? = nil,
        quality: String? = nil,
        outputFormat: String? = nil,
        compression: Int? = nil,
        style: String? = nil,
        background: String? = nil,
        seed: Int? = nil,
        cfgScale: Double? = nil,
        idempotencyKey: String? = nil
    ) async throws -> ImageResponse {
        let request = ImageRequest(
            model: model,
            prompt: prompt,
            count: n,
            size: size,
            aspectRatio: aspectRatio,
            quality: quality,
            outputFormat: outputFormat,
            compression: compression,
            style: style,
            background: background,
            seed: seed,
            cfgScale: cfgScale
        )
        return try await generateImage(request, idempotencyKey: idempotencyKey)
    }

    /// Generate images from a fully-specified ``ImageRequest``.
    ///
    /// Use this when you want to thread an arbitrary parameter set — e.g. one
    /// built from a model's parameter schema (`GET /qai/v1/models`) — or provider
    /// params the convenience overload doesn't surface (Meshy image-to-3D fields).
    public func generateImage(_ request: ImageRequest, idempotencyKey: String? = nil) async throws -> ImageResponse {
        let (data, _): (ImageResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/images/generate", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Edit images using an AI model.
    public func editImage(_ request: ImageEditRequest, idempotencyKey: String? = nil) async throws -> ImageEditResponse {
        let (data, _): (ImageEditResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/images/edit", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    // MARK: - Audio: TTS

    /// Generate speech from text.
    ///
    /// - Parameters:
    ///   - text: Text to speak.
    ///   - model: TTS model.
    ///   - voice: Voice ID.
    ///   - outputFormat: Output format (e.g. "mp3", "wav").
    ///   - speed: Speaking speed.
    ///   - instructions: Voice-steering (tone/emotion/accent). gpt-4o-mini-tts
    ///     only; the backend drops it for tts-1/tts-1-hd.
    /// - Returns: The TTS response with audio URL.
    public func speak(
        text: String,
        model: String,
        voice: String? = nil,
        outputFormat: String? = nil,
        speed: Double? = nil,
        instructions: String? = nil,
        voiceSettings: TTSVoiceSettings? = nil,
        idempotencyKey: String? = nil
    ) async throws -> TTSResponse {
        let request = TTSRequest(model: model, text: text, voice: voice, outputFormat: outputFormat, speed: speed, instructions: instructions, voiceSettings: voiceSettings)
        let (data, _): (TTSResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/tts", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    // MARK: - Audio: STT

    /// Convert speech to text.
    ///
    /// - Parameters:
    ///   - audioBase64: Base64-encoded audio data.
    ///   - model: STT model.
    ///   - filename: Original filename (helps with format detection).
    ///   - language: BCP-47 language code.
    /// - Returns: The transcription response.
    public func transcribe(
        audioBase64: String,
        model: String,
        filename: String? = nil,
        language: String? = nil,
        idempotencyKey: String? = nil
    ) async throws -> STTResponse {
        let request = STTRequest(model: model, audioBase64: audioBase64, filename: filename, language: language)
        let (data, _): (STTResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/stt", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    // MARK: - Audio: Sound Effects

    /// Generate sound effects from a text prompt (ElevenLabs).
    public func soundEffects(_ request: SoundEffectRequest) async throws -> SoundEffectResponse {
        let (data, _): (SoundEffectResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/sound-effects", body: request
        )
        return data
    }

    // MARK: - Audio: Music

    /// Generate music from a text prompt.
    public func generateMusic(prompt: String, durationSeconds: Int? = nil, model: String, idempotencyKey: String? = nil) async throws -> MusicResponse {
        let request = MusicRequest(model: model, prompt: prompt, durationSeconds: durationSeconds)
        let (data, _): (MusicResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/music", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Generate music via the advanced endpoint (ElevenLabs, finetunes).
    public func generateMusicAdvanced(_ request: MusicAdvancedRequest) async throws -> MusicAdvancedResponse {
        let (data, _): (MusicAdvancedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/music/advanced", body: request
        )
        return data
    }

    /// Generate music via the advanced endpoint with the full Eleven Music
    /// surface — sections (composition plan), vocals toggle, global styles,
    /// and finetunes.
    public func generateElevenMusic(_ request: ElevenMusicRequest) async throws -> ElevenMusicResponse {
        let (data, _): (ElevenMusicResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/music/advanced", body: request
        )
        return data
    }

    // MARK: - Audio: Dialogue

    /// Generate multi-speaker dialogue audio (ElevenLabs).
    public func dialogue(_ request: DialogueRequest) async throws -> DialogueResponse {
        let (data, _): (DialogueResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/dialogue", body: request
        )
        return data
    }

    // MARK: - Audio: Speech to Speech

    /// Convert speech audio to a different voice (ElevenLabs).
    public func speechToSpeech(_ request: SpeechToSpeechRequest) async throws -> SpeechToSpeechResponse {
        let (data, _): (SpeechToSpeechResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/speech-to-speech", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Isolation

    /// Remove background noise and isolate speech (ElevenLabs).
    public func isolateVoice(audioBase64: String) async throws -> IsolateVoiceResponse {
        let request = IsolateVoiceRequest(audioBase64: audioBase64)
        let (data, _): (IsolateVoiceResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/isolate", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Remix

    /// Transform a voice by modifying attributes (ElevenLabs).
    public func remixVoice(_ request: RemixVoiceRequest) async throws -> RemixVoiceResponse {
        let (data, _): (RemixVoiceResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/remix", body: request
        )
        return data
    }

    // MARK: - Audio: Dubbing

    /// Dub audio/video into a target language (ElevenLabs).
    public func dub(_ request: DubRequest) async throws -> DubResponse {
        let (data, _): (DubResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/dub", body: request
        )
        return data
    }

    // MARK: - Audio: Alignment

    /// Get word-level timestamps for audio+text alignment (ElevenLabs).
    public func align(_ request: AlignRequest) async throws -> AlignResponse {
        let (data, _): (AlignResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/align", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Design

    /// Save a voice-design preview as a permanent account voice.
    /// Completes the two-step design flow: ``voiceDesign(_:)`` returns previews
    /// (each with a `generatedVoiceId`); this persists the chosen one.
    public func saveDesignedVoice(generatedVoiceId: String, name: String, description: String? = nil) async throws -> SavedDesignedVoice {
        struct Body: Codable {
            let generatedVoiceId: String
            let name: String
            let description: String?
            enum CodingKeys: String, CodingKey {
                case name, description
                case generatedVoiceId = "generated_voice_id"
            }
        }
        let (data, _): (SavedDesignedVoice, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/voice-design/save",
            body: Body(generatedVoiceId: generatedVoiceId, name: name, description: description)
        )
        return data
    }

    /// Generate voice previews from a text description (ElevenLabs).
    public func voiceDesign(_ request: VoiceDesignRequest) async throws -> VoiceDesignResponse {
        let (data, _): (VoiceDesignResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/voice-design", body: request
        )
        return data
    }

    // MARK: - Audio: Starfish TTS

    /// Generate speech using HeyGen's Starfish TTS model.
    public func starfishTTS(_ request: StarfishTTSRequest) async throws -> StarfishTTSResponse {
        let (data, _): (StarfishTTSResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/starfish-tts", body: request
        )
        return data
    }

    // MARK: - Audio: Finetunes

    /// Poll one music finetune's training status. When status == "complete",
    /// modelId carries the usable model identifier for generation.
    public func getFinetune(id: String) async throws -> MusicFinetuneStatus {
        let (data, _): (MusicFinetuneStatus, _) = try await doReq(
            method: "GET", path: "/qai/v1/audio/finetunes/\(id)"
        )
        return data
    }

    /// List all music finetunes.
    public func listFinetunes() async throws -> MusicFinetuneListResponse {
        let (data, _): (MusicFinetuneListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/audio/finetunes"
        )
        return data
    }

    /// Create a new music finetune from audio samples.
    public func createFinetune(_ request: MusicFinetuneCreateRequest) async throws -> MusicFinetuneInfo {
        let (data, _): (MusicFinetuneInfo, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/finetunes", body: request
        )
        return data
    }

    /// Delete a music finetune by ID.
    public func deleteFinetune(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/audio/finetunes/\(id)"
        )
        return data
    }

    // MARK: - Video

    /// Generate a video from a text prompt.
    ///
    /// Video generation is slow (30s-5min). For production use, consider
    /// submitting via the Jobs API instead.
    public func generateVideo(
        model: String,
        prompt: String,
        durationSeconds: Int? = nil,
        aspectRatio: String? = nil,
        idempotencyKey: String? = nil
    ) async throws -> VideoResponse {
        let request = VideoRequest(model: model, prompt: prompt, durationSeconds: durationSeconds, aspectRatio: aspectRatio)
        let (data, _): (VideoResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/video/generate", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Create a talking-head video via HeyGen Studio. Returns an async job.
    public func videoStudio(_ request: VideoStudioRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/video/studio", body: request
        )
        return data
    }

    /// Submit a video translation job via HeyGen. Returns an async job.
    public func videoTranslate(_ request: VideoTranslateRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/video/translate", body: request
        )
        return data
    }

    /// Create a photo avatar via HeyGen. Returns an async job.
    public func videoPhotoAvatar(photoBase64: String, script: String) async throws -> JobAcceptedResponse {
        try await videoPhotoAvatar(PhotoAvatarRequest(photoBase64: photoBase64, script: script))
    }

    /// Create a photo avatar via HeyGen from a full request (carries the
    /// optional `voiceId` / `aspectRatio`). Returns an async job.
    public func videoPhotoAvatar(_ request: PhotoAvatarRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/video/photo-avatar", body: request
        )
        return data
    }

    /// Render a video of a trained twin avatar. Returns an async job.
    ///
    /// Forwards to ``twinVideo(_:)`` (`/qai/v1/video/twin-video`). Twin
    /// creation is ``createDigitalTwin(name:footage:filename:contentType:avatarGroupId:)``;
    /// `/qai/v1/video/digital-twin` trains a twin and does not render one.
    @available(*, deprecated, renamed: "twinVideo(_:)")
    public func videoDigitalTwin(avatarId: String, script: String) async throws -> JobAcceptedResponse {
        try await videoDigitalTwin(DigitalTwinRequest(avatarId: avatarId, script: script))
    }

    /// Render a video of a trained twin avatar from a full request (carries
    /// the optional `voiceId` / `aspectRatio`). Returns an async job.
    @available(*, deprecated, renamed: "twinVideo(_:)")
    public func videoDigitalTwin(_ request: DigitalTwinRequest) async throws -> JobAcceptedResponse {
        try await twinVideo(TwinVideoRequest(
            avatarId: request.avatarId,
            script: request.script,
            voiceId: request.voiceId,
            aspectRatio: request.aspectRatio
        ))
    }

    /// List available HeyGen avatars.
    public func videoAvatars() async throws -> AvatarsResponse {
        let (data, _): (AvatarsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/video/avatars"
        )
        return data
    }

    /// List available HeyGen templates.
    public func videoTemplates() async throws -> HeyGenTemplatesResponse {
        let (data, _): (HeyGenTemplatesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/video/templates"
        )
        return data
    }

    /// List available HeyGen voices.
    public func videoHeygenVoices() async throws -> HeyGenVoicesResponse {
        let (data, _): (HeyGenVoicesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/video/heygen-voices"
        )
        return data
    }

    // MARK: - Embeddings

    /// Generate text embeddings for the given input.
    ///
    /// - Parameters:
    ///   - input: Text to embed.
    ///   - model: Embedding model.
    /// - Returns: The embedding response with vectors.
    public func embed(input: String, model: String? = nil) async throws -> EmbedResponse {
        let request = EmbedRequest(input: input, model: model)
        let (data, _): (EmbedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/embeddings", body: request
        )
        return data
    }

    /// Generate text embeddings for multiple inputs.
    public func embed(inputs: [String], model: String? = nil) async throws -> EmbedResponse {
        let request = EmbedRequest(inputs: inputs, model: model)
        let (data, _): (EmbedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/embeddings", body: request
        )
        return data
    }

    // MARK: - Documents

    /// Extract text content from a document (PDF, image, etc.).
    public func extractDocument(_ request: DocumentRequest) async throws -> DocumentResponse {
        let (data, _): (DocumentResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/documents/extract", body: request
        )
        return data
    }

    /// Chunk a document into smaller pieces for embedding or processing.
    public func chunkDocument(_ request: ChunkDocumentRequest) async throws -> ChunkDocumentResponse {
        let (data, _): (ChunkDocumentResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/documents/chunk", body: request
        )
        return data
    }

    /// Process a document with extraction + optional instructions.
    public func processDocument(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse {
        let (data, _): (ProcessDocumentResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/documents/process", body: request
        )
        return data
    }

    // MARK: - Search (Brave)

    /// Perform a web search. Returns web results, news, videos, infobox, discussions.
    public func webSearch(_ request: WebSearchRequest) async throws -> WebSearchResponse {
        let (data, _): (WebSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/search/web", body: request
        )
        return data
    }

    /// Get LLM-optimized content chunks for grounding.
    public func searchContext(_ request: SearchContextRequest) async throws -> SearchContextResponse {
        let (data, _): (SearchContextResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/search/context", body: request
        )
        return data
    }

    /// Get a grounded AI answer with citations.
    public func searchAnswer(_ request: SearchAnswerRequest) async throws -> SearchAnswerResponse {
        let (data, _): (SearchAnswerResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/search/answer", body: request
        )
        return data
    }

    // MARK: - Jobs

    /// Create an async job. Returns the job ID for polling.
    public func createJob(type: String, params: [String: AnyCodable], idempotencyKey: String? = nil) async throws -> JobCreateResponse {
        let request = JobCreateRequest(jobType: type, params: AnyCodable(params))
        let (data, _): (JobCreateResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/jobs", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Check the status of an async job.
    public func getJob(jobId: String) async throws -> JobStatusResponse {
        let (data, _): (JobStatusResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/jobs/\(jobId)"
        )
        return data
    }

    /// Poll a job until completion or timeout.
    ///
    /// - Parameters:
    ///   - jobId: Job ID to poll.
    ///   - interval: Polling interval (default 2 seconds).
    ///   - maxAttempts: Maximum poll attempts before timeout (default 150).
    /// - Returns: The final job status.
    public func pollJob(
        jobId: String,
        interval: TimeInterval = 2.0,
        maxAttempts: Int = 150
    ) async throws -> JobStatusResponse {
        for _ in 0..<maxAttempts {
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            let status = try await getJob(jobId: jobId)
            if status.status == "completed" || status.status == "failed" {
                return status
            }
        }

        return JobStatusResponse(
            jobId: jobId,
            status: "timeout",
            result: nil,
            error: "Job polling timed out after \(maxAttempts) attempts",
            costTicks: 0
        )
    }

    /// List all jobs for the authenticated user.
    public func listJobs() async throws -> JobListResponse {
        let (data, _): (JobListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/jobs"
        )
        return data
    }

    /// Submit a 3D generation job.
    public func generate3D(model: String, prompt: String? = nil, imageUrl: String? = nil) async throws -> JobCreateResponse {
        var params: [String: AnyCodable] = ["model": AnyCodable(model)]
        if let prompt { params["prompt"] = AnyCodable(prompt) }
        if let imageUrl { params["image_url"] = AnyCodable(imageUrl) }
        return try await createJob(type: "3d/generate", params: params)
    }

    // MARK: - Voice Management

    /// List all available voices (ElevenLabs).
    public func listVoices() async throws -> VoicesResponse {
        let (data, _): (VoicesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/voices"
        )
        return data
    }

    /// Create an instant voice clone from audio samples (ElevenLabs).
    public func cloneVoice(_ request: CloneVoiceRequest) async throws -> CloneVoiceResponse {
        let (data, _): (CloneVoiceResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/voices/clone", body: request
        )
        return data
    }

    /// Delete a cloned voice (ElevenLabs).
    public func deleteVoice(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/voices/\(id)"
        )
        return data
    }

    /// Browse the shared voice library with optional filters.
    public func voiceLibrary(query: VoiceLibraryQuery? = nil) async throws -> SharedVoicesResponse {
        var params: [String] = []
        if let q = query?.query { params.append("query=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let ps = query?.pageSize { params.append("page_size=\(ps)") }
        if let c = query?.cursor { params.append("cursor=\(c)") }
        if let g = query?.gender { params.append("gender=\(g)") }
        if let l = query?.language { params.append("language=\(l)") }
        if let u = query?.useCase { params.append("use_case=\(u)") }

        var path = "/qai/v1/voices/library"
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }

        let (data, _): (SharedVoicesResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Add a shared voice from the library to the user's account.
    public func addVoiceFromLibrary(_ request: AddVoiceFromLibraryRequest) async throws -> AddVoiceFromLibraryResponse {
        let (data, _): (AddVoiceFromLibraryResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/voices/library/add", body: request
        )
        return data
    }

    // MARK: - Realtime Voice

    /// Request an ephemeral token for direct voice connection.
    ///
    /// - Parameter provider: Optional provider ("xai" default, "elevenlabs").
    /// - Returns: Session info with token and WebSocket URL.
    public func realtimeSession(provider: String? = nil) async throws -> RealtimeSession {
        var body: [String: AnyCodable] = [:]
        if let provider { body["provider"] = AnyCodable(provider) }

        struct Wrapper: Encodable {
            let body: [String: AnyCodable]
            func encode(to encoder: Encoder) throws {
                try body.encode(to: encoder)
            }
        }

        let (data, _): (RealtimeSession, _) = try await doReq(
            method: "POST", path: "/qai/v1/realtime/session", body: Wrapper(body: body)
        )
        return data
    }

    /// End a realtime session and finalize billing.
    public func realtimeEnd(sessionId: String, durationSeconds: Double) async throws {
        struct Body: Encodable {
            let session_id: String
            let duration_seconds: Double
        }
        let _: (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/realtime/end",
            body: Body(session_id: sessionId, duration_seconds: durationSeconds)
        )
    }

    /// Refresh an ephemeral token for long sessions (>4 min).
    public func realtimeRefresh(sessionId: String) async throws -> String {
        struct Body: Encodable { let session_id: String }
        struct Response: Decodable { let ephemeral_token: String }

        let (data, _): (Response, _) = try await doReq(
            method: "POST", path: "/qai/v1/realtime/refresh",
            body: Body(session_id: sessionId)
        )
        return data.ephemeral_token
    }

    // MARK: - Batch Processing

    /// Submit a batch of jobs for processing.
    public func batchSubmit(_ request: BatchSubmitRequest) async throws -> BatchSubmitResponse {
        let (data, _): (BatchSubmitResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/batch", body: request
        )
        return data
    }

    /// Submit a batch of jobs using JSONL format.
    public func batchSubmitJsonl(_ jsonl: String) async throws -> BatchJsonlResponse {
        struct Body: Encodable { let jsonl: String }
        let (data, _): (BatchJsonlResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/batch/jsonl", body: Body(jsonl: jsonl)
        )
        return data
    }

    /// List all batch jobs for the account.
    public func batchJobs() async throws -> BatchJobsResponse {
        let (data, _): (BatchJobsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/batch/jobs"
        )
        return data
    }

    /// Get the status and result of a single batch job.
    public func batchJob(id: String) async throws -> BatchJobInfo {
        let (data, _): (BatchJobInfo, _) = try await doReq(
            method: "GET", path: "/qai/v1/batch/jobs/\(id)"
        )
        return data
    }

    // MARK: - Job SSE Streaming

    /// Stream job events via SSE. Yields events as the job progresses.
    ///
    /// ```swift
    /// let job = try await client.createJob(type: "3d/generate", params: ["model": "meshy-6", "prompt": "a sword"])
    /// for try await event in client.streamJob(jobId: job.jobId) {
    ///     print(event.type, event.status)
    /// }
    /// ```
    public func streamJob(jobId: String) -> AsyncThrowingStream<JobStreamEvent, any Error> {
        struct Body: Encodable { let job_id: String }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await http.doStreamRequest(
                        path: "/qai/v1/jobs/\(jobId)/stream",
                        body: Body(job_id: jobId)
                    )
                    let parser = SSEParser(bytes: bytes)

                    for try await sseEvent in parser {
                        switch sseEvent {
                        case .done:
                            continuation.finish()
                            return
                        case let .data(data):
                            let event = try JSONDecoder().decode(JobStreamEvent.self, from: data)
                            continuation.yield(event)
                        case let .error(message):
                            continuation.finish(throwing: QuantumError.streamError(message))
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

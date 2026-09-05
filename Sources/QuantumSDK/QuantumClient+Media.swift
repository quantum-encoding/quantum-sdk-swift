import Foundation

// Image, audio, video, voice, documents, search, jobs, batch and realtime
// token routes.
extension QuantumClient {
    // MARK: - Shared helpers

    /// Multipart chokepoint that records response meta into
    /// ``lastResponseMeta`` like ``doReq`` does for JSON calls.
    func doMultipartReq<T: Decodable>(
        path: String,
        fieldName: String,
        filename: String,
        data: Data,
        contentType: String,
        fields: [String: String] = [:]
    ) async throws -> (data: T, meta: HTTPClient.ResponseMeta) {
        let pair: (data: T, meta: HTTPClient.ResponseMeta) = try await http.doMultipart(
            path: path, fieldName: fieldName, filename: filename,
            data: data, contentType: contentType, fields: fields
        )
        _ = recordMeta(pair.meta)
        return pair
    }

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
    ///   - seed: Sent as `seed`; the gateway does not read it today (see
    ///     ``ImageRequest/seed``).
    ///   - cfgScale: Sent as `cfg_scale`; the gateway does not read it today
    ///     (see ``ImageRequest/cfgScale``).
    /// - Returns: The image response with base64 image data.
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
        let (data, meta): (ImageResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/images/generate", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return Self.backfill(data, meta)
    }

    /// Edit images using an AI model.
    public func editImage(_ request: ImageEditRequest, idempotencyKey: String? = nil) async throws -> ImageEditResponse {
        let (data, meta): (ImageEditResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/images/edit", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return Self.backfill(data, meta)
    }

    private static func backfill(_ response: ImageResponse, _ meta: HTTPClient.ResponseMeta) -> ImageResponse {
        var r = response
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.balanceAfter == nil { r.balanceAfter = meta.balanceAfter }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
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
    /// - Returns: The TTS response with base64 audio.
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

    /// Mint a token for a realtime speech-to-text WebSocket (ElevenLabs
    /// Scribe). The client then connects straight to
    /// ``RealtimeSttTokenResponse/wsEndpoint`` with `?token=<token>`.
    /// Billed flat at mint; see ``RealtimeSttTokenResponse``.
    ///
    /// `POST /qai/v1/audio/stt/realtime-token`
    public func audioSTTRealtimeToken() async throws -> RealtimeSttTokenResponse {
        let (data, meta): (RealtimeSttTokenResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/audio/stt/realtime-token"
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
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

    /// Generate music via the advanced endpoint (ElevenLabs Eleven Music:
    /// sections, vocals toggle, global styles, finetunes). Editing an earlier
    /// generation is not supported on this route.
    public func generateMusicAdvanced(_ request: ElevenMusicRequest) async throws -> ElevenMusicResponse {
        let (data, meta): (ElevenMusicResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/audio/music/advanced", body: request
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Same route as ``generateMusicAdvanced(_:)``, kept under its original
    /// name.
    public func generateElevenMusic(_ request: ElevenMusicRequest) async throws -> ElevenMusicResponse {
        try await generateMusicAdvanced(request)
    }

    // MARK: - Audio: Dialogue

    /// Generate multi-speaker dialogue audio (ElevenLabs). Billed per
    /// character of the script.
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
    public func isolateVoice(_ request: IsolateVoiceRequest) async throws -> IsolateVoiceResponse {
        let (data, _): (IsolateVoiceResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/isolate", body: request
        )
        return data
    }

    /// Remove background noise and isolate speech (ElevenLabs).
    public func isolateVoice(audioBase64: String, filename: String? = nil) async throws -> IsolateVoiceResponse {
        try await isolateVoice(IsolateVoiceRequest(audioBase64: audioBase64, filename: filename))
    }

    // MARK: - Audio: Voice Remix

    /// Remix a voice recording towards the requested attributes (ElevenLabs).
    /// Flat per-request charge whether or not any attribute is set.
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
    /// `modelId` carries the usable model identifier for generation.
    ///
    /// Only the caller's own finetunes are readable. ElevenLabs is the only
    /// provider with music finetunes, so another provider's account gets a
    /// `provider_error`.
    ///
    /// `GET /qai/v1/audio/finetunes/{id}`
    public func getFinetune(id: String) async throws -> FinetuneInfo {
        let (data, _): (FinetuneInfo, _) = try await doReq(
            method: "GET", path: "/qai/v1/audio/finetunes/\(id)"
        )
        return data
    }

    /// List the music finetunes on the account.
    public func listFinetunes() async throws -> ListFinetunesResponse {
        let (data, _): (ListFinetunesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/audio/finetunes"
        )
        return data
    }

    /// Create a music finetune from base64 audio samples. Answers 201 with
    /// the finetune's `id` and initial `status`; training is asynchronous, so
    /// `modelId` is empty until ``listFinetunes()`` reports it.
    public func createFinetune(_ request: MusicFinetuneCreateRequest) async throws -> FinetuneInfo {
        let (data, _): (FinetuneInfo, _) = try await doReq(
            method: "POST", path: "/qai/v1/audio/finetunes", body: request
        )
        return data
    }

    /// Delete a music finetune by ID (`{"status":"deleted"}`; 404 when
    /// unknown, 403 when owned by another account).
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
        let (data, meta): (VideoResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/video/generate", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.balanceAfter == nil { r.balanceAfter = meta.balanceAfter }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Create a HeyGen studio talking-head video (async job type
    /// "video/studio"). Poll the returned job id for the result.
    public func videoStudio(_ request: VideoStudioRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/video/studio", body: request
        )
        return data
    }

    /// Translate a video into another language (HeyGen; async job type
    /// "video/translate"). A flat hold is taken at submit and trued up when
    /// the job settles.
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

    /// Create a digital twin from training footage at a URL (HeyGen).
    /// Synchronous; the subject must complete `consentUrl` before the twin
    /// renders. Render with ``twinVideo(_:)``. Flat charge.
    public func videoDigitalTwin(_ request: DigitalTwinCreateRequest) async throws -> DigitalTwinCreateResponse {
        try await createDigitalTwin(request)
    }

    /// List available HeyGen avatar looks (public and private).
    public func videoAvatars() async throws -> AvatarsResponse {
        let (data, _): (AvatarsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/video/avatars"
        )
        return data
    }

    /// List available HeyGen video templates (API-ready templates only).
    public func videoTemplates() async throws -> VideoTemplatesResponse {
        let (data, _): (VideoTemplatesResponse, _) = try await doReq(
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

    /// Generate text embeddings for the given inputs.
    public func embed(_ request: EmbedRequest) async throws -> EmbedResponse {
        let (data, meta): (EmbedResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/embeddings", body: request
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = meta.costTicks }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Generate a text embedding for one input.
    ///
    /// - Parameters:
    ///   - input: Text to embed (sent as a one-element list; the route only
    ///     accepts lists).
    ///   - model: Embedding model (required by the route).
    public func embed(input: String, model: String) async throws -> EmbedResponse {
        try await embed(EmbedRequest(model: model, input: [input]))
    }

    /// Generate text embeddings for multiple inputs.
    public func embed(inputs: [String], model: String) async throws -> EmbedResponse {
        try await embed(EmbedRequest(model: model, input: inputs))
    }

    // MARK: - Documents

    /// Extract a PDF or DOCX to Markdown.
    ///
    /// `POST /qai/v1/documents/extract` (multipart, field `file`)
    public func extractDocument(_ request: DocumentRequest) async throws -> DocumentResponse {
        let (data, meta): (DocumentResponse, HTTPClient.ResponseMeta) = try await doMultipartReq(
            path: "/qai/v1/documents/extract",
            fieldName: "file",
            filename: request.filename,
            data: request.content,
            contentType: request.mimeType ?? "application/octet-stream",
            fields: documentFormFields(extractImages: request.extractImages, chunkSize: nil, overlap: nil)
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Extract a document and split the Markdown into overlapping chunks
    /// sized in characters, for embeddings or RAG.
    ///
    /// `POST /qai/v1/documents/chunk` (multipart, field `file`)
    public func chunkDocument(_ request: ChunkDocumentRequest) async throws -> ChunkDocumentResponse {
        let (data, meta): (ChunkDocumentResponse, HTTPClient.ResponseMeta) = try await doMultipartReq(
            path: "/qai/v1/documents/chunk",
            fieldName: "file",
            filename: request.filename,
            data: request.content,
            contentType: request.mimeType ?? "application/octet-stream",
            fields: documentFormFields(extractImages: false, chunkSize: request.chunkSize, overlap: request.overlap)
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Run the whole pipeline: extraction, chunking, and images when asked.
    /// No model is involved; the price is the same mechanical rate.
    ///
    /// `POST /qai/v1/documents/process` (multipart, field `file`)
    public func processDocument(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse {
        let (data, meta): (ProcessDocumentResponse, HTTPClient.ResponseMeta) = try await doMultipartReq(
            path: "/qai/v1/documents/process",
            fieldName: "file",
            filename: request.filename,
            data: request.content,
            contentType: request.mimeType ?? "application/octet-stream",
            fields: documentFormFields(extractImages: request.extractImages, chunkSize: request.chunkSize, overlap: request.overlap)
        )
        var r = data
        if r.costTicks == 0 { r.costTicks = Int64(meta.costTicks) }
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    // MARK: - Search

    /// Perform a Brave web search. Returns web results, news, videos,
    /// infobox, discussions.
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

    /// Get a grounded AI answer with citations (Brave).
    public func searchAnswer(_ request: SearchAnswerRequest) async throws -> SearchAnswerResponse {
        let (data, _): (SearchAnswerResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/search/answer", body: request
        )
        return data
    }

    /// Google grounded search via Gemini Flash + the `google_search` built-in
    /// tool: a grounded answer plus citations, the ToS-required
    /// search-entry-point widget, and the queries Gemini actually executed.
    ///
    /// Billed per executed query ($0.035 each); ``searchAnswer(_:)`` is the
    /// Brave-backed alternative for cheap high-volume search.
    ///
    /// `POST /qai/v1/search/google`
    public func googleSearch(_ request: GoogleSearchRequest) async throws -> GoogleSearchResponse {
        let (data, _): (GoogleSearchResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/search/google", body: request
        )
        return data
    }

    // MARK: - Jobs

    /// Create an async job (202). Returns the job envelope for polling.
    public func createJob(type: String, params: [String: AnyCodable], idempotencyKey: String? = nil) async throws -> JobAcceptedResponse {
        let request = JobCreateRequest(jobType: type, params: AnyCodable(params))
        let (data, _): (JobAcceptedResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/jobs", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Check the status of an async job. Batch jobs live in a different
    /// store: read those with ``batchJob(id:)``.
    public func getJob(jobId: String) async throws -> JobStatusResponse {
        let (data, _): (JobStatusResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/jobs/\(jobId)"
        )
        return data
    }

    /// Poll a job until it reports "completed" or "failed".
    ///
    /// Each attempt sleeps for `interval` before checking, so the first
    /// status read happens one interval after the call. A "failed" job is
    /// returned normally with `status == "failed"`. When `maxAttempts` runs
    /// out this throws ``QuantumError/api(statusCode:code:message:requestId:)``
    /// with `code == "poll_timeout"` and `statusCode == 0` (raised locally,
    /// no HTTP status); the job keeps running and can be polled again.
    ///
    /// - Parameters:
    ///   - jobId: Job ID to poll.
    ///   - interval: Polling interval (default 2 seconds).
    ///   - maxAttempts: Maximum poll attempts before giving up (default 150).
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

        throw QuantumError.api(
            statusCode: 0,
            code: "poll_timeout",
            message: "job \(jobId) still running after \(maxAttempts) polls of \(interval)s",
            requestId: nil
        )
    }

    /// List the caller's newest 50 jobs. Older jobs are not reachable
    /// through this route; keep the ids from submission if you need them.
    public func listJobs() async throws -> JobListResponse {
        let (data, _): (JobListResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/jobs"
        )
        return data
    }

    /// Submit a 3D generation job.
    public func generate3D(model: String, prompt: String? = nil, imageUrl: String? = nil) async throws -> JobAcceptedResponse {
        var params: [String: AnyCodable] = ["model": AnyCodable(model)]
        if let prompt { params["prompt"] = AnyCodable(prompt) }
        if let imageUrl { params["image_url"] = AnyCodable(imageUrl) }
        return try await createJob(type: "3d/generate", params: params)
    }

    // MARK: - Voice Management

    /// List all available voices (built-in catalogs, then the live
    /// ElevenLabs library).
    public func listVoices() async throws -> VoicesResponse {
        let (data, _): (VoicesResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/voices"
        )
        return data
    }

    /// Create an instant voice clone from base64 audio samples (ElevenLabs;
    /// flat charge per clone, 402 preflight when under-funded).
    public func cloneVoice(_ request: CloneVoiceRequest) async throws -> CloneVoiceResponse {
        let (data, meta): (CloneVoiceResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/voices/clone", body: request
        )
        var r = data
        if r.requestId.isEmpty { r.requestId = meta.requestId }
        return r
    }

    /// Delete a cloned voice (403 unless the caller owns it, 404 when
    /// unknown upstream).
    public func deleteVoice(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/voices/\(id)"
        )
        return data
    }

    /// Browse the shared voice library with optional filters. Page through
    /// with `cursor = lastSortId` while `hasMore` is true.
    public func voiceLibrary(query: VoiceLibraryQuery? = nil) async throws -> SharedVoicesResponse {
        var path = "/qai/v1/voices/library"
        if let params = query?.queryItems, !params.isEmpty {
            path += "?" + params.joined(separator: "&")
        }
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

    // MARK: - Realtime Voice (token minting)

    /// Request an ephemeral token for a direct voice connection.
    ///
    /// - Parameter provider: The gateway recognises `"elevenlabs"`; any other
    ///   value, or nil, mints an xAI token. An ElevenLabs session is charged
    ///   one pre-authorised minute at mint and returns `signedUrl` +
    ///   `provider` only; an xAI session returns `ephemeralToken` + `url`.
    /// - Returns: Session info; connect to ``RealtimeSession/wsUrl``.
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

    /// End a realtime session and settle its bill. The gateway charges the
    /// longer of its own clock and `durationSeconds`, less the minute it
    /// pre-authorised at session start. 404 for an unknown session.
    public func realtimeEnd(sessionId: String, durationSeconds: Int) async throws {
        struct Body: Encodable {
            let session_id: String
            let duration_seconds: Int
        }
        let _: (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/realtime/end",
            body: Body(session_id: sessionId, duration_seconds: durationSeconds)
        )
    }

    /// Refresh an ephemeral token for long sessions (default TTL 300 s;
    /// refresh before it lapses). Needs an owned session and at least one
    /// funded minute.
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

    /// Submit a batch of jobs for processing (1–100 per call).
    ///
    /// The gateway requires a small per-job minimum balance (402 otherwise)
    /// and rejects the whole batch when any job names an unpriced model
    /// (400). Each accepted job runs independently; read results with
    /// ``batchJob(id:)``, not the Jobs API. See ``BatchSubmitResponse`` for
    /// why `jobIds` may be shorter than the input.
    public func batchSubmit(_ request: BatchSubmitRequest) async throws -> BatchSubmitResponse {
        let (data, _): (BatchSubmitResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/batch", body: request
        )
        return data
    }

    /// Submit a batch of jobs as raw JSONL: the body is the text itself,
    /// one JSON object per line in the ``BatchJob`` shape (up to 1 MiB).
    /// Blank lines and lines starting with `#` are ignored; lines that fail
    /// to parse or lack `model`/`prompt` are dropped, and a body with no
    /// valid line is rejected with 400.
    public func batchSubmitJsonl(_ jsonl: String) async throws -> BatchJsonlResponse {
        let (data, meta): (BatchJsonlResponse, HTTPClient.ResponseMeta) = try await http.doRawUpload(
            method: "POST",
            path: "/qai/v1/batch/jsonl",
            data: Data(jsonl.utf8),
            contentType: "application/x-ndjson"
        )
        _ = recordMeta(meta)
        return data
    }

    /// List the caller's batch jobs.
    ///
    /// The gateway reads the newest 100 batch jobs across all users and
    /// filters to the caller, so a caller's older jobs drop out of this
    /// list once other users' jobs push them past that window.
    public func batchJobs() async throws -> BatchJobsResponse {
        let (data, _): (BatchJobsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/batch/jobs"
        )
        return data
    }

    /// Get the status and output of a single batch job.
    ///
    /// The lookup scans the newest 200 batch jobs across all users; a
    /// caller's job older than that window answers 404 even though it
    /// exists. Read the output promptly once `status == "complete"`.
    public func batchJob(id: String) async throws -> BatchJobInfo {
        let (data, _): (BatchJobInfo, _) = try await doReq(
            method: "GET", path: "/qai/v1/batch/jobs/\(id)"
        )
        return data
    }

    // MARK: - Job SSE Streaming

    /// Stream job events via SSE (`GET /qai/v1/jobs/{id}/stream`).
    ///
    /// Yields a "progress" event on each status change, then one "complete"
    /// or "error", after which the stream closes. The stream also closes
    /// after 10 minutes with an `error` event whose `jobId` is absent (see
    /// ``JobStreamEvent/isStreamTimeout``); the job itself continues.
    ///
    /// ```swift
    /// let job = try await client.createJob(type: "3d/generate", params: ["model": "meshy-6", "prompt": "a sword"])
    /// for try await event in client.streamJob(jobId: job.jobId) {
    ///     print(event.eventType, event.status ?? "")
    /// }
    /// ```
    public func streamJob(jobId: String) -> AsyncThrowingStream<JobStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await self.http.doStreamGet(path: "/qai/v1/jobs/\(jobId)/stream")
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

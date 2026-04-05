import Foundation

/// Default production Quantum AI API endpoint.
public let defaultBaseURL = "https://api.quantumencoding.ai"

/// Number of ticks in one US dollar (10 billion).
public let ticksPerUSD: UInt64 = 10_000_000_000

/// The Quantum AI API client.
///
/// Provides async/await access to all Quantum AI endpoints including chat, image generation,
/// audio processing, video generation, embeddings, RAG search, and more.
///
/// ## Usage
///
/// ```swift
/// let client = QuantumClient(apiKey: "qai_k_xxx")
///
/// // Chat
/// let response = try await client.chat(model: "gemini-2.5-flash", messages: [.user("Hello")])
/// print(response.text)
///
/// // Stream
/// for try await event in client.chatStream(model: "claude-sonnet-4-6", messages: [.user("Write a poem")]) {
///     print(event.delta?.text ?? "", terminator: "")
/// }
///
/// // Image generation
/// let images = try await client.generateImage(model: "grok-imagine-image", prompt: "A cosmic duck")
/// ```
public final class QuantumClient: Sendable {
    let http: HTTPClient
    private let baseURLString: String

    /// Create a new Quantum AI client.
    ///
    /// - Parameters:
    ///   - apiKey: Your API key (starts with `qai_` or `qai_k_`).
    ///   - baseURL: Override the default API base URL.
    ///   - session: Custom URLSession (defaults to `.shared`).
    public init(
        apiKey: String,
        baseURL: String = defaultBaseURL,
        session: URLSession = .shared
    ) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid base URL: \(baseURL)")
        }
        self.baseURLString = baseURL
        self.http = HTTPClient(baseURL: url, apiKey: apiKey, session: session)
    }

    // MARK: - Chat

    /// Send a non-streaming chat request.
    ///
    /// - Parameters:
    ///   - model: Model ID (e.g. "claude-sonnet-4-6", "gpt-5-mini", "gemini-2.5-flash").
    ///   - messages: Conversation history.
    ///   - tools: Optional function tools the model can call.
    ///   - temperature: Controls randomness (0.0-2.0).
    ///   - maxTokens: Limits the response length.
    ///   - providerOptions: Provider-specific settings.
    /// - Returns: The chat response.
    public func chat(
        model: String,
        messages: [ChatMessage],
        tools: [ChatTool]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: false,
            temperature: temperature,
            maxTokens: maxTokens,
            providerOptions: providerOptions
        )
        return try await chat(request)
    }

    /// Send a non-streaming chat request with a full ``ChatRequest``.
    public func chat(_ request: ChatRequest) async throws -> ChatResponse {
        var req = request
        req.stream = false
        let (data, _): (ChatResponse, _) = try await http.doJSON(method: "POST", path: "/qai/v1/chat", body: req)
        return data
    }

    /// Send a streaming chat request. Returns an `AsyncThrowingStream` of ``StreamEvent`` values.
    ///
    /// ```swift
    /// for try await event in client.chatStream(model: "claude-sonnet-4-6", messages: [.user("Hello")]) {
    ///     print(event.delta?.text ?? "", terminator: "")
    /// }
    /// ```
    public func chatStream(
        model: String,
        messages: [ChatMessage],
        tools: [ChatTool]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        toolChoice: String? = nil,
        outputSchema: [String: AnyCodable]? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
    ) -> AsyncThrowingStream<StreamEvent, any Error> {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: true,
            temperature: temperature,
            maxTokens: maxTokens,
            toolChoice: toolChoice,
            outputSchema: outputSchema,
            providerOptions: providerOptions
        )
        return chatStream(request)
    }

    /// Send a streaming chat request with a full ``ChatRequest``.
    public func chatStream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, any Error> {
        var req = request
        req.stream = true

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await http.doStreamRequest(path: "/qai/v1/chat", body: req)
                    let parser = SSEParser(bytes: bytes)

                    for try await sseEvent in parser {
                        switch sseEvent {
                        case .done:
                            continuation.yield(StreamEvent(type: "done", done: true))
                            continuation.finish()
                            return
                        case let .data(data):
                            let event = try parseStreamEvent(data)
                            continuation.yield(event)
                            if event.done {
                                continuation.finish()
                                return
                            }
                        case let .error(message):
                            continuation.yield(StreamEvent(type: "error", error: message))
                            continuation.finish()
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

    // MARK: - Session Chat

    /// Send a session-based chat request. The server manages conversation history.
    ///
    /// - Parameters:
    ///   - message: The user message.
    ///   - sessionId: Session ID for follow-up messages (omit to create a new session).
    ///   - model: Model to use.
    ///   - systemPrompt: System prompt.
    ///   - contextConfig: Context management configuration.
    /// - Returns: The session chat response with session ID for follow-ups.
    public func chatSession(
        message: String,
        sessionId: String? = nil,
        model: String? = nil,
        systemPrompt: String? = nil,
        contextConfig: ContextConfig? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
    ) async throws -> SessionChatResponse {
        let request = SessionChatRequest(
            message: message,
            sessionId: sessionId,
            model: model,
            stream: false,
            systemPrompt: systemPrompt,
            contextConfig: contextConfig,
            providerOptions: providerOptions
        )
        return try await chatSession(request)
    }

    /// Send a session-based chat request with a full ``SessionChatRequest``.
    public func chatSession(_ request: SessionChatRequest) async throws -> SessionChatResponse {
        var req = request
        req.stream = false
        let (data, _): (SessionChatResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/chat/session", body: req
        )
        return data
    }

    // MARK: - Agent

    /// Run a server-side agent orchestration. Returns a stream of ``AgentEvent`` values.
    ///
    /// ```swift
    /// for try await event in client.agentRun(task: "Research the latest AI papers") {
    ///     print(event.type, event.content ?? "")
    /// }
    /// ```
    public func agentRun(
        task: String,
        conductorModel: String? = nil,
        workers: [AgentWorkerConfig]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<AgentEvent, any Error> {
        let request = AgentRequest(
            task: task,
            conductorModel: conductorModel,
            workers: workers,
            maxSteps: maxSteps,
            systemPrompt: systemPrompt
        )
        return agentRun(request)
    }

    /// Run an agent orchestration with a full ``AgentRequest``.
    public func agentRun(_ request: AgentRequest) -> AsyncThrowingStream<AgentEvent, any Error> {
        return makeSSEStream(path: "/qai/v1/agent", body: request) { data in
            try self.parseAgentEvent(data)
        }
    }

    // MARK: - Mission

    /// Run a full mission orchestration. Returns a stream of ``MissionEvent`` values.
    public func missionRun(
        goal: String,
        conductorModel: String? = nil,
        workers: [String: MissionWorker]? = nil,
        maxSteps: Int? = nil
    ) -> AsyncThrowingStream<MissionEvent, any Error> {
        let request = MissionRequest(
            goal: goal,
            conductorModel: conductorModel,
            workers: workers,
            maxSteps: maxSteps
        )
        return missionRun(request)
    }

    /// Run a mission orchestration with a full ``MissionRequest``.
    public func missionRun(_ request: MissionRequest) -> AsyncThrowingStream<MissionEvent, any Error> {
        return makeSSEStream(path: "/qai/v1/missions", body: request) { data in
            try self.parseMissionEvent(data)
        }
    }

    // MARK: - Image

    /// Generate images from a text prompt.
    ///
    /// - Parameters:
    ///   - model: Model for image generation (e.g. "grok-imagine-image", "dall-e-3").
    ///   - prompt: Text prompt describing the image.
    ///   - n: Number of images to generate.
    ///   - size: Image size (e.g. "1024x1024").
    ///   - quality: Quality level (e.g. "standard", "hd").
    /// - Returns: The image response with URLs or base64 data.
    public func generateImage(
        model: String,
        prompt: String,
        n: Int? = nil,
        size: String? = nil,
        quality: String? = nil
    ) async throws -> ImageResponse {
        let request = ImageRequest(model: model, prompt: prompt, count: n, size: size, quality: quality)
        let (data, _): (ImageResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/images/generate", body: request
        )
        return data
    }

    /// Edit images using an AI model.
    public func editImage(_ request: ImageEditRequest) async throws -> ImageEditResponse {
        let (data, _): (ImageEditResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/images/edit", body: request
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
    /// - Returns: The TTS response with audio URL.
    public func speak(
        text: String,
        model: String,
        voice: String? = nil,
        outputFormat: String? = nil,
        speed: Double? = nil
    ) async throws -> TTSResponse {
        let request = TTSRequest(model: model, text: text, voice: voice, outputFormat: outputFormat, speed: speed)
        let (data, _): (TTSResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/tts", body: request
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
        language: String? = nil
    ) async throws -> STTResponse {
        let request = STTRequest(model: model, audioBase64: audioBase64, filename: filename, language: language)
        let (data, _): (STTResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/stt", body: request
        )
        return data
    }

    // MARK: - Audio: Sound Effects

    /// Generate sound effects from a text prompt (ElevenLabs).
    public func soundEffects(_ request: SoundEffectRequest) async throws -> SoundEffectResponse {
        let (data, _): (SoundEffectResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/sound-effects", body: request
        )
        return data
    }

    // MARK: - Audio: Music

    /// Generate music from a text prompt.
    public func generateMusic(prompt: String, durationSeconds: Int? = nil, model: String) async throws -> MusicResponse {
        let request = MusicRequest(model: model, prompt: prompt, durationSeconds: durationSeconds)
        let (data, _): (MusicResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/music", body: request
        )
        return data
    }

    /// Generate music via the advanced endpoint (ElevenLabs, finetunes).
    public func generateMusicAdvanced(_ request: MusicAdvancedRequest) async throws -> MusicAdvancedResponse {
        let (data, _): (MusicAdvancedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/music/advanced", body: request
        )
        return data
    }

    // MARK: - Audio: Dialogue

    /// Generate multi-speaker dialogue audio (ElevenLabs).
    public func dialogue(_ request: DialogueRequest) async throws -> DialogueResponse {
        let (data, _): (DialogueResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/dialogue", body: request
        )
        return data
    }

    // MARK: - Audio: Speech to Speech

    /// Convert speech audio to a different voice (ElevenLabs).
    public func speechToSpeech(_ request: SpeechToSpeechRequest) async throws -> SpeechToSpeechResponse {
        let (data, _): (SpeechToSpeechResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/speech-to-speech", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Isolation

    /// Remove background noise and isolate speech (ElevenLabs).
    public func isolateVoice(audioBase64: String) async throws -> IsolateVoiceResponse {
        let request = IsolateVoiceRequest(audioBase64: audioBase64)
        let (data, _): (IsolateVoiceResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/isolate", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Remix

    /// Transform a voice by modifying attributes (ElevenLabs).
    public func remixVoice(_ request: RemixVoiceRequest) async throws -> RemixVoiceResponse {
        let (data, _): (RemixVoiceResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/remix", body: request
        )
        return data
    }

    // MARK: - Audio: Dubbing

    /// Dub audio/video into a target language (ElevenLabs).
    public func dub(_ request: DubRequest) async throws -> DubResponse {
        let (data, _): (DubResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/dub", body: request
        )
        return data
    }

    // MARK: - Audio: Alignment

    /// Get word-level timestamps for audio+text alignment (ElevenLabs).
    public func align(_ request: AlignRequest) async throws -> AlignResponse {
        let (data, _): (AlignResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/align", body: request
        )
        return data
    }

    // MARK: - Audio: Voice Design

    /// Generate voice previews from a text description (ElevenLabs).
    public func voiceDesign(_ request: VoiceDesignRequest) async throws -> VoiceDesignResponse {
        let (data, _): (VoiceDesignResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/voice-design", body: request
        )
        return data
    }

    // MARK: - Audio: Starfish TTS

    /// Generate speech using HeyGen's Starfish TTS model.
    public func starfishTTS(_ request: StarfishTTSRequest) async throws -> StarfishTTSResponse {
        let (data, _): (StarfishTTSResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/starfish-tts", body: request
        )
        return data
    }

    // MARK: - Audio: Finetunes

    /// List all music finetunes.
    public func listFinetunes() async throws -> MusicFinetuneListResponse {
        let (data, _): (MusicFinetuneListResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/audio/finetunes"
        )
        return data
    }

    /// Create a new music finetune from audio samples.
    public func createFinetune(_ request: MusicFinetuneCreateRequest) async throws -> MusicFinetuneInfo {
        let (data, _): (MusicFinetuneInfo, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/audio/finetunes", body: request
        )
        return data
    }

    /// Delete a music finetune by ID.
    public func deleteFinetune(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await http.doJSON(
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
        aspectRatio: String? = nil
    ) async throws -> VideoResponse {
        let request = VideoRequest(model: model, prompt: prompt, durationSeconds: durationSeconds, aspectRatio: aspectRatio)
        let (data, _): (VideoResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/generate", body: request
        )
        return data
    }

    /// Create a talking-head video via HeyGen Studio. Returns an async job.
    public func videoStudio(_ request: VideoStudioRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/studio", body: request
        )
        return data
    }

    /// Submit a video translation job via HeyGen. Returns an async job.
    public func videoTranslate(_ request: VideoTranslateRequest) async throws -> JobAcceptedResponse {
        let (data, _): (JobAcceptedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/translate", body: request
        )
        return data
    }

    /// Create a photo avatar via HeyGen. Returns an async job.
    public func videoPhotoAvatar(photoBase64: String, script: String) async throws -> JobAcceptedResponse {
        let request = PhotoAvatarRequest(photoBase64: photoBase64, script: script)
        let (data, _): (JobAcceptedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/photo-avatar", body: request
        )
        return data
    }

    /// Create a digital twin via HeyGen. Returns an async job.
    public func videoDigitalTwin(avatarId: String, script: String) async throws -> JobAcceptedResponse {
        let request = DigitalTwinRequest(avatarId: avatarId, script: script)
        let (data, _): (JobAcceptedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/video/digital-twin", body: request
        )
        return data
    }

    /// List available HeyGen avatars.
    public func videoAvatars() async throws -> AvatarsResponse {
        let (data, _): (AvatarsResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/video/avatars"
        )
        return data
    }

    /// List available HeyGen templates.
    public func videoTemplates() async throws -> HeyGenTemplatesResponse {
        let (data, _): (HeyGenTemplatesResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/video/templates"
        )
        return data
    }

    /// List available HeyGen voices.
    public func videoHeygenVoices() async throws -> HeyGenVoicesResponse {
        let (data, _): (HeyGenVoicesResponse, _) = try await http.doJSON(
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
        let (data, _): (EmbedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/embeddings", body: request
        )
        return data
    }

    /// Generate text embeddings for multiple inputs.
    public func embed(inputs: [String], model: String? = nil) async throws -> EmbedResponse {
        let request = EmbedRequest(inputs: inputs, model: model)
        let (data, _): (EmbedResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/embeddings", body: request
        )
        return data
    }

    // MARK: - Documents

    /// Extract text content from a document (PDF, image, etc.).
    public func extractDocument(_ request: DocumentRequest) async throws -> DocumentResponse {
        let (data, _): (DocumentResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/documents/extract", body: request
        )
        return data
    }

    /// Chunk a document into smaller pieces for embedding or processing.
    public func chunkDocument(_ request: ChunkDocumentRequest) async throws -> ChunkDocumentResponse {
        let (data, _): (ChunkDocumentResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/documents/chunk", body: request
        )
        return data
    }

    /// Process a document with extraction + optional instructions.
    public func processDocument(_ request: ProcessDocumentRequest) async throws -> ProcessDocumentResponse {
        let (data, _): (ProcessDocumentResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/documents/process", body: request
        )
        return data
    }

    // MARK: - RAG

    /// Search Vertex AI RAG corpora for relevant documentation.
    public func ragSearch(_ request: RAGSearchRequest) async throws -> RAGSearchResponse {
        let (data, _): (RAGSearchResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/rag/search", body: request
        )
        return data
    }

    /// List available Vertex AI RAG corpora.
    public func ragCorpora() async throws -> [RAGCorpus] {
        struct Body: Decodable { let corpora: [RAGCorpus]; let request_id: String }
        let (data, _): (Body, _) = try await http.doJSON(method: "GET", path: "/qai/v1/rag/corpora")
        return data.corpora
    }

    /// Search provider API documentation via SurrealDB vector search.
    public func surrealRagSearch(_ request: SurrealRAGSearchRequest) async throws -> SurrealRAGSearchResponse {
        let (data, _): (SurrealRAGSearchResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/rag/surreal/search", body: request
        )
        return data
    }

    /// List available documentation providers in SurrealDB RAG.
    public func surrealRagProviders() async throws -> SurrealRAGProvidersResponse {
        let (data, _): (SurrealRAGProvidersResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/rag/surreal/providers"
        )
        return data
    }

    // MARK: - Search (Brave)

    /// Perform a web search. Returns web results, news, videos, infobox, discussions.
    public func webSearch(_ request: WebSearchRequest) async throws -> WebSearchResponse {
        let (data, _): (WebSearchResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/search/web", body: request
        )
        return data
    }

    /// Get LLM-optimized content chunks for grounding.
    public func searchContext(_ request: SearchContextRequest) async throws -> SearchContextResponse {
        let (data, _): (SearchContextResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/search/context", body: request
        )
        return data
    }

    /// Get a grounded AI answer with citations.
    public func searchAnswer(_ request: SearchAnswerRequest) async throws -> SearchAnswerResponse {
        let (data, _): (SearchAnswerResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/search/answer", body: request
        )
        return data
    }

    // MARK: - Models

    /// List all available models with provider and pricing information.
    public func listModels() async throws -> [ModelInfo] {
        struct Body: Decodable { let models: [ModelInfo] }
        let (data, _): (Body, _) = try await http.doJSON(method: "GET", path: "/qai/v1/models")
        return data.models
    }

    /// Get the complete pricing table for all models.
    public func getPricing() async throws -> [PricingInfo] {
        struct Body: Decodable { let pricing: [PricingInfo] }
        let (data, _): (Body, _) = try await http.doJSON(method: "GET", path: "/qai/v1/pricing")
        return data.pricing
    }

    // MARK: - Account

    /// Get the account credit balance.
    public func accountBalance() async throws -> BalanceResponse {
        let (data, _): (BalanceResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/account/balance"
        )
        return data
    }

    /// Get paginated usage history.
    public func accountUsage(query: UsageQuery? = nil) async throws -> UsageResponse {
        var path = "/qai/v1/account/usage"
        var params: [String] = []
        if let limit = query?.limit { params.append("limit=\(limit)") }
        if let startAfter = query?.startAfter { params.append("start_after=\(startAfter)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }

        let (data, _): (UsageResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }

    /// Get monthly usage summary.
    public func accountUsageSummary(months: Int? = nil) async throws -> UsageSummaryResponse {
        var path = "/qai/v1/account/usage/summary"
        if let months { path += "?months=\(months)" }

        let (data, _): (UsageSummaryResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }

    /// Get the full pricing table (model ID -> pricing entry map).
    public func accountPricing() async throws -> AccountPricingResponse {
        let (data, _): (AccountPricingResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/pricing"
        )
        return data
    }

    // MARK: - Jobs

    /// Create an async job. Returns the job ID for polling.
    public func createJob(type: String, params: [String: AnyCodable]) async throws -> JobCreateResponse {
        let request = JobCreateRequest(jobType: type, params: AnyCodable(params))
        let (data, _): (JobCreateResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/jobs", body: request
        )
        return data
    }

    /// Check the status of an async job.
    public func getJob(jobId: String) async throws -> JobStatusResponse {
        let (data, _): (JobStatusResponse, _) = try await http.doJSON(
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
        let (data, _): (JobListResponse, _) = try await http.doJSON(
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

    // MARK: - API Keys

    /// Create a scoped API key.
    public func createKey(_ request: CreateKeyRequest) async throws -> CreateKeyResponse {
        let (data, _): (CreateKeyResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/keys", body: request
        )
        return data
    }

    /// List all API keys for the authenticated user.
    public func listKeys() async throws -> ListKeysResponse {
        let (data, _): (ListKeysResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/keys"
        )
        return data
    }

    /// Revoke an API key.
    public func revokeKey(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await http.doJSON(
            method: "DELETE", path: "/qai/v1/keys/\(id)"
        )
        return data
    }

    // MARK: - Compute

    /// Get available compute templates with pricing.
    public func computeTemplates() async throws -> TemplatesResponse {
        let (data, _): (TemplatesResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/compute/templates"
        )
        return data
    }

    /// Provision a new GPU compute instance.
    public func computeProvision(_ request: ProvisionRequest) async throws -> ProvisionResponse {
        let (data, _): (ProvisionResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/provision", body: request
        )
        return data
    }

    /// List all compute instances for the authenticated user.
    public func computeInstances() async throws -> InstancesResponse {
        let (data, _): (InstancesResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/compute/instances"
        )
        return data
    }

    /// Get full status of a single compute instance.
    public func computeInstance(id: String) async throws -> InstanceResponse {
        let (data, _): (InstanceResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/compute/instance/\(id)"
        )
        return data
    }

    /// Tear down a compute instance and finalize billing.
    public func computeDelete(id: String) async throws -> DeleteResponse {
        let (data, _): (DeleteResponse, _) = try await http.doJSON(
            method: "DELETE", path: "/qai/v1/compute/instance/\(id)"
        )
        return data
    }

    /// Inject an SSH public key into a running instance.
    public func computeSSHKey(id: String, sshPublicKey: String) async throws -> StatusResponse {
        let request = SSHKeyRequest(sshPublicKey: sshPublicKey)
        let (data, _): (StatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/instance/\(id)/ssh-key", body: request
        )
        return data
    }

    /// Reset the inactivity timer on a compute instance.
    public func computeKeepalive(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/compute/instance/\(id)/keepalive"
        )
        return data
    }

    // MARK: - Voice Management

    /// List all available voices (ElevenLabs).
    public func listVoices() async throws -> VoicesResponse {
        let (data, _): (VoicesResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/voices"
        )
        return data
    }

    /// Create an instant voice clone from audio samples (ElevenLabs).
    public func cloneVoice(_ request: CloneVoiceRequest) async throws -> CloneVoiceResponse {
        let (data, _): (CloneVoiceResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/voices/clone", body: request
        )
        return data
    }

    /// Delete a cloned voice (ElevenLabs).
    public func deleteVoice(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await http.doJSON(
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

        let (data, _): (SharedVoicesResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }

    /// Add a shared voice from the library to the user's account.
    public func addVoiceFromLibrary(_ request: AddVoiceFromLibraryRequest) async throws -> AddVoiceFromLibraryResponse {
        let (data, _): (AddVoiceFromLibraryResponse, _) = try await http.doJSON(
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

        let (data, _): (RealtimeSession, _) = try await http.doJSON(
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
        let _: (StatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/realtime/end",
            body: Body(session_id: sessionId, duration_seconds: durationSeconds)
        )
    }

    /// Refresh an ephemeral token for long sessions (>4 min).
    public func realtimeRefresh(sessionId: String) async throws -> String {
        struct Body: Encodable { let session_id: String }
        struct Response: Decodable { let ephemeral_token: String }

        let (data, _): (Response, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/realtime/refresh",
            body: Body(session_id: sessionId)
        )
        return data.ephemeral_token
    }

    // MARK: - Batch Processing

    /// Submit a batch of jobs for processing.
    public func batchSubmit(_ request: BatchSubmitRequest) async throws -> BatchSubmitResponse {
        let (data, _): (BatchSubmitResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/batch", body: request
        )
        return data
    }

    /// Submit a batch of jobs using JSONL format.
    public func batchSubmitJsonl(_ jsonl: String) async throws -> BatchJsonlResponse {
        struct Body: Encodable { let jsonl: String }
        let (data, _): (BatchJsonlResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/batch/jsonl", body: Body(jsonl: jsonl)
        )
        return data
    }

    /// List all batch jobs for the account.
    public func batchJobs() async throws -> BatchJobsResponse {
        let (data, _): (BatchJobsResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/batch/jobs"
        )
        return data
    }

    /// Get the status and result of a single batch job.
    public func batchJob(id: String) async throws -> BatchJobInfo {
        let (data, _): (BatchJobInfo, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/batch/jobs/\(id)"
        )
        return data
    }

    // MARK: - Credits

    /// List available credit packs (no auth required).
    public func creditPacks() async throws -> CreditPacksResponse {
        let (data, _): (CreditPacksResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/credits/packs"
        )
        return data
    }

    /// Purchase a credit pack. Returns a checkout URL for payment.
    public func creditPurchase(_ request: CreditPurchaseRequest) async throws -> CreditPurchaseResponse {
        let (data, _): (CreditPurchaseResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/credits/purchase", body: request
        )
        return data
    }

    /// Get the current credit balance.
    public func creditBalance() async throws -> CreditBalanceResponse {
        let (data, _): (CreditBalanceResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/credits/balance"
        )
        return data
    }

    /// List available credit tiers (no auth required).
    public func creditTiers() async throws -> CreditTiersResponse {
        let (data, _): (CreditTiersResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/credits/tiers"
        )
        return data
    }

    /// Apply for the developer program.
    public func devProgramApply(_ request: DevProgramApplyRequest) async throws -> DevProgramApplyResponse {
        let (data, _): (DevProgramApplyResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/credits/dev-program", body: request
        )
        return data
    }

    // MARK: - Auth

    /// Authenticate with Apple Sign-In.
    public func authApple(_ request: AuthAppleRequest) async throws -> AuthResponse {
        let (data, _): (AuthResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/auth/apple", body: request
        )
        return data
    }

    // MARK: - Contact

    /// Send a contact form message.
    ///
    /// This is a public endpoint (no auth required), but will use the
    /// configured API key if present.
    public func contact(_ request: ContactRequest) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/contact", body: request
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

    // MARK: - Private Helpers

    /// Generic SSE stream builder for agent/mission endpoints.
    private func makeSSEStream<T>(
        path: String,
        body: some Encodable,
        parse: @escaping (Data) throws -> T
    ) -> AsyncThrowingStream<T, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await self.http.doStreamRequest(path: path, body: body)
                    let parser = SSEParser(bytes: bytes)

                    for try await sseEvent in parser {
                        switch sseEvent {
                        case .done:
                            continuation.finish()
                            return
                        case let .data(data):
                            let event = try parse(data)
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

    /// Parse a raw SSE JSON payload into a ``StreamEvent``.
    private func parseStreamEvent(_ data: Data) throws -> StreamEvent {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(RawStreamEvent.self, from: data)

        var event = StreamEvent(type: raw.type ?? "unknown")

        switch raw.type {
        case "content_delta", "thinking_delta":
            event.delta = raw.delta

        case "tool_use":
            if let id = raw.id, let name = raw.name {
                event.toolUse = StreamToolUse(
                    id: id,
                    name: name,
                    input: raw.input ?? [:]
                )
            }

        case "usage":
            event.usage = ChatUsage(
                inputTokens: raw.inputTokens ?? 0,
                outputTokens: raw.outputTokens ?? 0,
                costTicks: raw.costTicks ?? 0
            )

        case "error":
            event.error = raw.message

        case "done":
            event.done = true

        default:
            break
        }

        return event
    }

    /// Parse a raw SSE JSON payload into an ``AgentEvent``.
    private func parseAgentEvent(_ data: Data) throws -> AgentEvent {
        // Log raw JSON for debugging
        if let jsonStr = String(data: data, encoding: .utf8) {
            print("[QuantumSDK] Agent raw event: \(jsonStr.prefix(200))")
        }
        let raw = try JSONDecoder().decode(RawAgentEvent.self, from: data)
        return AgentEvent(
            type: raw.type ?? "unknown",
            done: raw.type == "done",
            worker: raw.worker,
            content: raw.content ?? raw.message,  // some events put text in "message"
            error: raw.error ?? (raw.type == "agent_error" ? (raw.message ?? "Unknown agent error") : nil)
        )
    }

    /// Parse a raw SSE JSON payload into a ``MissionEvent``.
    private func parseMissionEvent(_ data: Data) throws -> MissionEvent {
        let raw = try JSONDecoder().decode(RawAgentEvent.self, from: data)
        return MissionEvent(
            type: raw.type ?? "unknown",
            done: raw.type == "done",
            worker: raw.worker,
            content: raw.content,
            error: raw.error
        )
    }
}

// MARK: - Internal Raw Event Types

private struct RawAgentEvent: Decodable {
    var type: String?
    var worker: String?
    var content: String?
    var error: String?
    var message: String?

    enum CodingKeys: String, CodingKey {
        case type, worker, content, error, message
    }
}

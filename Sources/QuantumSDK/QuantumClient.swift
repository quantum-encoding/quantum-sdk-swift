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
    let baseURLString: String

    /// Default URLSession tuned for the Quantum AI API.
    ///
    /// `URLSession.shared` aborts a request after 60s without bytes. Buffered
    /// media calls (image and video generation) return one JSON blob only once
    /// the provider finishes, so nothing flows for the whole generation. This
    /// session allows 5 minutes between bytes and 1 hour overall so synchronous
    /// media generation completes. Streaming chat is unaffected.
    public static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300   // 5 min between bytes (buffered media gen)
        config.timeoutIntervalForResource = 3600 // 1 hour overall ceiling
        return URLSession(configuration: config)
    }()

    /// Create a new Quantum AI client.
    ///
    /// - Parameters:
    ///   - apiKey: Your API key (starts with `qai_` or `qai_k_`).
    ///   - baseURL: Override the default API base URL.
    ///   - session: Custom URLSession. Defaults to ``defaultSession``, which is
    ///     tuned with long timeouts for buffered image/video generation. Pass
    ///     `.shared` explicitly only if you want the 60s default behaviour.
    public init(
        apiKey: String,
        baseURL: String = defaultBaseURL,
        session: URLSession = QuantumClient.defaultSession
    ) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid base URL: \(baseURL)")
        }
        self.baseURLString = baseURL
        self.http = HTTPClient(baseURL: url, apiKey: apiKey, session: session)
    }

    /// Set a GCP identity token for Cloud Run IAM authentication.
    /// When set, Authorization header carries this token for Cloud Run,
    /// and X-API-Key carries the API key for the Zig app layer.
    public func setCloudRunToken(_ token: String?) {
        http.cloudRunIdentityToken = token
    }

    // MARK: - Response Metadata

    /// Lock guarding `_lastResponseMeta`. `QuantumClient` is `Sendable`; the
    /// mutable last-meta slot is protected so concurrent callers don't race.
    let metaLock = NSLock()
    var _lastResponseMeta: ResponseMeta?

    /// Metadata from the most recent response (cost ticks, request id, model,
    /// post-charge balance). Updated on every ``doJSON``-backed call. Use this
    /// to surface per-request cost / balance for endpoints whose response
    /// types don't carry those fields directly (chat responses populate
    /// ``ChatResponse/requestId`` / ``ChatResponse/costTicks`` /
    /// ``ChatResponse/balanceAfter`` via ``ChatResponse/apply(_:)``).
    public var lastResponseMeta: ResponseMeta? {
        metaLock.lock()
        defer { metaLock.unlock() }
        return _lastResponseMeta
    }

    /// Record header-derived meta on the client and return the meta upstream.
    @discardableResult
    func recordMeta(_ m: HTTPClient.ResponseMeta) -> ResponseMeta {
        let publicMeta = ResponseMeta(
            costTicks: Int64(m.costTicks),
            requestId: m.requestId,
            model: m.model,
            balanceAfter: m.balanceAfter
        )
        metaLock.lock()
        _lastResponseMeta = publicMeta
        metaLock.unlock()
        return publicMeta
    }

    // MARK: - Routing Region

    /// Lock guarding `_region`. Same Sendable discipline as the meta slot.
    let regionLock = NSLock()
    var _region: Region?

    /// The client-level routing region applied to chat requests
    /// (region-scoped inference routing — EU AI Act Art 50). `nil` = no
    /// client-level routing; the key's scope (or unscoped legacy) decides.
    public var region: Region? {
        regionLock.lock()
        defer { regionLock.unlock() }
        return _region
    }

    /// Sets (or clears, with `nil`) the routing region for this client's
    /// chat traffic.
    ///
    /// The region rides `provider_options.region` on every chat /
    /// chatStream request the client sends — unless the request itself
    /// already sets one (``ChatRequest/region`` wins). Only `/qai/v1/chat`
    /// honors the override; the agent endpoint routes by the key's scope.
    /// Apps that let their user pick a region call this once at startup and
    /// again whenever the pick changes — no per-call-site wiring needed.
    public func setRegion(_ region: Region?) {
        regionLock.lock()
        _region = region
        regionLock.unlock()
    }

    /// Applies the client-level routing region to a chat request unless the
    /// request already chose one. Internal so the wire-shape tests can
    /// exercise it without a network round trip.
    func applyRegion(_ request: ChatRequest) -> ChatRequest {
        var req = request
        if req.region == nil, let region = self.region {
            req.region = region
        }
        return req
    }

    /// JSON POST/GET chokepoint that records response meta into
    /// ``lastResponseMeta``. Every ``doJSON`` call routes through here so meta
    /// is never discarded. Billing-bearing callers pass an `idempotencyKey`
    /// (UUID when the caller didn't supply one) so the gateway can dedup
    /// retries; GETs leave it nil.
    func doReq<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (data: T, meta: HTTPClient.ResponseMeta) {
        let pair: (data: T, meta: HTTPClient.ResponseMeta) = try await http.doJSON(
            method: method, path: path, body: body, idempotencyKey: idempotencyKey
        )
        _ = recordMeta(pair.meta)
        return pair
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
    ///   - toolChoice: "auto" (default), "any" (force a tool), "none", or a tool name.
    ///   - outputSchema: JSON Schema for structured output — forces the model to
    ///     return JSON matching this schema.
    ///   - providerOptions: Provider-specific settings.
    /// - Returns: The chat response.
    public func chat(
        model: String,
        messages: [ChatMessage],
        tools: [ChatTool]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        toolChoice: String? = nil,
        outputSchema: [String: AnyCodable]? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil,
        idempotencyKey: String? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: false,
            temperature: temperature,
            maxTokens: maxTokens,
            toolChoice: toolChoice,
            outputSchema: outputSchema,
            providerOptions: providerOptions
        )
        return try await chat(request, idempotencyKey: idempotencyKey)
    }

    /// Send a non-streaming chat request with a full ``ChatRequest``.
    ///
    /// - Parameters:
    ///   - idempotencyKey: Optional `Idempotency-Key`. When nil the SDK
    ///     auto-generates a UUID so retries against the gateway dedup; pass an
    ///     explicit value only when you want caller-controlled dedup scope.
    public func chat(_ request: ChatRequest, idempotencyKey: String? = nil) async throws -> ChatResponse {
        var req = applyRegion(request)
        req.stream = false
        let (data, meta): (ChatResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/chat", body: req,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        var response = data
        response.apply(ResponseMeta(
            costTicks: Int64(meta.costTicks),
            requestId: meta.requestId,
            model: meta.model,
            balanceAfter: meta.balanceAfter
        ))
        return response
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
        providerOptions: [String: [String: AnyCodable]]? = nil,
        idempotencyKey: String? = nil
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
        return chatStream(request, idempotencyKey: idempotencyKey)
    }

    /// Send a streaming chat request with a full ``ChatRequest``.
    ///
    /// - Parameters:
    ///   - idempotencyKey: Optional `Idempotency-Key`. When nil the SDK
    ///     auto-generates a UUID so a reconnected/duplicated stream request
    ///     dedups at the gateway.
    public func chatStream(_ request: ChatRequest, idempotencyKey: String? = nil) -> AsyncThrowingStream<StreamEvent, any Error> {
        var req = applyRegion(request)
        req.stream = true
        let key = idempotencyKey ?? UUID().uuidString

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, _) = try await http.doStreamRequest(path: "/qai/v1/chat", body: req, idempotencyKey: key)
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
        let (data, _): (SessionChatResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/chat/session", body: req
        )
        return data
    }

    // MARK: - Models

    /// List all available models with provider and pricing information.
    public func listModels() async throws -> [ModelInfo] {
        try await listModelsResponse().models
    }

    /// List models including the response envelope (`schema_version`, `count`).
    public func listModelsResponse() async throws -> ModelsResponse {
        let (data, _): (ModelsResponse, _) = try await doReq(method: "GET", path: "/qai/v1/models")
        return data
    }

    /// Get the complete pricing table for all models.
    public func getPricing() async throws -> [PricingInfo] {
        struct Body: Decodable { let pricing: [PricingInfo] }
        let (data, _): (Body, _) = try await doReq(method: "GET", path: "/qai/v1/pricing")
        return data.pricing
    }

    // MARK: - Account

    /// Get the account credit balance.
    public func accountBalance() async throws -> BalanceResponse {
        let (data, _): (BalanceResponse, _) = try await doReq(
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

        let (data, _): (UsageResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Get monthly usage summary.
    public func accountUsageSummary(months: Int? = nil) async throws -> UsageSummaryResponse {
        var path = "/qai/v1/account/usage/summary"
        if let months { path += "?months=\(months)" }

        let (data, _): (UsageSummaryResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Get the full pricing table (model ID -> pricing entry map).
    public func accountPricing() async throws -> AccountPricingResponse {
        let (data, _): (AccountPricingResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/pricing"
        )
        return data
    }

    // MARK: - API Keys

    /// Create a scoped API key.
    public func createKey(_ request: CreateKeyRequest) async throws -> CreateKeyResponse {
        let (data, _): (CreateKeyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/keys", body: request
        )
        return data
    }

    /// List all API keys for the authenticated user.
    public func listKeys() async throws -> ListKeysResponse {
        let (data, _): (ListKeysResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/keys"
        )
        return data
    }

    /// Revoke an API key.
    public func revokeKey(id: String) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/keys/\(id)"
        )
        return data
    }

    // MARK: - Credits

    /// List available credit packs (no auth required).
    public func creditPacks() async throws -> CreditPacksResponse {
        let (data, _): (CreditPacksResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/credits/packs"
        )
        return data
    }

    /// Purchase a credit pack. Returns a checkout URL for payment.
    public func creditPurchase(_ request: CreditPurchaseRequest) async throws -> CreditPurchaseResponse {
        let (data, _): (CreditPurchaseResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/credits/purchase", body: request
        )
        return data
    }

    /// Get the current credit balance.
    public func creditBalance() async throws -> CreditBalanceResponse {
        let (data, _): (CreditBalanceResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/credits/balance"
        )
        return data
    }

    /// List available credit tiers (no auth required).
    public func creditTiers() async throws -> CreditTiersResponse {
        let (data, _): (CreditTiersResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/credits/tiers"
        )
        return data
    }

    /// Apply for the developer program.
    public func devProgramApply(_ request: DevProgramApplyRequest) async throws -> DevProgramApplyResponse {
        let (data, _): (DevProgramApplyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/credits/dev-program", body: request
        )
        return data
    }

    // MARK: - Auth

    /// Authenticate with Apple Sign-In.
    public func authApple(_ request: AuthAppleRequest) async throws -> AuthResponse {
        let (data, _): (AuthResponse, _) = try await doReq(
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
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/contact", body: request
        )
        return data
    }

    // MARK: - Private Helpers

    /// Generic SSE stream builder for agent/mission endpoints.
    func makeSSEStream<T>(
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
    func parseStreamEvent(_ data: Data) throws -> StreamEvent {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(RawStreamEvent.self, from: data)

        var event = StreamEvent(type: raw.type ?? "unknown")

        switch raw.type {
        case "content_delta", "thinking_delta":
            event.delta = raw.delta

        case "tool_use":
            // Single-event tool call with complete arguments. The gateway also
            // emits the streaming triplet (start/input_delta/complete).
            if let id = raw.id, let name = raw.name {
                event.toolUse = StreamToolUse(
                    id: id,
                    name: name,
                    input: raw.input ?? [:]
                )
            }

        case "tool_use_start":
            // Fires once per tool call before any input data arrives. Lets the
            // client render a "card with spinner" immediately. input is empty
            // here; the real args come via tool_use_input_delta / complete.
            if let id = raw.id, let name = raw.name {
                event.toolUse = StreamToolUse(id: id, name: name, input: [:])
            }

        case "tool_use_input_delta":
            // Raw partial-JSON fragment of the tool args. May not parse on its
            // own; concatenate across deltas or wait for tool_use_complete.
            event.partialJSON = raw.partialJSON

        case "tool_use_complete":
            // Fires once after all input fragments with the server-accumulated,
            // fully-parsed arguments.
            if let id = raw.id, let name = raw.name {
                event.toolUse = StreamToolUse(
                    id: id,
                    name: name,
                    input: raw.input ?? [:]
                )
            }

        case "usage":
            // Streaming usage carries reasoning_tokens so callers see hidden
            // reasoning cost (billed at output rate, broken out for transparency).
            event.usage = ChatUsage(
                inputTokens: raw.inputTokens ?? 0,
                outputTokens: raw.outputTokens ?? 0,
                costTicks: raw.costTicks ?? 0,
                cachedTokens: 0,
                reasoningTokens: raw.reasoningTokens ?? 0
            )

        case "error":
            event.error = raw.message

        case "done":
            event.done = true

        default:
            // Zig backend format: no "type" field, full response in one event
            // {"content":[{"type":"text","text":"..."}],"usage":{...},"stop_reason":"end_turn"}
            if let content = raw.content {
                let text = content.compactMap(\.text).joined()
                if !text.isEmpty {
                    event.eventType = "content_delta"
                    event.delta = StreamDelta(text: text)
                }
            }
            if let usage = raw.usage {
                // Usage may share the event with the delta.
                event.usage = usage
            }
            if let error = raw.error {
                event.eventType = "error"
                event.error = error
            }
        }

        return event
    }

    /// Parse a raw SSE JSON payload into an ``AgentEvent``.
    func parseAgentEvent(_ data: Data) throws -> AgentEvent {
        let raw = try JSONDecoder().decode(RawAgentEvent.self, from: data)

        // Build toolUse for "tool_use" events if we have enough fields
        var toolUse: StreamToolUse? = nil
        if raw.type == "tool_use", let id = raw.id, let name = raw.name {
            toolUse = StreamToolUse(id: id, name: name, input: raw.input ?? [:])
        }

        // Only the model's own output fills `content`. Lifecycle events
        // (tick_completed, mission_started, ...) carry a `message` describing
        // what happened; that belongs in an activity timeline, not in the
        // assistant's reply, so `message` fills `content` only for
        // content-bearing event types.
        let contentBearingTypes: Set<String> = [
            "content", "content_delta",
            "thinking", "thinking_delta",
            "worker_content"
        ]
        let isContentBearing = (raw.type).map { contentBearingTypes.contains($0) } ?? false
        let resolvedContent = raw.content ?? (isContentBearing ? raw.message : nil)

        return AgentEvent(
            type: raw.type ?? "unknown",
            done: raw.type == "done",
            worker: raw.worker,
            content: resolvedContent,
            toolUse: toolUse,
            toolUseId: raw.toolUseId,
            toolOutput: raw.output,
            diff: raw.diff,
            error: raw.error ?? (raw.type == "agent_error" ? (raw.message ?? "Unknown agent error") : nil),
            role: raw.role,
            data: raw.data,
            timestamp: raw.timestamp,
            index: raw.index
        )
    }

    /// Parse a raw SSE JSON payload into a ``MissionEvent``.
    func parseMissionEvent(_ data: Data) throws -> MissionEvent {
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

struct RawAgentEvent: Decodable {
    var type: String?
    var worker: String?
    var content: String?
    var error: String?
    var message: String?
    // Tool-call correlation fields
    var id: String?                         // tool_use id
    var name: String?                       // tool name
    var input: [String: AnyCodable]?        // tool args
    var toolUseId: String?                  // links tool_result → tool_use
    var output: String?                     // tool_result output text
    var diff: String?                       // unified diff for file ops
    // agentruntime.Event passthrough fields
    var role: String?                       // event authoring role
    var data: [String: AnyCodable]?         // free-form structured payload
    var timestamp: String?                  // RFC3339 server-assigned time
    var index: Int64?                       // Last-Event-ID resume cursor

    enum CodingKeys: String, CodingKey {
        case type, worker, content, error, message, id, name, input, output, diff, role, data, timestamp, index
        case toolUseId = "tool_use_id"
    }
}

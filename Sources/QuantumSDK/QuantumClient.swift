import Foundation

/// Default production Quantum AI API endpoint.
public let defaultBaseURL = "https://api.quantumencoding.ai"

/// Number of ticks in one US dollar (10 billion).
public let ticksPerUSD: UInt64 = 10_000_000_000

// MARK: - Configuration

/// Everything a ``QuantumClient`` is built from. Mirrors the Rust crate's
/// `ClientBuilder`: set the fields you need, then pass it to
/// ``QuantumClient/init(configuration:)``, which validates the key and the
/// headers and throws instead of trapping.
public struct ClientConfiguration: Sendable {
    /// The credential sent as `Authorization: Bearer` and `X-API-Key`.
    public var apiKey: String

    /// API base URL (default: `https://api.quantumencoding.ai`).
    public var baseURL: String

    /// Timeout for buffered (non-streaming) requests, in seconds. The
    /// default of 600 s outlasts the backend's 5-minute media deadline, so
    /// buffered media generation (video, dubbing, 3D) fails server-side
    /// rather than here. Lower it for latency-sensitive callers, or use the
    /// async jobs API (`createJob` / `pollJob`), which does not block.
    /// Streaming requests use a separate session with no idle timeout.
    /// Ignored when ``session`` is set.
    public var timeout: TimeInterval

    /// Tags every request with the calling app's identifier, sent as
    /// `X-Quantum-App: <app>` (streaming included). The server uses it to
    /// route requests through app-specific paywall, quota or dispatch
    /// logic. Wins over an `extraHeaders` entry of the same name.
    public var app: String?

    /// Routes this client's chat calls through a region (region-scoped
    /// inference routing, EU AI Act Art 50). See ``QuantumClient/setRegion(_:)``.
    public var region: Region?

    /// Extra HTTP headers on every request from this client (request
    /// tagging, A/B routing, …). `Authorization` and `X-API-Key` are
    /// reserved: naming either fails ``QuantumClient/init(configuration:)``
    /// with an `invalid_header` error, as does a malformed name or value.
    public var extraHeaders: [(name: String, value: String)]

    /// A custom `URLSession` for buffered requests (a mock transport in
    /// tests, say). The streaming session is derived from its configuration
    /// with the idle timeout removed. When nil, sessions are built from
    /// ``timeout``.
    public var session: URLSession?

    public init(apiKey: String, baseURL: String = defaultBaseURL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = 600
        self.app = nil
        self.region = nil
        self.extraHeaders = []
        self.session = nil
    }
}

// MARK: - Client

/// The Quantum AI API client.
///
/// Provides async/await access to all Quantum AI endpoints including chat, image generation,
/// audio processing, video generation, embeddings, RAG search, and more.
///
/// ## Usage
///
/// ```swift
/// let client = try QuantumClient(apiKey: "qai_k_xxx")
///
/// // Chat
/// let response = try await client.chat(model: "gemini-2.5-flash", messages: [.user("Hello")])
/// print(response.text)
///
/// // Stream
/// for try await event in client.chatStream(model: "claude-sonnet-4-6", messages: [.user("Write a poem")]) {
///     print(event.delta?.text ?? "", terminator: "")
/// }
/// ```
///
/// ## Replays
///
/// A POST is replayed only on 429, waiting for the response's `Retry-After`
/// (clamped to 30 s) or 0.5 s / 1 s / 2 s, up to three times. A 502, 503
/// or 504 is thrown, never replayed: the gateway bills chat, session chat
/// and every media route through a reserve→settle rail that does not read
/// `Idempotency-Key`, and key-minting and Stripe checkout routes have no
/// dedupe at all, so a replay after a 5xx that masked a completed
/// operation would run, and charge for, it a second time. A GET is
/// replayed on all four statuses. Every JSON POST carries an
/// `Idempotency-Key` (a fresh UUID unless the caller supplies one), reused
/// across replays. Only routes billed through the gateway's
/// `DeductAndTrack` rail read it: agent, batch, jobs, search, scanner, rag,
/// documents, vision, voice, compute and deployments, inference, missions,
/// cloudrun and security. It is ignored on `/chat`, `/chat/session`,
/// `/chat/estimate`, every image, video, audio and avatar route, and on
/// keys, credits, auth and account.
public final class QuantumClient: Sendable {
    let http: HTTPClient
    let baseURLString: String

    /// Buffered session with `timeout` between bytes and overall. Response
    /// caching is off: every route is authenticated, and a cached
    /// balance or key list would be wrong the moment it was served.
    public static func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    /// Default buffered session: 600 s, the ``ClientConfiguration/timeout``
    /// default.
    public static let defaultSession: URLSession = makeSession(timeout: 600)

    /// A streaming session built from `configuration` with no idle timeout
    /// in practice (seven days): an SSE stream is open for as long as the
    /// model talks, and the gateway pings every 20 s while a provider is
    /// silent.
    static func makeStreamSession(from configuration: URLSessionConfiguration) -> URLSession {
        let config = configuration
        config.timeoutIntervalForRequest = 7 * 24 * 3600
        config.timeoutIntervalForResource = 7 * 24 * 3600
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }

    /// Create a client from a ``ClientConfiguration``.
    ///
    /// Throws ``QuantumError/api(statusCode:code:message:requestId:)`` with
    /// status 0 and code `invalid_api_key` when the key cannot be sent as
    /// an HTTP header value (a trailing newline read from a file is the
    /// usual cause), `invalid_header` when an extra header is reserved or
    /// malformed, and ``QuantumError/invalidArgument(_:)`` for a base URL
    /// that does not parse. Nothing here traps.
    public init(configuration: ClientConfiguration) throws {
        guard HTTPClient.isValidHeaderValue(configuration.apiKey) else {
            throw QuantumError.api(
                statusCode: 0,
                code: "invalid_api_key",
                message: "API key contains characters not allowed in an HTTP header "
                    + "(a trailing newline read from a file is the usual cause)",
                requestId: nil
            )
        }

        let trimmedBase = configuration.baseURL.hasSuffix("/")
            ? String(configuration.baseURL.dropLast())
            : configuration.baseURL
        guard let url = URL(string: trimmedBase),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil
        else {
            throw QuantumError.invalidArgument("Invalid base URL: \(configuration.baseURL)")
        }

        var headers = configuration.extraHeaders
        if let app = configuration.app {
            headers.removeAll { $0.name.lowercased() == "x-quantum-app" }
            headers.append((name: "X-Quantum-App", value: app))
        }
        for header in headers {
            if HTTPClient.isReservedHeader(header.name) {
                throw QuantumError.api(
                    statusCode: 0,
                    code: "invalid_header",
                    message: "header '\(header.name)' is reserved by the SDK and cannot be overridden via extraHeaders",
                    requestId: nil
                )
            }
            guard HTTPClient.isValidHeaderName(header.name) else {
                throw QuantumError.api(
                    statusCode: 0, code: "invalid_header",
                    message: "invalid header name '\(header.name)'", requestId: nil
                )
            }
            guard HTTPClient.isValidHeaderValue(header.value) else {
                throw QuantumError.api(
                    statusCode: 0, code: "invalid_header",
                    message: "invalid header value for '\(header.name)'", requestId: nil
                )
            }
        }

        let session = configuration.session ?? Self.makeSession(timeout: configuration.timeout)
        let streamSession = Self.makeStreamSession(from: session.configuration)

        self.baseURLString = trimmedBase
        self.http = HTTPClient(
            baseURL: url,
            apiKey: configuration.apiKey,
            session: session,
            streamSession: streamSession,
            extraHeaders: headers
        )
        self.regionSlot = Locked(configuration.region)
    }

    /// Create a client with an API key and default settings.
    ///
    /// - Parameters:
    ///   - apiKey: Your API key: a persistent `qai_k_…` key, a `qai_eph_…`
    ///     ephemeral key, or the `qai_…` session token a sign-in returns.
    ///   - baseURL: Override the default API base URL.
    ///   - session: Custom `URLSession` for buffered requests. See
    ///     ``ClientConfiguration/session``.
    ///
    /// Throws as ``init(configuration:)`` does.
    public convenience init(
        apiKey: String,
        baseURL: String = defaultBaseURL,
        session: URLSession? = nil
    ) throws {
        var configuration = ClientConfiguration(apiKey: apiKey, baseURL: baseURL)
        configuration.session = session
        try self.init(configuration: configuration)
    }

    /// Set a GCP identity token for Cloud Run IAM authentication.
    /// When set, `Authorization` carries this token for Cloud Run and
    /// `X-API-Key` carries the API key, which the gateway reads first.
    public func setCloudRunToken(_ token: String?) {
        http.setCloudRunIdentityToken(token)
    }

    // MARK: - Response Metadata

    /// Metadata from the most recent 2xx response (cost ticks, request id,
    /// model, post-charge balance), whichever method produced it. Use this
    /// to surface per-request cost for endpoints whose response types
    /// don't carry it directly (chat responses populate
    /// ``ChatResponse/requestId`` / ``ChatResponse/costTicks`` via
    /// ``ChatResponse/apply(_:)``).
    public var lastResponseMeta: ResponseMeta? {
        http.lastMeta.get().map(Self.publicMeta)
    }

    static func publicMeta(_ m: HTTPClient.ResponseMeta) -> ResponseMeta {
        ResponseMeta(
            costTicks: Int64(m.costTicks),
            requestId: m.requestId,
            model: m.model,
            balanceAfter: m.balanceAfter
        )
    }

    /// Records header-derived meta as the most recent and returns it in
    /// its public shape. The HTTP layer already records every 2xx; this is
    /// for a domain extension that wants the public value in hand.
    @discardableResult
    func recordMeta(_ m: HTTPClient.ResponseMeta) -> ResponseMeta {
        http.lastMeta.set(m)
        return Self.publicMeta(m)
    }

    // MARK: - Routing Region

    private let regionSlot: Locked<Region?>

    /// The client-level routing region applied to chat requests
    /// (region-scoped inference routing — EU AI Act Art 50). `nil` = no
    /// client-level routing; the key's scope (or unscoped legacy) decides.
    public var region: Region? {
        regionSlot.get()
    }

    /// Sets (or clears, with `nil`) the routing region for this client's
    /// chat traffic.
    ///
    /// The region rides `provider_options.region` on every chat /
    /// chatStream / estimateChat request the client sends — unless the
    /// request itself already sets one (``ChatRequest/region`` wins). Only
    /// `/qai/v1/chat` honors the override; the agent endpoint routes by the
    /// key's scope. Apps that let their user pick a region call this once
    /// at startup and again whenever the pick changes.
    public func setRegion(_ region: Region?) {
        regionSlot.set(region)
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

    /// JSON chokepoint for the domain extensions. Replay policy is by
    /// method (see the type docs); `idempotencyKey` sets the header on a
    /// POST (a UUID when nil) and does not change the policy.
    func doReq<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (data: T, meta: HTTPClient.ResponseMeta) {
        try await http.doJSON(method: method, path: path, body: body, idempotencyKey: idempotencyKey)
    }

    /// Like ``doReq(method:path:body:idempotencyKey:)`` but the caller's
    /// key also opts the POST into replay on 502/503/504. Only for routes
    /// that dedupe on the key; see ``HTTPClient/doJSONIdempotent(method:path:body:idempotencyKey:)``.
    func doReqIdempotent<T: Decodable>(
        method: String = "POST",
        path: String,
        body: (any Encodable)? = nil,
        idempotencyKey: String
    ) async throws -> (data: T, meta: HTTPClient.ResponseMeta) {
        try await http.doJSONIdempotent(method: method, path: path, body: body, idempotencyKey: idempotencyKey)
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
    ///   - reasoningEffort: See ``ChatRequest/reasoningEffort``.
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
        reasoningEffort: String? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            temperature: temperature,
            maxTokens: maxTokens,
            toolChoice: toolChoice,
            outputSchema: outputSchema,
            providerOptions: providerOptions,
            reasoningEffort: reasoningEffort
        )
        return try await chat(request)
    }

    /// Send a non-streaming chat request with a full ``ChatRequest``.
    ///
    /// The request goes out with `stream: false` whatever the struct says.
    /// Replayed on 429 only; `/qai/v1/chat` does not read
    /// `Idempotency-Key`.
    public func chat(_ request: ChatRequest) async throws -> ChatResponse {
        var req = applyRegion(request)
        req.stream = false
        let (data, meta): (ChatResponse, HTTPClient.ResponseMeta) = try await doReq(
            method: "POST", path: "/qai/v1/chat", body: req
        )
        var response = data
        response.apply(Self.publicMeta(meta))
        return response
    }

    /// Estimates the upfront credit reservation a ``chat(_:)`` call with
    /// the same request would book, without calling the provider or
    /// deducting credits. Use it to show a cost hint before the user
    /// commits to an expensive payload such as a long video attached via
    /// ``ContentBlock/fileURI``. Wraps `POST /qai/v1/chat/estimate`; same
    /// auth as `chat`.
    public func estimateChat(_ request: ChatRequest) async throws -> EstimateResponse {
        // Streaming does not change the cost ceiling, so `stream` stays off
        // the estimate payload.
        var req = applyRegion(request)
        req.stream = nil
        let (data, _): (EstimateResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/chat/estimate", body: req
        )
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
        providerOptions: [String: [String: AnyCodable]]? = nil,
        reasoningEffort: String? = nil
    ) -> AsyncThrowingStream<StreamEvent, any Error> {
        let request = ChatRequest(
            model: model,
            messages: messages,
            tools: tools,
            temperature: temperature,
            maxTokens: maxTokens,
            toolChoice: toolChoice,
            outputSchema: outputSchema,
            providerOptions: providerOptions,
            reasoningEffort: reasoningEffort
        )
        return chatStream(request)
    }

    /// Send a streaming chat request with a full ``ChatRequest``.
    ///
    /// Single attempt on the no-timeout streaming session, with `stream:
    /// true` whatever the struct says. The request fails as a thrown
    /// ``QuantumError`` before the first event when the gateway rejects it;
    /// a failure after the stream opens arrives as an event with
    /// ``StreamEvent/error`` set (see ``StreamEvent``).
    public func chatStream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, any Error> {
        var streamRequest = applyRegion(request)
        streamRequest.stream = true
        let req = streamRequest

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await http.doStreamRequest(path: "/qai/v1/chat", body: req)
                    try await self.pump(bytes, into: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Reads SSE events off `bytes` and yields them as ``StreamEvent``s
    /// until `[DONE]`, a `done` event, or end of stream.
    private func pump(_ bytes: URLSession.AsyncBytes, into continuation: AsyncThrowingStream<StreamEvent, any Error>.Continuation) async throws {
        for try await sseEvent in SSEParser(bytes: bytes) {
            switch sseEvent {
            case .done:
                continuation.yield(StreamEvent(eventType: "done", done: true))
                continuation.finish()
                return
            case let .data(data):
                let event = parseStreamEvent(data)
                continuation.yield(event)
                if event.done {
                    continuation.finish()
                    return
                }
            case let .error(message):
                continuation.yield(StreamEvent(eventType: "error", error: message))
                continuation.finish()
                return
            }
        }
        continuation.finish()
    }

    // MARK: - Session Chat

    /// Send a session-based chat request and wait for the whole answer.
    /// The server manages conversation history with automatic context
    /// compaction.
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
            systemPrompt: systemPrompt,
            contextConfig: contextConfig,
            providerOptions: providerOptions
        )
        return try await chatSession(request)
    }

    /// Send a session-based chat request with a full ``SessionChatRequest``.
    /// The request goes out with `stream: false` whatever the struct says;
    /// use ``chatSessionStream(_:)`` to stream. Replayed on 429 only.
    public func chatSession(_ request: SessionChatRequest) async throws -> SessionChatResponse {
        var req = request
        req.stream = false
        let (data, _): (SessionChatResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/chat/session", body: req
        )
        return data
    }

    /// Send a message within a persistent session and stream the answer.
    /// Same route and semantics as ``chatSession(_:)`` with `stream: true`.
    /// Returns once the gateway has accepted the request, with the session
    /// id from the `X-QAI-Session-Id` header and the events to iterate.
    public func chatSessionStream(_ request: SessionChatRequest) async throws -> SessionChatStream {
        var req = request
        req.stream = true
        let (bytes, response) = try await http.doStreamRequest(path: "/qai/v1/chat/session", body: req)
        let sessionId = response.value(forHTTPHeaderField: "X-QAI-Session-Id") ?? ""
        let events = AsyncThrowingStream<StreamEvent, any Error> { continuation in
            let task = Task {
                do {
                    try await self.pump(bytes, into: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return SessionChatStream(sessionId: sessionId, events: events)
    }

    /// Convenience form of ``chatSessionStream(_:)``.
    public func chatSessionStream(
        message: String,
        sessionId: String? = nil,
        model: String? = nil,
        systemPrompt: String? = nil,
        contextConfig: ContextConfig? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
    ) async throws -> SessionChatStream {
        try await chatSessionStream(SessionChatRequest(
            message: message,
            sessionId: sessionId,
            model: model,
            systemPrompt: systemPrompt,
            contextConfig: contextConfig,
            providerOptions: providerOptions
        ))
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

    /// The pricing table for every model, keyed by model id, with the
    /// gateway's margin already applied. The same route as
    /// ``accountPricing()``, unwrapped to the map.
    public func getPricing() async throws -> [String: PricingInfo] {
        try await accountPricing().pricing
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
        if let startAfter = query?.startAfter {
            params.append("start_after=\(Self.queryEscape(startAfter))")
        }
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
    public func accountPricing() async throws -> PricingResponse {
        let (data, _): (PricingResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/pricing"
        )
        return data
    }

    /// Deletes the account and its sign-in. Remaining credit is forfeited,
    /// content is erased within 30 days, and payment records are kept for
    /// as long as the law requires with the identity removed. The
    /// confirmation phrase the gateway demands is sent for you: calling
    /// this IS the confirmation.
    public func accountDelete() async throws -> AccountDeleteResponse {
        let (data, _): (AccountDeleteResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/account/delete", body: AccountDeleteRequest(confirm: "DELETE")
        )
        return data
    }

    /// Whether the account is active or being erased, and where the
    /// erasure has got to.
    public func accountDeletionStatus() async throws -> DeletionStatus {
        let (data, _): (DeletionStatus, _) = try await doReq(
            method: "GET", path: "/qai/v1/account/deletion"
        )
        return data
    }

    // MARK: - API Keys

    /// Create a scoped API key.
    ///
    /// The gateway does not dedupe key minting, so the request is never
    /// replayed on a 502/503/504: if one masks a completed mint, the key
    /// exists but its secret was never delivered. List keys and revoke it
    /// rather than minting again blindly.
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
            method: "DELETE", path: "/qai/v1/keys/\(Self.pathEscape(id))"
        )
        return data
    }

    /// Lists the account's per-device default keys.
    public func listDeviceKeys() async throws -> ListDeviceKeysResponse {
        let (data, _): (ListDeviceKeysResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/keys/devices"
        )
        return data
    }

    /// Rotates a key: mints a replacement and keeps the old one working for
    /// `graceSeconds` so deployed clients can pick the new one up.
    ///
    /// Never replayed on a 5xx: a second rotate of an already-rotated id
    /// is a 409 `invalid_state`, and the only copy of the new secret was
    /// in the lost response. On a 502/503/504 here, treat the rotation as
    /// possibly done, list keys, and rotate the new id if you must.
    public func rotateKey(id: String, _ request: RotateKeyRequest = RotateKeyRequest()) async throws -> RotateKeyResponse {
        let (data, _): (RotateKeyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/keys/\(Self.pathEscape(id))/rotate", body: request
        )
        return data
    }

    /// A key's usage by day and by model.
    public func keyUsage(id: String) async throws -> KeyUsageResponse {
        let (data, _): (KeyUsageResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/keys/\(Self.pathEscape(id))/usage"
        )
        return data
    }

    /// Mints a short-lived token for a browser or device.
    ///
    /// Only accounts on the `internal` developer tier (and admins) may
    /// call this; any other account gets a 403 `forbidden` before the body
    /// is read. Single attempt on 5xx: a replay could mint a second token
    /// whose secret nobody received.
    public func createEphemeralKey(_ request: EphemeralKeyRequest) async throws -> EphemeralKeyResponse {
        let (data, _): (EphemeralKeyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/keys/ephemeral", body: request
        )
        return data
    }

    /// Mints a key on behalf of a partner app's end user.
    ///
    /// Only accounts on the `internal` developer tier (and admins) may
    /// call this; any other account gets a 403 `forbidden` before the body
    /// is read. Single attempt on 5xx, like every key-minting call.
    public func createPartnerKey(_ request: PartnerKeyRequest) async throws -> PartnerKeyResponse {
        let (data, _): (PartnerKeyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/keys/partner", body: request
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

    /// Purchase a credit pack. Returns a checkout URL for payment. Never
    /// replayed on a 5xx: Stripe checkout has no dedupe.
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

    /// List the lifetime unlock plans (no auth required).
    public func lifetimePlans() async throws -> LifetimePlansResponse {
        let (data, _): (LifetimePlansResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/credits/lifetime"
        )
        return data
    }

    /// Buy a lifetime plan. Returns a checkout URL for payment. Never
    /// replayed on a 5xx: Stripe checkout has no dedupe.
    public func lifetimePurchase(_ request: LifetimePurchaseRequest) async throws -> LifetimePurchaseResponse {
        let (data, _): (LifetimePurchaseResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/credits/lifetime", body: request
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
    ///
    /// The `idToken` is the JWT received from the Sign in with Apple flow.
    /// On first sign-in, pass the user's `name` so the account is created
    /// with a display name, and the `nonce` the flow was started with so
    /// the gateway can check it.
    public func authApple(_ request: AuthAppleRequest) async throws -> AuthResponse {
        let (data, _): (AuthResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/auth/apple", body: request
        )
        return data
    }

    /// Authenticate with Google Sign-In.
    ///
    /// The `idToken` is the JWT from Google's OAuth flow and `clientId` the
    /// OAuth client it was issued for. Construct the client with any
    /// placeholder key: the call needs none, and the response's `token`
    /// becomes the credential for everything after.
    public func authGoogle(_ request: AuthGoogleRequest) async throws -> AuthResponse {
        let (data, _): (AuthResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/auth/google", body: request
        )
        return data
    }

    /// Authenticate with a Firebase ID token (any Firebase Auth provider).
    public func authFirebase(_ request: AuthFirebaseRequest) async throws -> AuthResponse {
        let (data, _): (AuthResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/auth/firebase", body: request
        )
        return data
    }

    /// Resolve a `qai_k_` key to its owner. For services that accept a
    /// customer's key and need to know whose it is; with no key in the
    /// request, the calling credential is the one verified.
    public func verifyKey(_ request: VerifyKeyRequest = VerifyKeyRequest()) async throws -> VerifyKeyResponse {
        let (data, _): (VerifyKeyResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/auth/verify-key", body: request
        )
        return data
    }

    /// Sign out: revoke the session token this client was built with.
    ///
    /// Session tokens only. A client built on a `qai_k_` or `qai_eph_` key
    /// gets a 403 `invalid_request`; revoke those with ``revokeKey(id:)``
    /// instead.
    public func revokeSession() async throws -> RevokeSessionResponse {
        let (data, _): (RevokeSessionResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/auth/session"
        )
        return data
    }

    // MARK: - Contact

    /// Send a contact form message.
    ///
    /// This is a public endpoint (no auth required), but will use the
    /// configured API key if present. Answers `{"status": "sent"}`.
    public func contact(_ request: ContactRequest) async throws -> StatusResponse {
        let (data, _): (StatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/contact", body: request
        )
        return data
    }

    // MARK: - Helpers

    /// Percent-encodes one path segment.
    static func pathEscape(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? segment
    }

    /// Percent-encodes one query value.
    static func queryEscape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Parse a raw SSE JSON payload into a ``StreamEvent``. A payload that
    /// is not JSON becomes an `error` event rather than ending the stream.
    func parseStreamEvent(_ data: Data) -> StreamEvent {
        let raw: RawStreamEvent
        do {
            raw = try JSONDecoder().decode(RawStreamEvent.self, from: data)
        } catch {
            return StreamEvent(eventType: "error", error: "parse SSE: \(error.localizedDescription)")
        }

        var event = StreamEvent(eventType: raw.type ?? "unknown")

        switch raw.type {
        case "content_delta", "thinking_delta":
            event.delta = raw.delta

        case "tool_use":
            // Atomic form, from backends that do not stream the triplet.
            event.toolUse = StreamToolUse(id: raw.id ?? "", name: raw.name ?? "", input: raw.input ?? [:])

        case "tool_use_start":
            event.toolUseStart = StreamToolUseStart(id: raw.id ?? "", name: raw.name ?? "")

        case "tool_use_input_delta":
            event.toolUseInputDelta = StreamToolUseInputDelta(id: raw.id ?? "", partialJSON: raw.partialJSON ?? "")

        case "tool_use_complete":
            event.toolUseComplete = StreamToolUseComplete(id: raw.id ?? "", name: raw.name ?? "", input: raw.input ?? [:])

        case "usage":
            // The streaming usage event carries reasoning_tokens but not
            // cached_tokens; the cache split arrives only on the
            // non-streaming envelope.
            event.usage = ChatUsage(
                inputTokens: raw.inputTokens ?? 0,
                outputTokens: raw.outputTokens ?? 0,
                costTicks: raw.costTicks ?? 0,
                cachedTokens: nil,
                reasoningTokens: raw.reasoningTokens
            )

        // The gateway classifies a failed stream as one of three types;
        // the message rides the same field on all of them.
        case "error", "invalid_request", "rate_limit":
            event.error = raw.message ?? ""

        case "citations":
            event.citations = raw.citations ?? []

        case "session":
            event.session = StreamSession(sessionId: raw.sessionId ?? "", compacted: raw.compacted ?? false)

        case "done":
            event.done = true

        case "heartbeat":
            break

        default:
            // A payload with no `type`: a single-envelope backend that
            // sends the whole response in one event
            // {"content":[{"type":"text","text":"..."}],"usage":{...},"stop_reason":"end_turn"}.
            if let content = raw.content {
                let text = content.compactMap(\.text).joined()
                if !text.isEmpty {
                    event.eventType = "content_delta"
                    event.delta = StreamDelta(text: text)
                }
            }
            if let usage = raw.usage {
                event.usage = usage
            }
            if let error = raw.error {
                event.eventType = "error"
                event.error = error
            }
        }

        return event
    }
}

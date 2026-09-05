import Foundation

// MARK: - Chat Request

/// Request body for the `/qai/v1/chat` endpoint.
public struct ChatRequest: Codable, Sendable {
    /// Model ID that determines provider routing (e.g. "claude-sonnet-4-6",
    /// "grok-4-1-fast-non-reasoning", "qwen3.8-max"). See `listModels()`.
    public var model: String

    /// Conversation history.
    public var messages: [ChatMessage]

    /// Functions the model can call.
    public var tools: [ChatTool]?

    /// Enable server-sent event streaming. `chat` and `chatStream` set it.
    public var stream: Bool?

    /// Controls randomness (0.0-2.0).
    public var temperature: Double?

    /// Limits the response length.
    public var maxTokens: Int?

    /// Controls tool calling behavior.
    /// - `"auto"` (default): Model decides whether to call tools
    /// - `"any"`: Force the model to call at least one tool
    /// - `"none"`: Prevent tool calls
    /// - A tool name: Force the model to call that specific tool
    public var toolChoice: String?

    /// JSON Schema for structured output. When set, the model returns valid JSON matching this schema.
    public var outputSchema: [String: AnyCodable]?

    /// Provider-specific settings (e.g. Anthropic thinking, xAI search).
    /// The routing-region override (`provider_options.region`) rides here
    /// too — prefer the typed ``region`` property for it.
    public var providerOptions: [String: [String: AnyCodable]]?

    /// Routing region override for this chat request — encoded as
    /// `provider_options.region` on the wire (it is not a standalone JSON
    /// field) and wins over the key's scope region. Honored by
    /// `/qai/v1/chat` only: the agent endpoint routes by the key's scope by
    /// design. Decoding a request extracts a string `provider_options.region`
    /// back into this property.
    public var region: Region?

    /// How much chain-of-thought a reasoning model runs before answering.
    /// One of `"none"`, `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"`;
    /// `nil` = provider default (medium on GPT-5.5+). `max` is Anthropic
    /// Opus 4.7+ only (OpenAI will 400 on it). On hybrid-thinking Qwen
    /// models any value but `"none"` enables thinking and `"none"` disables
    /// it. An unknown value is rejected with 400 by the gateway.
    public var reasoningEffort: String?

    /// Vertex resource name of a previously created context cache (e.g.
    /// `"cachedContents/abc123"`). When set, the cached content is billed at
    /// the cached-read rate and need not be re-sent. Gemini-only; the cache's
    /// model must match this request's model.
    public var cachedContent: String?

    public init(
        model: String,
        messages: [ChatMessage],
        tools: [ChatTool]? = nil,
        stream: Bool? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        toolChoice: String? = nil,
        outputSchema: [String: AnyCodable]? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil,
        region: Region? = nil,
        reasoningEffort: String? = nil,
        cachedContent: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.toolChoice = toolChoice
        self.outputSchema = outputSchema
        self.providerOptions = providerOptions
        self.region = region
        self.reasoningEffort = reasoningEffort
        self.cachedContent = cachedContent
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
        case outputSchema = "output_schema"
        case providerOptions = "provider_options"
        case reasoningEffort = "reasoning_effort"
        case cachedContent = "cached_content"
    }

    // Custom Codable: `region` has no JSON field of its own — it rides
    // inside `provider_options` as the one entry whose value is a plain
    // string, which the nested-dictionary type of `providerOptions` cannot
    // represent. Encoding merges it in; decoding extracts it back out.

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(stream, forKey: .stream)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
        try container.encodeIfPresent(outputSchema, forKey: .outputSchema)
        var merged: [String: AnyCodable]? =
            providerOptions?.mapValues { AnyCodable($0) }
        if let region {
            var opts = merged ?? [:]
            opts["region"] = AnyCodable(region.rawValue)
            merged = opts
        }
        try container.encodeIfPresent(merged, forKey: .providerOptions)
        try container.encodeIfPresent(reasoningEffort, forKey: .reasoningEffort)
        try container.encodeIfPresent(cachedContent, forKey: .cachedContent)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        tools = try container.decodeIfPresent([ChatTool].self, forKey: .tools)
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        toolChoice = try container.decodeIfPresent(String.self, forKey: .toolChoice)
        outputSchema = try container.decodeIfPresent([String: AnyCodable].self, forKey: .outputSchema)
        let rawOptions = try container.decodeIfPresent([String: AnyCodable].self, forKey: .providerOptions)
        if let rawOptions {
            if let raw = rawOptions["region"]?.value as? String {
                region = Region(parsing: raw)
            }
            var rest: [String: [String: AnyCodable]] = [:]
            for (key, value) in rawOptions where key != "region" {
                if let nested = value.value as? [String: Any] {
                    rest[key] = nested.mapValues { AnyCodable($0) }
                }
            }
            providerOptions = rest.isEmpty ? nil : rest
        }
        reasoningEffort = try container.decodeIfPresent(String.self, forKey: .reasoningEffort)
        cachedContent = try container.decodeIfPresent(String.self, forKey: .cachedContent)
    }
}

// MARK: - Chat Message

/// A single message in a chat conversation.
public struct ChatMessage: Codable, Sendable {
    /// The role of the message author.
    public var role: Role

    /// Plain text content of the message.
    public var content: String?

    /// Structured content blocks. When present, takes precedence over
    /// `content`. A `null` on the wire decodes as `nil`; a malformed block
    /// array is a decode error, not `nil`.
    public var contentBlocks: [ContentBlock]?

    /// Tool call ID for tool result messages.
    public var toolCallId: String?

    /// Whether this tool result is an error.
    public var isError: Bool?

    /// Provider-side reasoning state (OpenAI Responses API). Pass back the
    /// `phase` received on the previous turn's ``ChatResponse`` so reasoning
    /// state is preserved across replay. `nil` for providers without phase.
    public var phase: String?

    public init(
        role: Role,
        content: String? = nil,
        contentBlocks: [ContentBlock]? = nil,
        toolCallId: String? = nil,
        isError: Bool? = nil,
        phase: String? = nil
    ) {
        self.role = role
        self.content = content
        self.contentBlocks = contentBlocks
        self.toolCallId = toolCallId
        self.isError = isError
        self.phase = phase
    }

    /// Create a user message with text content.
    public static func user(_ text: String) -> ChatMessage {
        ChatMessage(role: .user, content: text)
    }

    /// Create a system message with text content.
    public static func system(_ text: String) -> ChatMessage {
        ChatMessage(role: .system, content: text)
    }

    /// Create an assistant message with text content.
    public static func assistant(_ text: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: text)
    }

    /// Create a tool result message.
    public static func tool(callId: String, content: String, isError: Bool = false) -> ChatMessage {
        ChatMessage(role: .tool, content: content, toolCallId: callId, isError: isError)
    }

    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    enum CodingKeys: String, CodingKey {
        case role, content, phase
        case contentBlocks = "content_blocks"
        case toolCallId = "tool_call_id"
        case isError = "is_error"
    }
}

// MARK: - Content Block

/// A structured content block in a chat message or response.
public struct ContentBlock: Codable, Sendable {
    /// Block type (e.g. "text", "thinking", "tool_use", "image", "file",
    /// "file_uri").
    public var blockType: String

    /// Text content for text/thinking blocks.
    public var text: String?

    /// Tool call ID for tool_use blocks.
    public var id: String?

    /// Tool name for tool_use blocks.
    public var name: String?

    /// Tool input arguments for tool_use blocks.
    public var input: [String: AnyCodable]?

    /// Gemini thought signature -- must be echoed back with tool results.
    public var thoughtSignature: String?

    /// Base64-encoded content for `"image"` and `"file"` blocks.
    public var data: String?

    /// MIME type for `"image"`/`"file"`/`"file_uri"` blocks (e.g. `"image/png"`, `"application/pdf"`).
    public var mimeType: String?

    /// Original filename for `"file"` blocks.
    public var fileName: String?

    /// Remote resource URL for `"file_uri"` blocks. Gemini accepts YouTube
    /// URLs verbatim here (with `mimeType: "video/mp4"`); other providers
    /// may require a pre-uploaded resource URI, and an unsupported URI is
    /// skipped server-side rather than erroring the request.
    public var fileURI: String?

    public init(
        blockType: String,
        text: String? = nil,
        id: String? = nil,
        name: String? = nil,
        input: [String: AnyCodable]? = nil,
        thoughtSignature: String? = nil,
        data: String? = nil,
        mimeType: String? = nil,
        fileName: String? = nil,
        fileURI: String? = nil
    ) {
        self.blockType = blockType
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.thoughtSignature = thoughtSignature
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
        self.fileURI = fileURI
    }

    /// Legacy convenience init using `type` parameter name.
    public init(
        type: String,
        text: String? = nil,
        id: String? = nil,
        name: String? = nil,
        input: [String: AnyCodable]? = nil
    ) {
        self.blockType = type
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.thoughtSignature = nil
    }

    /// Legacy accessor for blockType.
    public var type: String {
        get { blockType }
        set { blockType = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case text, id, name, input, data
        case blockType = "type"
        case thoughtSignature = "thought_signature"
        case mimeType = "mime_type"
        case fileName = "file_name"
        case fileURI = "file_uri"
    }
}

// MARK: - Chat Tool

/// A function tool definition for chat completions.
///
/// Wire shape is FLAT, matching the gateway contract:
/// `{"name","description","parameters","strict"}`. The gateway does not
/// understand the OpenAI/Anthropic nested `{"type":"function","function":{...}}`
/// shape: it forwards such a tool with an empty name, and the provider
/// rejects or ignores it.
public struct ChatTool: Codable, Sendable {
    /// Tool name.
    public var name: String

    /// Human-readable description of what the tool does.
    public var description: String?

    /// JSON Schema describing the tool's parameters.
    public var parameters: [String: AnyCodable]?

    /// Enable strict schema validation (Anthropic, OpenAI). First call has
    /// ~1s extra latency for grammar compilation, then cached 24h.
    public var strict: Bool?

    public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil, strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
        self.strict = strict
    }

    enum CodingKeys: String, CodingKey {
        case name, description, parameters, strict
    }
}

// MARK: - Citation

/// A source reference from web search grounding.
public struct Citation: Codable, Sendable {
    /// Title of the cited source.
    public var title: String

    /// URL of the cited source.
    public var url: String

    /// Relevant text snippet from the source.
    public var text: String

    /// Position in the response.
    public var index: Int

    public init(title: String = "", url: String = "", text: String = "", index: Int = 0) {
        self.title = title
        self.url = url
        self.text = text
        self.index = index
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        index = try c.decodeIfPresent(Int.self, forKey: .index) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case title, url, text, index
    }
}

// MARK: - Chat Usage

/// Token usage and cost information for a chat request.
///
/// The two paths count output differently. On the non-streaming envelope
/// ``outputTokens`` is completion plus reasoning. On the streaming `usage`
/// event ``outputTokens`` is the visible completion only and reasoning is
/// reported beside it; ``costTicks`` covers both either way, so the billed
/// output on a stream is `outputTokens + (reasoningTokens ?? 0)`.
public struct ChatUsage: Codable, Sendable {
    /// Number of input tokens processed.
    public var inputTokens: Int

    /// Output tokens billed at the output rate. Includes reasoning on the
    /// non-streaming envelope; excludes it on the streaming usage event.
    public var outputTokens: Int

    /// What the call cost, covering input, output and reasoning. Zero on a
    /// semantic-cache hit.
    public var costTicks: Int

    /// Input tokens served from the provider's prompt cache, billed at the
    /// lower cached rate. `nil` on responses with no cache hit and on the
    /// streaming usage event.
    public var cachedTokens: Int?

    /// Reasoning / thinking tokens, billed at the output rate. `nil` on
    /// responses from non-reasoning models. Already inside ``outputTokens``
    /// on the non-streaming envelope; on top of it on the streaming usage
    /// event.
    public var reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedTokens = "cached_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case costTicks = "cost_ticks"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        costTicks = try container.decodeIfPresent(Int.self, forKey: .costTicks) ?? 0
        cachedTokens = try container.decodeIfPresent(Int.self, forKey: .cachedTokens)
        reasoningTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningTokens)
    }

    public init(inputTokens: Int, outputTokens: Int, costTicks: Int = 0, cachedTokens: Int? = nil, reasoningTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costTicks = costTicks
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
    }
}

// MARK: - Estimate

/// Response shape from `POST /qai/v1/chat/estimate`. Returned by
/// `QuantumClient.estimateChat(_:)`.
///
/// ``estimatedCostTicks`` is the upfront reservation a `chat` call with the
/// same request would book: a worst-case ceiling the caller must have
/// available, not a prediction of the final settle. Text-only payloads
/// settle close to it; video and other multimodal inputs can over-estimate,
/// and the post-call settle refunds the difference.
public struct EstimateResponse: Codable, Sendable {
    public var estimatedCostTicks: Int64

    /// The same value converted to USD at the gateway's tick rate.
    public var estimatedCostUsd: Double

    /// Model the estimate was computed against.
    public var model: String

    enum CodingKeys: String, CodingKey {
        case model
        case estimatedCostTicks = "estimated_cost_ticks"
        case estimatedCostUsd = "estimated_cost_usd"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estimatedCostTicks = try c.decode(Int64.self, forKey: .estimatedCostTicks)
        estimatedCostUsd = try c.decode(Double.self, forKey: .estimatedCostUsd)
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
    }
}

// MARK: - Stop Reason

/// Canonical `stop_reason` values emitted by the gateway. Every provider's
/// native finish reason is normalized into this Anthropic-flavored space, so
/// comparing ``ChatResponse/stopReason`` against these works regardless of
/// which model served the request. A provider-specific reason the gateway
/// cannot map passes through lowercased — treat any other value as terminal.
public enum StopReason {
    /// Natural completion.
    public static let endTurn = "end_turn"
    /// Model is requesting tool execution (tool_use blocks present).
    public static let toolUse = "tool_use"
    /// Output token cap reached — the response is truncated.
    public static let maxTokens = "max_tokens"
    /// A requested stop sequence matched.
    public static let stopSequence = "stop_sequence"
    /// Provider-side safety/policy stop.
    public static let contentFilter = "content_filter"
    /// A safety classifier declined the request; discard any partial output.
    public static let refusal = "refusal"
    /// Provider reported a terminal failure.
    public static let error = "error"
}

// MARK: - Chat Response

/// Response from the `/qai/v1/chat` endpoint (non-streaming).
public struct ChatResponse: Codable, Sendable {
    /// Unique response ID (the request id).
    public var id: String

    /// Model used for generation.
    public var model: String

    /// Content blocks in the response. A `null` on the wire decodes as
    /// empty.
    public var content: [ContentBlock]

    /// Token usage and cost information.
    public var usage: ChatUsage

    /// Reason the model stopped generating. See ``StopReason``.
    public var stopReason: String

    /// Citations from web search (when search is enabled via provider_options).
    public var citations: [Citation]?

    /// Provider-side reasoning-state tag (OpenAI Responses API). Echo it back
    /// on the corresponding assistant ``ChatMessage/phase`` of the next turn
    /// to preserve reasoning state across replay. `nil` when the provider
    /// doesn't surface phase.
    public var phase: String?

    /// Unique request ID. The body does not carry `request_id` at the top
    /// level (the `X-QAI-Request-Id` header and the body `id` field hold it).
    /// Decoded as optional and populated from ``ResponseMeta`` after decode
    /// via ``apply(_:)``.
    public var requestId: String?

    /// Cost in ticks. The body does not carry `cost_ticks` at the top level
    /// (it lives inside `usage` and the `X-QAI-Cost-Ticks` header).
    /// Decoded as optional and populated from ``ResponseMeta`` after decode.
    public var costTicks: Int?

    /// Post-charge wallet balance in ticks from `X-QAI-Balance-After`.
    /// Only the media routes send that header, so on a chat response this
    /// is always `nil`; use `creditBalance()` / `accountBalance()` for the
    /// balance after a chat.
    public var balanceAfter: Int64?

    /// `true` when this response was served from the semantic cache (the
    /// same signal the `X-QAI-Cache: hit-tier-N` header carries). A hit is
    /// served before any credit reservation: nothing is charged or
    /// metered, `usage.costTicks` is 0 and no `X-QAI-Cost-Ticks` header is
    /// sent. `nil` or `false` on a fresh provider response.
    public var cached: Bool?

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage, citations, phase, cached
        case stopReason = "stop_reason"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
        case balanceAfter = "balance_after"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` and `model` are required keys, as in the Rust reference: a
        // gateway error envelope written with a 2xx status carries neither,
        // and defaulting them here would decode a moderation block into an
        // empty success. Failing to decode is what routes the body to the
        // error envelope check in `HTTPClient.decodeSuccess`. An empty
        // `model` is still allowed — `apply(_:)` backfills it from the
        // `X-QAI-Model` header.
        id = try c.decode(String.self, forKey: .id)
        model = try c.decode(String.self, forKey: .model)
        content = try c.decodeIfPresent([ContentBlock].self, forKey: .content) ?? []
        stopReason = try c.decodeIfPresent(String.self, forKey: .stopReason) ?? ""
        usage = try c.decodeIfPresent(ChatUsage.self, forKey: .usage)
            ?? ChatUsage(inputTokens: 0, outputTokens: 0)
        citations = try c.decodeIfPresent([Citation].self, forKey: .citations)
        phase = try c.decodeIfPresent(String.self, forKey: .phase)
        cached = try c.decodeIfPresent(Bool.self, forKey: .cached)
        // The body never carries these at top level; they're populated from
        // response headers via apply(_:). decodeIfPresent keeps decode from
        // throwing if a future gateway revision does include them.
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId)
        costTicks = try c.decodeIfPresent(Int.self, forKey: .costTicks)
        balanceAfter = try c.decodeIfPresent(Int64.self, forKey: .balanceAfter)
    }

    /// Populate header-derived fields (requestId, costTicks, model,
    /// balanceAfter) from ``ResponseMeta`` when the body didn't carry them.
    /// Called by ``QuantumClient`` after decode so callers see per-request
    /// cost without reading headers themselves.
    public mutating func apply(_ meta: ResponseMeta) {
        if requestId == nil { requestId = meta.requestId.isEmpty ? nil : meta.requestId }
        if costTicks == nil { costTicks = Int(truncatingIfNeeded: meta.costTicks) }
        if model.isEmpty { model = meta.model }
        if balanceAfter == nil { balanceAfter = meta.balanceAfter }
    }

    /// True when the model is requesting tool execution
    /// (`stopReason == StopReason.toolUse`). Every provider is normalised
    /// the same way: a natural stop with tool_use blocks present becomes
    /// `tool_use`. A provider that reports `max_tokens`, `content_filter`
    /// or `error` alongside tool calls keeps that reason, so check
    /// ``toolCalls`` too if you must act on a partial tool request.
    public var isToolUse: Bool { stopReason == StopReason.toolUse }

    /// True when a safety classifier declined the request
    /// (`stopReason == StopReason.refusal`). On a refusal the content may be
    /// empty or a partial prefix that should be discarded — check this before
    /// reading ``text``. A refusal arrives as a normal 2xx response, so the
    /// HTTP status does not signal it.
    public var isRefusal: Bool { stopReason == StopReason.refusal }

    /// True when output was cut off by the token cap
    /// (`stopReason == StopReason.maxTokens`) — the response is incomplete.
    public var isMaxTokens: Bool { stopReason == StopReason.maxTokens }

    /// Concatenated text content, ignoring thinking and tool_use blocks.
    public var text: String {
        content
            .filter { $0.blockType == "text" }
            .compactMap(\.text)
            .joined()
    }

    /// Concatenated thinking content.
    public var thinking: String {
        content
            .filter { $0.blockType == "thinking" }
            .compactMap(\.text)
            .joined()
    }

    /// All tool_use blocks from the response.
    public var toolCalls: [ContentBlock] {
        content.filter { $0.blockType == "tool_use" }
    }
}

// MARK: - Stream Types

/// A delta update in a streaming response.
public struct StreamDelta: Codable, Sendable {
    /// Incremental text content.
    public var text: String?

    public init(text: String? = nil) {
        self.text = text
    }
}

/// A tool call from an atomic `tool_use` streaming event.
public struct StreamToolUse: Codable, Sendable {
    /// Tool call ID.
    public var id: String

    /// Tool name.
    public var name: String

    /// Tool input arguments.
    public var input: [String: AnyCodable]

    public init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// Tool-call start event — fires once before any input deltas.
public struct StreamToolUseStart: Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Tool-call input delta — fires zero or more times with raw JSON fragments.
public struct StreamToolUseInputDelta: Sendable {
    public var id: String
    /// Raw JSON fragment. May not parse on its own; accumulate until the
    /// corresponding `tool_use_complete` event arrives with the
    /// authoritative `input`.
    public var partialJSON: String

    public init(id: String, partialJSON: String) {
        self.id = id
        self.partialJSON = partialJSON
    }
}

/// Tool-call completion event — fires exactly once per call with the
/// server-accumulated, fully-parsed arguments.
public struct StreamToolUseComplete: Sendable {
    public var id: String
    public var name: String
    public var input: [String: AnyCodable]

    public init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

/// The `session` event a session stream opens with.
public struct StreamSession: Sendable {
    /// The session identifier (newly created when the request had none).
    public var sessionId: String
    /// Whether the history was compacted before this turn.
    public var compacted: Bool

    public init(sessionId: String, compacted: Bool) {
        self.sessionId = sessionId
        self.compacted = compacted
    }
}

/// A single event from a streaming chat response.
///
/// A tool call streams as a triplet: one `tool_use_start`, zero or more
/// `tool_use_input_delta`, then one `tool_use_complete` carrying the full
/// arguments. Some backends emit a single atomic `tool_use` event instead,
/// so a consumer handles both forms.
///
/// A stream that fails after the HTTP 200 is locked in reports the failure
/// as an event whose type is `error`, `invalid_request` (the request was
/// rejected: do not retry as-is) or `rate_limit` (the provider throttled:
/// retry later); all three carry the message in ``error``, and `done`
/// follows.
public struct StreamEvent: Sendable {
    /// Event type: "content_delta", "thinking_delta", "tool_use_start",
    /// "tool_use_input_delta", "tool_use_complete", "tool_use" (atomic),
    /// "citations", "session", "usage", "heartbeat", "error",
    /// "invalid_request", "rate_limit", "done".
    public var eventType: String

    /// Text delta for content_delta/thinking_delta events.
    public var delta: StreamDelta?

    /// Populated for atomic `tool_use` events.
    public var toolUse: StreamToolUse?

    /// Populated for `tool_use_start` events.
    public var toolUseStart: StreamToolUseStart?

    /// Populated for `tool_use_input_delta` events.
    public var toolUseInputDelta: StreamToolUseInputDelta?

    /// Populated for `tool_use_complete` events.
    public var toolUseComplete: StreamToolUseComplete?

    /// Usage information for `usage` events. Carries ``ChatUsage/reasoningTokens``
    /// beside ``ChatUsage/outputTokens``; never ``ChatUsage/cachedTokens``.
    public var usage: ChatUsage?

    /// Web-search grounding sources, on a `citations` event. The gateway
    /// sends it once, before the first content delta, on streams where
    /// search results were injected; empty on every other event.
    public var citations: [Citation]

    /// Populated for the `session` event that opens a
    /// `chatSessionStream`.
    public var session: StreamSession?

    /// The failure message, on `error`, `invalid_request` and `rate_limit`
    /// events, and on an `error` the SDK raises for a payload it could not
    /// parse.
    public var error: String?

    /// Whether this is the final event in the stream.
    public var done: Bool

    public init(
        eventType: String,
        delta: StreamDelta? = nil,
        toolUse: StreamToolUse? = nil,
        toolUseStart: StreamToolUseStart? = nil,
        toolUseInputDelta: StreamToolUseInputDelta? = nil,
        toolUseComplete: StreamToolUseComplete? = nil,
        usage: ChatUsage? = nil,
        citations: [Citation] = [],
        session: StreamSession? = nil,
        error: String? = nil,
        done: Bool = false
    ) {
        self.eventType = eventType
        self.delta = delta
        self.toolUse = toolUse
        self.toolUseStart = toolUseStart
        self.toolUseInputDelta = toolUseInputDelta
        self.toolUseComplete = toolUseComplete
        self.usage = usage
        self.citations = citations
        self.session = session
        self.error = error
        self.done = done
    }

    /// True when this event reports a failure, whichever of the three
    /// failure types the gateway used.
    public var isError: Bool { error != nil }

    /// Legacy accessor for eventType.
    public var type: String {
        get { eventType }
        set { eventType = newValue }
    }
}

// MARK: - Raw Stream Event (internal)

struct RawStreamEvent: Decodable {
    var type: String?
    var delta: StreamDelta?
    var id: String?
    var name: String?
    var input: [String: AnyCodable]?
    var message: String?
    var inputTokens: Int?
    var outputTokens: Int?
    var reasoningTokens: Int?
    var costTicks: Int?
    /// `partial_json` fragment from `tool_use_input_delta` events.
    var partialJSON: String?
    /// Carried by the `citations` event.
    var citations: [Citation]?
    /// Carried by the `session` event that opens a session stream.
    var sessionId: String?
    var compacted: Bool?
    // Single-envelope backend format: the whole response in one event.
    var content: [ContentBlock]?
    var usage: ChatUsage?
    var model: String?
    var stopReason: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case type, delta, id, name, input, message, content, usage, model, error, citations, compacted
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case costTicks = "cost_ticks"
        case partialJSON = "partial_json"
        case sessionId = "session_id"
        case stopReason = "stop_reason"
    }
}

import Foundation

// MARK: - Chat Request

/// Request body for the `/qai/v1/chat` endpoint.
public struct ChatRequest: Codable, Sendable {
    /// Model ID that determines provider routing (e.g. "claude-sonnet-4-6").
    public var model: String

    /// Conversation history.
    public var messages: [ChatMessage]

    /// Functions the model can call.
    public var tools: [ChatTool]?

    /// Enable server-sent event streaming.
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
    public var providerOptions: [String: [String: AnyCodable]]?

    /// Capability allowlist. Filters which client-declared tools are forwarded
    /// to the model by matching their names against the server's capability
    /// registry (e.g. `"file_read"`, `"code_execution"`).
    /// - `nil`: pass all tools through (backwards compatible).
    /// - `[]`: Safe Mode — drop all tools (pure chat).
    /// - non-empty: only tools whose names map to the allowed capabilities.
    public var capabilities: [String]?

    /// How much chain-of-thought a reasoning model runs before answering.
    /// One of `"none"`, `"low"`, `"medium"`, `"high"`, `"xhigh"`; `nil` =
    /// provider default (medium on GPT-5.5+). An unknown value is rejected
    /// with 400 by the gateway.
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
        capabilities: [String]? = nil,
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
        self.capabilities = capabilities
        self.reasoningEffort = reasoningEffort
        self.cachedContent = cachedContent
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature, capabilities
        case maxTokens = "max_tokens"
        case toolChoice = "tool_choice"
        case outputSchema = "output_schema"
        case providerOptions = "provider_options"
        case reasoningEffort = "reasoning_effort"
        case cachedContent = "cached_content"
    }
}

// MARK: - Chat Message

/// A single message in a chat conversation.
public struct ChatMessage: Codable, Sendable {
    /// The role of the message author.
    public var role: Role

    /// Plain text content of the message.
    public var content: String?

    /// Structured content blocks.
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
    /// Block type (e.g. "text", "thinking", "tool_use").
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

    /// MIME type for `"image"`/`"file"` blocks (e.g. `"image/png"`, `"application/pdf"`).
    public var mimeType: String?

    /// Original filename for `"file"` blocks.
    public var fileName: String?

    /// Remote resource URL for `"file_uri"` blocks (YouTube, `gs://`, etc.) —
    /// the model fetches it directly instead of receiving inline data.
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
/// Wire shape is FLAT to match the Go gateway contract
/// (`internal/server/convert.go` `ChatTool`): `{"name","description","parameters","strict"}`.
/// The previous SDK emitted the OpenAI/Anthropic nested shape
/// `{"type":"function","function":{...}}`, which the backend silently dropped
/// (it has no custom UnmarshalJSON), so every tool definition was lost on the
/// wire. This is a breaking change but the prior shape never worked.
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
}

// MARK: - Chat Usage

/// Token usage and cost information for a chat request.
public struct ChatUsage: Codable, Sendable {
    /// Number of input tokens processed.
    public var inputTokens: Int

    /// Portion of `inputTokens` served from a prompt cache (billed at the
    /// cheaper cached-read rate). Present on providers that report cache hits.
    public var cachedTokens: Int

    /// Number of output tokens generated.
    public var outputTokens: Int

    /// Chain-of-thought tokens billed on top of `outputTokens` for reasoning
    /// models (Gemini/Vertex report these separately). Zero when folded in.
    public var reasoningTokens: Int

    /// Cost in ticks (10 billion ticks = $1 USD). Optional — Zig backend may not send this.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedTokens = "cached_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case costTicks = "cost_ticks"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        cachedTokens = try container.decodeIfPresent(Int.self, forKey: .cachedTokens) ?? 0
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        reasoningTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningTokens) ?? 0
        costTicks = try container.decodeIfPresent(Int.self, forKey: .costTicks) ?? 0
    }

    public init(inputTokens: Int, outputTokens: Int, costTicks: Int = 0, cachedTokens: Int = 0, reasoningTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.cachedTokens = cachedTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.costTicks = costTicks
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
    /// Unique response ID.
    public var id: String

    /// Model used for generation.
    public var model: String

    /// Content blocks in the response.
    public var content: [ContentBlock]

    /// Token usage and cost information.
    public var usage: ChatUsage

    /// Reason the model stopped generating.
    public var stopReason: String

    /// Citations from web search (when search is enabled via provider_options).
    public var citations: [Citation]?

    /// Provider-side reasoning-state tag (OpenAI Responses API). Echo it back
    /// on the corresponding assistant ``ChatMessage/phase`` of the next turn
    /// to preserve reasoning state across replay. `nil` when the provider
    /// doesn't surface phase.
    public var phase: String?

    /// Unique request ID. The Go gateway body does NOT carry `request_id` at
    /// the top level (it's only in the `X-QAI-Request-Id` header, and the body
    /// `id` field holds it). Decoded as optional and populated from
    /// ``ResponseMeta`` after decode via ``apply(_:)-4gior``.
    public var requestId: String?

    /// Cost in ticks. The Go gateway body does NOT carry `cost_ticks` at the
    /// top level (it lives inside `usage` and the `X-QAI-Cost-Ticks` header).
    /// Decoded as optional and populated from ``ResponseMeta`` after decode.
    public var costTicks: Int?

    /// Post-charge wallet balance in ticks (from `X-QAI-Balance-After`).
    /// Signed: the claw-back path can make it negative. Populated from
    /// ``ResponseMeta`` after decode.
    public var balanceAfter: Int64?

    /// True when this response was served from the semantic cache
    /// (`convert.go` sets `cached` on cache hits). `nil` on fresh responses.
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
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
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
    /// cost and balance without reading headers themselves.
    public mutating func apply(_ meta: ResponseMeta) {
        if requestId == nil { requestId = meta.requestId.isEmpty ? nil : meta.requestId }
        if costTicks == nil { costTicks = Int(truncatingIfNeeded: meta.costTicks) }
        if model.isEmpty { model = meta.model }
        if balanceAfter == nil { balanceAfter = meta.balanceAfter }
    }

    /// True when the model is requesting tool execution
    /// (`stopReason == StopReason.toolUse`). The gateway guarantees this
    /// whenever tool_use blocks are present, across every provider.
    public var isToolUse: Bool { stopReason == StopReason.toolUse }

    /// True when a safety classifier declined the request
    /// (`stopReason == StopReason.refusal`). On a refusal the content may be
    /// empty or a partial prefix that should be discarded — check this before
    /// reading ``text``. (Claude Fable 5 can refuse with an HTTP 200.)
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
}

/// A tool use event in a streaming response.
public struct StreamToolUse: Codable, Sendable {
    /// Tool call ID.
    public var id: String

    /// Tool name.
    public var name: String

    /// Tool input arguments.
    public var input: [String: AnyCodable]
}

/// A single event from a streaming chat response.
public struct StreamEvent: Sendable {
    /// Event type (e.g. "content_delta", "thinking_delta", "tool_use", "usage", "done", "error").
    public var eventType: String

    /// Text delta for content_delta/thinking_delta events.
    public var delta: StreamDelta?

    /// Tool use information for `tool_use` / `tool_use_start` /
    /// `tool_use_complete` events. For `tool_use_start` the `input` is empty
    /// (args haven't streamed yet); for `tool_use_complete` it carries the
    /// server-accumulated, fully-parsed arguments.
    public var toolUse: StreamToolUse?

    /// Raw argument-JSON fragment for `tool_use_input_delta` events. A partial
    /// fragment that may not parse on its own; concatenate across deltas for
    /// the full args, or ignore and wait for `tool_use_complete`.
    public var partialJSON: String?

    /// Usage information for usage events.
    public var usage: ChatUsage?

    /// Error message for error events.
    public var error: String?

    /// Whether this is the final event in the stream.
    public var done: Bool

    public init(
        eventType: String,
        delta: StreamDelta? = nil,
        toolUse: StreamToolUse? = nil,
        partialJSON: String? = nil,
        usage: ChatUsage? = nil,
        error: String? = nil,
        done: Bool = false
    ) {
        self.eventType = eventType
        self.delta = delta
        self.toolUse = toolUse
        self.partialJSON = partialJSON
        self.usage = usage
        self.error = error
        self.done = done
    }

    /// Backward-compatible init using `type` parameter name.
    public init(
        type: String,
        delta: StreamDelta? = nil,
        toolUse: StreamToolUse? = nil,
        partialJSON: String? = nil,
        usage: ChatUsage? = nil,
        error: String? = nil,
        done: Bool = false
    ) {
        self.eventType = type
        self.delta = delta
        self.toolUse = toolUse
        self.partialJSON = partialJSON
        self.usage = usage
        self.error = error
        self.done = done
    }

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
    // Zig backend format: full response in one SSE event
    var content: [ContentBlock]?
    var usage: ChatUsage?
    var model: String?
    var stopReason: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case type, delta, id, name, input, message, content, usage, model, error
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case costTicks = "cost_ticks"
        case partialJSON = "partial_json"
        case stopReason = "stop_reason"
    }
}

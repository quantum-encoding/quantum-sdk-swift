import Foundation

// MARK: - Tool Result

/// A tool result to feed back into the session.
public struct ToolResult: Codable, Sendable {
    /// The tool_use ID this result corresponds to.
    public var toolCallId: String

    /// The result content.
    public var content: String

    /// Whether this result is an error.
    public var isError: Bool?

    public init(toolCallId: String, content: String, isError: Bool? = nil) {
        self.toolCallId = toolCallId
        self.content = content
        self.isError = isError
    }

    enum CodingKeys: String, CodingKey {
        case content
        case toolCallId = "tool_call_id"
        case isError = "is_error"
    }
}

/// Legacy alias.
public typealias SessionToolResult = ToolResult

// MARK: - Session Chat Request

/// Request body for the `/qai/v1/chat/session` endpoint.
public struct SessionChatRequest: Codable, Sendable {
    /// Session ID. Omit to create a new session.
    public var sessionId: String?

    /// Model to use for generation.
    public var model: String?

    /// The user message.
    public var message: String

    /// Tools the model can call.
    public var tools: [ChatTool]?

    /// Tool results from previous calls.
    public var toolResults: [ToolResult]?

    /// Streaming flag on the wire. The method sets it: `chatSession` sends
    /// `false` and `chatSessionStream` sends `true`, overwriting whatever
    /// is here, so the buffered call never receives an SSE body it cannot
    /// decode.
    public var stream: Bool?

    /// System prompt.
    public var systemPrompt: String?

    /// Context management configuration.
    public var contextConfig: ContextConfig?

    /// How much chain-of-thought a reasoning model runs before answering.
    /// One of `"none"`, `"low"`, `"medium"`, `"high"`, `"xhigh"`, `"max"`;
    /// `nil` = provider default. Mirrors ``ChatRequest/reasoningEffort``.
    public var reasoningEffort: String?

    /// Provider-specific settings.
    public var providerOptions: [String: [String: AnyCodable]]?

    public init(
        message: String,
        sessionId: String? = nil,
        model: String? = nil,
        tools: [ChatTool]? = nil,
        toolResults: [ToolResult]? = nil,
        stream: Bool? = nil,
        systemPrompt: String? = nil,
        contextConfig: ContextConfig? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil,
        reasoningEffort: String? = nil
    ) {
        self.message = message
        self.sessionId = sessionId
        self.model = model
        self.tools = tools
        self.toolResults = toolResults
        self.stream = stream
        self.systemPrompt = systemPrompt
        self.contextConfig = contextConfig
        self.providerOptions = providerOptions
        self.reasoningEffort = reasoningEffort
    }

    enum CodingKeys: String, CodingKey {
        case message, model, tools, stream
        case sessionId = "session_id"
        case toolResults = "tool_results"
        case systemPrompt = "system_prompt"
        case contextConfig = "context_config"
        case providerOptions = "provider_options"
        case reasoningEffort = "reasoning_effort"
    }
}

// MARK: - Context Config

/// Configuration for session context management. These are the fields the
/// gateway reads; an omitted field keeps the server default (compaction at
/// 100 000 tokens, the default summary).
public struct ContextConfig: Codable, Sendable {
    /// Token threshold that triggers automatic compaction.
    public var compactAtTokens: Int64?

    /// Number of recent tool call/result pairs to keep uncompacted.
    public var keepRecentToolResults: Int?

    /// Strip thinking blocks from older assistant turns.
    public var clearThinking: Bool?

    /// Summarization strategy. `"plan_and_tools"` is the only strategy the
    /// gateway distinguishes (it keeps the plan and tool history in the
    /// summary); any other value, unset included, gets the default summary.
    public var summarizeStrategy: String?

    /// Model to use for summarization (default: gemini-2.5-flash).
    public var summarizeModel: String?

    public init(
        compactAtTokens: Int64? = nil,
        keepRecentToolResults: Int? = nil,
        clearThinking: Bool? = nil,
        summarizeStrategy: String? = nil,
        summarizeModel: String? = nil
    ) {
        self.compactAtTokens = compactAtTokens
        self.keepRecentToolResults = keepRecentToolResults
        self.clearThinking = clearThinking
        self.summarizeStrategy = summarizeStrategy
        self.summarizeModel = summarizeModel
    }

    enum CodingKeys: String, CodingKey {
        case compactAtTokens = "compact_at_tokens"
        case keepRecentToolResults = "keep_recent_tool_results"
        case clearThinking = "clear_thinking"
        case summarizeStrategy = "summarize_strategy"
        case summarizeModel = "summarize_model"
    }
}

// MARK: - Session Context

/// Context metadata returned with session responses.
public struct SessionContext: Codable, Sendable {
    /// Number of conversation turns in the session.
    public var turnCount: Int64

    /// Estimated total tokens in the session context.
    public var estimatedTokens: Int64

    /// Whether context was compacted during this turn. The key is absent
    /// on the wire on every turn that was not compacted.
    public var compacted: Bool

    /// Note about the compaction, if any.
    public var compactionNote: String?

    /// Number of stale tool results that were cleared, when the gateway
    /// reports it.
    public var toolsCleared: Int?

    enum CodingKeys: String, CodingKey {
        case compacted
        case turnCount = "turn_count"
        case estimatedTokens = "estimated_tokens"
        case compactionNote = "compaction_note"
        case toolsCleared = "tools_cleared"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        turnCount = try c.decodeIfPresent(Int64.self, forKey: .turnCount) ?? 0
        estimatedTokens = try c.decodeIfPresent(Int64.self, forKey: .estimatedTokens) ?? 0
        compacted = try c.decodeIfPresent(Bool.self, forKey: .compacted) ?? false
        compactionNote = try c.decodeIfPresent(String.self, forKey: .compactionNote)
        toolsCleared = try c.decodeIfPresent(Int.self, forKey: .toolsCleared)
    }

    public init(turnCount: Int64, estimatedTokens: Int64, compacted: Bool = false, compactionNote: String? = nil, toolsCleared: Int? = nil) {
        self.turnCount = turnCount
        self.estimatedTokens = estimatedTokens
        self.compacted = compacted
        self.compactionNote = compactionNote
        self.toolsCleared = toolsCleared
    }
}

/// Legacy alias.
public typealias ContextMetadata = SessionContext

// MARK: - Session Chat Response

/// Response from the `/qai/v1/chat/session` endpoint.
public struct SessionChatResponse: Codable, Sendable {
    /// The session ID (use this for follow-up messages).
    public var sessionId: String

    /// The chat response.
    public var response: ChatResponse

    /// Context metadata.
    public var context: SessionContext

    enum CodingKeys: String, CodingKey {
        case response, context
        case sessionId = "session_id"
    }
}

// MARK: - Session Chat Stream

/// A streaming session turn: the session it belongs to, and the events.
///
/// The gateway sends the session id in the `X-QAI-Session-Id` header and
/// again as the first event (`type: "session"`, see
/// ``StreamEvent/session``); then `content_delta` / `thinking_delta`, a
/// `usage` event and `done`. Tool calls are not streamed on this route.
public struct SessionChatStream: Sendable {
    /// The session identifier (newly created when the request had none).
    public var sessionId: String

    /// The events, in the same shape as `chatStream`.
    public var events: AsyncThrowingStream<StreamEvent, any Error>

    public init(sessionId: String, events: AsyncThrowingStream<StreamEvent, any Error>) {
        self.sessionId = sessionId
        self.events = events
    }
}

import Foundation

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
    public var toolResults: [SessionToolResult]?

    /// Enable streaming.
    public var stream: Bool?

    /// System prompt.
    public var systemPrompt: String?

    /// Context management configuration.
    public var contextConfig: ContextConfig?

    /// Provider-specific settings.
    public var providerOptions: [String: [String: AnyCodable]]?

    public init(
        message: String,
        sessionId: String? = nil,
        model: String? = nil,
        tools: [ChatTool]? = nil,
        toolResults: [SessionToolResult]? = nil,
        stream: Bool? = nil,
        systemPrompt: String? = nil,
        contextConfig: ContextConfig? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case message, model, tools, stream
        case sessionId = "session_id"
        case toolResults = "tool_results"
        case systemPrompt = "system_prompt"
        case contextConfig = "context_config"
        case providerOptions = "provider_options"
    }
}

// MARK: - Session Tool Result

/// A tool result returned in a session chat request.
public struct SessionToolResult: Codable, Sendable {
    /// The tool call ID this result corresponds to.
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

// MARK: - Context Config

/// Configuration for session context management.
public struct ContextConfig: Codable, Sendable {
    /// Maximum token budget for context.
    public var maxTokens: Int?

    /// Whether to automatically compact context when it exceeds the budget.
    public var autoCompact: Bool?

    public init(maxTokens: Int? = nil, autoCompact: Bool? = nil) {
        self.maxTokens = maxTokens
        self.autoCompact = autoCompact
    }

    enum CodingKeys: String, CodingKey {
        case maxTokens = "max_tokens"
        case autoCompact = "auto_compact"
    }
}

// MARK: - Context Metadata

/// Metadata about the session context state.
public struct ContextMetadata: Codable, Sendable {
    /// Number of conversation turns.
    public var turnCount: Int

    /// Estimated token count of the context.
    public var estimatedTokens: Int

    /// Whether the context was compacted.
    public var compacted: Bool

    /// Note about any compaction that occurred.
    public var compactionNote: String?

    enum CodingKeys: String, CodingKey {
        case compacted
        case turnCount = "turn_count"
        case estimatedTokens = "estimated_tokens"
        case compactionNote = "compaction_note"
    }
}

// MARK: - Session Chat Response

/// Response from the `/qai/v1/chat/session` endpoint.
public struct SessionChatResponse: Codable, Sendable {
    /// The session ID (use this for follow-up messages).
    public var sessionId: String

    /// The chat response.
    public var response: ChatResponse

    /// Context metadata.
    public var context: ContextMetadata

    enum CodingKeys: String, CodingKey {
        case response, context
        case sessionId = "session_id"
    }
}

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

    /// Provider-specific settings (e.g. Anthropic thinking, xAI search).
    public var providerOptions: [String: [String: AnyCodable]]?

    public init(
        model: String,
        messages: [ChatMessage],
        tools: [ChatTool]? = nil,
        stream: Bool? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        providerOptions: [String: [String: AnyCodable]]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.providerOptions = providerOptions
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, stream, temperature
        case maxTokens = "max_tokens"
        case providerOptions = "provider_options"
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

    public init(
        role: Role,
        content: String? = nil,
        contentBlocks: [ContentBlock]? = nil,
        toolCallId: String? = nil,
        isError: Bool? = nil
    ) {
        self.role = role
        self.content = content
        self.contentBlocks = contentBlocks
        self.toolCallId = toolCallId
        self.isError = isError
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
        case role, content
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

    public init(
        blockType: String,
        text: String? = nil,
        id: String? = nil,
        name: String? = nil,
        input: [String: AnyCodable]? = nil,
        thoughtSignature: String? = nil
    ) {
        self.blockType = blockType
        self.text = text
        self.id = id
        self.name = name
        self.input = input
        self.thoughtSignature = thoughtSignature
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
        case text, id, name, input
        case blockType = "type"
        case thoughtSignature = "thought_signature"
    }
}

// MARK: - Chat Tool

/// A function tool definition for chat completions.
public struct ChatTool: Codable, Sendable {
    /// Tool type (always "function").
    public var type: String

    /// Function definition.
    public var function: FunctionDefinition

    public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil) {
        self.type = "function"
        self.function = FunctionDefinition(name: name, description: description, parameters: parameters)
    }

    public struct FunctionDefinition: Codable, Sendable {
        public var name: String
        public var description: String?
        public var parameters: [String: AnyCodable]?

        public init(name: String, description: String? = nil, parameters: [String: AnyCodable]? = nil) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
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

    /// Number of output tokens generated.
    public var outputTokens: Int

    /// Cost in ticks (10 billion ticks = $1 USD).
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costTicks = "cost_ticks"
    }
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

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage, citations
        case stopReason = "stop_reason"
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }

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

    /// Tool use information for tool_use events.
    public var toolUse: StreamToolUse?

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
        usage: ChatUsage? = nil,
        error: String? = nil,
        done: Bool = false
    ) {
        self.eventType = eventType
        self.delta = delta
        self.toolUse = toolUse
        self.usage = usage
        self.error = error
        self.done = done
    }

    /// Backward-compatible init using `type` parameter name.
    public init(
        type: String,
        delta: StreamDelta? = nil,
        toolUse: StreamToolUse? = nil,
        usage: ChatUsage? = nil,
        error: String? = nil,
        done: Bool = false
    ) {
        self.eventType = type
        self.delta = delta
        self.toolUse = toolUse
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
    var costTicks: Int?

    enum CodingKeys: String, CodingKey {
        case type, delta, id, name, input, message
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costTicks = "cost_ticks"
    }
}

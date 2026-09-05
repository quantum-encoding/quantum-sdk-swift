import Foundation

// Two different surfaces live here:
//
// - `AgentRequest` / `AgentResponse` are `POST /qai/v1/agent`: one
//   non-streaming model turn with tool-call passthrough. The gateway never
//   executes tools; it returns whatever `tool_use` blocks the model produced,
//   the client runs them and sends the results back as `tool` messages on the
//   next call. See ``QuantumClient/agentStep(_:)``.
// - `MissionRequest` is `POST /qai/v1/missions`: a server-side conductor and
//   worker run streamed back as ``AgentStreamEvent`` values. See
//   ``QuantumClient/missionRun(_:)``.
//
// For a server-side loop that also executes tools in the gateway's sandbox,
// see ``QuantumClient/cloudrun(_:)``.

// MARK: - Agent (single turn, client-executed tools)

/// A tool call made by the model.
///
/// Returned in ``AgentResponse/toolUse``, and sent back on an `assistant`
/// ``AgentMessage`` when the conversation is replayed so the model sees its
/// own call before the `tool` result that answers it.
public struct AgentToolUse: Codable, Sendable {
    /// Call identifier. A `tool` message answers it via
    /// ``AgentMessage/toolCallId``.
    public var id: String

    /// Name of the tool called.
    public var name: String

    /// Parsed arguments, as a JSON object.
    public var input: [String: AnyCodable]

    public init(id: String, name: String, input: [String: AnyCodable] = [:]) {
        self.id = id
        self.name = name
        self.input = input
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        input = try container.decodeIfPresent([String: AnyCodable].self, forKey: .input) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case id, name, input
    }
}

/// One message in an agent conversation.
public struct AgentMessage: Codable, Sendable {
    /// `"user"`, `"assistant"`, `"tool"`, or `"system"`. `system` messages
    /// are folded into the system prompt; an unknown role is sent as `user`.
    public var role: String

    /// Text content. For a `tool` message this is the tool's output.
    public var content: String

    /// For `tool` messages: the ``AgentToolUse/id`` this result answers.
    public var toolCallId: String

    /// For `assistant` messages replayed from history: the tool calls the
    /// model made on that turn.
    public var toolUse: [AgentToolUse]

    /// For `tool` messages: whether the tool failed.
    public var isError: Bool

    public init(
        role: String,
        content: String = "",
        toolCallId: String = "",
        toolUse: [AgentToolUse] = [],
        isError: Bool = false
    ) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolUse = toolUse
        self.isError = isError
    }

    /// A `user` message.
    public static func user(_ content: String) -> AgentMessage {
        AgentMessage(role: "user", content: content)
    }

    /// A `system` message. The gateway appends it to the system prompt.
    public static func system(_ content: String) -> AgentMessage {
        AgentMessage(role: "system", content: content)
    }

    /// An `assistant` message replaying a previous turn: its text and the
    /// tool calls it made.
    public static func assistant(_ content: String, toolUse: [AgentToolUse] = []) -> AgentMessage {
        AgentMessage(role: "assistant", content: content, toolUse: toolUse)
    }

    /// A `tool` message carrying the result of one tool call. Consecutive
    /// tool results are grouped onto one provider turn by the gateway.
    public static func toolResult(toolCallId: String, content: String, isError: Bool = false) -> AgentMessage {
        AgentMessage(role: "tool", content: content, toolCallId: toolCallId, isError: isError)
    }

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCallId = "tool_call_id"
        case toolUse = "tool_use"
        case isError = "is_error"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId) ?? ""
        toolUse = try container.decodeIfPresent([AgentToolUse].self, forKey: .toolUse) ?? []
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
    }

    /// Empty strings, empty lists and a false `is_error` are omitted, so the
    /// body carries only what the handler reads for that role.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        if !content.isEmpty { try container.encode(content, forKey: .content) }
        if !toolCallId.isEmpty { try container.encode(toolCallId, forKey: .toolCallId) }
        if !toolUse.isEmpty { try container.encode(toolUse, forKey: .toolUse) }
        if isError { try container.encode(isError, forKey: .isError) }
    }
}

/// A tool the model may call. The gateway forwards the definition to the
/// provider; execution is the client's job.
public struct AgentToolDef: Codable, Sendable {
    /// Tool name. Also the key the `capabilities` allowlist matches on.
    public var name: String

    /// What the tool does.
    public var description: String?

    /// JSON Schema for the tool's input, as an object. Omitted when nil.
    public var inputSchema: [String: AnyCodable]?

    public init(name: String, description: String? = nil, inputSchema: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

/// Request body for `POST /qai/v1/agent`.
public struct AgentRequest: Codable, Sendable {
    /// Model to run the turn on. Required; unknown models are refused with
    /// 400 `unknown_model`.
    public var model: String

    /// The conversation so far. Required and non-empty; at most 1000
    /// messages and 2 MB of content in total.
    public var messages: [AgentMessage]

    /// Tools the model may call. At most 256. An empty list is omitted from
    /// the body.
    public var tools: [AgentToolDef]

    /// Tool allowlist by name. Three-state: `nil` forwards every tool, `[]`
    /// forwards none (safe mode), and a non-empty list forwards only the
    /// named ones.
    public var capabilities: [String]?

    /// System prompt. `system` messages are appended to it.
    public var systemPrompt: String?

    /// Maximum output tokens.
    public var maxTokens: Int?

    /// Sampling temperature.
    public var temperature: Double?

    public init(
        model: String,
        messages: [AgentMessage],
        tools: [AgentToolDef] = [],
        capabilities: [String]? = nil,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.capabilities = capabilities
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, tools, capabilities, temperature
        case systemPrompt = "system_prompt"
        case maxTokens = "max_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(String.self, forKey: .model)
        messages = try container.decodeIfPresent([AgentMessage].self, forKey: .messages) ?? []
        tools = try container.decodeIfPresent([AgentToolDef].self, forKey: .tools) ?? []
        capabilities = try container.decodeIfPresent([String].self, forKey: .capabilities)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt)
        maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        if !tools.isEmpty { try container.encode(tools, forKey: .tools) }
        try container.encodeIfPresent(capabilities, forKey: .capabilities)
        try container.encodeIfPresent(systemPrompt, forKey: .systemPrompt)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
        try container.encodeIfPresent(temperature, forKey: .temperature)
    }
}

/// One content block in an ``AgentResponse``.
public struct AgentContentPart: Codable, Sendable {
    /// Block type: `"text"`.
    public var type: String

    /// The text.
    public var text: String

    public init(type: String = "text", text: String = "") {
        self.type = type
        self.text = text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case type, text
    }
}

/// Token usage for one agent turn.
public struct AgentUsage: Codable, Sendable {
    /// Prompt tokens.
    public var inputTokens: Int64

    /// Completion tokens.
    public var outputTokens: Int64

    public init(inputTokens: Int64 = 0, outputTokens: Int64 = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int64.self, forKey: .inputTokens) ?? 0
        outputTokens = try container.decodeIfPresent(Int64.self, forKey: .outputTokens) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// Response from `POST /qai/v1/agent`: a single JSON document, never a
/// stream.
public struct AgentResponse: Codable, Sendable {
    /// The gateway request id.
    public var id: String

    /// Model that ran the turn.
    public var model: String

    /// Why the model stopped. `"tool_use"` whenever ``toolUse`` is
    /// non-empty, otherwise the provider's reason (`"end_turn"` when the
    /// provider gave none).
    public var stopReason: String

    /// Text blocks. Empty when the model only called tools.
    @NullToEmpty public var content: [AgentContentPart]

    /// Tool calls to execute. Present only when the model called tools.
    @NullToEmpty public var toolUse: [AgentToolUse]

    /// Token usage for the turn.
    public var usage: AgentUsage

    /// Cost of the turn in ticks, read from the `X-QAI-Cost-Ticks` response
    /// header. Zero when the gateway sent none.
    public var costTicks: Int64

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        stopReason = try container.decodeIfPresent(String.self, forKey: .stopReason) ?? ""
        _content = try container.decode(NullToEmpty<AgentContentPart>.self, forKey: .content)
        _toolUse = try container.decode(NullToEmpty<AgentToolUse>.self, forKey: .toolUse)
        usage = try container.decodeIfPresent(AgentUsage.self, forKey: .usage) ?? AgentUsage()
        costTicks = try container.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, model, content, usage
        case stopReason = "stop_reason"
        case toolUse = "tool_use"
        case costTicks = "cost_ticks"
    }

    /// All text blocks joined.
    public var text: String {
        content.filter { $0.type == "text" }.map(\.text).joined()
    }

    /// This turn as an `assistant` message, for replaying into the next
    /// request's history ahead of the tool results.
    public func toMessage() -> AgentMessage {
        AgentMessage.assistant(text, toolUse: toolUse)
    }
}

// MARK: - Agent Stream Event

/// A single event from a mission, Cloud Run, managed-agents or inference SSE
/// stream: the wire object's `type` plus every other top-level key, kept in
/// ``data`` for the caller to interpret.
///
/// Two events are synthesised client-side: `done` when the `[DONE]` sentinel
/// arrives, and `error` when a `data:` payload does not parse or the
/// transport fails mid-stream. The latter carries `error` (the message) and
/// `transport: true` in ``data``; the stream ends after it, so a run that
/// stops without a preceding `done` or result event was cut off.
public struct AgentStreamEvent: Codable, Sendable {
    /// Event type (e.g. "agent_step", "mission_started", "task_completed",
    /// "error", "done"). Empty when the payload had no `type`.
    public var eventType: String

    /// Every top-level key of the payload other than `type`.
    public var data: [String: AnyCodable]

    public init(eventType: String, data: [String: AnyCodable] = [:]) {
        self.eventType = eventType
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var object = try container.decode([String: AnyCodable].self)
        eventType = (object.removeValue(forKey: "type")?.value as? String) ?? ""
        data = object
    }

    public func encode(to encoder: Encoder) throws {
        var object = data
        object["type"] = AnyCodable(eventType)
        var container = encoder.singleValueContainer()
        try container.encode(object)
    }

    /// The failure reason on an error-class event: the `error` key, else the
    /// `message` key the mission routes use for `mission_failed`.
    public var error: String? {
        data["error"]?.value as? String ?? data["message"]?.value as? String
    }

    /// The `message` text carried by lifecycle events, or nil.
    public var message: String? {
        data["message"]?.value as? String
    }

    /// True for the synthesised `done` event.
    public var isDone: Bool { eventType == "done" }

    /// True for `error` events, including the two synthesised ones.
    public var isError: Bool { eventType == "error" }

    /// True when the stream was cut by a transport failure.
    public var isTransportError: Bool {
        eventType == "error" && (data["transport"]?.value as? Bool ?? false)
    }
}

// MARK: - Mission Worker

/// Describes a named worker for a mission (map keyed by name).
public struct MissionWorker: Codable, Sendable {
    /// Model ID for this worker.
    public var model: String?

    /// Cost tier: `"cheap"`, `"mid"`, `"expensive"`. Anything else,
    /// including an empty string, is priced and routed as `cheap`.
    public var tier: String?

    /// Description of this worker's purpose.
    public var description: String?

    /// Worker to escalate to on failure (e.g. cheap coder to expensive coder).
    public var escalateTo: String?

    /// Max retries before escalating (default 1).
    public var maxRetries: Int?

    public init(
        model: String? = nil,
        tier: String? = nil,
        description: String? = nil,
        escalateTo: String? = nil,
        maxRetries: Int? = nil
    ) {
        self.model = model
        self.tier = tier
        self.description = description
        self.escalateTo = escalateTo
        self.maxRetries = maxRetries
    }

    enum CodingKeys: String, CodingKey {
        case model, tier, description
        case escalateTo = "escalate_to"
        case maxRetries = "max_retries"
    }
}

// MARK: - Mission Request

/// Request body for `POST /qai/v1/missions` (streamed run).
public struct MissionRequest: Codable, Sendable {
    /// The high-level goal for the mission. Required.
    public var goal: String

    /// Execution strategy hint: `"wave"` (default), `"dag"`, `"mapreduce"`,
    /// `"refinement"`, `"branch"`, `"codegen"` (dedicated pipeline, the only
    /// strategy honouring `workspacePath`, `buildCommand` and
    /// `deploymentId`), or the pre-built teams `"coding_team"`,
    /// `"security_team"`, `"pipeline"` (which read `workers` only for named
    /// overrides).
    public var strategy: String?

    /// Model for the conductor.
    public var conductorModel: String?

    /// Conductor tier override. Default: "expensive". Set to "cheap" when
    /// using a fast router as conductor; it decides what the budget guard
    /// prices the conductor at.
    public var conductorTier: String?

    /// Named workers (key = worker name).
    public var workers: [String: MissionWorker]?

    /// Maximum number of steps (default 25, ceiling 50).
    public var maxSteps: Int?

    /// System prompt for the conductor. Applied only when a session is
    /// created; a re-used `sessionId` ignores it.
    public var systemPrompt: String?

    /// Session identifier for continuity. Must belong to the caller (404
    /// otherwise).
    public var sessionId: String?

    /// Context management configuration. Applied only when a session is
    /// created; a re-used `sessionId` ignores it.
    public var contextConfig: ContextConfig?

    /// Deployment whose endpoint worker inference is routed to. Honoured
    /// only when `strategy` is `"codegen"`; ignored otherwise.
    public var deploymentId: String?

    /// Build command to run after codegen (e.g. `"cargo build"`). Honoured
    /// only when `strategy` is `"codegen"`; ignored otherwise.
    public var buildCommand: String?

    /// Directory the codegen pipeline writes generated files to, on the
    /// gateway's own filesystem. Interpreted relative to the caller's
    /// per-user workspace root; an absolute path or any `..` segment is
    /// rejected with 400 `invalid_workspace_path`. It never names a
    /// directory on the caller's machine. Honoured only when `strategy` is
    /// `"codegen"`; ignored otherwise.
    public var workspacePath: String?

    /// Reference material for the conductor: uploaded files, pasted docs.
    /// Free-form. Prepended to ``goal`` only when ``useContext`` is true and
    /// this is non-empty, so the harness sees context followed by the goal.
    public var context: String?

    /// Whether ``context`` is prepended to the goal. False or absent leaves
    /// the goal as written, whatever ``context`` holds.
    public var useContext: Bool?

    public init(
        goal: String,
        strategy: String? = nil,
        conductorModel: String? = nil,
        conductorTier: String? = nil,
        workers: [String: MissionWorker]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        sessionId: String? = nil,
        contextConfig: ContextConfig? = nil,
        deploymentId: String? = nil,
        buildCommand: String? = nil,
        workspacePath: String? = nil,
        context: String? = nil,
        useContext: Bool? = nil
    ) {
        self.goal = goal
        self.strategy = strategy
        self.conductorModel = conductorModel
        self.conductorTier = conductorTier
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
        self.sessionId = sessionId
        self.contextConfig = contextConfig
        self.deploymentId = deploymentId
        self.buildCommand = buildCommand
        self.workspacePath = workspacePath
        self.context = context
        self.useContext = useContext
    }

    enum CodingKeys: String, CodingKey {
        case goal, strategy, workers, context
        case conductorModel = "conductor_model"
        case conductorTier = "conductor_tier"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
        case sessionId = "session_id"
        case contextConfig = "context_config"
        case deploymentId = "deployment_id"
        case buildCommand = "build_command"
        case workspacePath = "workspace_path"
        case useContext = "use_context"
    }
}

// MARK: - Mission Worker Config (legacy alias)

/// Configuration for a mission worker (legacy alias).
public typealias MissionWorkerConfig = MissionWorker

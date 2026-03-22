import Foundation

// MARK: - Agent Request

/// Request body for the `/qai/v1/agent` endpoint.
public struct AgentRequest: Codable, Sendable {
    /// The task or goal for the agent to accomplish.
    public var task: String

    /// Model for the conductor (default: server picks).
    public var conductorModel: String?

    /// Worker configurations.
    public var workers: [AgentWorkerConfig]?

    /// Maximum number of orchestration steps.
    public var maxSteps: Int?

    /// System prompt for the conductor.
    public var systemPrompt: String?

    public init(
        task: String,
        conductorModel: String? = nil,
        workers: [AgentWorkerConfig]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil
    ) {
        self.task = task
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case task, workers
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
    }
}

// MARK: - Agent Worker Config

/// Configuration for an agent worker.
public struct AgentWorkerConfig: Codable, Sendable {
    /// Worker name.
    public var name: String

    /// Model to use for this worker.
    public var model: String?

    /// Tools available to this worker.
    public var tools: [ChatTool]?

    /// System prompt for this worker.
    public var systemPrompt: String?

    public init(name: String, model: String? = nil, tools: [ChatTool]? = nil, systemPrompt: String? = nil) {
        self.name = name
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case name, model, tools
        case systemPrompt = "system_prompt"
    }
}

// MARK: - Agent Event

/// A single event from an agent orchestration stream.
public struct AgentEvent: Sendable {
    /// Event type (e.g. "conductor", "worker_start", "content_delta", "done").
    public var type: String

    /// Whether this is the final event.
    public var done: Bool

    /// Worker name (if applicable).
    public var worker: String?

    /// Content text.
    public var content: String?

    /// Tool use information.
    public var toolUse: StreamToolUse?

    /// Error message.
    public var error: String?

    public init(
        type: String,
        done: Bool = false,
        worker: String? = nil,
        content: String? = nil,
        toolUse: StreamToolUse? = nil,
        error: String? = nil
    ) {
        self.type = type
        self.done = done
        self.worker = worker
        self.content = content
        self.toolUse = toolUse
        self.error = error
    }
}

// MARK: - Mission Request

/// Request body for the `/qai/v1/missions` endpoint.
public struct MissionRequest: Codable, Sendable {
    /// The goal for the mission.
    public var goal: String

    /// Model for the conductor.
    public var conductorModel: String?

    /// Worker configurations.
    public var workers: [MissionWorkerConfig]?

    /// Maximum orchestration steps.
    public var maxSteps: Int?

    public init(
        goal: String,
        conductorModel: String? = nil,
        workers: [MissionWorkerConfig]? = nil,
        maxSteps: Int? = nil
    ) {
        self.goal = goal
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
    }

    enum CodingKeys: String, CodingKey {
        case goal, workers
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
    }
}

// MARK: - Mission Worker Config

/// Configuration for a mission worker.
public struct MissionWorkerConfig: Codable, Sendable {
    /// Worker name.
    public var name: String

    /// Model to use for this worker.
    public var model: String?

    /// Tools available to this worker.
    public var tools: [ChatTool]?

    /// System prompt for this worker.
    public var systemPrompt: String?

    public init(name: String, model: String? = nil, tools: [ChatTool]? = nil, systemPrompt: String? = nil) {
        self.name = name
        self.model = model
        self.tools = tools
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case name, model, tools
        case systemPrompt = "system_prompt"
    }
}

// MARK: - Mission Event

/// A single event from a mission orchestration stream.
public struct MissionEvent: Sendable {
    /// Event type.
    public var type: String

    /// Whether this is the final event.
    public var done: Bool

    /// Worker name (if applicable).
    public var worker: String?

    /// Content text.
    public var content: String?

    /// Tool use information.
    public var toolUse: StreamToolUse?

    /// Error message.
    public var error: String?

    public init(
        type: String,
        done: Bool = false,
        worker: String? = nil,
        content: String? = nil,
        toolUse: StreamToolUse? = nil,
        error: String? = nil
    ) {
        self.type = type
        self.done = done
        self.worker = worker
        self.content = content
        self.toolUse = toolUse
        self.error = error
    }
}

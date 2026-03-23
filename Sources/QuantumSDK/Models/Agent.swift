import Foundation

// MARK: - Agent Worker

/// Describes a worker agent in a multi-agent run.
public struct AgentWorker: Codable, Sendable {
    /// Worker name.
    public var name: String

    /// Model ID for this worker.
    public var model: String?

    /// Worker tier (e.g. "fast", "thinking").
    public var tier: String?

    /// Description of this worker's role.
    public var description: String?

    public init(name: String, model: String? = nil, tier: String? = nil, description: String? = nil) {
        self.name = name
        self.model = model
        self.tier = tier
        self.description = description
    }
}

// MARK: - Agent Request

/// Request body for the `/qai/v1/agent` endpoint.
public struct AgentRequest: Codable, Sendable {
    /// Session identifier for continuity across runs.
    public var sessionId: String?

    /// The task or goal for the agent to accomplish.
    public var task: String

    /// Model for the conductor (default: server picks).
    public var conductorModel: String?

    /// Worker configurations.
    public var workers: [AgentWorker]?

    /// Maximum number of orchestration steps.
    public var maxSteps: Int?

    /// System prompt for the conductor.
    public var systemPrompt: String?

    public init(
        task: String,
        sessionId: String? = nil,
        conductorModel: String? = nil,
        workers: [AgentWorker]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil
    ) {
        self.task = task
        self.sessionId = sessionId
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case task, workers
        case sessionId = "session_id"
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
    }
}

// MARK: - Agent Worker Config (legacy alias)

/// Configuration for an agent worker (legacy alias for AgentWorker).
public typealias AgentWorkerConfig = AgentWorker

// MARK: - Agent Stream Event

/// A single event from an agent or mission SSE stream.
public struct AgentStreamEvent: Codable, Sendable {
    /// Event type (e.g. "step", "thought", "tool_call", "tool_result", "message", "error", "done").
    public var eventType: String

    /// Raw JSON payload for caller to interpret.
    public var data: [String: AnyCodable]?

    public init(eventType: String, data: [String: AnyCodable]? = nil) {
        self.eventType = eventType
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case data
        case eventType = "type"
    }
}

// MARK: - Agent Event (legacy)

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

// MARK: - Mission Worker

/// Describes a named worker for a mission.
public struct MissionWorker: Codable, Sendable {
    /// Model ID for this worker.
    public var model: String?

    /// Worker tier.
    public var tier: String?

    /// Description of this worker's purpose.
    public var description: String?

    public init(model: String? = nil, tier: String? = nil, description: String? = nil) {
        self.model = model
        self.tier = tier
        self.description = description
    }
}

// MARK: - Mission Request

/// Request body for the `/qai/v1/missions` endpoint.
public struct MissionRequest: Codable, Sendable {
    /// The goal for the mission.
    public var goal: String

    /// Execution strategy hint.
    public var strategy: String?

    /// Model for the conductor.
    public var conductorModel: String?

    /// Named workers (key = worker name).
    public var workers: [String: MissionWorker]?

    /// Maximum orchestration steps.
    public var maxSteps: Int?

    /// System prompt for the conductor.
    public var systemPrompt: String?

    /// Session identifier for continuity.
    public var sessionId: String?

    /// Whether to auto-plan before execution.
    public var autoPlan: Bool?

    /// Context management configuration.
    public var contextConfig: ContextConfig?

    /// Model for worker nodes (codegen strategy).
    public var workerModel: String?

    /// Deployment ID -- route worker inference to a managed Vertex endpoint.
    public var deploymentId: String?

    /// Build command to run after codegen (e.g. "cargo build", "npm run build").
    public var buildCommand: String?

    /// Workspace directory for generated files.
    public var workspacePath: String?

    public init(
        goal: String,
        strategy: String? = nil,
        conductorModel: String? = nil,
        workers: [String: MissionWorker]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        sessionId: String? = nil,
        autoPlan: Bool? = nil,
        contextConfig: ContextConfig? = nil,
        workerModel: String? = nil,
        deploymentId: String? = nil,
        buildCommand: String? = nil,
        workspacePath: String? = nil
    ) {
        self.goal = goal
        self.strategy = strategy
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
        self.sessionId = sessionId
        self.autoPlan = autoPlan
        self.contextConfig = contextConfig
        self.workerModel = workerModel
        self.deploymentId = deploymentId
        self.buildCommand = buildCommand
        self.workspacePath = workspacePath
    }

    enum CodingKeys: String, CodingKey {
        case goal, strategy, workers
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
        case sessionId = "session_id"
        case autoPlan = "auto_plan"
        case contextConfig = "context_config"
        case workerModel = "worker_model"
        case deploymentId = "deployment_id"
        case buildCommand = "build_command"
        case workspacePath = "workspace_path"
    }
}

// MARK: - Mission Worker Config (legacy alias)

/// Configuration for a mission worker (legacy alias).
public typealias MissionWorkerConfig = MissionWorker

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

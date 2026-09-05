import Foundation

// Sandbox-backed agent orchestration.
//
// `POST /qai/v1/cloudrun` runs the whole conductor/worker loop server-side.
// Tool calls, shell commands included, execute in the gateway's sandbox
// rather than on the client, and progress streams back as SSE. Use
// `agentStep` instead when the client executes the tool calls itself: that
// route is a single non-streaming turn that hands the tool calls back.
//
// Events arrive as `AgentStreamEvent`s. The `type` field carries
// `agent_session` (the opening event naming the conductor, workers, and step
// budget), `agent_step` per conductor step, `agent_result` with the final
// content and per-tier token totals, `agent_error`, and the two guard-halt
// events `agent_budget_exhausted` / `agent_budget_check_unavailable`; a halt
// bills only the steps that completed.

/// A worker in a Cloud Run agent team.
public struct CloudRunWorker: Codable, Sendable {
    /// Worker name the conductor delegates by.
    public var name: String

    /// Model this worker runs on.
    public var model: String

    /// Cost tier: `"cheap"`, `"mid"`, or `"expensive"`. Used only by the
    /// in-loop budget guard, which prices each tier from the worker
    /// registered against it. The final charge ignores tiers: every token
    /// of the run, workers included, is billed at the conductor model's
    /// rate.
    public var tier: String

    /// What this worker is for; the conductor reads it when delegating.
    public var description: String

    public init(name: String, model: String, tier: String, description: String) {
        self.name = name
        self.model = model
        self.tier = tier
        self.description = description
    }
}

/// Request body for `POST /qai/v1/cloudrun`.
public struct CloudRunRequest: Codable, Sendable {
    /// Conversation session to continue. A new one is created when omitted.
    public var sessionId: String?

    /// The task to accomplish. Required.
    public var task: String

    /// Model the conductor plans and delegates with. Always billed at the
    /// expensive tier.
    public var conductorModel: String?

    /// The agent team. A default team is used when omitted.
    public var workers: [CloudRunWorker]?

    /// Conductor steps to allow. Defaults to 10 and is clamped to a hard
    /// ceiling of 30; the opening `agent_session` event reports both the
    /// requested and the effective value when the clamp fires.
    public var maxSteps: Int?

    /// System prompt for the conductor.
    public var systemPrompt: String?

    /// Context management for a newly created session.
    public var contextConfig: ContextConfig?

    /// Tool capability allowlist. Three-state: `nil` gives the full tool
    /// suite, `[]` gives zero tools (safe mode), and a non-empty list
    /// restricts to those capabilities.
    public var capabilities: [String]?

    /// Directory on the gateway's own filesystem to use as the worker
    /// workspace, relative to the caller's per-user workspace root. An
    /// absolute path or any `..` segment is rejected with 400
    /// `invalid_workspace_path`; it never names a directory on the caller's
    /// machine. An ephemeral per-session directory is used when omitted.
    public var workspacePath: String?

    public init(
        task: String,
        sessionId: String? = nil,
        conductorModel: String? = nil,
        workers: [CloudRunWorker]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        contextConfig: ContextConfig? = nil,
        capabilities: [String]? = nil,
        workspacePath: String? = nil
    ) {
        self.task = task
        self.sessionId = sessionId
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
        self.contextConfig = contextConfig
        self.capabilities = capabilities
        self.workspacePath = workspacePath
    }

    enum CodingKeys: String, CodingKey {
        case task, workers, capabilities
        case sessionId = "session_id"
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
        case contextConfig = "context_config"
        case workspacePath = "workspace_path"
    }
}

/// The event type ``QuantumClient/cloudrun(_:)`` yields.
public typealias CloudRunEvent = AgentStreamEvent

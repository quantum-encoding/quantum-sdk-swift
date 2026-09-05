import Foundation

// MARK: - Mission Request Types

/// Request body for creating a mission.
public struct MissionCreateRequest: Codable, Sendable {
    /// High-level task description.
    public var goal: String

    /// Strategy: "wave" (default), "dag", "mapreduce", "refinement",
    /// "branch", "codegen" (dedicated pipeline), or the pre-built teams
    /// "coding_team", "security_team", "pipeline" (which read `workers` only
    /// for named overrides).
    public var strategy: String?

    /// Conductor model (default: claude-sonnet-4-6).
    public var conductorModel: String?

    /// Conductor tier override. Default: "expensive". Set to "cheap" when
    /// using a fast router as conductor; it decides what the budget guard
    /// prices the conductor at.
    public var conductorTier: String?

    /// Worker team configuration keyed by worker name. Default team:
    /// reader, coder, reviewer.
    public var workers: [String: MissionWorkerDetail]?

    /// Maximum orchestration steps (default: 25, ceiling 50).
    public var maxSteps: Int?

    /// Custom system prompt for the conductor. Applied only when a session
    /// is created; a re-used `sessionId` ignores it.
    public var systemPrompt: String?

    /// Existing session ID for context continuity. Must belong to the
    /// caller (404 otherwise).
    public var sessionId: String?

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
        workers: [String: MissionWorkerDetail]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        sessionId: String? = nil,
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
        case useContext = "use_context"
    }
}

/// Worker configuration within a mission.
public struct MissionWorkerDetail: Codable, Sendable {
    /// Model to use for this worker.
    public var model: String

    /// Cost tier: "cheap", "mid", "expensive". The gateway prices and
    /// routes any other value, an empty string included, as "cheap", so the
    /// tier is required here.
    public var tier: String

    /// Worker description / capabilities.
    public var description: String?

    /// Worker to escalate to on failure (e.g. cheap coder to expensive coder).
    public var escalateTo: String?

    /// Max retries before escalating (default 1 = escalate on first failure).
    public var maxRetries: Int?

    public init(model: String, tier: String, description: String? = nil, escalateTo: String? = nil, maxRetries: Int? = nil) {
        self.model = model
        self.tier = tier
        self.description = description
        self.escalateTo = escalateTo
        self.maxRetries = maxRetries
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        tier = try container.decodeIfPresent(String.self, forKey: .tier) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        escalateTo = try container.decodeIfPresent(String.self, forKey: .escalateTo)
        maxRetries = try container.decodeIfPresent(Int.self, forKey: .maxRetries)
    }

    enum CodingKeys: String, CodingKey {
        case model, tier, description
        case escalateTo = "escalate_to"
        case maxRetries = "max_retries"
    }
}

/// Request body for chatting with a mission's architect.
public struct MissionChatRequest: Codable, Sendable {
    /// Message to send to the architect.
    public var message: String

    /// Request a streamed reply. The chat route does not stream, so the flag
    /// has no effect.
    public var stream: Bool?

    public init(message: String, stream: Bool? = nil) {
        self.message = message
        self.stream = stream
    }
}

/// Request body for updating a mission plan. Only a pending, paused, or
/// running mission accepts it (409 `invalid_state` otherwise).
public struct MissionPlanUpdate: Codable, Sendable {
    /// Tasks to write or overwrite, in order. Each takes its id from an `id`
    /// key or its position (`task_001`, ...); a missing `status` becomes
    /// `pending`.
    public var tasks: [[String: AnyCodable]]?

    /// Updated worker configuration.
    public var workers: [String: MissionWorkerDetail]?

    /// Updated max steps. Values at or below zero are ignored.
    public var maxSteps: Int?

    /// Additional context, appended to the mission's session as a user turn
    /// prefixed `[Plan Update]`.
    public var context: String?

    public init(
        tasks: [[String: AnyCodable]]? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        maxSteps: Int? = nil,
        context: String? = nil
    ) {
        self.tasks = tasks
        self.workers = workers
        self.maxSteps = maxSteps
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case tasks, workers, context
        case maxSteps = "max_steps"
    }
}

/// Request body for confirming/rejecting a mission structure.
public struct MissionConfirmStructure: Codable, Sendable {
    /// Whether the structure is approved.
    public var confirmed: Bool

    /// Rejection reason or modification notes.
    public var feedback: String?

    public init(confirmed: Bool, feedback: String? = nil) {
        self.confirmed = confirmed
        self.feedback = feedback
    }
}

/// Request body for approving a completed mission.
public struct MissionApproveRequest: Codable, Sendable {
    /// Git commit SHA associated with the mission output.
    public var commitSHA: String?

    /// Approval comment, stored as `approval_comment` on the mission.
    public var comment: String?

    public init(commitSHA: String? = nil, comment: String? = nil) {
        self.commitSHA = commitSHA
        self.comment = comment
    }

    enum CodingKeys: String, CodingKey {
        case commitSHA = "commit_sha"
        case comment
    }
}

/// Request body for importing a plan as a new mission.
public struct MissionImportRequest: Codable, Sendable {
    /// Mission goal.
    public var goal: String

    /// Strategy.
    public var strategy: String?

    /// Conductor model.
    public var conductorModel: String?

    /// Worker configuration.
    public var workers: [String: MissionWorkerDetail]?

    /// Pre-defined tasks. Always sent, empty included.
    public var tasks: [[String: AnyCodable]]

    /// System prompt.
    public var systemPrompt: String?

    /// Maximum steps.
    public var maxSteps: Int?

    /// Auto-execute after import: the run starts and the reply reports
    /// `running`.
    public var autoExecute: Bool

    public init(
        goal: String,
        strategy: String? = nil,
        conductorModel: String? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        tasks: [[String: AnyCodable]] = [],
        systemPrompt: String? = nil,
        maxSteps: Int? = nil,
        autoExecute: Bool = false
    ) {
        self.goal = goal
        self.strategy = strategy
        self.conductorModel = conductorModel
        self.workers = workers
        self.tasks = tasks
        self.systemPrompt = systemPrompt
        self.maxSteps = maxSteps
        self.autoExecute = autoExecute
    }

    enum CodingKeys: String, CodingKey {
        case goal, strategy, workers, tasks
        case conductorModel = "conductor_model"
        case systemPrompt = "system_prompt"
        case maxSteps = "max_steps"
        case autoExecute = "auto_execute"
    }
}

// MARK: - Mission Response Types

/// Response from mission creation (202) or import (201).
public struct MissionCreateResponse: Codable, Sendable {
    /// Mission identifier.
    public var missionId: String

    /// Initial status.
    public var status: String

    /// Session ID for conversation context.
    public var sessionId: String?

    /// Conductor model used.
    public var conductorModel: String?

    /// Strategy used.
    public var strategy: String?

    /// Worker configuration.
    public var workers: [String: MissionWorkerDetail]?

    /// Creation timestamp.
    public var createdAt: String?

    /// Request identifier.
    public var requestId: String?

    public init(
        missionId: String,
        status: String = "",
        sessionId: String? = nil,
        conductorModel: String? = nil,
        strategy: String? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        createdAt: String? = nil,
        requestId: String? = nil
    ) {
        self.missionId = missionId
        self.status = status
        self.sessionId = sessionId
        self.conductorModel = conductorModel
        self.strategy = strategy
        self.workers = workers
        self.createdAt = createdAt
        self.requestId = requestId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        missionId = try container.decode(String.self, forKey: .missionId)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        conductorModel = try container.decodeIfPresent(String.self, forKey: .conductorModel)
        strategy = try container.decodeIfPresent(String.self, forKey: .strategy)
        workers = try container.decodeIfPresent([String: MissionWorkerDetail].self, forKey: .workers)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
    }

    enum CodingKeys: String, CodingKey {
        case status, strategy, workers
        case missionId = "mission_id"
        case sessionId = "session_id"
        case conductorModel = "conductor_model"
        case createdAt = "created_at"
        case requestId = "request_id"
    }
}

/// Mission detail (from GET /missions/{id}); list rows are the same
/// Firestore map without `tasks`.
///
/// Only the keys a given mission has been through are present: `approved`
/// appears once the mission is approved, `tasks` only on the single-mission
/// read, and the token counts on a task only after a retry. Absent keys
/// decode to their zero values.
public struct MissionDetail: Codable, Sendable {
    /// Mission identifier.
    public var id: String?

    /// User who created the mission.
    public var userId: String?

    /// Mission goal.
    public var goal: String?

    /// Strategy.
    public var strategy: String?

    /// Conductor model.
    public var conductorModel: String?

    /// Current status.
    public var status: String?

    /// Creation timestamp.
    public var createdAt: String?

    /// Start timestamp.
    public var startedAt: String?

    /// Completion timestamp.
    public var completedAt: String?

    /// Error message if failed.
    public var error: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Number of steps executed.
    public var totalSteps: Int

    /// Session ID.
    public var sessionId: String?

    /// Final result text.
    public var result: String?

    /// Tasks within the mission. Empty on list rows.
    public var tasks: [MissionTask]

    /// Whether the mission was approved. False until the key is written.
    public var approved: Bool

    /// Commit SHA (if approved).
    public var commitSHA: String?

    public init(
        id: String? = nil,
        userId: String? = nil,
        goal: String? = nil,
        strategy: String? = nil,
        conductorModel: String? = nil,
        status: String? = nil,
        createdAt: String? = nil,
        startedAt: String? = nil,
        completedAt: String? = nil,
        error: String? = nil,
        costTicks: Int64 = 0,
        totalSteps: Int = 0,
        sessionId: String? = nil,
        result: String? = nil,
        tasks: [MissionTask] = [],
        approved: Bool = false,
        commitSHA: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.goal = goal
        self.strategy = strategy
        self.conductorModel = conductorModel
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
        self.costTicks = costTicks
        self.totalSteps = totalSteps
        self.sessionId = sessionId
        self.result = result
        self.tasks = tasks
        self.approved = approved
        self.commitSHA = commitSHA
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        goal = try container.decodeIfPresent(String.self, forKey: .goal)
        strategy = try container.decodeIfPresent(String.self, forKey: .strategy)
        conductorModel = try container.decodeIfPresent(String.self, forKey: .conductorModel)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        costTicks = try container.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        totalSteps = try container.decodeIfPresent(Int.self, forKey: .totalSteps) ?? 0
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        tasks = try container.decode(NullToEmpty<MissionTask>.self, forKey: .tasks).wrappedValue
        approved = try container.decodeIfPresent(Bool.self, forKey: .approved) ?? false
        commitSHA = try container.decodeIfPresent(String.self, forKey: .commitSHA)
    }

    enum CodingKeys: String, CodingKey {
        case id, goal, strategy, status, error, result, tasks, approved
        case userId = "user_id"
        case conductorModel = "conductor_model"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case costTicks = "cost_ticks"
        case totalSteps = "total_steps"
        case sessionId = "session_id"
        case commitSHA = "commit_sha"
    }
}

/// A task within a mission. The executor writes `name`, `status`, `step`,
/// `created_at` and optionally `result`, `worker`, `model`; the retry path
/// adds `tokens_in` / `tokens_out`. Absent counts decode to zero.
public struct MissionTask: Codable, Sendable {
    /// Task identifier.
    public var id: String?

    /// Task name.
    public var name: String?

    /// Task description.
    public var description: String?

    /// Assigned worker name.
    public var worker: String?

    /// Model used.
    public var model: String?

    /// Task status.
    public var status: String?

    /// Task result.
    public var result: String?

    /// Error message if failed.
    public var error: String?

    /// Step number.
    public var step: Int

    /// Input tokens used.
    public var tokensIn: Int

    /// Output tokens used.
    public var tokensOut: Int

    public init(
        id: String? = nil,
        name: String? = nil,
        description: String? = nil,
        worker: String? = nil,
        model: String? = nil,
        status: String? = nil,
        result: String? = nil,
        error: String? = nil,
        step: Int = 0,
        tokensIn: Int = 0,
        tokensOut: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.worker = worker
        self.model = model
        self.status = status
        self.result = result
        self.error = error
        self.step = step
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        worker = try container.decodeIfPresent(String.self, forKey: .worker)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        step = try container.decodeIfPresent(Int.self, forKey: .step) ?? 0
        tokensIn = try container.decodeIfPresent(Int.self, forKey: .tokensIn) ?? 0
        tokensOut = try container.decodeIfPresent(Int.self, forKey: .tokensOut) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, worker, model, status, result, error, step
        case tokensIn = "tokens_in"
        case tokensOut = "tokens_out"
    }
}

/// Response from listing missions.
public struct MissionListResponse: Codable, Sendable {
    /// List of missions.
    @NullToEmpty public var missions: [MissionDetail]

    public init(missions: [MissionDetail] = []) {
        self.missions = missions
    }
}

/// Response from chatting with the architect.
public struct MissionChatResponse: Codable, Sendable {
    /// Mission identifier.
    public var missionId: String?

    /// Architect's response content.
    public var content: String?

    /// Model used.
    public var model: String?

    /// Cost in ticks.
    public var costTicks: Int64

    /// Token usage.
    public var usage: MissionChatUsage?

    public init(
        missionId: String? = nil,
        content: String? = nil,
        model: String? = nil,
        costTicks: Int64 = 0,
        usage: MissionChatUsage? = nil
    ) {
        self.missionId = missionId
        self.content = content
        self.model = model
        self.costTicks = costTicks
        self.usage = usage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        missionId = try container.decodeIfPresent(String.self, forKey: .missionId)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        costTicks = try container.decodeIfPresent(Int64.self, forKey: .costTicks) ?? 0
        usage = try container.decodeIfPresent(MissionChatUsage.self, forKey: .usage)
    }

    enum CodingKeys: String, CodingKey {
        case content, model, usage
        case missionId = "mission_id"
        case costTicks = "cost_ticks"
    }
}

/// Token usage for a mission chat response.
public struct MissionChatUsage: Codable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int

    public init(inputTokens: Int = 0, outputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

/// A git checkpoint within a mission.
public struct MissionCheckpoint: Codable, Sendable {
    /// Checkpoint identifier.
    public var id: String?

    /// Commit SHA.
    public var commitSHA: String?

    /// Checkpoint message.
    public var message: String?

    /// Creation timestamp.
    public var createdAt: String?

    public init(
        id: String? = nil,
        commitSHA: String? = nil,
        message: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.commitSHA = commitSHA
        self.message = message
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, message
        case commitSHA = "commit_sha"
        case createdAt = "created_at"
    }
}

/// Response from listing checkpoints.
public struct MissionCheckpointsResponse: Codable, Sendable {
    public var missionId: String?
    @NullToEmpty public var checkpoints: [MissionCheckpoint]

    public init(missionId: String? = nil, checkpoints: [MissionCheckpoint] = []) {
        self.missionId = missionId
        self.checkpoints = checkpoints
    }

    enum CodingKeys: String, CodingKey {
        case checkpoints
        case missionId = "mission_id"
    }
}

/// Generic status response for mission operations.
public struct MissionStatusResponse: Codable, Sendable {
    public var missionId: String?
    public var status: String?
    public var confirmed: Bool?
    public var approved: Bool?
    public var deleted: Bool?
    public var updated: Bool?
    public var commitSHA: String?

    /// USD charged by ``QuantumClient/missionCancel(missionId:)`` for the
    /// work already done; zero for a pending mission.
    public var cancellationCost: Double?

    public init(
        missionId: String? = nil,
        status: String? = nil,
        confirmed: Bool? = nil,
        approved: Bool? = nil,
        deleted: Bool? = nil,
        updated: Bool? = nil,
        commitSHA: String? = nil,
        cancellationCost: Double? = nil
    ) {
        self.missionId = missionId
        self.status = status
        self.confirmed = confirmed
        self.approved = approved
        self.deleted = deleted
        self.updated = updated
        self.commitSHA = commitSHA
        self.cancellationCost = cancellationCost
    }

    enum CodingKeys: String, CodingKey {
        case status, confirmed, approved, deleted, updated
        case missionId = "mission_id"
        case commitSHA = "commit_sha"
        case cancellationCost = "cancellation_cost"
    }
}

/// Response from `POST /qai/v1/missions/{id}/retry/{task_id}`.
public struct MissionRetryResponse: Codable, Sendable {
    /// The mission.
    public var missionId: String

    /// The task that was retried.
    public var taskId: String

    /// `"task_completed"`.
    public var status: String

    /// The retried task's output.
    public var result: String

    /// Model the retry ran on.
    public var model: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        missionId = try container.decodeIfPresent(String.self, forKey: .missionId) ?? ""
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        result = try container.decodeIfPresent(String.self, forKey: .result) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case status, result, model
        case missionId = "mission_id"
        case taskId = "task_id"
    }
}

// MARK: - Client Extension

extension QuantumClient {
    /// Creates and executes a mission asynchronously (202). The injection
    /// gate fails closed; `goal` is required (400).
    ///
    /// `POST /qai/v1/missions/create`
    public func missionCreate(_ request: MissionCreateRequest, idempotencyKey: String? = nil) async throws -> MissionCreateResponse {
        let (data, _): (MissionCreateResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/create", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Lists missions for the authenticated user, optionally filtered by
    /// status. Rows carry no `tasks`.
    ///
    /// `GET /qai/v1/missions/list`
    public func missionList(status: String? = nil) async throws -> MissionListResponse {
        var path = "/qai/v1/missions/list"
        if let status { path += "?status=\(status.strictQueryEncoded)" }
        let (data, _): (MissionListResponse, _) = try await doReq(method: "GET", path: path)
        return data
    }

    /// Gets mission details including tasks. 404 unless the mission is the
    /// caller's (admins bypass).
    ///
    /// `GET /qai/v1/missions/{id}`
    public func missionGet(missionId: String) async throws -> MissionDetail {
        let (data, _): (MissionDetail, _) = try await doReq(
            method: "GET", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)"
        )
        return data
    }

    /// Deletes a mission (409 while it is running).
    ///
    /// `DELETE /qai/v1/missions/{id}`
    public func missionDelete(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "DELETE", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)"
        )
        return data
    }

    /// Cancels a pending or running mission (409 `invalid_state` otherwise).
    ///
    /// Cancelling a running mission charges for the work already done,
    /// estimated at $0.02 per elapsed minute since it started with a
    /// half-minute minimum; the amount comes back as
    /// ``MissionStatusResponse/cancellationCost``. A pending mission is
    /// cancelled free.
    ///
    /// `POST /qai/v1/missions/{id}/cancel`
    public func missionCancel(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/cancel"
        )
        return data
    }

    /// Pauses a running mission. The status flips immediately; the executor
    /// checks it only every fifth event and then cancels its context, so the
    /// mission keeps running and billing until then.
    ///
    /// `POST /qai/v1/missions/{id}/pause`
    public func missionPause(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/pause"
        )
        return data
    }

    /// Restarts a paused mission from the beginning as a fresh async run.
    ///
    /// Only `goal`, `strategy`, `conductor_model` and `session_id` are
    /// restored; `max_steps` resets to the default, and the system prompt,
    /// context, conductor tier and context config are lost. Everything
    /// already done is re-executed and re-billed; nothing reads a
    /// checkpoint.
    ///
    /// `POST /qai/v1/missions/{id}/resume`
    public func missionResume(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/resume"
        )
        return data
    }

    /// Chats with the mission's architect (billed; `stream` has no effect).
    ///
    /// `POST /qai/v1/missions/{id}/chat`
    public func missionChat(missionId: String, request: MissionChatRequest, idempotencyKey: String? = nil) async throws -> MissionChatResponse {
        let (data, _): (MissionChatResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/chat", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Retries a failed task.
    ///
    /// The retry runs as one bare generation on the task's model, billed at
    /// that model's rate, writes `task_completed` on the task, and the
    /// reply carries the new output and the model used.
    ///
    /// `POST /qai/v1/missions/{id}/retry/{task_id}`
    public func missionRetryTask(missionId: String, taskId: String, idempotencyKey: String? = nil) async throws -> MissionRetryResponse {
        let (data, _): (MissionRetryResponse, _) = try await doReq(
            method: "POST",
            path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/retry/\(taskId.strictQueryEncoded)",
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    /// Approves a completed mission (409 unless `completed`).
    ///
    /// `POST /qai/v1/missions/{id}/approve`
    public func missionApprove(missionId: String, request: MissionApproveRequest) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/approve", body: request
        )
        return data
    }

    /// Updates the mission plan (pending, paused or running missions only).
    ///
    /// `PUT /qai/v1/missions/{id}/plan`
    public func missionUpdatePlan(missionId: String, request: MissionPlanUpdate) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "PUT", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/plan", body: request
        )
        return data
    }

    /// Confirms or rejects the proposed execution structure.
    ///
    /// `POST /qai/v1/missions/{id}/confirm-structure`
    public func missionConfirmStructure(missionId: String, request: MissionConfirmStructure) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/confirm-structure", body: request
        )
        return data
    }

    /// Lists git checkpoints for a mission.
    ///
    /// `GET /qai/v1/missions/{id}/checkpoints`
    public func missionCheckpoints(missionId: String) async throws -> MissionCheckpointsResponse {
        let (data, _): (MissionCheckpointsResponse, _) = try await doReq(
            method: "GET", path: "/qai/v1/missions/\(missionId.strictQueryEncoded)/checkpoints"
        )
        return data
    }

    /// Imports an existing plan as a new mission (201).
    ///
    /// `POST /qai/v1/missions/import`
    public func missionImport(_ request: MissionImportRequest, idempotencyKey: String? = nil) async throws -> MissionCreateResponse {
        let (data, _): (MissionCreateResponse, _) = try await doReq(
            method: "POST", path: "/qai/v1/missions/import", body: request,
            idempotencyKey: idempotencyKey ?? UUID().uuidString
        )
        return data
    }

    // MARK: - Mission Streaming

    /// Streams a mission execution via SSE, as typed ``MissionStreamEvent``
    /// values. The wire is the same as ``missionRun(_:)``; this view decodes
    /// the known event shapes and keeps every key in
    /// ``MissionStreamEvent/raw`` for the rest.
    ///
    /// The stream runs until the gateway's `[DONE]` sentinel (surfaced as a
    /// `done` event with `done == true`), so the `usage` event the default
    /// strategies send after `mission_completed` is delivered. A transport
    /// failure, or a body that ends before `[DONE]`, ends the stream with
    /// an `error` event whose `transport` flag is set; only a non-2xx
    /// status before the stream opens throws.
    ///
    /// ```swift
    /// for try await event in client.missionStream(request) {
    ///     switch event.type {
    ///     case "step_detail":
    ///         print("Step \(event.step ?? 0): \(event.role ?? "")")
    ///     case "mission_completed":
    ///         print("Done: \(event.content ?? "")")
    ///     default:
    ///         break
    ///     }
    /// }
    /// ```
    public func missionStream(_ request: MissionCreateRequest) -> AsyncThrowingStream<MissionStreamEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, _) = try await self.http.doStreamRequest(
                        path: "/qai/v1/missions", body: request
                    )
                    var sawDone = false
                    do {
                        for try await sseEvent in SSEParser(bytes: bytes) {
                            switch sseEvent {
                            case .done:
                                sawDone = true
                                continuation.yield(MissionStreamEvent(type: "done", done: true))
                            case let .data(data):
                                continuation.yield(Self.parseMissionStreamEvent(data))
                            case let .error(message):
                                continuation.yield(MissionStreamEvent(type: "error", error: "parse SSE: \(message)"))
                            }
                        }
                    } catch is CancellationError {
                        continuation.finish()
                        return
                    } catch let error as URLError where error.code == .cancelled {
                        continuation.finish()
                        return
                    } catch {
                        continuation.yield(MissionStreamEvent(
                            type: "error", done: true, transport: true,
                            error: "transport: \(error.localizedDescription)"
                        ))
                        continuation.finish()
                        return
                    }
                    if !sawDone {
                        continuation.yield(MissionStreamEvent(
                            type: "error", done: true, transport: true,
                            error: "transport: stream ended before [DONE]"
                        ))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Mission Stream Parsing

    /// Parses a raw SSE JSON payload into a ``MissionStreamEvent``. A
    /// payload that is not a JSON object becomes an `error` event carrying
    /// the parse failure.
    static func parseMissionStreamEvent(_ data: Data) -> MissionStreamEvent {
        let rawObject: [String: AnyCodable]
        let raw: RawMissionStreamEvent
        do {
            rawObject = try JSONDecoder().decode([String: AnyCodable].self, from: data)
            raw = try JSONDecoder().decode(RawMissionStreamEvent.self, from: data)
        } catch {
            return MissionStreamEvent(type: "error", error: "parse SSE: \(error.localizedDescription)")
        }

        var event = MissionStreamEvent(type: raw.type ?? "unknown")
        event.raw = rawObject
        event.missionId = raw.missionId
        event.taskId = raw.taskId
        event.message = raw.message

        switch raw.type {
        case "mission_started":
            event.sessionId = raw.sessionId
            event.conductor = raw.conductor
            event.strategy = raw.strategy
            event.workers = raw.workers
            event.maxSteps = raw.maxSteps
            event.maxStepsRequested = raw.maxStepsRequested
            event.maxStepsClampedToCeiling = raw.maxStepsClampedToCeiling

        case "step_detail":
            event.step = raw.step
            event.role = raw.role
            event.tier = raw.tier
            event.durationMs = raw.duration ?? raw.durationMs
            event.delegated = raw.delegated
            event.content = raw.content

        case "mission_completed":
            event.content = raw.content
            event.cost = raw.cost
            event.totalSteps = raw.totalSteps
            event.durationMs = raw.durationMs
            event.strategy = raw.strategy
            event.workspacePath = raw.workspacePath
            event.filesGenerated = raw.filesGenerated
            event.filesFailed = raw.filesFailed
            event.fixIterations = raw.fixIterations
            event.buildPassed = raw.buildPassed

        case "mission_failed", "task_failed", "error", "agent_error":
            event.content = raw.content
            event.error = raw.error ?? raw.message

        case "mission_budget_exhausted", "mission_budget_check_unavailable":
            event.stepsCompleted = raw.stepsCompleted
            event.maxStepsTarget = raw.maxStepsTarget

        case "tick_completed":
            event.step = raw.step
            event.content = raw.content

        case "usage":
            event.inputTokens = raw.inputTokens
            event.outputTokens = raw.outputTokens
            event.costTicks = raw.costTicks

        default:
            event.content = raw.content
            event.step = raw.step
        }

        return event
    }
}

// MARK: - Mission Stream Types

/// A streamed event from a mission execution.
///
/// Wire types: `mission_started`, `step_detail`, `mission_completed`,
/// `mission_failed`, `mission_budget_exhausted`,
/// `mission_budget_check_unavailable`, `usage`, and the executor's
/// `task_queued` / `task_started` / `task_completed` / `task_failed` /
/// `task_skipped`, `wave_*`, `graph_mutated`, `tick_completed`,
/// `mission_paused` / `mission_resumed` / `mission_cancelled`. Client-side
/// synthesised: `done` (the `[DONE]` sentinel) and `error`. Whatever the
/// type, every key of the payload is in ``raw``.
public struct MissionStreamEvent: Sendable {
    /// Event type.
    public var type: String
    /// Whether this event ends the stream: true for `done` and for a
    /// transport `error`.
    public var done: Bool
    /// True when an `error` event was caused by the connection, not the
    /// mission.
    public var transport: Bool

    /// Every key of the wire payload, `type` included.
    public var raw: [String: AnyCodable]

    // mission_started fields
    public var sessionId: String?
    public var conductor: String?
    /// Strategy: on `mission_started`, and on the codegen `mission_completed`.
    public var strategy: String?
    public var workers: [String: MissionWorkerDetail]?
    public var maxSteps: Int?
    /// Present only when the requested `max_steps` was clamped to the ceiling.
    public var maxStepsRequested: Int?
    public var maxStepsClampedToCeiling: Int?

    // step_detail fields
    public var step: Int?
    public var role: String?
    public var tier: String?
    /// Milliseconds: the `duration` key on `step_detail`, `duration_ms` on
    /// `mission_completed`.
    public var durationMs: Int?
    public var delegated: Bool?

    // mission_completed fields
    /// The final answer for the default strategies; absent on codegen.
    public var content: String?
    public var cost: MissionCost?
    public var totalSteps: Int?
    // codegen mission_completed fields
    public var workspacePath: String?
    public var filesGenerated: Int?
    public var filesFailed: Int?
    public var fixIterations: Int?
    public var buildPassed: Bool?

    // budget halt fields
    public var stepsCompleted: Int?
    public var maxStepsTarget: Int?

    // executor event fields
    public var missionId: String?
    public var taskId: String?
    public var message: String?

    // usage fields (sent after mission_completed by the default strategies,
    // before it by codegen)
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var costTicks: Int64?

    /// The failure reason on `mission_failed` (its `message` key),
    /// `task_failed`, `error` and the client-side error events.
    public var error: String?

    public init(
        type: String,
        done: Bool = false,
        transport: Bool = false,
        raw: [String: AnyCodable] = [:],
        sessionId: String? = nil,
        conductor: String? = nil,
        strategy: String? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        maxSteps: Int? = nil,
        maxStepsRequested: Int? = nil,
        maxStepsClampedToCeiling: Int? = nil,
        step: Int? = nil,
        role: String? = nil,
        tier: String? = nil,
        durationMs: Int? = nil,
        delegated: Bool? = nil,
        content: String? = nil,
        cost: MissionCost? = nil,
        totalSteps: Int? = nil,
        workspacePath: String? = nil,
        filesGenerated: Int? = nil,
        filesFailed: Int? = nil,
        fixIterations: Int? = nil,
        buildPassed: Bool? = nil,
        stepsCompleted: Int? = nil,
        maxStepsTarget: Int? = nil,
        missionId: String? = nil,
        taskId: String? = nil,
        message: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        costTicks: Int64? = nil,
        error: String? = nil
    ) {
        self.type = type
        self.done = done
        self.transport = transport
        self.raw = raw
        self.sessionId = sessionId
        self.conductor = conductor
        self.strategy = strategy
        self.workers = workers
        self.maxSteps = maxSteps
        self.maxStepsRequested = maxStepsRequested
        self.maxStepsClampedToCeiling = maxStepsClampedToCeiling
        self.step = step
        self.role = role
        self.tier = tier
        self.durationMs = durationMs
        self.delegated = delegated
        self.content = content
        self.cost = cost
        self.totalSteps = totalSteps
        self.workspacePath = workspacePath
        self.filesGenerated = filesGenerated
        self.filesFailed = filesFailed
        self.fixIterations = fixIterations
        self.buildPassed = buildPassed
        self.stepsCompleted = stepsCompleted
        self.maxStepsTarget = maxStepsTarget
        self.missionId = missionId
        self.taskId = taskId
        self.message = message
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costTicks = costTicks
        self.error = error
    }
}

/// Prompt and completion token counts for one cost tier. The gateway
/// serialises the Go struct without tags, so the wire keys are `Prompt`
/// and `Completion`.
public struct MissionTokenCount: Codable, Sendable {
    public var prompt: Int
    public var completion: Int

    public init(prompt: Int = 0, completion: Int = 0) {
        self.prompt = prompt
        self.completion = completion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try container.decodeIfPresent(Int.self, forKey: .prompt) ?? 0
        completion = try container.decodeIfPresent(Int.self, forKey: .completion) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case prompt = "Prompt"
        case completion = "Completion"
    }
}

/// Token counts by model tier on `mission_completed`.
public struct MissionCost: Codable, Sendable {
    public var cheap: MissionTokenCount?
    public var mid: MissionTokenCount?
    public var expensive: MissionTokenCount?

    public init(cheap: MissionTokenCount? = nil, mid: MissionTokenCount? = nil, expensive: MissionTokenCount? = nil) {
        self.cheap = cheap
        self.mid = mid
        self.expensive = expensive
    }
}

// MARK: - Raw Mission Stream Event (Internal)

/// Internal decoder for mission SSE payloads. Maps every typed field from
/// the wire format; unknown keys are kept on ``MissionStreamEvent/raw``.
private struct RawMissionStreamEvent: Decodable {
    var type: String?

    // mission_started
    var sessionId: String?
    var conductor: String?
    var strategy: String?
    var workers: [String: MissionWorkerDetail]?
    var maxSteps: Int?
    var maxStepsRequested: Int?
    var maxStepsClampedToCeiling: Int?

    // step_detail
    var step: Int?
    var role: String?
    var tier: String?
    var duration: Int?
    var durationMs: Int?
    var delegated: Bool?

    // mission_completed
    var content: String?
    var cost: MissionCost?
    var totalSteps: Int?
    var workspacePath: String?
    var filesGenerated: Int?
    var filesFailed: Int?
    var fixIterations: Int?
    var buildPassed: Bool?

    // budget halts
    var stepsCompleted: Int?
    var maxStepsTarget: Int?

    // executor events
    var missionId: String?
    var taskId: String?
    var message: String?

    // usage
    var inputTokens: Int?
    var outputTokens: Int?
    var costTicks: Int64?

    var error: String?

    enum CodingKeys: String, CodingKey {
        case type, conductor, strategy, workers, step, role, tier, delegated, duration
        case content, cost, message, error
        case sessionId = "session_id"
        case maxSteps = "max_steps"
        case maxStepsRequested = "max_steps_requested"
        case maxStepsClampedToCeiling = "max_steps_clamped_to_ceiling"
        case durationMs = "duration_ms"
        case totalSteps = "total_steps"
        case workspacePath = "workspace_path"
        case filesGenerated = "files_generated"
        case filesFailed = "files_failed"
        case fixIterations = "fix_iterations"
        case buildPassed = "build_passed"
        case stepsCompleted = "steps_completed"
        case maxStepsTarget = "max_steps_target"
        case missionId = "mission_id"
        case taskId = "task_id"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costTicks = "cost_ticks"
    }
}

import Foundation

// MARK: - Mission Request Types

/// Request body for creating a mission.
public struct MissionCreateRequest: Codable, Sendable {
    /// High-level task description.
    public var goal: String

    /// Strategy: "wave" (default), "dag", "mapreduce", "refinement", "branch".
    public var strategy: String?

    /// Conductor model (default: claude-sonnet-4-6).
    public var conductorModel: String?

    /// Worker team configuration keyed by worker name.
    public var workers: [String: MissionWorkerDetail]?

    /// Maximum orchestration steps (default: 25).
    public var maxSteps: Int?

    /// Custom system prompt for the conductor.
    public var systemPrompt: String?

    /// Existing session ID for context continuity.
    public var sessionId: String?

    public init(
        goal: String,
        strategy: String? = nil,
        conductorModel: String? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        maxSteps: Int? = nil,
        systemPrompt: String? = nil,
        sessionId: String? = nil
    ) {
        self.goal = goal
        self.strategy = strategy
        self.conductorModel = conductorModel
        self.workers = workers
        self.maxSteps = maxSteps
        self.systemPrompt = systemPrompt
        self.sessionId = sessionId
    }

    enum CodingKeys: String, CodingKey {
        case goal, strategy, workers
        case conductorModel = "conductor_model"
        case maxSteps = "max_steps"
        case systemPrompt = "system_prompt"
        case sessionId = "session_id"
    }
}

/// Worker configuration within a mission.
public struct MissionWorkerDetail: Codable, Sendable {
    /// Model to use for this worker.
    public var model: String

    /// Cost tier: "cheap", "mid", "expensive".
    public var tier: String

    /// Worker description / capabilities.
    public var description: String?

    public init(model: String, tier: String = "", description: String? = nil) {
        self.model = model
        self.tier = tier
        self.description = description
    }
}

/// Request body for chatting with a mission's architect.
public struct MissionChatRequest: Codable, Sendable {
    /// Message to send to the architect.
    public var message: String

    /// Enable streaming (not yet supported).
    public var stream: Bool?

    public init(message: String, stream: Bool? = nil) {
        self.message = message
        self.stream = stream
    }
}

/// Request body for updating a mission plan.
public struct MissionPlanUpdate: Codable, Sendable {
    /// Updated task list.
    public var tasks: [[String: AnyCodable]]?

    /// Updated worker configuration.
    public var workers: [String: MissionWorkerDetail]?

    /// Additional system prompt.
    public var systemPrompt: String?

    /// Updated max steps.
    public var maxSteps: Int?

    /// Additional context to inject.
    public var context: String?

    public init(
        tasks: [[String: AnyCodable]]? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        systemPrompt: String? = nil,
        maxSteps: Int? = nil,
        context: String? = nil
    ) {
        self.tasks = tasks
        self.workers = workers
        self.systemPrompt = systemPrompt
        self.maxSteps = maxSteps
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case tasks, workers, context
        case systemPrompt = "system_prompt"
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

    /// Approval comment.
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

    /// Pre-defined tasks.
    public var tasks: [[String: AnyCodable]]

    /// System prompt.
    public var systemPrompt: String?

    /// Maximum steps.
    public var maxSteps: Int?

    /// Auto-execute after import.
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

/// Response from mission creation.
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

    enum CodingKeys: String, CodingKey {
        case status, strategy, workers
        case missionId = "mission_id"
        case sessionId = "session_id"
        case conductorModel = "conductor_model"
        case createdAt = "created_at"
        case requestId = "request_id"
    }
}

/// Mission detail (from GET /missions/{id}).
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

    /// Tasks within the mission.
    public var tasks: [MissionTask]

    /// Whether the mission was approved.
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

/// A task within a mission.
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

    enum CodingKeys: String, CodingKey {
        case id, name, description, worker, model, status, result, error, step
        case tokensIn = "tokens_in"
        case tokensOut = "tokens_out"
    }
}

/// Response from listing missions.
public struct MissionListResponse: Codable, Sendable {
    /// List of missions.
    public var missions: [MissionDetail]

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
    public var checkpoints: [MissionCheckpoint]

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

    public init(
        missionId: String? = nil,
        status: String? = nil,
        confirmed: Bool? = nil,
        approved: Bool? = nil,
        deleted: Bool? = nil,
        updated: Bool? = nil,
        commitSHA: String? = nil
    ) {
        self.missionId = missionId
        self.status = status
        self.confirmed = confirmed
        self.approved = approved
        self.deleted = deleted
        self.updated = updated
        self.commitSHA = commitSHA
    }

    enum CodingKeys: String, CodingKey {
        case status, confirmed, approved, deleted, updated
        case missionId = "mission_id"
        case commitSHA = "commit_sha"
    }
}

// MARK: - Client Extension

extension QuantumClient {
    /// Create and execute a mission asynchronously.
    public func missionCreate(_ request: MissionCreateRequest) async throws -> MissionCreateResponse {
        let (data, _): (MissionCreateResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/create", body: request
        )
        return data
    }

    /// List missions for the authenticated user.
    public func missionList(status: String? = nil) async throws -> MissionListResponse {
        var path = "/qai/v1/missions/list"
        if let status { path += "?status=\(status)" }
        let (data, _): (MissionListResponse, _) = try await http.doJSON(method: "GET", path: path)
        return data
    }

    /// Get mission details including tasks.
    public func missionGet(missionId: String) async throws -> MissionDetail {
        let (data, _): (MissionDetail, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/missions/\(missionId)"
        )
        return data
    }

    /// Delete a mission.
    public func missionDelete(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "DELETE", path: "/qai/v1/missions/\(missionId)"
        )
        return data
    }

    /// Cancel a running mission.
    public func missionCancel(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/cancel"
        )
        return data
    }

    /// Pause a running mission.
    public func missionPause(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/pause"
        )
        return data
    }

    /// Resume a paused mission.
    public func missionResume(missionId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/resume"
        )
        return data
    }

    /// Chat with the mission's architect.
    public func missionChat(missionId: String, request: MissionChatRequest) async throws -> MissionChatResponse {
        let (data, _): (MissionChatResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/chat", body: request
        )
        return data
    }

    /// Retry a failed task.
    public func missionRetryTask(missionId: String, taskId: String) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/retry/\(taskId)"
        )
        return data
    }

    /// Approve a completed mission.
    public func missionApprove(missionId: String, request: MissionApproveRequest) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/approve", body: request
        )
        return data
    }

    /// Update the mission plan.
    public func missionUpdatePlan(missionId: String, request: MissionPlanUpdate) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "PUT", path: "/qai/v1/missions/\(missionId)/plan", body: request
        )
        return data
    }

    /// Confirm or reject the proposed execution structure.
    public func missionConfirmStructure(missionId: String, request: MissionConfirmStructure) async throws -> MissionStatusResponse {
        let (data, _): (MissionStatusResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/\(missionId)/confirm-structure", body: request
        )
        return data
    }

    /// List git checkpoints for a mission.
    public func missionCheckpoints(missionId: String) async throws -> MissionCheckpointsResponse {
        let (data, _): (MissionCheckpointsResponse, _) = try await http.doJSON(
            method: "GET", path: "/qai/v1/missions/\(missionId)/checkpoints"
        )
        return data
    }

    /// Import an existing plan as a new mission.
    public func missionImport(_ request: MissionImportRequest) async throws -> MissionCreateResponse {
        let (data, _): (MissionCreateResponse, _) = try await http.doJSON(
            method: "POST", path: "/qai/v1/missions/import", body: request
        )
        return data
    }

    // MARK: - Mission Streaming

    /// Stream a mission execution via SSE. Returns events as the mission progresses through
    /// planning, task execution, and completion phases.
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
            Task {
                do {
                    let (bytes, _) = try await self.http.doStreamRequest(
                        path: "/qai/v1/missions", body: request
                    )
                    let parser = SSEParser(bytes: bytes)

                    for try await sseEvent in parser {
                        switch sseEvent {
                        case .done:
                            continuation.yield(MissionStreamEvent(type: "done", done: true))
                            continuation.finish()
                            return
                        case let .data(data):
                            let event = try parseMissionStreamEvent(data)
                            continuation.yield(event)
                            if event.done {
                                continuation.finish()
                                return
                            }
                        case let .error(message):
                            continuation.yield(MissionStreamEvent(type: "error", done: true, error: message))
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Workspace

    /// Upload a tar.gz workspace archive for a coding session.
    ///
    /// - Parameters:
    ///   - sessionId: The session ID to associate the workspace with.
    ///   - tarGzData: Raw tar.gz archive bytes.
    /// - Returns: Upload confirmation with extracted file count and workspace path.
    public func workspaceUpload(sessionId: String, tarGzData: Data) async throws -> WorkspaceUploadResponse {
        let (data, _): (WorkspaceUploadResponse, _) = try await http.doRawUpload(
            path: "/qai/v1/workspace/\(sessionId)/upload",
            data: tarGzData,
            contentType: "application/gzip"
        )
        return data
    }

    /// Download the workspace tar.gz after mission completion.
    ///
    /// - Parameter sessionId: The session ID of the workspace to download.
    /// - Returns: Raw tar.gz archive bytes.
    public func workspaceDownload(sessionId: String) async throws -> Data {
        let (data, _) = try await http.doRawDownload(
            path: "/qai/v1/workspace/\(sessionId)/download"
        )
        return data
    }

    // MARK: - Private Mission Stream Parsing

    /// Parse a raw SSE JSON payload into a ``MissionStreamEvent``.
    private func parseMissionStreamEvent(_ data: Data) throws -> MissionStreamEvent {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(RawMissionStreamEvent.self, from: data)

        var event = MissionStreamEvent(
            type: raw.type ?? "unknown",
            done: raw.type == "mission_completed" || raw.type == "mission_failed"
        )

        switch raw.type {
        case "mission_started":
            event.sessionId = raw.sessionId
            event.conductor = raw.conductor
            event.strategy = raw.strategy
            event.workers = raw.workers
            event.maxSteps = raw.maxSteps

        case "step_detail":
            event.step = raw.step
            event.role = raw.role
            event.tier = raw.tier
            event.durationMs = raw.durationMs
            event.delegated = raw.delegated
            event.content = raw.content

        case "mission_completed":
            event.content = raw.content
            event.cost = raw.cost
            event.totalSteps = raw.totalSteps
            event.workspacePath = raw.workspacePath
            event.filesGenerated = raw.filesGenerated
            event.buildPassed = raw.buildPassed

        case "mission_failed":
            event.error = raw.error ?? raw.message

        case "task_started", "task_completed", "task_failed":
            event.missionId = raw.missionId
            event.taskId = raw.taskId
            event.message = raw.message
            event.content = raw.content
            if raw.type == "task_failed" {
                event.error = raw.error ?? raw.message
            }

        case "tick_completed":
            event.step = raw.step
            event.content = raw.content

        case "usage":
            event.inputTokens = raw.inputTokens
            event.outputTokens = raw.outputTokens
            event.costTicks = raw.costTicks

        case "error":
            event.error = raw.error ?? raw.message

        default:
            break
        }

        return event
    }
}

// MARK: - Mission Stream Types

/// A streamed event from a mission execution.
public struct MissionStreamEvent: Sendable {
    /// Event type: mission_started, step_detail, mission_completed, mission_failed,
    /// usage, task_started, task_completed, task_failed, tick_completed, done, error.
    public var type: String
    /// Whether this event signals the end of the stream.
    public var done: Bool

    // mission_started fields
    public var sessionId: String?
    public var conductor: String?
    public var strategy: String?
    public var workers: [String: MissionWorkerDetail]?
    public var maxSteps: Int?

    // step_detail fields
    public var step: Int?
    public var role: String?
    public var tier: String?
    public var durationMs: Int?
    public var delegated: Bool?

    // mission_completed fields
    public var content: String?
    public var cost: MissionCost?
    public var totalSteps: Int?
    public var workspacePath: String?
    public var filesGenerated: Int?
    public var buildPassed: Bool?

    // task event fields
    public var missionId: String?
    public var taskId: String?
    public var message: String?

    // usage fields
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var costTicks: Int64?

    public var error: String?

    public init(
        type: String,
        done: Bool = false,
        sessionId: String? = nil,
        conductor: String? = nil,
        strategy: String? = nil,
        workers: [String: MissionWorkerDetail]? = nil,
        maxSteps: Int? = nil,
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
        buildPassed: Bool? = nil,
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
        self.sessionId = sessionId
        self.conductor = conductor
        self.strategy = strategy
        self.workers = workers
        self.maxSteps = maxSteps
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
        self.buildPassed = buildPassed
        self.missionId = missionId
        self.taskId = taskId
        self.message = message
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costTicks = costTicks
        self.error = error
    }
}

/// Cost breakdown by model tier.
public struct MissionCost: Codable, Sendable {
    public var cheap: Int?
    public var mid: Int?
    public var expensive: Int?

    public init(cheap: Int? = nil, mid: Int? = nil, expensive: Int? = nil) {
        self.cheap = cheap
        self.mid = mid
        self.expensive = expensive
    }
}

/// Response from uploading a workspace archive.
public struct WorkspaceUploadResponse: Codable, Sendable {
    /// Session ID the workspace was uploaded to.
    public let sessionId: String
    /// Number of files extracted from the archive.
    public let filesExtracted: Int
    /// Server-side workspace path.
    public let workspace: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case filesExtracted = "files_extracted"
        case workspace
    }
}

// MARK: - Raw Mission Stream Event (Internal)

/// Internal decoder for mission SSE payloads. Maps all possible fields from the wire format.
private struct RawMissionStreamEvent: Decodable {
    var type: String?

    // mission_started
    var sessionId: String?
    var conductor: String?
    var strategy: String?
    var workers: [String: MissionWorkerDetail]?
    var maxSteps: Int?

    // step_detail
    var step: Int?
    var role: String?
    var tier: String?
    var durationMs: Int?
    var delegated: Bool?

    // mission_completed
    var content: String?
    var cost: MissionCost?
    var totalSteps: Int?
    var workspacePath: String?
    var filesGenerated: Int?
    var buildPassed: Bool?

    // task events
    var missionId: String?
    var taskId: String?
    var message: String?

    // usage
    var inputTokens: Int?
    var outputTokens: Int?
    var costTicks: Int64?

    var error: String?

    enum CodingKeys: String, CodingKey {
        case type, conductor, strategy, workers, step, role, tier, delegated
        case content, cost, message, error
        case sessionId = "session_id"
        case maxSteps = "max_steps"
        case durationMs = "duration_ms"
        case totalSteps = "total_steps"
        case workspacePath = "workspace_path"
        case filesGenerated = "files_generated"
        case buildPassed = "build_passed"
        case missionId = "mission_id"
        case taskId = "task_id"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case costTicks = "cost_ticks"
    }
}

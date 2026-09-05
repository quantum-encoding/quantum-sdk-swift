import Foundation

// Agent runtime: the gateway's own agent / environment / session surface.
//
// A `RuntimeAgent` is a reusable config (model, system prompt, tools). A
// `RuntimeEnvironment` binds it to a backend: `coding-session` runs in the
// gateway's metered container, `managed-agents` projects onto Anthropic's
// hosted runtime and is admin-only. Starting a session returns a
// `RuntimeSession` descriptor which the client then holds and passes back on
// every session call. The event, stream, stop, and workspace routes read the
// descriptor rather than a server-side session record, but the server still
// resolves the session's owner from its own store by `upstream_id`: a
// descriptor it does not hold, or one belonging to someone else, is refused
// with 403 `not your session`.
//
// Agent and environment records are free to create and edit; spend starts at
// session start.

// MARK: - Agents

/// A tool reference on a runtime agent. `type` is the provider tool type
/// (e.g. `bash_20250124`); each backend maps it onto its own capability.
public struct RuntimeTool: Codable, Sendable, Equatable {
    /// Provider tool type.
    public var type: String

    /// Name the tool is exposed under.
    public var name: String

    public init(type: String, name: String) {
        self.type = type
        self.name = name
    }
}

/// Request body for creating a runtime agent.
///
/// The update route reads the same body but carries only `name` and `model`
/// forward when they are empty: an omitted `system_prompt` or `tools` is
/// written as empty. ``QuantumClient/agentRuntimeAgentUpdate(id:_:)``
/// therefore takes a ``RuntimeAgentUpdate`` and merges it onto the stored
/// agent before sending.
public struct RuntimeAgentRequest: Codable, Sendable {
    /// Display name for the agent.
    public var name: String

    /// Model the agent runs on.
    public var model: String

    /// System prompt. Omitted from the body when empty.
    public var systemPrompt: String

    /// Tools the agent may call. Omitted from the body when nil.
    public var tools: [RuntimeTool]?

    public init(name: String, model: String, systemPrompt: String = "", tools: [RuntimeTool]? = nil) {
        self.name = name
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
    }

    enum CodingKeys: String, CodingKey {
        case name, model, tools
        case systemPrompt = "system_prompt"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
        tools = try container.decodeIfPresent([RuntimeTool].self, forKey: .tools)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(model, forKey: .model)
        if !systemPrompt.isEmpty {
            try container.encode(systemPrompt, forKey: .systemPrompt)
        }
        try container.encodeIfPresent(tools, forKey: .tools)
    }
}

/// The fields to change on a runtime agent. `nil` keeps the stored value.
public struct RuntimeAgentUpdate: Sendable {
    /// New display name.
    public var name: String?

    /// New model.
    public var model: String?

    /// New system prompt. `""` clears it.
    public var systemPrompt: String?

    /// New tool list. `[]` clears it.
    public var tools: [RuntimeTool]?

    public init(name: String? = nil, model: String? = nil, systemPrompt: String? = nil, tools: [RuntimeTool]? = nil) {
        self.name = name
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
    }

    /// Merges the update onto a stored agent, producing the full body the
    /// update route writes.
    public func apply(to current: RuntimeAgent) -> RuntimeAgentRequest {
        RuntimeAgentRequest(
            name: name ?? current.name,
            model: model ?? current.model,
            systemPrompt: systemPrompt ?? current.systemPrompt,
            tools: tools ?? current.tools
        )
    }
}

/// A stored runtime agent.
public struct RuntimeAgent: Codable, Sendable {
    /// Agent identifier.
    public var id: String

    /// Owning user.
    public var userId: String?

    /// Display name.
    public var name: String

    /// Model the agent runs on.
    public var model: String

    /// System prompt.
    public var systemPrompt: String

    /// Tools the agent may call.
    @NullToEmpty public var tools: [RuntimeTool]

    /// Config version, bumped on every update.
    public var version: Int64?

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    /// RFC3339 timestamp of the last update.
    public var updatedAt: String?

    /// Backend-side id once the agent has been projected onto a backend.
    /// Absent until first instantiated.
    public var upstreamId: String?

    public init(
        id: String,
        userId: String? = nil,
        name: String,
        model: String,
        systemPrompt: String = "",
        tools: [RuntimeTool] = [],
        version: Int64? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        upstreamId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.model = model
        self.systemPrompt = systemPrompt
        self.tools = tools
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.upstreamId = upstreamId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
        _tools = try container.decode(NullToEmpty<RuntimeTool>.self, forKey: .tools)
        version = try container.decodeIfPresent(Int64.self, forKey: .version)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        upstreamId = try container.decodeIfPresent(String.self, forKey: .upstreamId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, model, tools, version
        case userId = "user_id"
        case systemPrompt = "system_prompt"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case upstreamId = "upstream_id"
    }
}

/// Response from `GET /qai/v1/agent-runtime/agents`.
public struct RuntimeAgentsResponse: Codable, Sendable {
    /// The caller's agents.
    @NullToEmpty public var agents: [RuntimeAgent]
}

/// Response from `PUT /qai/v1/agent-runtime/agents/{id}`: the update returns
/// the new config version rather than the whole record.
public struct RuntimeAgentUpdateResponse: Codable, Sendable {
    /// The agent that was updated.
    public var id: String

    /// The config version after the update.
    public var version: Int64
}

// MARK: - Environments

/// The git contract a `coding-session` environment runs under: which repo to
/// check out at which ref, the path the agent may write, and how its diff is
/// published. A session needs one of `coreRepo` and `workspaceObject`; the
/// environment route only checks that an overlay is present, so the mismatch
/// surfaces at session start rather than at creation.
public struct OverlayConfig: Codable, Sendable {
    /// Repository to check out.
    public var coreRepo: String

    /// Ref the checkout is pinned to.
    public var corePinnedRef: String

    /// Path within the checkout the agent may write.
    public var overlayPath: String

    /// Prefix for the per-session branch.
    public var branchPrefix: String

    /// Push the per-session branch to origin after each snapshot, so the diff
    /// survives the gateway workdir. Needs a git credential for the repo; push
    /// failures are reported, never fatal.
    public var pushBranch: Bool

    /// Seed the session from an uploaded archive instead of a git clone: the
    /// object returned by ``QuantumClient/agentRuntimeStageWorkspace(filename:archive:)``.
    /// Makes `pushBranch` meaningless (there is no origin). Omitted from the
    /// body when nil.
    public var workspaceObject: String?

    public init(
        coreRepo: String = "",
        corePinnedRef: String = "",
        overlayPath: String = "",
        branchPrefix: String = "",
        pushBranch: Bool = false,
        workspaceObject: String? = nil
    ) {
        self.coreRepo = coreRepo
        self.corePinnedRef = corePinnedRef
        self.overlayPath = overlayPath
        self.branchPrefix = branchPrefix
        self.pushBranch = pushBranch
        self.workspaceObject = workspaceObject
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coreRepo = try container.decodeIfPresent(String.self, forKey: .coreRepo) ?? ""
        corePinnedRef = try container.decodeIfPresent(String.self, forKey: .corePinnedRef) ?? ""
        overlayPath = try container.decodeIfPresent(String.self, forKey: .overlayPath) ?? ""
        branchPrefix = try container.decodeIfPresent(String.self, forKey: .branchPrefix) ?? ""
        pushBranch = try container.decodeIfPresent(Bool.self, forKey: .pushBranch) ?? false
        workspaceObject = try container.decodeIfPresent(String.self, forKey: .workspaceObject)
    }

    enum CodingKeys: String, CodingKey {
        case coreRepo = "core_repo"
        case corePinnedRef = "core_pinned_ref"
        case overlayPath = "overlay_path"
        case branchPrefix = "branch_prefix"
        case pushBranch = "push_branch"
        case workspaceObject = "workspace_object"
    }
}

/// Request body for `POST /qai/v1/agent-runtime/environments`.
public struct RuntimeEnvironmentRequest: Codable, Sendable {
    /// Display name for the environment.
    public var name: String

    /// Backend: `"coding-session"` or `"managed-agents"`. Required.
    public var backend: String

    /// Coding-session lifecycle: single-shot by default, or a long-lived
    /// multi-turn workspace. Ignored by the managed-agents backend.
    public var mode: String?

    /// Coding-session container size (`s`, `m`, `l`). Ignored by the
    /// managed-agents backend; empty means medium.
    public var tier: String?

    /// Container image override. Both backends have defaults.
    public var image: String?

    /// Stored credential references the session mounts (e.g. a git push
    /// token).
    public var vaultIds: [String]?

    /// The coding-session git contract. Required for that backend; omit for
    /// managed-agents environments.
    public var overlay: OverlayConfig?

    public init(
        name: String,
        backend: String,
        mode: String? = nil,
        tier: String? = nil,
        image: String? = nil,
        vaultIds: [String]? = nil,
        overlay: OverlayConfig? = nil
    ) {
        self.name = name
        self.backend = backend
        self.mode = mode
        self.tier = tier
        self.image = image
        self.vaultIds = vaultIds
        self.overlay = overlay
    }

    enum CodingKeys: String, CodingKey {
        case name, backend, mode, tier, image, overlay
        case vaultIds = "vault_ids"
    }
}

/// A stored runtime environment.
public struct RuntimeEnvironment: Codable, Sendable {
    /// Environment identifier.
    public var id: String

    /// Owning user.
    public var userId: String?

    /// Display name.
    public var name: String?

    /// Backend this environment runs on.
    public var backend: String?

    /// Coding-session lifecycle mode.
    public var mode: String?

    /// Coding-session container size.
    public var tier: String?

    /// Container image.
    public var image: String?

    /// Stored credential references.
    @NullToEmpty public var vaultIds: [String]

    /// The coding-session git contract, when there is one.
    public var overlay: OverlayConfig?

    /// Backend-side environment id once provisioned.
    public var upstreamId: String?

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, backend, mode, tier, image, overlay
        case userId = "user_id"
        case vaultIds = "vault_ids"
        case upstreamId = "upstream_id"
        case createdAt = "created_at"
    }
}

/// Response from `GET /qai/v1/agent-runtime/environments`.
public struct RuntimeEnvironmentsResponse: Codable, Sendable {
    /// The caller's environments.
    @NullToEmpty public var environments: [RuntimeEnvironment]
}

// MARK: - Sessions

/// Request body for `POST /qai/v1/agent-runtime/sessions`.
public struct StartSessionRequest: Codable, Sendable {
    /// The agent to run.
    public var agentId: String

    /// The environment to run it in.
    public var environmentId: String

    public init(agentId: String, environmentId: String) {
        self.agentId = agentId
        self.environmentId = environmentId
    }

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case environmentId = "environment_id"
    }
}

/// A running session. This descriptor is the whole of the client's session
/// state; every session call takes it as an argument.
public struct RuntimeSession: Codable, Sendable {
    /// Session identifier.
    public var id: String

    /// Owning user.
    public var userId: String

    /// The agent being run.
    public var agentId: String

    /// The environment it runs in.
    public var environmentId: String

    /// Backend the session runs on.
    public var backend: String

    /// Session status.
    public var status: String

    /// Backend-side session id. Required for every session call; omitted
    /// from the body when empty.
    public var upstreamId: String

    /// RFC3339 creation timestamp.
    public var createdAt: String

    public init(
        id: String = "",
        userId: String = "",
        agentId: String = "",
        environmentId: String = "",
        backend: String = "",
        status: String = "",
        upstreamId: String = "",
        createdAt: String = ""
    ) {
        self.id = id
        self.userId = userId
        self.agentId = agentId
        self.environmentId = environmentId
        self.backend = backend
        self.status = status
        self.upstreamId = upstreamId
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        agentId = try container.decodeIfPresent(String.self, forKey: .agentId) ?? ""
        environmentId = try container.decodeIfPresent(String.self, forKey: .environmentId) ?? ""
        backend = try container.decodeIfPresent(String.self, forKey: .backend) ?? ""
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        upstreamId = try container.decodeIfPresent(String.self, forKey: .upstreamId) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(agentId, forKey: .agentId)
        try container.encode(environmentId, forKey: .environmentId)
        try container.encode(backend, forKey: .backend)
        try container.encode(status, forKey: .status)
        if !upstreamId.isEmpty {
            try container.encode(upstreamId, forKey: .upstreamId)
        }
        try container.encode(createdAt, forKey: .createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, backend, status
        case userId = "user_id"
        case agentId = "agent_id"
        case environmentId = "environment_id"
        case upstreamId = "upstream_id"
        case createdAt = "created_at"
    }
}

/// One item appended to, or emitted from, a session. Type names follow the
/// Managed Agents event vocabulary so both backends stream the same shape.
///
/// ``QuantumClient/agentRuntimeSessionStream(_:since:)`` synthesises two
/// types of its own: `unknown` for a `data:` payload that is not a JSON
/// object, carrying the raw payload in ``content``, and `error` with a
/// `transport: ...` content when the connection fails mid-stream (the
/// gateway also writes an `error` event of its own when the upstream stream
/// fails; both end the stream).
public struct RuntimeEvent: Codable, Sendable {
    /// Event type (e.g. a user message, a model delta, a tool use/result, a
    /// status change).
    public var type: String

    /// Message role, when the event carries one. Omitted when empty.
    public var role: String

    /// Text payload, when the event carries one. Omitted when empty.
    public var content: String

    /// Structured payload, when the event carries one.
    public var data: [String: AnyCodable]?

    /// RFC3339 timestamp. Omitted when empty.
    public var timestamp: String

    /// 1-based sequence number, assigned only to durable structural events.
    /// Send the last one back as `since` to resume a dropped stream. Zero for
    /// ephemeral events (bash output, token deltas), which are never
    /// persisted or replayed. Omitted when zero.
    public var index: Int64

    public init(
        type: String,
        role: String = "",
        content: String = "",
        data: [String: AnyCodable]? = nil,
        timestamp: String = "",
        index: Int64 = 0
    ) {
        self.type = type
        self.role = role
        self.content = content
        self.data = data
        self.timestamp = timestamp
        self.index = index
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        data = try container.decodeIfPresent([String: AnyCodable].self, forKey: .data)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
        index = try container.decodeIfPresent(Int64.self, forKey: .index) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if !role.isEmpty { try container.encode(role, forKey: .role) }
        if !content.isEmpty { try container.encode(content, forKey: .content) }
        try container.encodeIfPresent(data, forKey: .data)
        if !timestamp.isEmpty { try container.encode(timestamp, forKey: .timestamp) }
        if index != 0 { try container.encode(index, forKey: .index) }
    }

    enum CodingKeys: String, CodingKey {
        case type, role, content, data, timestamp, index
    }
}

/// Request body for `POST /qai/v1/agent-runtime/sessions/events`.
public struct AppendEventRequest: Codable, Sendable {
    /// The session descriptor returned by
    /// ``QuantumClient/agentRuntimeSessionStart(_:)``.
    public var session: RuntimeSession

    /// The event to append.
    public var event: RuntimeEvent

    public init(session: RuntimeSession, event: RuntimeEvent) {
        self.session = session
        self.event = event
    }
}

/// Response from the session routes that only report success.
public struct RuntimeOkResponse: Codable, Sendable {
    /// True once the call was accepted.
    public var ok: Bool
}

/// Response from `POST /qai/v1/agent-runtime/workspaces`.
public struct StageWorkspaceResponse: Codable, Sendable {
    /// The staged object, to set as ``OverlayConfig/workspaceObject`` on the
    /// environment that launches the session.
    public var workspaceObject: String

    enum CodingKeys: String, CodingKey {
        case workspaceObject = "workspace_object"
    }
}

import Foundation

// Media sessions — server-side state for multi-turn Q&A over one uploaded
// media file.
//
// A session pins three things on the gateway: a Gemini Files API resource
// (uploaded via `fileUpload`), a Vertex context cache built over that file
// at session boot, and the conversation history. While the cache is alive a
// chat turn sends only the next user message and is billed at the
// cached-read rate; once `expiresAt` has passed the turn re-sends the file
// inline at the full input rate and the gateway rebuilds the cache
// afterwards.
//
// Sessions are stored server-side, so the same session id resumes from any
// device.

/// Request body for `POST /qai/v1/media-sessions`.
public struct MediaSessionCreateRequest: Codable, Sendable {
    /// Gemini Files API resource to pin, e.g. `files/abc123` or the
    /// fully-qualified upload URI. Required.
    public var fileUri: String

    /// MIME type of the pinned file (e.g. `video/mp4`). Required.
    public var mimeType: String

    /// Gemini model the session's cache is scoped to. Required, and must be a
    /// `gemini-*` id — context caching is Gemini-only.
    public var model: String

    /// System prompt baked into the cached prefix, so follow-up turns get the
    /// cache discount on it too.
    public var systemInstruction: String?

    /// Human-readable label for the session's cache. Defaults to the file URI
    /// tail.
    public var displayName: String?

    /// Requested cache TTL in seconds. Clamped server-side to `[60, 86400]`;
    /// defaults to 3600.
    public var cacheTtlSeconds: Int64?

    public init(
        fileUri: String,
        mimeType: String,
        model: String,
        systemInstruction: String? = nil,
        displayName: String? = nil,
        cacheTtlSeconds: Int64? = nil
    ) {
        self.fileUri = fileUri
        self.mimeType = mimeType
        self.model = model
        self.systemInstruction = systemInstruction
        self.displayName = displayName
        self.cacheTtlSeconds = cacheTtlSeconds
    }

    enum CodingKeys: String, CodingKey {
        case model
        case fileUri = "file_uri"
        case mimeType = "mime_type"
        case systemInstruction = "system_instruction"
        case displayName = "display_name"
        case cacheTtlSeconds = "cache_ttl_seconds"
    }
}

/// One persisted turn of a media session's conversation.
public struct MediaSessionTurn: Codable, Sendable {
    /// `"user"` or `"assistant"`.
    public var role: String

    /// The message text.
    public var content: String

    /// RFC3339 timestamp of the turn.
    public var at: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        at = try c.decodeIfPresent(String.self, forKey: .at)
    }
}

/// A media session record as returned by create / get / list.
public struct MediaSession: Codable, Sendable {
    /// Session identifier — the `{id}` in the session sub-routes.
    public var id: String

    /// The pinned Gemini Files API resource.
    public var fileUri: String

    /// MIME type of the pinned file.
    public var mimeType: String

    /// The session's display name, else the tail of the file URI, else
    /// "untitled media session".
    public var fileDisplayName: String?

    /// Vertex cache resource name (`cachedContents/...`) backing the session.
    public var cacheName: String

    /// Input-token count of the cache at default media resolution. Zero means
    /// the gateway could not determine it.
    public var cacheTokenCount: Int64

    /// Gemini model the session's cache is scoped to.
    public var model: String

    /// System prompt baked into the cached prefix, if any.
    public var systemInstruction: String?

    /// Conversation history, oldest first.
    @NullToEmpty public var history: [MediaSessionTurn]

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    /// RFC3339 timestamp of the last chat turn.
    public var lastUsedAt: String?

    /// RFC3339 timestamp at which the underlying cache expires.
    public var expiresAt: String?

    /// Number of messages recorded on the session.
    public var messageCount: Int64

    enum CodingKeys: String, CodingKey {
        case id, model, history
        case fileUri = "file_uri"
        case mimeType = "mime_type"
        case fileDisplayName = "file_display_name"
        case cacheName = "cache_name"
        case cacheTokenCount = "cache_token_count"
        case systemInstruction = "system_instruction"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case expiresAt = "expires_at"
        case messageCount = "message_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        fileUri = try c.decodeIfPresent(String.self, forKey: .fileUri) ?? ""
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? ""
        fileDisplayName = try c.decodeIfPresent(String.self, forKey: .fileDisplayName)
        cacheName = try c.decodeIfPresent(String.self, forKey: .cacheName) ?? ""
        cacheTokenCount = try c.decodeIfPresent(Int64.self, forKey: .cacheTokenCount) ?? 0
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        systemInstruction = try c.decodeIfPresent(String.self, forKey: .systemInstruction)
        _history = try c.decode(NullToEmpty<MediaSessionTurn>.self, forKey: .history)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastUsedAt = try c.decodeIfPresent(String.self, forKey: .lastUsedAt)
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        messageCount = try c.decodeIfPresent(Int64.self, forKey: .messageCount) ?? 0
    }
}

/// Response from `GET /qai/v1/media-sessions`.
public struct MediaSessionListResponse: Codable, Sendable {
    /// The caller's sessions, most recently used first.
    @NullToEmpty public var sessions: [MediaSession]
}

/// Request body for `POST /qai/v1/media-sessions/{id}/chat`.
public struct MediaSessionChatRequest: Codable, Sendable {
    /// The next user message. Required.
    public var message: String

    /// Output token cap for this turn.
    public var maxTokens: Int?

    /// Sampling temperature for this turn.
    public var temperature: Double?

    /// JSON Schema the model is forced to fill for this turn. Applied per-turn
    /// without invalidating the session cache.
    public var outputSchema: [String: AnyCodable]?

    public init(message: String, maxTokens: Int? = nil, temperature: Double? = nil, outputSchema: [String: AnyCodable]? = nil) {
        self.message = message
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.outputSchema = outputSchema
    }

    enum CodingKeys: String, CodingKey {
        case message, temperature
        case maxTokens = "max_tokens"
        case outputSchema = "output_schema"
    }
}

/// Response from `POST /qai/v1/media-sessions/{id}/chat`.
public struct MediaSessionChatResponse: Codable, Sendable {
    /// The session the turn was appended to.
    public var sessionId: String

    /// The assistant's reply.
    public var answer: String

    /// Token usage and cost for this turn.
    public var usage: ChatUsage?

    /// The session's full history including this turn.
    @NullToEmpty public var history: [MediaSessionTurn]

    enum CodingKeys: String, CodingKey {
        case answer, usage, history
        case sessionId = "session_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        answer = try c.decodeIfPresent(String.self, forKey: .answer) ?? ""
        usage = try c.decodeIfPresent(ChatUsage.self, forKey: .usage)
        _history = try c.decode(NullToEmpty<MediaSessionTurn>.self, forKey: .history)
    }
}

/// Response from `DELETE /qai/v1/media-sessions/{id}`.
public struct MediaSessionDeleteResponse: Codable, Sendable {
    /// True once the session record is deleted; releasing the context cache
    /// is best-effort and does not change the answer. Deleting an
    /// already-absent session also reports `true` — the call is idempotent.
    public var deleted: Bool

    /// Present when the session was already gone (`"already absent"`).
    public var note: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

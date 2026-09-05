import Foundation

// Gemini context caching.
//
// A cache pins an uploaded file (and an optional system prompt) at the
// provider so follow-up turns are billed at the cached-read rate instead of
// re-sending the whole file each time. Create a cache over a `fileUri` from
// `fileUpload`, then pass the returned `cacheName` as `cached_content` on
// subsequent chat requests.
//
// Caching is Gemini-only, and the provider requires a minimum of ~4096 tokens
// of content — files below that are rejected with `cache_too_small`, and the
// caller should fall back to attaching the file directly.

/// Request body for `POST /qai/v1/caches`.
public struct CacheCreateRequest: Codable, Sendable {
    /// Provider file resource to cache (e.g. `files/abc123`). Required.
    public var fileUri: String

    /// MIME type of the cached file. Required.
    public var mimeType: String

    /// Gemini model id the cache is scoped to. Required — a cache can only be
    /// read back by the model it was created for.
    public var model: String

    /// System prompt baked into the cached prefix so follow-up turns get the
    /// discount on it too.
    public var systemInstruction: String?

    /// Human-readable label. Defaults to the file URI tail.
    public var displayName: String?

    /// Requested lifetime in seconds. Clamped server-side to `[60, 86400]`;
    /// defaults to 3600. Cached tokens bill per stored token-hour, so a long
    /// TTL over a large file is real money.
    public var ttlSeconds: Int64?

    public init(
        fileUri: String,
        mimeType: String,
        model: String,
        systemInstruction: String? = nil,
        displayName: String? = nil,
        ttlSeconds: Int64? = nil
    ) {
        self.fileUri = fileUri
        self.mimeType = mimeType
        self.model = model
        self.systemInstruction = systemInstruction
        self.displayName = displayName
        self.ttlSeconds = ttlSeconds
    }

    enum CodingKeys: String, CodingKey {
        case model
        case fileUri = "file_uri"
        case mimeType = "mime_type"
        case systemInstruction = "system_instruction"
        case displayName = "display_name"
        case ttlSeconds = "ttl_seconds"
    }
}

/// Response from `POST /qai/v1/caches`.
public struct CacheCreateResponse: Codable, Sendable {
    /// Provider resource name (`cachedContents/...`). Pass verbatim as
    /// `cached_content` on chat requests.
    public var cacheName: String

    /// The model the cache is scoped to, echoed back.
    public var model: String

    /// RFC3339 expiry. Chat calls referencing the cache after this 404.
    public var expiresAt: String

    /// The label set at creation, or the auto-derived one.
    public var displayName: String

    /// Number of tokens the cache occupies, when the provider reported it.
    public var tokenCount: Int64

    enum CodingKeys: String, CodingKey {
        case model
        case cacheName = "cache_name"
        case expiresAt = "expires_at"
        case displayName = "display_name"
        case tokenCount = "token_count"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cacheName = try c.decodeIfPresent(String.self, forKey: .cacheName) ?? ""
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? ""
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        tokenCount = try c.decodeIfPresent(Int64.self, forKey: .tokenCount) ?? 0
    }
}

/// Response from `DELETE /qai/v1/caches/{name}`.
public struct CacheDeleteResponse: Codable, Sendable {
    /// True once the cache is released. A cache that already expired also
    /// reports `true` — the call is idempotent.
    public var deleted: Bool

    /// Present when the cache was already gone
    /// (`"already expired or unknown"`).
    public var note: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

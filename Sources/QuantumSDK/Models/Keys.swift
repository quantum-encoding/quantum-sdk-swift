import Foundation

// MARK: - Create Key

/// Request body for creating an API key.
public struct CreateKeyRequest: Codable, Sendable {
    /// Human-readable name for the key.
    public var name: String

    /// Restrict to specific endpoints (e.g. ["chat", "images"]).
    public var endpoints: [String]?

    /// Maximum spend in USD before the key is disabled.
    public var spendCapUsd: Double?

    /// Rate limit in requests per minute.
    public var rateLimit: Int?

    /// Routing region for every request made with this key: `"americas"`,
    /// `"europe"`, or `"asia"` (see ``Region``). The gateway scopes the
    /// key's inference routing to that region; nil = unscoped legacy
    /// routing. Honored on standard key creation only — partner and
    /// ephemeral keys ignore it.
    public var region: String?

    public init(
        name: String,
        endpoints: [String]? = nil,
        spendCapUsd: Double? = nil,
        rateLimit: Int? = nil,
        region: Region? = nil
    ) {
        self.name = name
        self.endpoints = endpoints
        self.spendCapUsd = spendCapUsd
        self.rateLimit = rateLimit
        self.region = region?.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case name, endpoints, region
        case spendCapUsd = "spend_cap_usd"
        case rateLimit = "rate_limit"
    }
}

// MARK: - Key Details

/// Details about an API key.
public struct KeyDetails: Codable, Sendable {
    /// Unique key identifier.
    public var id: String

    /// Human-readable name.
    public var name: String

    /// First characters of the key for identification.
    public var keyPrefix: String?

    /// Scope restrictions.
    public var scope: AnyCodable?

    /// Amount spent by this key in ticks.
    public var spentTicks: Int64?

    /// Whether the key has been revoked.
    public var revoked: Bool?

    /// Creation timestamp (RFC 3339).
    public var createdAt: String?

    /// Last usage timestamp (RFC 3339).
    public var lastUsed: String?

    enum CodingKeys: String, CodingKey {
        case id, name, scope, revoked
        case keyPrefix = "key_prefix"
        case spentTicks = "spent_ticks"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }

    /// The key's effective routing region from its scope (`scope.region`) —
    /// `nil` for unscoped legacy keys. Compare against ``Region`` raw
    /// values or re-parse with ``Region/init(parsing:)``.
    public var scopeRegion: String? {
        guard let scopeDict = scope?.value as? [String: Any],
              let region = scopeDict["region"] as? String,
              !region.isEmpty
        else { return nil }
        return region
    }
}

/// Response from creating an API key.
public struct CreateKeyResponse: Codable, Sendable {
    /// The full API key (only shown once on creation).
    public var key: String

    /// Key metadata.
    public var details: KeyDetails?

    enum CodingKeys: String, CodingKey {
        case key, details
    }
}

/// Response from listing API keys.
public struct ListKeysResponse: Codable, Sendable {
    /// All keys for the account.
    public var keys: [KeyDetails]
}

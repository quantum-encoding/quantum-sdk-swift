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

    /// Routing region for every request made with this key. The gateway
    /// scopes the key's inference routing to that region; nil = unscoped
    /// legacy routing. Honored on standard key creation only — partner and
    /// ephemeral keys ignore it. Typed so a typo cannot reach the wire: the
    /// gateway would degrade an unknown value to unscoped routing without
    /// an error.
    public var region: Region?

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
        self.region = region
    }

    enum CodingKeys: String, CodingKey {
        case name, endpoints, region
        case spendCapUsd = "spend_cap_usd"
        case rateLimit = "rate_limit"
    }
}

// MARK: - Key Details

/// Details about an API key (returned on creation and listing).
public struct KeyDetails: Codable, Sendable {
    /// Unique key identifier.
    public var id: String

    /// Human-readable name.
    public var name: String

    /// First characters of the key for identification.
    public var keyPrefix: String

    /// Scope restrictions.
    public var scope: AnyCodable?

    /// Amount spent by this key in ticks.
    public var spentTicks: Int64

    /// Whether the key has been revoked.
    public var revoked: Bool

    /// Creation timestamp (RFC 3339).
    public var createdAt: String?

    /// Last usage timestamp (RFC 3339). Only present in list responses.
    public var lastUsed: String?

    enum CodingKeys: String, CodingKey {
        case id, name, scope, revoked
        case keyPrefix = "key_prefix"
        case spentTicks = "spent_ticks"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        keyPrefix = try c.decodeIfPresent(String.self, forKey: .keyPrefix) ?? ""
        scope = try c.decodeIfPresent(AnyCodable.self, forKey: .scope)
        spentTicks = try c.decodeIfPresent(Int64.self, forKey: .spentTicks) ?? 0
        revoked = try c.decodeIfPresent(Bool.self, forKey: .revoked) ?? false
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastUsed = try c.decodeIfPresent(String.self, forKey: .lastUsed)
    }

    /// The key's effective routing region from its scope (`scope.region`),
    /// `nil` for unscoped legacy keys or a scope value the SDK does not
    /// recognise.
    public var scopeRegion: Region? {
        guard let scopeDict = scope?.value as? [String: Any],
              let region = scopeDict["region"] as? String
        else { return nil }
        return Region(parsing: region)
    }
}

/// Response from creating an API key. `description` masks the key.
public struct CreateKeyResponse: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The full API key (only shown once on creation).
    public var key: String

    /// Key metadata.
    public var details: KeyDetails

    enum CodingKeys: String, CodingKey {
        case key, details
    }

    public var description: String {
        "CreateKeyResponse(key: \(redact(key)), id: \(details.id))"
    }

    public var debugDescription: String { description }
}

/// Response from listing API keys.
public struct ListKeysResponse: Codable, Sendable {
    /// All keys for the account.
    public var keys: [KeyDetails]
}

// MARK: - Device Keys

/// A per-device default key, as listed by `listDeviceKeys()`.
public struct DeviceKey: Codable, Sendable {
    /// Key identifier.
    public var keyId: String
    /// The device the key was minted for.
    public var deviceId: String?
    /// First characters of the key.
    public var keyPrefix: String?
    /// When it was created.
    public var createdAt: String?
    /// When it was last used, if ever.
    public var lastUsed: String?

    enum CodingKeys: String, CodingKey {
        case keyId = "key_id"
        case deviceId = "device_id"
        case keyPrefix = "key_prefix"
        case createdAt = "created_at"
        case lastUsed = "last_used"
    }
}

/// Response from listing device keys.
public struct ListDeviceKeysResponse: Codable, Sendable {
    public var devices: [DeviceKey]
}

// MARK: - Rotate

/// Request body for rotating a key.
public struct RotateKeyRequest: Codable, Sendable {
    /// How long the old key keeps working after rotation, in seconds. 0
    /// revokes it at once.
    public var graceSeconds: Int64

    public init(graceSeconds: Int64 = 0) {
        self.graceSeconds = graceSeconds
    }

    enum CodingKeys: String, CodingKey {
        case graceSeconds = "grace_seconds"
    }
}

/// Response from rotating a key. `description` masks the new key.
public struct RotateKeyResponse: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The new key, shown once.
    public var key: String
    /// The new key's details.
    public var details: KeyDetails
    /// The id of the key that was rotated out.
    public var oldKeyId: String?

    enum CodingKeys: String, CodingKey {
        case key, details
        case oldKeyId = "old_key_id"
    }

    public var description: String {
        "RotateKeyResponse(key: \(redact(key)), id: \(details.id), oldKeyId: \(oldKeyId ?? "nil"))"
    }

    public var debugDescription: String { description }
}

// MARK: - Key Usage

/// One day of a key's usage.
public struct KeyUsageDay: Codable, Sendable {
    public var day: String
    public var requests: Int64
    public var costUsd: Double
    public var inputTokens: Int64
    public var outputTokens: Int64

    enum CodingKeys: String, CodingKey {
        case day, requests
        case costUsd = "cost_usd"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        requests = try c.decode(Int64.self, forKey: .requests)
        costUsd = try c.decode(Double.self, forKey: .costUsd)
        inputTokens = try c.decodeIfPresent(Int64.self, forKey: .inputTokens) ?? 0
        outputTokens = try c.decodeIfPresent(Int64.self, forKey: .outputTokens) ?? 0
    }
}

/// A key's usage on one model.
public struct KeyUsageModel: Codable, Sendable {
    public var model: String
    public var requests: Int64
    public var costUsd: Double

    enum CodingKeys: String, CodingKey {
        case model, requests
        case costUsd = "cost_usd"
    }
}

/// Response from `keyUsage(id:)`.
public struct KeyUsageResponse: Codable, Sendable {
    public var days: [KeyUsageDay]
    public var models: [KeyUsageModel]
    public var totalCostUsd: Double

    enum CodingKeys: String, CodingKey {
        case days, models
        case totalCostUsd = "total_cost_usd"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        days = try c.decodeIfPresent([KeyUsageDay].self, forKey: .days) ?? []
        models = try c.decodeIfPresent([KeyUsageModel].self, forKey: .models) ?? []
        totalCostUsd = try c.decodeIfPresent(Double.self, forKey: .totalCostUsd) ?? 0
    }
}

// MARK: - Ephemeral Keys

/// Request body for an ephemeral key: a short-lived token a server hands
/// to a browser or device so it can call the gateway directly.
public struct EphemeralKeyRequest: Codable, Sendable {
    /// Lifetime in seconds (default 3600, at most 86400).
    public var ttl: Int64?
    /// Downstream user id, for attribution.
    public var userRef: String?
    /// Spend cap for the session, in USD.
    public var spendCap: Double?
    /// Endpoints the token may call.
    public var endpoints: [String]?
    /// Requests per minute.
    public var rateLimit: Int?

    public init(ttl: Int64? = nil, userRef: String? = nil, spendCap: Double? = nil, endpoints: [String]? = nil, rateLimit: Int? = nil) {
        self.ttl = ttl
        self.userRef = userRef
        self.spendCap = spendCap
        self.endpoints = endpoints
        self.rateLimit = rateLimit
    }

    enum CodingKeys: String, CodingKey {
        case ttl, endpoints
        case userRef = "user_ref"
        case spendCap = "spend_cap"
        case rateLimit = "rate_limit"
    }
}

/// Response from `createEphemeralKey(_:)`. `description` masks the token.
public struct EphemeralKeyResponse: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The token, shown once.
    public var token: String
    /// When it expires (RFC 3339).
    public var expiresAt: String
    /// The gateway the token is for.
    public var baseUrl: String?

    enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case baseUrl = "base_url"
    }

    public var description: String {
        "EphemeralKeyResponse(token: \(redact(token)), expiresAt: \(expiresAt))"
    }

    public var debugDescription: String { description }
}

// MARK: - Partner Keys

/// Request body for a partner key: a key minted on behalf of a partner
/// app's end user, attributed to that user.
public struct PartnerKeyRequest: Codable, Sendable {
    /// The partner (e.g. `"cosmicduck"`).
    public var partnerId: String
    /// The partner's user id.
    public var partnerRef: String
    /// Display name (default `partner:{partnerRef}`).
    public var name: String?
    /// Spend cap for the key, in USD.
    public var spendCapUsd: Double?
    /// Endpoints the key may call.
    public var endpoints: [String]?
    /// Requests per minute.
    public var rateLimit: Int?

    public init(partnerId: String, partnerRef: String, name: String? = nil, spendCapUsd: Double? = nil, endpoints: [String]? = nil, rateLimit: Int? = nil) {
        self.partnerId = partnerId
        self.partnerRef = partnerRef
        self.name = name
        self.spendCapUsd = spendCapUsd
        self.endpoints = endpoints
        self.rateLimit = rateLimit
    }

    enum CodingKeys: String, CodingKey {
        case name, endpoints
        case partnerId = "partner_id"
        case partnerRef = "partner_ref"
        case spendCapUsd = "spend_cap_usd"
        case rateLimit = "rate_limit"
    }
}

/// Response from `createPartnerKey(_:)`. `description` masks the key.
public struct PartnerKeyResponse: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// The key, shown once.
    public var key: String
    /// The key's details.
    public var details: KeyDetails
    /// The gateway the key is for.
    public var baseUrl: String?

    enum CodingKeys: String, CodingKey {
        case key, details
        case baseUrl = "base_url"
    }

    public var description: String {
        "PartnerKeyResponse(key: \(redact(key)), id: \(details.id))"
    }

    public var debugDescription: String { description }
}

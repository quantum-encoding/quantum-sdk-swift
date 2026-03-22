import Foundation

// MARK: - Create Key

/// Request body for the `/qai/v1/keys` endpoint.
public struct CreateKeyRequest: Codable, Sendable {
    /// Key name.
    public var name: String

    /// Permission scopes.
    public var scopes: [String]?

    /// Expiration date (ISO 8601).
    public var expiresAt: String?

    public init(name: String, scopes: [String]? = nil, expiresAt: String? = nil) {
        self.name = name
        self.scopes = scopes
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case name, scopes
        case expiresAt = "expires_at"
    }
}

/// Response from creating an API key.
public struct CreateKeyResponse: Codable, Sendable {
    /// The full API key (only shown once).
    public var key: String

    /// Key ID.
    public var id: String
}

// MARK: - Key Details

/// Details about an API key.
public struct KeyDetails: Codable, Sendable {
    /// Key ID.
    public var id: String

    /// Key name.
    public var name: String

    /// Key prefix (first few characters).
    public var prefix: String

    /// Permission scopes.
    public var scopes: [String]?

    /// Creation timestamp.
    public var createdAt: String

    /// Expiration timestamp.
    public var expiresAt: String?

    /// Last used timestamp.
    public var lastUsedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, prefix, scopes
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
    }
}

/// Response from listing API keys.
public struct ListKeysResponse: Codable, Sendable {
    /// API keys.
    public var keys: [KeyDetails]
}

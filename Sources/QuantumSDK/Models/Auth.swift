// Authentication — sign in via OAuth providers, verify keys, end sessions.
//
// Every sign-in answers with the same `AuthResponse`: a session token (the
// bearer for later calls), when it expires, the account's default API key,
// and the user. An app that signs a person in never has to hold a developer
// key — the token is the credential.

import Foundation

// MARK: - Auth User

/// User information returned after authentication.
public struct AuthUser: Codable, Sendable {
    /// User ID.
    public var id: String

    /// Display name (`display_name` on the wire; the older `name` spelling
    /// is read too).
    public var name: String?

    /// Email address.
    public var email: String?

    /// Avatar URL (`photo_url` on the wire; the older `avatar_url` spelling
    /// is read too).
    public var avatarUrl: String?

    /// Credit balance in ticks (10¹⁰ ticks per USD).
    public var creditTicks: Int64?

    /// Account role (e.g. `"user"`, `"admin"`).
    public var role: String?

    enum CodingKeys: String, CodingKey {
        case id, email, role, name
        case displayName = "display_name"
        case photoUrl = "photo_url"
        case avatarUrl = "avatar_url"
        case creditTicks = "credit_ticks"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .displayName)
            ?? c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
            ?? c.decodeIfPresent(String.self, forKey: .avatarUrl)
        creditTicks = try c.decodeIfPresent(Int64.self, forKey: .creditTicks)
        role = try c.decodeIfPresent(String.self, forKey: .role)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .displayName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(avatarUrl, forKey: .photoUrl)
        try c.encodeIfPresent(creditTicks, forKey: .creditTicks)
        try c.encodeIfPresent(role, forKey: .role)
    }

    public init(id: String, name: String? = nil, email: String? = nil, avatarUrl: String? = nil, creditTicks: Int64? = nil, role: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.creditTicks = creditTicks
        self.role = role
    }
}

// MARK: - Auth Response

/// Response from authentication endpoints.
///
/// Carries two live credentials (``token`` and ``apiKey``). `description`
/// masks both, so an interpolated or printed value never leaks them.
public struct AuthResponse: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// Session token: the bearer for subsequent requests.
    public var token: String

    /// When the session token expires (RFC 3339).
    public var expiresAt: String?

    /// The account's default API key, for clients that persist a key
    /// rather than a session.
    public var apiKey: String?

    /// Email address of the signed-in account.
    public var email: String?

    /// Credit balance in USD at sign-in.
    public var creditUsd: Double?

    /// Authenticated user.
    public var user: AuthUser

    enum CodingKeys: String, CodingKey {
        case token, email, user
        case expiresAt = "expires_at"
        case apiKey = "api_key"
        case creditUsd = "credit_usd"
    }

    public var description: String {
        "AuthResponse(token: \(redact(token)), apiKey: \(apiKey.map(redact) ?? "nil"), "
            + "expiresAt: \(expiresAt ?? "nil"), email: \(email ?? "nil"), user: \(user.id))"
    }

    public var debugDescription: String { description }
}

/// A credential with everything but its prefix hidden.
func redact(_ secret: String) -> String {
    let visible = secret.prefix(6)
    return secret.count > 6 ? "\(visible)…[redacted]" : "[redacted]"
}

// MARK: - Apple Sign-In

/// Request body for the `/qai/v1/auth/apple` endpoint.
public struct AuthAppleRequest: Codable, Sendable {
    /// The Apple identity token (JWT from Sign in with Apple).
    public var idToken: String

    /// Optional display name (only provided on first sign-in).
    public var name: String?

    /// The raw nonce the sign-in was started with; its SHA-256 is checked
    /// against the token's claim for replay protection. The gateway
    /// enforces it only when one is sent.
    public var nonce: String?

    /// Per-device key bucket: each device gets its own default key. Empty
    /// means the account's shared default.
    public var deviceId: String?

    /// The authorization code from Sign in with Apple, when the app has one
    /// (Apple supplies it on first authorization only). The gateway
    /// exchanges it for the refresh token account deletion needs in order
    /// to revoke the Apple sign-in.
    public var authorizationCode: String?

    public init(idToken: String, name: String? = nil, nonce: String? = nil, deviceId: String? = nil, authorizationCode: String? = nil) {
        self.idToken = idToken
        self.name = name
        self.nonce = nonce
        self.deviceId = deviceId
        self.authorizationCode = authorizationCode
    }

    enum CodingKeys: String, CodingKey {
        case name, nonce
        case idToken = "id_token"
        case deviceId = "device_id"
        case authorizationCode = "authorization_code"
    }
}

// MARK: - Google Sign-In

/// Request body for the `/qai/v1/auth/google` endpoint.
public struct AuthGoogleRequest: Codable, Sendable {
    /// The Google ID token (JWT) from the OAuth flow.
    public var idToken: String

    /// The OAuth client ID the token was issued for. The gateway checks the
    /// token's audience against it first and, when that fails, against
    /// every other client id it recognises, so a token minted for a
    /// different recognised client still signs in. An unrecognised id is
    /// rejected.
    public var clientId: String

    /// Per-device key bucket (see ``AuthAppleRequest/deviceId``).
    public var deviceId: String?

    public init(idToken: String, clientId: String, deviceId: String? = nil) {
        self.idToken = idToken
        self.clientId = clientId
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case clientId = "client_id"
        case deviceId = "device_id"
    }
}

// MARK: - Firebase Sign-In

/// Request body for the `/qai/v1/auth/firebase` endpoint (any Firebase
/// Auth provider).
public struct AuthFirebaseRequest: Codable, Sendable {
    /// The Firebase ID token.
    public var idToken: String

    /// Per-device key bucket (see ``AuthAppleRequest/deviceId``).
    public var deviceId: String?

    public init(idToken: String, deviceId: String? = nil) {
        self.idToken = idToken
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case deviceId = "device_id"
    }
}

// MARK: - Verify Key

/// Request body for the `/qai/v1/auth/verify-key` endpoint.
public struct VerifyKeyRequest: Codable, Sendable {
    /// The `qai_k_` key to resolve. `nil` verifies the calling credential.
    public var apiKey: String?

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
    }
}

/// Who a key belongs to.
public struct VerifyKeyResponse: Codable, Sendable {
    /// Always true on a 200; an unknown key is a 401.
    public var verified: Bool

    /// Owner's user id.
    public var userId: String

    /// Owner's Apple subject, when they signed in with Apple.
    public var appleSub: String?

    /// Owner's email.
    public var email: String?

    /// When the key was created (RFC 3339).
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case verified, email
        case userId = "user_id"
        case appleSub = "apple_sub"
        case createdAt = "created_at"
    }
}

// MARK: - Revoke Session

/// Outcome of revoking the calling session.
public struct RevokeSessionResponse: Codable, Sendable {
    /// `"revoked"`.
    public var status: String
}

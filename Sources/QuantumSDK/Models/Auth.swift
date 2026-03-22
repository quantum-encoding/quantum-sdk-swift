import Foundation

// MARK: - Auth User

/// User information returned after authentication.
public struct AuthUser: Codable, Sendable {
    /// User ID.
    public var id: String

    /// Display name.
    public var name: String?

    /// Email address.
    public var email: String?

    /// Avatar URL.
    public var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Auth Response

/// Response from authentication endpoints.
public struct AuthResponse: Codable, Sendable {
    /// Authentication token.
    public var token: String

    /// Authenticated user.
    public var user: AuthUser
}

// MARK: - Apple Sign-In

/// Request body for the `/qai/v1/auth/apple` endpoint.
public struct AuthAppleRequest: Codable, Sendable {
    /// The Apple identity token (JWT from Sign in with Apple).
    public var idToken: String

    /// Optional display name (only provided on first sign-in).
    public var name: String?

    public init(idToken: String, name: String? = nil) {
        self.idToken = idToken
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case name
        case idToken = "id_token"
    }
}

import Foundation

// MARK: - Contact

/// Request body for the `/qai/v1/contact` endpoint (public; no key needed).
public struct ContactRequest: Codable, Sendable {
    /// Sender name.
    public var name: String

    /// Sender email address.
    public var email: String

    /// Message subject.
    public var subject: String?

    /// Message body.
    public var message: String

    public init(name: String, email: String, message: String, subject: String? = nil) {
        self.name = name
        self.email = email
        self.message = message
        self.subject = subject
    }
}

/// Response from the contact form endpoint: `{"status": "sent"}`.
public typealias ContactResponse = StatusResponse

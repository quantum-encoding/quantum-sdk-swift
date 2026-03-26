import Foundation

// MARK: - Contact

/// Request body for the public contact form.
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

/// Response from the contact form endpoint.
public struct ContactResponse: Codable, Sendable {
    /// Status message (e.g. "ok", "sent").
    public var status: String

    /// Optional detail message.
    public var message: String?
}

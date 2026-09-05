import Foundation

// ContactRequest is declared in Account.swift.

/// Response from the contact form endpoint.
public struct ContactResponse: Codable, Sendable {
    /// Status message (e.g. "ok", "sent").
    public var status: String

    /// Optional detail message.
    public var message: String?
}

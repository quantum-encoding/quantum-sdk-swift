import Foundation

// MARK: - Learn course catalog (GET /qai/v1/courses)

/// One published course in the gateway catalog.
public struct CatalogCourse: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let author: String?
    public let version: String?
    public let level: String?
    public let tags: [String]?
    public let lessonCount: Int
    public let estimatedHours: Double?
    public let priceCents: Int
    public let currency: String?
    public let sizeBytes: Int64
    public let updatedAt: String?

    public var isFree: Bool { priceCents <= 0 }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, author, version, level, tags, currency
        case lessonCount = "lesson_count"
        case estimatedHours = "estimated_hours"
        case priceCents = "price_cents"
        case sizeBytes = "size_bytes"
        case updatedAt = "updated_at"
    }
}

public struct CourseListResponse: Codable, Sendable {
    /// Published courses; empty when the catalog object is missing or holds
    /// a literal `null`.
    @NullToEmpty public var courses: [CatalogCourse]
}

/// Signed download for a course bundle (GET /qai/v1/courses/{id}/download).
public struct CourseDownloadResponse: Codable, Sendable {
    public let url: String
    public let version: String?
    public let sizeBytes: Int64?
    public let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case url, version
        case sizeBytes = "size_bytes"
        case expiresIn = "expires_in"
    }
}

/// Result of publishing a course bundle (POST /qai/v1/courses/publish, admin).
public struct CoursePublishResponse: Codable, Sendable {
    public let published: CatalogCourse
}

/// Learn sandbox guest image manifest (GET /qai/v1/learn/guest-image):
/// per-file SHA-256 + short-lived signed download URLs.
public struct GuestImageResponse: Codable, Sendable {
    public struct File: Codable, Sendable {
        public let sha256: String
        public let size: Int64?
        public let url: String
    }
    public let version: String
    public let files: [String: File]
}

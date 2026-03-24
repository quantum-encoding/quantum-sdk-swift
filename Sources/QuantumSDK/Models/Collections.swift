import Foundation

// MARK: - Collection Types

/// A user-scoped collection (proxied through quantum-ai).
public struct Collection: Codable, Sendable {
    /// Collection ID.
    public var id: String

    /// Human-readable name.
    public var name: String

    /// Optional description.
    public var description: String?

    /// Number of documents in the collection.
    public var documentCount: Int?

    /// Owner: user ID or "shared".
    public var owner: String?

    /// Backend provider (e.g. "xai").
    public var provider: String?

    /// ISO timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, owner, provider
        case documentCount = "document_count"
        case createdAt = "created_at"
    }
}

/// A document within a collection.
public struct CollectionDocument: Codable, Sendable {
    /// File identifier.
    public var fileId: String

    /// Document name.
    public var name: String

    /// File size in bytes.
    public var sizeBytes: Int?

    /// MIME content type.
    public var contentType: String?

    /// Processing status (e.g. "completed").
    public var processingStatus: String?

    /// Document status.
    public var documentStatus: String?

    /// Whether the document has been indexed.
    public var indexed: Bool?

    /// ISO timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case name, indexed
        case fileId = "file_id"
        case sizeBytes = "size_bytes"
        case contentType = "content_type"
        case processingStatus = "processing_status"
        case documentStatus = "document_status"
        case createdAt = "created_at"
    }
}

/// A search result from collection search.
public struct CollectionSearchResult: Codable, Sendable {
    /// Matching text content.
    public var content: String

    /// Relevance score.
    public var score: Double?

    /// Source file identifier.
    public var fileId: String?

    /// Source collection identifier.
    public var collectionId: String?

    /// Arbitrary metadata.
    public var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case content, score, metadata
        case fileId = "file_id"
        case collectionId = "collection_id"
    }
}

/// Request body for collection search.
public struct CollectionSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Collection IDs to search.
    public var collectionIds: [String]

    /// Search mode (e.g. "hybrid", "semantic", "keyword").
    public var mode: String?

    /// Maximum number of results.
    public var maxResults: Int?

    public init(query: String, collectionIds: [String], mode: String? = nil, maxResults: Int? = nil) {
        self.query = query
        self.collectionIds = collectionIds
        self.mode = mode
        self.maxResults = maxResults
    }

    enum CodingKeys: String, CodingKey {
        case query, mode
        case collectionIds = "collection_ids"
        case maxResults = "max_results"
    }
}

/// Upload result for a document added to a collection.
public struct CollectionUploadResult: Codable, Sendable {
    /// File identifier assigned by the backend.
    public var fileId: String

    /// Original filename.
    public var filename: String

    /// Size in bytes.
    public var bytes: Int?

    enum CodingKeys: String, CodingKey {
        case filename, bytes
        case fileId = "file_id"
    }
}

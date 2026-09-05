import Foundation

// MARK: - Collection Types

/// A user-scoped document collection, proxied through the gateway onto the
/// upstream provider.
public struct Collection: Codable, Sendable {
    /// Collection identifier, gateway-issued.
    public var id: String

    /// Human-readable name.
    public var name: String

    /// What the collection is for.
    public var description: String?

    /// Owner: a user id, or `"shared"` for collections everyone can read.
    public var owner: String?

    /// Backend the collection lives on (e.g. `"xai"`).
    public var provider: String?

    /// The provider's own id for the collection.
    public var providerCollectionId: String?

    /// Number of documents indexed.
    public var documentCount: Int64?

    /// RFC3339 creation timestamp.
    public var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, owner, provider
        case providerCollectionId = "provider_collection_id"
        case documentCount = "document_count"
        case createdAt = "created_at"
    }
}

/// A document within a collection, as the gateway's store records it.
public struct CollectionDocument: Codable, Sendable {
    /// Document identifier, gateway-issued.
    public var id: String

    /// The collection the document belongs to.
    public var collectionId: String?

    /// The provider's own file id.
    public var fileId: String?

    /// Uploaded filename.
    public var filename: String?

    /// Indexing status. The upload route records `indexed` as soon as the
    /// provider accepts the file; no other value is written today.
    public var status: String?

    /// Number of chunks the document was split into. The upload route never
    /// sets it, so it is zero in practice.
    public var chunks: Int64?

    /// RFC3339 upload timestamp.
    public var uploadedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, filename, status, chunks
        case collectionId = "collection_id"
        case fileId = "file_id"
        case uploadedAt = "uploaded_at"
    }
}

/// One chunk matched by a collection search.
public struct CollectionSearchResult: Codable, Sendable {
    /// The matched chunk text.
    public var content: String

    /// Relevance score; results come back highest first.
    public var score: Double?

    /// Name of the collection the chunk came from.
    public var collection: String?

    /// Id of the collection the chunk came from.
    public var collectionId: String?

    /// Provider document id, when the provider reported one.
    public var documentId: String?

    /// Source filename, when the provider reported one.
    public var filename: String?

    /// Whether the chunk came from a shared collection rather than the
    /// caller's own.
    public var isShared: Bool?

    enum CodingKeys: String, CodingKey {
        case content, score, collection, filename
        case collectionId = "collection_id"
        case documentId = "document_id"
        case isShared = "is_shared"
    }
}

/// Request body for `POST /qai/v1/rag/collections/search`. There is no
/// search mode: the gateway runs one provider search across the chosen
/// collections.
public struct CollectionSearchRequest: Codable, Sendable {
    /// The search query. Required.
    public var query: String

    /// Collections to search. Empty searches every collection the caller can
    /// read, their own and shared; an empty list is omitted from the body.
    public var collectionIds: [String]

    /// Maximum chunks to return across all collections. Defaults to 10.
    public var maxChunks: Int64?

    public init(query: String, collectionIds: [String] = [], maxChunks: Int64? = nil) {
        self.query = query
        self.collectionIds = collectionIds
        self.maxChunks = maxChunks
    }

    enum CodingKeys: String, CodingKey {
        case query
        case collectionIds = "collection_ids"
        case maxChunks = "max_chunks"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decode(String.self, forKey: .query)
        collectionIds = try container.decodeIfPresent([String].self, forKey: .collectionIds) ?? []
        maxChunks = try container.decodeIfPresent(Int64.self, forKey: .maxChunks)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        if !collectionIds.isEmpty {
            try container.encode(collectionIds, forKey: .collectionIds)
        }
        try container.encodeIfPresent(maxChunks, forKey: .maxChunks)
    }
}

/// The document record an upload produces.
public typealias CollectionUploadResult = CollectionDocument

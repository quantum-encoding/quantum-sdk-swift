import Foundation

// MARK: - RAG Search

/// Request body for Vertex AI RAG search.
public struct RagSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Filter by corpus name or ID (fuzzy match). Omit to search all corpora.
    public var corpus: String?

    /// Maximum number of results to return (default 10).
    public var topK: Int?

    public init(query: String, corpus: String? = nil, topK: Int? = nil) {
        self.query = query
        self.corpus = corpus
        self.topK = topK
    }

    enum CodingKeys: String, CodingKey {
        case query, corpus
        case topK = "top_k"
    }
}

/// Legacy alias.
public typealias RAGSearchRequest = RagSearchRequest

/// A single result from RAG search.
public struct RagResult: Codable, Sendable {
    /// Source document URI.
    public var sourceUri: String?

    /// Display name of the source.
    public var sourceName: String?

    /// Matching text chunk.
    public var text: String

    /// Relevance score.
    public var score: Double

    /// Vector distance (lower is more similar).
    public var distance: Double?

    enum CodingKeys: String, CodingKey {
        case text, score, distance
        case sourceUri = "source_uri"
        case sourceName = "source_name"
    }
}

/// Legacy alias.
public typealias RAGResult = RagResult

/// Response from RAG search.
public struct RagSearchResponse: Codable, Sendable {
    /// Matching document chunks.
    public var results: [RagResult]

    /// Original search query.
    public var query: String

    /// Corpora that were searched.
    public var corpora: [String]?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case results, query, corpora
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Legacy alias.
public typealias RAGSearchResponse = RagSearchResponse

// MARK: - RAG Corpus

/// Describes an available RAG corpus.
public struct RagCorpus: Codable, Sendable {
    /// Full resource name.
    public var name: String

    /// Human-readable name.
    public var displayName: String

    /// Describes the corpus contents.
    public var description: String

    /// Corpus state (e.g. "ACTIVE").
    public var state: String

    enum CodingKeys: String, CodingKey {
        case name, description, state
        case displayName = "displayName"
    }
}

/// Legacy alias.
public typealias RAGCorpus = RagCorpus

/// Response from listing RAG corpora.
public struct RagCorporaResponse: Codable, Sendable {
    /// Available corpora.
    public var corpora: [RagCorpus]
}

// MARK: - SurrealDB RAG

/// Request body for SurrealDB-backed RAG search.
public struct SurrealRagSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Filter by documentation provider (e.g. "xai", "claude", "heygen").
    public var provider: String?

    /// Maximum number of results (default 10, max 50).
    public var limit: Int?

    public init(query: String, provider: String? = nil, limit: Int? = nil) {
        self.query = query
        self.provider = provider
        self.limit = limit
    }
}

/// Legacy alias.
public typealias SurrealRAGSearchRequest = SurrealRagSearchRequest

/// A single result from SurrealDB RAG search.
public struct SurrealRagResult: Codable, Sendable {
    /// Documentation provider.
    public var provider: String

    /// Document title.
    public var title: String

    /// Section heading.
    public var heading: String?

    /// Original source file path.
    public var sourceFile: String?

    /// Matching text chunk.
    public var content: String

    /// Cosine similarity score.
    public var score: Double

    enum CodingKeys: String, CodingKey {
        case provider, title, heading, content, score
        case sourceFile = "source_file"
    }
}

/// Legacy alias.
public typealias SurrealRAGResult = SurrealRagResult

/// Response from SurrealDB RAG search.
public struct SurrealRagSearchResponse: Codable, Sendable {
    /// Matching documentation chunks.
    public var results: [SurrealRagResult]

    /// Original search query.
    public var query: String

    /// Provider filter that was applied.
    public var provider: String?

    /// Total cost in ticks.
    public var costTicks: Int64

    /// Unique request identifier.
    public var requestId: String

    enum CodingKeys: String, CodingKey {
        case results, query, provider
        case costTicks = "cost_ticks"
        case requestId = "request_id"
    }
}

/// Legacy alias.
public typealias SurrealRAGSearchResponse = SurrealRagSearchResponse

/// A SurrealDB RAG provider.
public struct SurrealRagProvider: Codable, Sendable {
    /// Provider identifier (e.g. "xai", "claude").
    public var provider: String

    /// Number of document chunks for this provider.
    public var chunkCount: Int64?

    enum CodingKeys: String, CodingKey {
        case provider
        case chunkCount = "chunk_count"
    }
}

/// Legacy alias.
public typealias SurrealRAGProviderInfo = SurrealRagProvider

/// Parity alias matching Rust SDK naming.
public typealias SurrealRagProviderInfo = SurrealRagProvider

/// Response from listing SurrealDB RAG providers.
public struct SurrealRagProvidersResponse: Codable, Sendable {
    public var providers: [SurrealRagProvider]
}

/// Legacy alias.
public typealias SurrealRAGProvidersResponse = SurrealRagProvidersResponse

// MARK: - Collection Wrapper Types

/// Request body for creating a collection.
public struct CreateCollectionRequest: Codable, Sendable {
    /// Collection name.
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

/// Response from listing collections.
public struct CollectionsListResponse: Codable, Sendable {
    /// Available collections.
    public var collections: [Collection]
}

/// Response from listing documents in a collection.
public struct CollectionDocumentsResponse: Codable, Sendable {
    /// Documents in the collection.
    public var documents: [CollectionDocument]
}

/// Response from collection search.
public struct CollectionSearchResponse: Codable, Sendable {
    /// Search results.
    public var results: [CollectionSearchResult]
}

/// Response from deleting a collection.
public struct DeleteCollectionResponse: Codable, Sendable {
    /// Status message.
    public var message: String
}

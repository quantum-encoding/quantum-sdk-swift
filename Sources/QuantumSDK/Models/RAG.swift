import Foundation

// MARK: - Null-tolerant map decoding

// The list form, ``NullToEmpty``, lives in Models/WireDecoding.swift.

/// Decodes a JSON object keyed by string that the gateway may send as `null`
/// (a nil Go map) or omit entirely, yielding an empty dictionary in both
/// cases.
@propertyWrapper
public struct NullToEmptyMap<Value: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [String: Value]

    public init(wrappedValue: [String: Value] = [:]) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? [:] : try container.decode([String: Value].self)
    }

    public func encode(to encoder: Encoder) throws {
        try wrappedValue.encode(to: encoder)
    }
}

extension NullToEmptyMap: Equatable where Value: Equatable {}

extension KeyedDecodingContainer {
    /// A missing key decodes to an empty dictionary, the same as an explicit `null`.
    public func decode<V>(_ type: NullToEmptyMap<V>.Type, forKey key: Key) throws -> NullToEmptyMap<V> {
        try decodeIfPresent(type, forKey: key) ?? NullToEmptyMap()
    }
}

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

/// Response from RAG search. Each query bills $0.002.
public struct RagSearchResponse: Codable, Sendable {
    /// Matching document chunks, best score first. Empty (sent as `null`)
    /// when no corpus returned a chunk.
    @NullToEmpty public var results: [RagResult]

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

/// Response from listing RAG corpora. Listing is free; the list is sent as
/// `null` when no corpus exists.
public struct RagCorporaResponse: Codable, Sendable {
    /// Available corpora.
    @NullToEmpty public var corpora: [RagCorpus]

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case corpora
        case requestId = "request_id"
    }
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

    /// Document title. The gateway's query does not select it, so it is
    /// absent in practice.
    public var title: String?

    /// Section heading. The gateway's query does not select it, so it is
    /// absent in practice.
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

/// Response from SurrealDB RAG search. Each query bills $0.001.
public struct SurrealRagSearchResponse: Codable, Sendable {
    /// Matching documentation chunks, best score first. Empty (sent as
    /// `null`) when nothing matched.
    @NullToEmpty public var results: [SurrealRagResult]

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
    public var chunks: Int64
}

/// Legacy alias.
public typealias SurrealRAGProviderInfo = SurrealRagProvider

/// Alias for ``SurrealRagProvider``.
public typealias SurrealRagProviderInfo = SurrealRagProvider

/// Response from listing SurrealDB RAG providers.
public struct SurrealRagProvidersResponse: Codable, Sendable {
    /// Providers with at least one chunk, most chunks first. Empty (sent as
    /// `null`) when the table is empty.
    @NullToEmpty public var providers: [SurrealRagProvider]

    /// Unique request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case providers
        case requestId = "request_id"
    }
}

/// Legacy alias.
public typealias SurrealRAGProvidersResponse = SurrealRagProvidersResponse

// MARK: - Collection Wrapper Types

/// Request body for `POST /qai/v1/rag/collections`.
public struct CreateCollectionRequest: Codable, Sendable {
    /// Human-readable name. Required.
    public var name: String

    /// What the collection is for.
    public var description: String?

    /// Label stored on the collection record. It does not choose a backend:
    /// every collection is created on xAI regardless of the value.
    public var provider: String?

    public init(name: String, description: String? = nil, provider: String? = nil) {
        self.name = name
        self.description = description
        self.provider = provider
    }
}

/// Response from `GET /qai/v1/rag/collections`.
public struct CollectionsListResponse: Codable, Sendable {
    /// The caller's collections plus the shared ones. Sent as `null` when
    /// the caller has neither.
    @NullToEmpty public var collections: [Collection]

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case collections
        case requestId = "request_id"
    }
}

/// One collection with its documents, the shape
/// `GET /qai/v1/rag/collections/{id}` returns.
public struct CollectionDetail: Codable, Sendable {
    /// The collection itself.
    public var collection: Collection

    /// Its documents. Sent as `null` when the collection is empty.
    @NullToEmpty public var documents: [CollectionDocument]
}

/// Full response from `POST /qai/v1/rag/collections/search`.
public struct CollectionSearchResponse: Codable, Sendable {
    /// Matched chunks, highest score first.
    @NullToEmpty public var results: [CollectionSearchResult]

    /// The query that was run.
    public var query: String?

    /// How many collections were searched.
    public var collectionsSearched: Int64?

    /// Gateway request identifier.
    public var requestId: String?

    enum CodingKeys: String, CodingKey {
        case results, query
        case collectionsSearched = "collections_searched"
        case requestId = "request_id"
    }
}

/// Response from `DELETE /qai/v1/rag/collections/{id}`.
public struct DeleteCollectionResponse: Codable, Sendable {
    /// True once the collection is gone.
    public var deleted: Bool

    /// The collection that was deleted.
    public var id: String?
}

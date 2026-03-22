import Foundation

// MARK: - RAG Search

/// Request body for the `/qai/v1/rag/search` endpoint.
public struct RAGSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Corpus name or ID (optional).
    public var corpus: String?

    /// Maximum number of results.
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

/// A single RAG search result.
public struct RAGResult: Codable, Sendable {
    /// Matched text content.
    public var text: String

    /// Relevance score.
    public var score: Double

    /// Source document.
    public var source: String?
}

/// Response from the `/qai/v1/rag/search` endpoint.
public struct RAGSearchResponse: Codable, Sendable {
    /// Search results.
    public var results: [RAGResult]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case results
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

// MARK: - RAG Corpus

/// A Vertex AI RAG corpus.
public struct RAGCorpus: Codable, Sendable {
    /// Corpus resource name.
    public var name: String

    /// Display name.
    public var displayName: String

    /// Description.
    public var description: String

    /// Current state.
    public var state: String
}

// MARK: - SurrealDB RAG

/// Request body for the `/qai/v1/rag/surreal/search` endpoint.
public struct SurrealRAGSearchRequest: Codable, Sendable {
    /// Search query.
    public var query: String

    /// Provider to search (optional).
    public var provider: String?

    /// Maximum number of results.
    public var limit: Int?

    public init(query: String, provider: String? = nil, limit: Int? = nil) {
        self.query = query
        self.provider = provider
        self.limit = limit
    }
}

/// A single SurrealDB RAG search result.
public struct SurrealRAGResult: Codable, Sendable {
    /// Result ID.
    public var id: String

    /// Matched text.
    public var text: String

    /// Relevance score.
    public var score: Double

    /// Provider.
    public var provider: String

    /// Source document.
    public var source: String?
}

/// Response from the `/qai/v1/rag/surreal/search` endpoint.
public struct SurrealRAGSearchResponse: Codable, Sendable {
    /// Search results.
    public var results: [SurrealRAGResult]

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case results
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }
}

/// Information about a SurrealDB RAG provider.
public struct SurrealRAGProviderInfo: Codable, Sendable {
    /// Provider name.
    public var provider: String

    /// Number of chunks.
    public var chunkCount: Int

    enum CodingKeys: String, CodingKey {
        case provider
        case chunkCount = "chunk_count"
    }
}

/// Response from the `/qai/v1/rag/surreal/providers` endpoint.
public struct SurrealRAGProvidersResponse: Codable, Sendable {
    /// Available providers.
    public var providers: [SurrealRAGProviderInfo]
}

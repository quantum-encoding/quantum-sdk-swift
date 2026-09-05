import Foundation

// MARK: - Embed Request

/// Request body for the `/qai/v1/embeddings` endpoint. The gateway requires
/// `model` and decodes `input` as a list of strings; a bare string is a 400.
public struct EmbedRequest: Codable, Sendable {
    /// Embedding model (e.g. "text-embedding-3-small", "text-embedding-3-large").
    public var model: String

    /// Texts to embed.
    public var input: [String]

    public init(model: String, input: [String]) {
        self.model = model
        self.input = input
    }
}

// MARK: - Embed Response

/// Response from the `/qai/v1/embeddings` endpoint.
public struct EmbedResponse: Codable, Sendable {
    /// Embedding vectors, one per input string.
    public var embeddings: [[Double]]

    /// Model used.
    public var model: String

    /// Unique request ID.
    public var requestId: String

    /// Cost in ticks.
    public var costTicks: Int

    enum CodingKeys: String, CodingKey {
        case embeddings, model
        case requestId = "request_id"
        case costTicks = "cost_ticks"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        embeddings = try c.decode([[Double]].self, forKey: .embeddings)
        model = try c.decode(String.self, forKey: .model)
        requestId = try c.decodeIfPresent(String.self, forKey: .requestId) ?? ""
        costTicks = try c.decodeIfPresent(Int.self, forKey: .costTicks) ?? 0
    }
}

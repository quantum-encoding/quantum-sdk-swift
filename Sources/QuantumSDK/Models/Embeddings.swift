import Foundation

// MARK: - Embed Request

/// Request body for the `/qai/v1/embeddings` endpoint.
public struct EmbedRequest: Codable, Sendable {
    /// Model for embedding generation.
    public var model: String?

    /// Input text(s) to embed.
    public var input: EmbedInput

    public init(input: String, model: String? = nil) {
        self.model = model
        self.input = .single(input)
    }

    public init(inputs: [String], model: String? = nil) {
        self.model = model
        self.input = .multiple(inputs)
    }

    enum CodingKeys: String, CodingKey {
        case model, input
    }
}

/// Input can be a single string or array of strings.
public enum EmbedInput: Codable, Sendable {
    case single(String)
    case multiple([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .single(str)
        } else {
            self = .multiple(try container.decode([String].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .single(str):
            try container.encode(str)
        case let .multiple(arr):
            try container.encode(arr)
        }
    }
}

// MARK: - Embed Response

/// Response from the `/qai/v1/embeddings` endpoint.
public struct EmbedResponse: Codable, Sendable {
    /// Generated embeddings.
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
}
